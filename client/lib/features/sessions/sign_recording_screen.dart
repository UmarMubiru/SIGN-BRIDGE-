import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';

class SignRecordingScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? signId;

  const SignRecordingScreen({super.key, required this.sessionId, this.signId});

  @override
  ConsumerState<SignRecordingScreen> createState() =>
      _SignRecordingScreenState();
}

class _SignRecordingScreenState extends ConsumerState<SignRecordingScreen> {
  final _apiClient = ApiClient();

  Map<String, dynamic>? _sessionData;
  Map<String, dynamic>? _signerData;
  List<Map<String, dynamic>> _signs = [];
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoading = true;
  final TextEditingController _signNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _loadData();
  }

  void _onRecordingsChanged() {
    _loadData(showLoading: false);
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load session data
      final session = await _apiClient.getSession(widget.sessionId);

      // Load signer data
      final signer = await _apiClient.getSigner(session['signer_id']);

      // Load all signs
      final signs = await _apiClient.listSigns();

      // Load recordings for this session
      final recordings = await _apiClient.listRecordings();

      if (!mounted) return;
      setState(() {
        _sessionData = session;
        _signerData = signer;
        _signs = signs;
        _recordings = recordings
            .where((r) => r['session_id'] == widget.sessionId)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    recordingsChanged.removeListener(_onRecordingsChanged);
    _signNameController.dispose();
    super.dispose();
  }

  List<String> _getCompletedFormats(String signId) {
    return _recordings
        .where(
          (r) =>
              r['sign_id'] == signId &&
              r['validation_status'] == 'approved' &&
              r['file_url'] != null &&
              r['file_url'].toString().isNotEmpty,
        )
        .map((r) => r['capture_format']?.toString() ?? '')
        .where((format) => CAPTURE_FORMATS.any((f) => f.id == format))
        .toSet()
        .toList();
  }

  String? _getNextFormat(String signId) {
    final completed = _getCompletedFormats(signId);
    for (final format in CAPTURE_FORMATS) {
      if (!completed.contains(format.id)) return format.id;
    }
    return null;
  }

  Future<void> _startRecording(String signId) async {
    // Validate required data before navigating
    if (_sessionData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session data not available'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_signerData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signer data not available'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final nextFormat = _getNextFormat(signId);
    if (nextFormat == null) return;

    // Get the sign label from the sign data
    final sign = _signs.firstWhere((s) => s['id'] == signId, orElse: () => {});
    final signLabel = sign['display_name'] ?? sign['sign_code'] ?? 'Unknown';

    await context.push(
      '/recording/setup',
      extra: {
        'sessionId': widget.sessionId,
        'signId': signId,
        'captureFormat': nextFormat,
        'lighting': _sessionData!['lighting_condition'],
        'background': _sessionData!['background'],
        'signerId': _signerData!['signer_id'],
        'signLabel': signLabel,
      },
    );

    // The recording and review routes pop back to this still-mounted screen.
    // Fetch the saved repetition so the next card state advances immediately.
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _addSign() async {
    final signName = _signNameController.text.trim();

    if (signName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a sign name'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      // Create new sign
      final signData = {
        'sign_code': signName.toUpperCase().replaceAll(' ', '_'),
        'gloss': signName,
        'display_name': signName,
        'target_formats': 3,
      };

      final newSign = await _apiClient.createSign(signData);

      setState(() {
        _signs.add(newSign);
        _signNameController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign "$signName" added'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add sign: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signsToDisplay = widget.signId == null
        ? _signs
        : _signs
              .where((sign) => sign['id']?.toString() == widget.signId)
              .toList();
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        leading: const NavigationBackButton(),
        title: const Text('Sign Recording', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session Info
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session: ${_sessionData?['public_id'] ?? 'Unknown'}',
                            style: const TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Signer: ${_signerData?['signer_id']} - ${_signerData?['name']}',
                            style: TextStyle(
                              color: AppTheme.ivory.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                Icons.light_mode,
                                color: AppTheme.gold,
                                size: 16,
                              ),
                              Text(
                                _sessionData?['lighting_condition'] ??
                                    'Unknown',
                                style: TextStyle(
                                  color: AppTheme.ivory.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Icon(
                                Icons.wallpaper,
                                color: AppTheme.teal,
                                size: 16,
                              ),
                              Text(
                                _sessionData?['background'] ?? 'Unknown',
                                style: TextStyle(
                                  color: AppTheme.ivory.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Add Sign Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Sign',
                            style: TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _signNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter sign name (e.g., Hello)',
                                    hintStyle: TextStyle(
                                      color: AppTheme.ivory.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.primaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: AppTheme.ivory),
                                ),
                              ),
                              const SizedBox(width: 12),
                              AppButton(text: 'ADD', onPressed: _addSign),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Signs List
                    const Text(
                      'Signs to Record',
                      style: TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...signsToDisplay.map((sign) {
                      final completedFormats = _getCompletedFormats(sign['id']);
                      final nextFormat = _getNextFormat(sign['id']);
                      final isComplete = nextFormat == null;

                      return _SignProgressCard(
                        sign: sign,
                        completedFormats: completedFormats,
                        nextFormat: nextFormat,
                        isComplete: isComplete,
                        onTap: () => _startRecording(sign['id']),
                      );
                    }).toList(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SignProgressCard extends StatelessWidget {
  final Map<String, dynamic> sign;
  final List<String> completedFormats;
  final String? nextFormat;
  final bool isComplete;
  final VoidCallback onTap;

  const _SignProgressCard({
    required this.sign,
    required this.completedFormats,
    required this.nextFormat,
    required this.isComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: isComplete ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sign['display_name'] ?? sign['sign_code'] ?? 'Unknown',
                    style: const TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (isComplete)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.teal,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress indicator
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completedFormats.length / CAPTURE_FORMATS.length,
                      backgroundColor: AppTheme.secondarySurface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? AppTheme.teal : AppTheme.gold,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${completedFormats.length} / ${CAPTURE_FORMATS.length}',
                  style: TextStyle(
                    color: AppTheme.ivory.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Required capture formats
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: CAPTURE_FORMATS
                  .map(
                    (format) => Chip(
                      avatar: Icon(
                        completedFormats.contains(format.id)
                            ? Icons.check_circle
                            : Icons.videocam,
                        size: 16,
                        color: completedFormats.contains(format.id)
                            ? AppTheme.teal
                            : AppTheme.gold,
                      ),
                      label: Text(format.label),
                      backgroundColor: AppTheme.secondarySurface,
                      labelStyle: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),

            if (!isComplete) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.videocam, color: AppTheme.gold, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Next: ${captureFormatById(nextFormat)?.label ?? 'Complete'}',
                      style: TextStyle(
                        color: AppTheme.ivory.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
