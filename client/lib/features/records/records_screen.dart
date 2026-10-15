import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'dart:math';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';
import '../../core/web/web_browser.dart' as browser;

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _loadRecordings();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    recordingsChanged.removeListener(_onRecordingsChanged);
    super.dispose();
  }

  void _onRecordingsChanged() {
    _loadRecordings();
  }

  void _startRealTimeUpdates() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadRecordings();
    });
  }

  Future<void> _loadRecordings() async {
    try {
      final recordings = await _apiClient.listRecordings();
      if (mounted) {
        setState(() {
          _recordings = recordings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: const NavigationBackButton(),
        title: const Text('Recordings'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppTheme.ivory),
            color: AppTheme.teal,
            onSelected: (status) {
              setState(() {
                _statusFilter = status;
              });
            },
            itemBuilder: (context) {
              return ['All', 'approved', 'pending', 'rejected'].map((status) {
                return PopupMenuItem<String>(
                  value: status,
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusFilter == status
                          ? AppTheme.gold
                          : AppTheme.ivory,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats overview
            if (!_isLoading && _recordings.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _StatCard(
                      label: 'Total',
                      value: _recordings.length.toString(),
                      color: AppTheme.ivory,
                    ),
                    _StatCard(
                      label: 'Approved',
                      value: _recordings
                          .where((r) => r['validation_status'] == 'approved')
                          .length
                          .toString(),
                      color: AppTheme.teal,
                    ),
                    _StatCard(
                      label: 'Pending',
                      value: _recordings
                          .where((r) => r['validation_status'] == 'pending')
                          .length
                          .toString(),
                      color: AppTheme.gold,
                    ),
                  ];
                  final cards = constraints.maxWidth >= 600
                      ? Row(
                          children: [
                            for (
                              var index = 0;
                              index < stats.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 16),
                              Expanded(child: stats[index]),
                            ],
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < stats.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(width: 12),
                                SizedBox(width: 160, child: stats[index]),
                              ],
                            ],
                          ),
                        );

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: cards,
                      ),
                    ),
                  );
                },
              ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                style: const TextStyle(color: AppTheme.ivory),
                decoration: InputDecoration(
                  hintText: 'Search recordings...',
                  hintStyle: const TextStyle(color: AppTheme.mutedText),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.teal),
                  filled: true,
                  fillColor: AppTheme.secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            // Records list
            Expanded(child: _buildRecordsList(isDesktop)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(bool isDesktop) {
    final filtered = _recordings.where((rec) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (rec['file_name']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          (rec['signer_id']?.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);
      final matchesStatus =
          _statusFilter == 'All' ||
          rec['validation_status']?.toString() == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.gold),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 64, color: AppTheme.secondarySurface),
            const SizedBox(height: 16),
            const Text(
              'No recordings found',
              style: TextStyle(color: AppTheme.ivory, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final recording = filtered[index];
        return _RecordingCard(
          recording: recording,
          onView: () => _viewRecording(recording),
          onDelete: () => _deleteRecording(recording['id']),
        );
      },
    );
  }

  void _viewRecording(Map<String, dynamic> recording) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlaybackDialog(recording: recording),
    );
  }

  void _deleteRecording(String recordingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: const Text(
          'Delete Recording',
          style: TextStyle(color: AppTheme.ivory),
        ),
        content: const Text(
          'Are you sure you want to delete this recording?',
          style: TextStyle(color: AppTheme.ivory),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.teal)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiClient.deleteRecording(recordingId);
        final updatedRecordings = await _apiClient.listRecordings();
        final stillExists = updatedRecordings.any(
          (recording) => recording['id']?.toString() == recordingId,
        );
        if (stillExists) {
          throw StateError(
            'The server still lists this recording after deletion.',
          );
        }
        if (mounted) {
          setState(() {
            _recordings = updatedRecordings;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}

class _VideoPlaybackDialog extends StatefulWidget {
  final Map<String, dynamic> recording;

  const _VideoPlaybackDialog({required this.recording});

  @override
  State<_VideoPlaybackDialog> createState() => _VideoPlaybackDialogState();
}

class _VideoPlaybackDialogState extends State<_VideoPlaybackDialog> {
  String? _videoUrl;
  String? _viewType;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final recordingId = widget.recording['id']?.toString();
    if (!mounted) return;
    if (recordingId == null || recordingId.isEmpty) {
      setState(
        () => _videoError = 'This recording has no uploaded video file.',
      );
      return;
    }

    try {
      _videoUrl = await ApiClient().getRecordingVideoUrl(recordingId);
    } catch (error) {
      if (mounted) {
        setState(() => _videoError = 'Could not open this video: $error');
      }
      return;
    }
    if (!mounted) return;
    _viewType =
        'recording-video-${widget.recording['id']}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      browser.registerVideoView(_viewType!, _videoUrl!);
      setState(() {});
    } catch (error) {
      setState(() => _videoError = 'Could not open this video: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      backgroundColor: AppTheme.secondarySurface,
      title: Text(
        widget.recording['file_name'] ?? 'Recording',
        style: const TextStyle(color: AppTheme.ivory),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: min(400.0, screenSize.width - 64).toDouble(),
        height: min(300.0, screenSize.height * 0.4).toDouble(),
        child: _viewType != null
            ? HtmlElementView(viewType: _viewType!)
            : _videoError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _videoError!,
                    style: const TextStyle(color: AppTheme.ivory),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: AppTheme.gold,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Video Playback',
                        style: TextStyle(color: AppTheme.ivory),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Duration: 0s',
                        style: TextStyle(color: AppTheme.mutedText),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Loading video…',
                        style: TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: AppTheme.teal)),
        ),
      ],
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final Map<String, dynamic> recording;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _RecordingCard({
    required this.recording,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = recording['validation_status'] as String? ?? 'pending';
    StatusType statusType;

    switch (status) {
      case 'approved':
        statusType = StatusType.success;
        break;
      case 'rejected':
        statusType = StatusType.error;
        break;
      default:
        statusType = StatusType.warning;
    }

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: AppTheme.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording['file_name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Signer: ${recording['signer_id'] ?? 'Unknown'}',
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: status, type: statusType),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.repeat,
                  label: captureFormatLabel(
                    recording['capture_format']?.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.camera_alt,
                  label: recording['camera_angle'] ?? 'Unknown',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.access_time,
                  label: '${recording['duration'] ?? 0}s',
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.visibility, color: AppTheme.teal),
                  onPressed: onView,
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppTheme.error),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.face_retouching_natural,
                  size: 16,
                  color: AppTheme.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _orientationSummary(recording),
                    style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  size: 16,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cloudSummary(recording),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _orientationSummary(Map<String, dynamic> recording) {
    final state = recording['orientation_status']?.toString() ?? 'pending';
    final count = recording['processed_frame_count']?.toString() ?? '0';
    switch (state) {
      case 'queued':
      case 'processing':
        return 'Analyzing video frames…';
      case 'completed':
        return 'Orientation and landmarks ready · $count frames';
      case 'failed':
        return 'Frame analysis failed: ${recording['orientation_error'] ?? 'unknown error'}';
      default:
        return 'Frame analysis pending';
    }
  }

  String _cloudSummary(Map<String, dynamic> recording) {
    final state = recording['cloud_storage_status']?.toString() ?? 'local_only';
    switch (state) {
      case 'queued':
      case 'uploading':
        return 'Uploading video directly to R2…';
      case 'uploaded':
        return 'Video stored in private R2 bucket';
      case 'failed':
        return 'Upload failed: ${recording['cloud_storage_error'] ?? 'retry from the review screen'}';
      default:
        return 'Video not uploaded';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: AppTheme.ivory, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.teal),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.teal, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
