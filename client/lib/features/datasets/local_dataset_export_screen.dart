import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../core/workspace/local_dataset_export_service.dart';
import '../../core/workspace/android_workspace_transfer.dart';
import '../../core/workspace/local_recording_service.dart';
import '../../core/workspace/local_workspace.dart';
import '../../core/workspace/workspace_service.dart';

class LocalDatasetExportScreen extends ConsumerStatefulWidget {
  const LocalDatasetExportScreen({super.key});

  @override
  ConsumerState<LocalDatasetExportScreen> createState() =>
      _LocalDatasetExportScreenState();
}

class _LocalDatasetExportScreenState
    extends ConsumerState<LocalDatasetExportScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isExporting = false;
  DatasetExportProgress? _exportProgress;
  String? _recordingsWorkspacePath;
  Future<List<LocalWorkspaceRecording>>? _recordingsFuture;
  Future<List<File>>? _datasetsFuture;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _export(LocalWorkspace workspace) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIds.isEmpty) {
      _showMessage(
        name.isEmpty ? 'Enter a dataset name.' : 'Select at least one video.',
      );
      return;
    }
    setState(() {
      _isExporting = true;
      _exportProgress = const DatasetExportProgress(stage: 'preparing');
    });
    try {
      final file = await LocalDatasetExportService().createWorkspaceDataset(
        workspace: workspace,
        recordingIds: _selectedIds.toList(),
        datasetName: name,
        onProgress: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
      );
      _nameController.clear();
      _selectedIds.clear();
      _refreshDatasets(workspace);
      _showMessage(
        'Dataset created: ${p.basename(file.path)}. Use Download in the dataset list to save a copy.',
      );
    } catch (error) {
      _showMessage('Dataset export failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = null;
        });
      }
    }
  }

  void _refreshDatasets(LocalWorkspace workspace) {
    setState(() {
      _datasetsFuture = LocalDatasetExportService().listDatasets(workspace);
    });
  }

  Future<void> _downloadDataset(File file) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await AndroidWorkspaceTransferService().exportDatasetZip(
          sourcePath: file.path,
          fileName: p.basename(file.path),
        );
        if (result == null) return;
        final copied = result.sha256ByRelativePath[''];
        final expected = await sha256.bind(file.openRead()).first;
        if (copied != expected.toString()) {
          throw StateError('The downloaded ZIP failed SHA-256 verification.');
        }
        _showMessage(
          'Dataset copied to the selected folder as ${result.name}.',
        );
      } catch (error) {
        _showMessage('Could not download dataset: $error');
      }
      return;
    }
    final location = await getSaveLocation(
      suggestedName: p.basename(file.path),
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP archive', extensions: ['zip']),
      ],
      confirmButtonText: 'Download Dataset',
    );
    if (location == null || !mounted) return;
    try {
      await file.copy(location.path);
      _showMessage('Dataset downloaded to ${location.path}');
    } catch (error) {
      _showMessage('Could not download dataset: $error');
    }
  }

  Future<void> _deleteDataset(File file, LocalWorkspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete dataset?'),
        content: Text('Delete ${p.basename(file.path)} from this workspace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
      _refreshDatasets(workspace);
      _showMessage('Dataset deleted.');
    } catch (error) {
      _showMessage('Could not delete dataset: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = ref.watch(activeWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(title: const Text('Export Dataset')),
      body: SafeArea(
        child: workspaceState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _Message('Could not load local workspace: $error'),
          data: (workspace) => workspace == null
              ? const _Message(
                  'Create or open a local workspace before exporting videos.',
                )
              : _buildWorkspace(workspace),
        ),
      ),
    );
  }

  Widget _buildWorkspace(LocalWorkspace workspace) {
    if (_recordingsWorkspacePath != workspace.rootPath) {
      _recordingsWorkspacePath = workspace.rootPath;
      _selectedIds.clear();
      _recordingsFuture = LocalRecordingService().listRecordings(workspace);
      _datasetsFuture = LocalDatasetExportService().listDatasets(workspace);
    }
    return FutureBuilder<List<LocalWorkspaceRecording>>(
      future: _recordingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message('Could not read recordings: ${snapshot.error}');
        }
        final recordings = snapshot.data ?? const <LocalWorkspaceRecording>[];
        final available = recordings.where((item) => item.videoExists).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DatasetList(
              future: _datasetsFuture!,
              onDownload: _downloadDataset,
              onDelete: (file) => _deleteDataset(file, workspace),
            ),
            const SizedBox(height: 20),
            const Text(
              'Build a downloadable dataset from local videos',
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Platform.isWindows || Platform.isAndroid
                  ? 'Choose a name and videos to include. Portable ZIPs contain video files, recording metadata, annotations, sampled JPG frames, and face/hand landmarks. Analysis runs locally and can take time for long videos. Participant names and demographics are excluded; speaker links use local pseudonyms. Each dataset is saved here and can be downloaded or deleted above.'
                  : 'Choose a name and videos to include. Portable ZIPs contain video files, recording metadata, and annotations. Frame and landmark analysis is supported in Windows and Android releases. Participant names and demographics are excluded; speaker links use local pseudonyms. Each dataset is saved here and can be downloaded or deleted above.',
              style: TextStyle(color: AppTheme.ivory.withValues(alpha: 0.75)),
            ),
            if (_isExporting) ...[
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _exportProgress?.message ?? 'Processing dataset…',
                            style: const TextStyle(color: AppTheme.ivory),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _exportProgress?.fraction,
                      color: AppTheme.gold,
                      backgroundColor: AppTheme.ivory.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Frame extraction and landmark detection run on this device. Keep SignBridge open while processing.',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              enabled: !_isExporting,
              style: const TextStyle(color: AppTheme.ivory),
              decoration: const InputDecoration(
                labelText: 'Dataset name',
                hintText: 'e.g. Dataset 2',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Videos (${available.length})',
                    style: const TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isExporting
                      ? null
                      : () => setState(() {
                          if (_selectedIds.length == available.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds
                              ..clear()
                              ..addAll(available.map((item) => item.id));
                          }
                        }),
                  child: Text(
                    _selectedIds.length == available.length
                        ? 'Clear selection'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            if (available.isEmpty)
              const AppCard(
                child: Text(
                  'No local videos are available in this workspace yet.',
                  style: TextStyle(color: AppTheme.ivory),
                ),
              )
            else
              for (final recording in recordings)
                AppCard(
                  child: CheckboxListTile(
                    value:
                        recording.videoExists &&
                        _selectedIds.contains(recording.id),
                    onChanged: !recording.videoExists || _isExporting
                        ? null
                        : (checked) => setState(() {
                            if (checked == true) {
                              _selectedIds.add(recording.id);
                            } else {
                              _selectedIds.remove(recording.id);
                            }
                          }),
                    activeColor: AppTheme.gold,
                    checkColor: AppTheme.primaryBackground,
                    title: Text(
                      recording.fileName,
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                    subtitle: Text(
                      '${recording.recordingType} · ${recording.reviewStatus}${recording.videoExists ? '' : ' · video missing'}',
                      style: const TextStyle(color: AppTheme.mutedText),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isExporting || available.isEmpty
                  ? null
                  : () => _export(workspace),
              icon: _isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isExporting
                    ? _exportProgress?.message ?? 'Preparing dataset…'
                    : 'CREATE DATASET ZIP (${_selectedIds.length})',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DatasetList extends StatelessWidget {
  const _DatasetList({
    required this.future,
    required this.onDownload,
    required this.onDelete,
  });

  final Future<List<File>> future;
  final ValueChanged<File> onDownload;
  final ValueChanged<File> onDelete;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Created datasets',
          style: TextStyle(
            color: AppTheme.ivory,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<File>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(
                'Could not list datasets: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              );
            }
            final datasets = snapshot.data ?? const <File>[];
            if (datasets.isEmpty) {
              return const Text(
                'Datasets you create will appear here.',
                style: TextStyle(color: AppTheme.mutedText),
              );
            }
            return Column(
              children: [
                for (final file in datasets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.archive_outlined,
                      color: AppTheme.teal,
                    ),
                    title: Text(
                      p.basename(file.path),
                      style: const TextStyle(color: AppTheme.ivory),
                    ),
                    subtitle: Text(
                      _fileSize(file.lengthSync()),
                      style: const TextStyle(color: AppTheme.mutedText),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Download dataset',
                          onPressed: () => onDownload(file),
                          icon: const Icon(
                            Icons.download,
                            color: AppTheme.gold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete dataset',
                          onPressed: () => onDelete(file),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  static String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.ivory),
      ),
    ),
  );
}
