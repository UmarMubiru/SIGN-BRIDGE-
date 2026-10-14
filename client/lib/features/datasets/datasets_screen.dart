import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';

class DatasetsScreen extends ConsumerStatefulWidget {
  const DatasetsScreen({super.key});

  @override
  ConsumerState<DatasetsScreen> createState() => _DatasetsScreenState();
}

class _DatasetsScreenState extends ConsumerState<DatasetsScreen> {
  bool _isLoading = true;
  bool _isLoadingRecordings = true;
  List<Map<String, dynamic>> _datasets = [];
  List<Map<String, dynamic>> _recordings = [];
  Set<String> _selectedRecordings = {};
  String? _error;
  String? _recordingsError;
  Timer? _recordingsRefreshTimer;
  bool _recordingsRequestInFlight = false;

  bool _hasUploadedVideo(Map<String, dynamic> recording) {
    final fileUrl = recording['file_url']?.toString().trim() ?? '';
    final storagePath = recording['storage_path']?.toString().trim() ?? '';
    final cloudStatus = recording['cloud_storage_status']?.toString();
    return fileUrl.isNotEmpty ||
        (storagePath.isNotEmpty && cloudStatus == 'uploaded');
  }

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _loadDatasets();
    _loadRecordings();
    // Recordings may be created from another browser or the phone client, so
    // local change notifications alone cannot keep this list current.
    _recordingsRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadRecordings(),
    );
  }

  void _onRecordingsChanged() {
    _loadRecordings();
  }

  @override
  void dispose() {
    _recordingsRefreshTimer?.cancel();
    recordingsChanged.removeListener(_onRecordingsChanged);
    super.dispose();
  }

  Future<void> _loadDatasets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ApiClient();
      final datasets = await apiClient.listDatasetVersions();

      if (mounted) {
        setState(() {
          _datasets = datasets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRecordings() async {
    if (!mounted || _recordingsRequestInFlight) return;
    _recordingsRequestInFlight = true;
    setState(() {
      _isLoadingRecordings = true;
      _recordingsError = null;
    });
    try {
      final apiClient = ApiClient();
      final recordings = await apiClient.listRecordings();

      if (mounted) {
        setState(() {
          _recordings = recordings;
          _isLoadingRecordings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordingsError = describeApiError(e);
          _isLoadingRecordings = false;
        });
      }
    } finally {
      _recordingsRequestInFlight = false;
    }
  }

  Future<void> _deleteRecording(Map<String, dynamic> recording) async {
    final recordingId = recording['id']?.toString();
    if (recordingId == null || recordingId.isEmpty) return;
    final fileName = recording['file_name']?.toString() ?? 'this recording';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: const Text('Delete recording?', style: TextStyle(color: AppTheme.ivory)),
        content: Text(
          '“$fileName” and its uploaded video will be permanently deleted. It will no longer be available in any dataset.',
          style: const TextStyle(color: AppTheme.ivory),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.ivory)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient().deleteRecording(recordingId);
      if (!mounted) return;
      setState(() {
        _recordings.removeWhere((item) => item['id']?.toString() == recordingId);
        _selectedRecordings.remove(recordingId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording and video deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete recording: ${describeApiError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.ivory),
                    onPressed: () => context.go('/dashboard'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dataset Versions',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ivory,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    text: 'Create',
                    onPressed: _showCreateDialog,
                    isSecondary: true,
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.secondarySurface),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.gold,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load datasets',
                            style: TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: AppTheme.ivory.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          AppButton(text: 'Retry', onPressed: _loadDatasets),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Keep the dataset list and recording selection in
                          // one page scroll so the lower section is reachable
                          // on short windows and phone-sized screens.
                          if (_datasets.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.folder_open,
                                    color: AppTheme.ivory,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No dataset versions yet',
                                    style: TextStyle(
                                      color: AppTheme.ivory,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create your first dataset version to export collected data',
                                    style: TextStyle(
                                      color: AppTheme.ivory.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: _datasets.map((dataset) {
                                  return _DatasetCard(
                                    dataset: dataset,
                                    onTap: () => _showDatasetDetails(dataset),
                                    onDownload: () => _downloadDataset(
                                      dataset['id'],
                                      dataset['name'],
                                      dataset['version_number'],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          Container(
                            height: 1,
                            color: AppTheme.secondarySurface,
                          ),
                          // Available recordings for dataset creation
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Available Recordings',
                                        style: TextStyle(
                                          color: AppTheme.ivory,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (_selectedRecordings.isNotEmpty)
                                        Row(
                                          children: [
                                            Text(
                                              '${_selectedRecordings.length} selected',
                                              style: const TextStyle(
                                                color: AppTheme.gold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AppButton(
                                              text: 'Create Dataset',
                                              onPressed: _showCreateDialog,
                                              isSecondary: true,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_isLoadingRecordings)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                  )
                                else if (_recordingsError != null)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Could not load recordings: $_recordingsError',
                                          style: const TextStyle(
                                            color: AppTheme.warning,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _loadRecordings,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                else if (_recordings.isEmpty)
                                  const Text(
                                    'No recordings available',
                                    style: TextStyle(color: AppTheme.mutedText),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _recordings.length,
                                    itemBuilder: (context, index) {
                                      final recording = _recordings[index];
                                      final isSelected = _selectedRecordings
                                          .contains(recording['id']);
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: CheckboxListTile(
                                              title: Text(
                                                recording['file_name'] ?? 'Unknown',
                                                style: const TextStyle(color: AppTheme.ivory),
                                              ),
                                              subtitle: Text(
                                                '${captureFormatLabel(recording['capture_format']?.toString())} • ${recording['validation_status']} • ${_hasUploadedVideo(recording) ? 'Video ready' : 'Video unavailable'}',
                                                style: const TextStyle(color: AppTheme.mutedText),
                                              ),
                                              value: isSelected,
                                              onChanged: !_hasUploadedVideo(recording)
                                                  ? null
                                                  : (bool? value) {
                                                      setState(() {
                                                        final id = recording['id'].toString();
                                                        if (value == true) {
                                                          _selectedRecordings.add(id);
                                                        } else {
                                                          _selectedRecordings.remove(id);
                                                        }
                                                      });
                                                    },
                                              activeColor: AppTheme.gold,
                                              checkColor: AppTheme.primaryBackground,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete recording and video',
                                            onPressed: () => _deleteRecording(recording),
                                            icon: const Icon(Icons.delete_outline, color: AppTheme.warning),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    if (_selectedRecordings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one recording'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => _CreateDatasetDialog(
        selectedRecordingCount: _selectedRecordings.length,
        onCreate: (data) async {
          final dialogNavigator = Navigator.of(dialogContext);
          try {
            final apiClient = ApiClient();

            // Choose the first unused sequential version. Dataset count is not
            // sufficient here because versions can have gaps after removals.
            final usedVersions = _datasets
                .map((dataset) => dataset['version_number']?.toString())
                .whereType<String>()
                .toSet();
            var nextVersion = 1;
            while (usedVersions.contains('v$nextVersion.0.0')) {
              nextVersion++;
            }
            final versionNumber = 'v$nextVersion.0.0';

            // Add selected recordings to dataset
            data['version_number'] = versionNumber;
            data['included_recordings'] = _selectedRecordings.length;
            data['total_recordings'] = _selectedRecordings.length;
            data['excluded_recordings'] = 0;
            data['export_config'] = {
              ...(data['export_config'] as Map<String, dynamic>? ?? {}),
              'recording_ids': _selectedRecordings.toList(),
            };

            await apiClient.createDatasetVersion(data);
            if (!mounted) return;
            if (dialogNavigator.mounted) {
              dialogNavigator.pop();
            }
            setState(() {
              _selectedRecordings.clear();
            });
            _loadDatasets();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dataset created successfully'),
                backgroundColor: AppTheme.success,
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to create dataset: ${describeApiError(e)}'),
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showDatasetDetails(Map<String, dynamic> dataset) {
    showDialog(
      context: context,
      builder: (context) => _DatasetDetailsDialog(dataset: dataset),
    );
  }

  void _downloadDataset(String datasetId, String name, String version) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.downloadDataset(
        datasetId,
        fileName: '${name}_${version}'.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '_',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dataset $name $version downloaded'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download dataset: ${describeApiError(e)}'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }
}

class _DatasetCard extends StatelessWidget {
  final Map<String, dynamic> dataset;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _DatasetCard({
    required this.dataset,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final exportConfig = dataset['export_config'];
    final recordingIds = exportConfig is Map
        ? exportConfig['recording_ids']
        : null;
    final canDownload = recordingIds is List && recordingIds.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder, color: AppTheme.teal, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dataset['name'] ?? 'Unnamed',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.ivory,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dataset['version_number'] ?? 'No version',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.ivory.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.download,
                        color: canDownload ? AppTheme.gold : AppTheme.mutedText,
                      ),
                      onPressed: canDownload ? onDownload : null,
                      tooltip: canDownload ? 'Download Dataset' : 'This older dataset has no saved recording selection. Create a new dataset to export videos.',
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.ivory),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatItem(
                      label: 'Total',
                      value: dataset['total_recordings']?.toString() ?? '0',
                      color: AppTheme.ivory,
                    ),
                    const SizedBox(width: 16),
                    _StatItem(
                      label: 'Included',
                      value: dataset['included_recordings']?.toString() ?? '0',
                      color: AppTheme.teal,
                    ),
                    const SizedBox(width: 16),
                    _StatItem(
                      label: 'Excluded',
                      value: dataset['excluded_recordings']?.toString() ?? '0',
                      color: AppTheme.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.ivory.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CreateDatasetDialog extends StatefulWidget {
  final int selectedRecordingCount;
  final Function(Map<String, dynamic>) onCreate;

  const _CreateDatasetDialog({
    required this.selectedRecordingCount,
    required this.onCreate,
  });

  @override
  State<_CreateDatasetDialog> createState() => _CreateDatasetDialogState();
}

class _CreateDatasetDialogState extends State<_CreateDatasetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.secondarySurface,
      title: const Text(
        'Create Dataset Version',
        style: TextStyle(color: AppTheme.ivory),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creating dataset with ${widget.selectedRecordingCount} selected recordings',
                style: const TextStyle(color: AppTheme.teal, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: AppTheme.ivory),
                  hintText: 'e.g., Initial Collection',
                  hintStyle: TextStyle(
                    color: AppTheme.ivory.withValues(alpha: 0.5),
                  ),
                ),
                style: const TextStyle(color: AppTheme.ivory),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: const TextStyle(color: AppTheme.ivory),
                  hintStyle: TextStyle(
                    color: AppTheme.ivory.withValues(alpha: 0.5),
                  ),
                ),
                style: const TextStyle(color: AppTheme.ivory),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.ivory)),
        ),
        AppButton(
          text: 'Create',
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onCreate({
                'name': _nameController.text,
                'description': _descriptionController.text,
              });
            }
          },
        ),
      ],
    );
  }
}

class _DatasetDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> dataset;

  const _DatasetDetailsDialog({required this.dataset});

  @override
  Widget build(BuildContext context) {
    final exportConfig = dataset['export_config'];
    final recordingIds = exportConfig is Map
        ? exportConfig['recording_ids']
        : null;
    final hasSavedSelection = recordingIds is List && recordingIds.isNotEmpty;
    return AlertDialog(
      backgroundColor: AppTheme.secondarySurface,
      title: Text(
        dataset['name'] ?? 'Dataset Details',
        style: const TextStyle(color: AppTheme.ivory),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Version', dataset['version_number'] ?? 'N/A'),
            _DetailRow(
              'Created',
              dataset['created_at']?.toString().split('.')[0] ?? 'N/A',
            ),
            _DetailRow(
              'Total Recordings',
              dataset['total_recordings']?.toString() ?? '0',
            ),
            _DetailRow(
              'Included',
              dataset['included_recordings']?.toString() ?? '0',
            ),
            _DetailRow(
              'Excluded',
              dataset['excluded_recordings']?.toString() ?? '0',
            ),
            if (!hasSavedSelection) ...[
              const SizedBox(height: 12),
              const Text(
                'This older dataset does not contain a saved recording selection, so it cannot be exported. Create a new dataset version with the recordings you want to include.',
                style: TextStyle(color: AppTheme.gold),
              ),
            ],
            if (dataset['description'] != null &&
                dataset['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Description',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dataset['description'].toString(),
                style: TextStyle(color: AppTheme.ivory.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(text: 'Close', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.ivory.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ivory,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
