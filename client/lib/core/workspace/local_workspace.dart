class LocalWorkspace {
  const LocalWorkspace({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.schemaVersion,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String rootPath;
  final int schemaVersion;
  final DateTime createdAt;
}
