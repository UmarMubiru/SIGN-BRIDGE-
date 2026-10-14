import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import 'dart:math';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';
import '../../core/web/web_browser.dart' as browser;

class SignsScreen extends ConsumerStatefulWidget {
  const SignsScreen({super.key});

  @override
  ConsumerState<SignsScreen> createState() => _SignsScreenState();
}

class _SignsScreenState extends ConsumerState<SignsScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _signs = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoading = true;
  bool _isLoadingSessions = true;
  bool _isLoadingRecordings = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _loadSigns();
    _loadSessions();
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
    // Refresh data every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadSigns();
      _loadRecordings();
    });
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _apiClient.listSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
      }
    }
  }

  Future<void> _loadRecordings() async {
    try {
      final recordings = await _apiClient.listRecordings();
      if (mounted) {
        setState(() {
          _recordings = recordings;
          _isLoadingRecordings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecordings = false;
        });
      }
    }
  }

  Future<void> _loadSigns() async {
    try {
      final signs = await _apiClient.listSigns();
      if (!mounted) return;
      setState(() {
        _signs = signs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load signs: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredSigns {
    var filtered = _signs;

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((sign) => sign['category']?.toString() == _selectedCategory)
          .toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((sign) {
        final name = sign['display_name']?.toString().toLowerCase() ?? '';
        final code = sign['sign_code']?.toString().toLowerCase() ?? '';
        final gloss = sign['gloss']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase()) ||
            code.contains(_searchQuery.toLowerCase()) ||
            gloss.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  List<String> get _categories {
    final categories = _signs
        .map((sign) => sign['category']?.toString() ?? 'Uncategorized')
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 1000
        ? 2
        : 4;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Sign Library', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            tooltip: 'Add sign',
            onPressed: _showAddSignDialog,
          ),
          _buildCategoryDropdown(),
          IconButton(
            icon: const Icon(Icons.folder, color: AppTheme.ivory),
            onPressed: () => context.go('/records'),
            tooltip: 'All Records',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats overview
            if (!_isLoading && _signs.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _StatCard(
                      label: 'Total Signs',
                      value: _signs.length.toString(),
                      color: AppTheme.ivory,
                    ),
                    _StatCard(
                      label: 'With Recordings',
                      value: _signs
                          .where(
                            (s) =>
                                _getRecordingsForSign(s['id']?.toString() ?? '')
                                    .isNotEmpty,
                          )
                          .length
                          .toString(),
                      color: AppTheme.teal,
                    ),
                    _StatCard(
                      label: 'Total Recordings',
                      value: _recordings.length.toString(),
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
                  hintText: 'Search signs...',
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

            // Signs grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : _filteredSigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books,
                            size: 64,
                            color: AppTheme.secondarySurface,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No signs found',
                            style: TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: crossAxisCount == 1 ? 1.35 : 1.2,
                      ),
                      itemCount: _filteredSigns.length,
                      itemBuilder: (context, index) {
                        final sign = _filteredSigns[index];
                        return _SignCard(
                          sign: sign,
                          recordings: _getRecordingsForSign(
                            sign['id']?.toString(),
                          ),
                          onTap: () => _handleSignTap(sign),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSignDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    var isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.secondarySurface,
          title: const Text(
            'Add sign',
            style: TextStyle(color: AppTheme.ivory),
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.ivory),
                      decoration: const InputDecoration(labelText: 'Sign name'),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter at least 2 characters'
                          : null,
                    ),
                    TextFormField(
                      controller: categoryController,
                      style: const TextStyle(color: AppTheme.ivory),
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                      ),
                    ),
                    TextFormField(
                      controller: descriptionController,
                      style: const TextStyle(color: AppTheme.ivory),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final name = nameController.text.trim();
                      final code = name
                          .toUpperCase()
                          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
                          .replaceAll(RegExp(r'^_|_$'), '');
                      try {
                        await _apiClient.createSign({
                          'sign_code': code,
                          'gloss': name,
                          'display_name': name,
                          'category': categoryController.text.trim().isEmpty
                              ? null
                              : categoryController.text.trim(),
                          'description':
                              descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          'target_formats': 3,
                        });
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        await _loadSigns();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "$name" to the sign library'),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Could not add sign: $error')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save sign'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
  }

  void _handleSignTap(Map<String, dynamic> sign) {
    final signRecordings = _getRecordingsForSign(sign['id']);
    final completedFormats = signRecordings
        .where(
          (recording) =>
              recording['validation_status'] == 'approved' &&
              (recording['file_url']?.toString().isNotEmpty ?? false),
        )
        .map((recording) => recording['capture_format']?.toString())
        .toSet();
    if (CAPTURE_FORMATS.any(
      (format) => !completedFormats.contains(format.id),
    )) {
      _navigateToRecording(sign);
    } else {
      _showRecordingsDialog(sign, signRecordings);
    }
  }

  void _navigateToRecording(Map<String, dynamic> sign) {
    // Check if there's an active session
    final activeSession = _sessions.firstWhere(
      (s) => s['status'] == 'in_progress',
      orElse: () => {},
    );

    if (activeSession.isNotEmpty) {
      // Go to recording setup with active session
      context.push(
        '/sessions/${activeSession['id']}/signs?signId=${sign['id']}',
      );
    } else if (_sessions.isNotEmpty) {
      // Show dialog to select a session
      _showSessionSelectionDialog(sign);
    } else {
      // No sessions, prompt to create one
      _showNoSessionDialog();
    }
  }

  void _showRecordingsDialog(
    Map<String, dynamic> sign,
    List<Map<String, dynamic>> recordings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: Text(
          '${sign['display_name']?.toString() ?? 'Unknown'} Recordings',
          style: const TextStyle(color: AppTheme.ivory),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: recordings.isEmpty
              ? const Center(
                  child: Text(
                    'No recordings yet',
                    style: TextStyle(color: AppTheme.mutedText),
                  ),
                )
              : ListView.builder(
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordings[index];
                    return _RecordingItem(
                      recording: recording,
                      onView: () => _viewRecording(recording),
                      onDelete: () => _deleteRecording(recording['id']),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.teal)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRecording(sign);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: const Text('Add Recording'),
          ),
        ],
      ),
    );
  }

  void _viewRecording(Map<String, dynamic> recording) {
    // Show video playback dialog
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

  void _showSessionSelectionDialog(Map<String, dynamic> sign) {
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: const Text(
          'Select a Session',
          style: TextStyle(color: AppTheme.ivory),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return ListTile(
                title: Text(
                  session['public_id'],
                  style: const TextStyle(color: AppTheme.ivory),
                ),
                subtitle: Text(
                  session['venue'] ?? 'Unknown venue',
                  style: const TextStyle(color: AppTheme.mutedText),
                ),
                onTap: () {
                  Navigator.pop(context);
                  router.push(
                    '/sessions/${session['id']}/signs?signId=${sign['id']}',
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.teal)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              router.go('/signers');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: const Text('Create New Session'),
          ),
        ],
      ),
    );
  }

  void _showNoSessionDialog() {
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: const Text(
          'No Session Found',
          style: TextStyle(color: AppTheme.ivory),
        ),
        content: const Text(
          'You need to create a session before recording. Would you like to create one now?',
          style: TextStyle(color: AppTheme.ivory),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.teal)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              router.go('/signers');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: const Text('Create Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list, color: AppTheme.ivory),
      color: AppTheme.teal,
      onSelected: (category) {
        setState(() {
          _selectedCategory = category;
        });
      },
      itemBuilder: (context) {
        return _categories.map((category) {
          return PopupMenuItem<String>(
            value: category,
            child: Text(
              category,
              style: TextStyle(
                color: _selectedCategory == category
                    ? AppTheme.gold
                    : AppTheme.ivory,
              ),
            ),
          );
        }).toList();
      },
    );
  }

  List<Map<String, dynamic>> _getRecordingsForSign(String? signId) {
    if (signId == null) return [];
    return _recordings
        .where((r) => r['sign_id']?.toString() == signId)
        .toList();
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

class _RecordingItem extends StatelessWidget {
  final Map<String, dynamic> recording;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _RecordingItem({
    required this.recording,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.secondarySurface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.videocam,
          color: recording['validation_status'] == 'approved'
              ? AppTheme.teal
              : AppTheme.gold,
        ),
        title: Text(
          recording['file_name'] ?? 'Unknown',
          style: const TextStyle(color: AppTheme.ivory),
        ),
        subtitle: Text(
          '${captureFormatLabel(recording['capture_format']?.toString())} • ${recording['validation_status']?.toString() ?? 'Unknown'}',
          style: const TextStyle(color: AppTheme.mutedText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      ),
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
            width: 100,
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

class _SignCard extends StatelessWidget {
  final Map<String, dynamic> sign;
  final List<Map<String, dynamic>> recordings;
  final VoidCallback onTap;

  const _SignCard({
    super.key,
    required this.sign,
    required this.recordings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final validRecordings = recordings
        .where(
          (r) =>
              r['capture_format'] != null &&
              r['validation_status'] == 'approved' &&
              (r['file_url']?.toString().isNotEmpty ?? false),
        )
        .toList();
    final completedCount = validRecordings
        .map((r) => r['capture_format'])
        .toSet()
        .length;
    final approvedCount = completedCount;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign['display_name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sign['sign_code']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: sign['category']?.toString() ?? 'Uncategorized',
                type: StatusType.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sign['description'] != null)
            Text(
              sign['description'],
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.videocam, size: 14, color: AppTheme.teal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$completedCount/${CAPTURE_FORMATS.length} formats',
                  style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 14, color: AppTheme.gold),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$approvedCount approved',
                  style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
