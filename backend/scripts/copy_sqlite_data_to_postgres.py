"""Copy application rows from the legacy SQLite file into configured PostgreSQL.

Run from backend/ after confirming DATABASE_URL targets the intended database.
The source SQLite file is only read. PostgreSQL writes are transactional, and
existing rows with matching primary keys must be identical or the copy aborts.
"""

from __future__ import annotations

import json
import sqlite3
import sys
from datetime import date, datetime
from enum import Enum
from pathlib import Path
from typing import Any

from sqlalchemy import MetaData, Table, and_, create_engine, insert, select, text
from sqlalchemy.engine import Connection

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings
from app.core.database import Base
from app import models  # noqa: F401 - register all application tables on Base.metadata


SOURCE_DB = Path(__file__).resolve().parents[1] / "signbridge.db"

# Fields introduced by revisions 011-014. SQLite revision 010 does not have
# them; these are the same initial values used by the schema migrations.
LEGACY_DEFAULTS: dict[str, dict[str, Any]] = {
    "recordings": {
        "cue_markers": [],
        "orientation_status": "pending",
        "orientation_error": None,
        "processed_frame_count": 0,
        "cloud_storage_status": "local_only",
        "cloud_storage_error": None,
        "cloud_object_key": None,
        "mime_type": None,
        "storage_path": None,
    }
}


def canonical(value: Any) -> Any:
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, bytes):
        return {"bytes_hex": value.hex()}
    if isinstance(value, dict):
        return {str(key): canonical(item) for key, item in sorted(value.items())}
    if isinstance(value, (list, tuple)):
        return [canonical(item) for item in value]
    return value


def same_value(left: Any, right: Any) -> bool:
    return json.dumps(canonical(left), sort_keys=True, separators=(",", ":")) == json.dumps(
        canonical(right), sort_keys=True, separators=(",", ":")
    )


def source_engine_for(path: Path):
    # Use SQLite's read-only URI mode so this transfer cannot alter the source.
    uri = path.resolve().as_uri() + "?mode=ro"
    return create_engine(
        "sqlite+pysqlite://",
        creator=lambda: sqlite3.connect(uri, uri=True),
    )


def transfer_table(
    source: Connection,
    destination: Connection,
    source_table: Table,
    destination_table: Table,
) -> tuple[int, int]:
    source_columns = set(source_table.c.keys())
    destination_columns = set(destination_table.c.keys())
    missing_destination = source_columns - destination_columns
    if missing_destination:
        raise RuntimeError(
            f"{source_table.name} has source columns absent from PostgreSQL: "
            f"{sorted(missing_destination)}"
        )

    common_columns = [column.name for column in source_table.columns if column.name in destination_columns]
    primary_key_columns = [column.name for column in destination_table.primary_key.columns]
    if not primary_key_columns or not set(primary_key_columns).issubset(source_columns):
        raise RuntimeError(f"Cannot safely identify rows in {source_table.name} by primary key")

    inserted = 0
    already_present = 0
    rows = source.execute(select(source_table)).mappings()
    for source_row in rows:
        values = {name: source_row[name] for name in common_columns}
        for column in destination_table.columns:
            if column.name in values:
                continue
            if column.name in LEGACY_DEFAULTS.get(source_table.name, {}):
                values[column.name] = LEGACY_DEFAULTS[source_table.name][column.name]
            elif column.nullable or column.server_default is not None or column.autoincrement:
                continue
            else:
                raise RuntimeError(
                    f"No safe value for required PostgreSQL column "
                    f"{source_table.name}.{column.name}"
                )

        identity = and_(
            *(
                destination_table.c[name] == values[name]
                for name in primary_key_columns
            )
        )
        existing = destination.execute(
            select(destination_table).where(identity)
        ).mappings().first()
        if existing is None:
            destination.execute(insert(destination_table).values(**values))
            inserted += 1
            existing = destination.execute(
                select(destination_table).where(identity)
            ).mappings().one()
        else:
            already_present += 1

        mismatched = [
            name
            for name in common_columns
            if not same_value(source_row[name], existing[name])
        ]
        if mismatched:
            raise RuntimeError(
                f"Data mismatch in {source_table.name} for a primary key; "
                "the PostgreSQL transaction has been rolled back."
            )

    return inserted, already_present


def main() -> None:
    if not SOURCE_DB.is_file():
        raise SystemExit(f"SQLite source not found: {SOURCE_DB}")
    if not settings.DATABASE_URL.lower().startswith("postgresql"):
        raise SystemExit("DATABASE_URL must target PostgreSQL; no data was copied.")

    source_engine = source_engine_for(SOURCE_DB)
    destination_engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    source_metadata = MetaData()
    destination_metadata = MetaData()

    try:
        with source_engine.connect() as source:
            source_metadata.reflect(bind=source)
            source_names = set(source_metadata.tables)
            source_names.discard("alembic_version")
            source_counts = {
                name: source.execute(text(f'SELECT COUNT(*) FROM "{name}"')).scalar_one()
                for name in sorted(source_names)
            }
            nonempty_names = {name for name, count in source_counts.items() if count}

            with destination_engine.begin() as destination:
                destination_metadata.reflect(bind=destination)
                destination_names = set(destination_metadata.tables)
                missing_tables = nonempty_names - destination_names
                if missing_tables:
                    raise RuntimeError(
                        "Nonempty SQLite tables missing from PostgreSQL: "
                        f"{sorted(missing_tables)}"
                    )

                ordered_names = [
                    table.name
                    for table in Base.metadata.sorted_tables
                    if table.name in nonempty_names
                ]
                ordered_names.extend(sorted(nonempty_names - set(ordered_names)))
                results: dict[str, tuple[int, int]] = {}
                for name in ordered_names:
                    results[name] = transfer_table(
                        source,
                        destination,
                        source_metadata.tables[name],
                        destination_metadata.tables[name],
                    )

                for name, expected_count in source_counts.items():
                    if not expected_count:
                        continue
                    actual_count = destination.execute(
                        text(
                            "SELECT COUNT(*) FROM "
                            + destination_engine.dialect.identifier_preparer.quote(name)
                        )
                    ).scalar_one()
                    if actual_count < expected_count:
                        raise RuntimeError(
                            f"Post-copy count mismatch in {name}; transaction rolled back."
                        )

        total_source = sum(source_counts.values())
        total_inserted = sum(inserted for inserted, _ in results.values())
        total_preexisting = sum(existing for _, existing in results.values())
        print(f"sqlite_source_rows={total_source}")
        print(f"postgres_rows_inserted={total_inserted}")
        print(f"identical_rows_already_present={total_preexisting}")
        print("copied_tables=" + ",".join(sorted(results)))
        print("copy_and_row_value_verification=passed")
    finally:
        source_engine.dispose()
        destination_engine.dispose()


if __name__ == "__main__":
    main()
