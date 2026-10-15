import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SQLite persists a row across close and reopen', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'signbridge_sqlite_smoke_',
    );
    final databasePath = '${directory.path}${Platform.pathSeparator}smoke.db';

    try {
      var database = await databaseFactoryFfi.openDatabase(databasePath);
      await database.execute('''
        CREATE TABLE smoke_records (
          id INTEGER PRIMARY KEY,
          label TEXT NOT NULL
        )
      ''');
      final insertedId = await database.insert('smoke_records', {
        'label': 'persisted locally',
      });
      expect(insertedId, 1);
      await database.close();

      database = await databaseFactoryFfi.openDatabase(databasePath);
      final rows = await database.query('smoke_records');
      expect(rows, hasLength(1));
      expect(rows.single['id'], insertedId);
      expect(rows.single['label'], 'persisted locally');
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
