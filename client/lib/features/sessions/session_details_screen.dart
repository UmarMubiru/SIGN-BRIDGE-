import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/api_client.dart';

class SessionDetailsScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailsScreen> createState() =>
      _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  final _apiClient = ApiClient();
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _signs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load session details
      final sessions = await _apiClient.listSessions();
      final session = sessions.firstWhere(
        (s) =>
            s['id'] == widget.sessionId || s['public_id'] == widget.sessionId,
        orElse: () => {},
      );

      // Load signs
      final signs = await _apiClient.listSigns();

      setState(() {
        _session = session.isNotEmpty ? session : null;
        _signs = signs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load session: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _startRecording(String signId, String signName) {
    // Navigate to sign recording screen
    context.push('/sessions/${widget.sessionId}/signs');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(title: Text(_session?['public_id'] ?? 'Session Details')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : _session == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.secondarySurface,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Session not found',
                      style: TextStyle(color: AppTheme.ivory, fontSize: 18),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 48 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session info card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, color: AppTheme.teal),
                              const SizedBox(width: 8),
                              Text(
                                _session!['public_id'],
                                style: const TextStyle(
                                  color: AppTheme.ivory,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Venue',
                            value: _session!['venue'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.verified,
                            label: 'Protocol',
                            value: _session!['protocol_version'] ?? 'N/A',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.videocam,
                            label: 'Recordings',
                            value:
                                '${_session!['successful_recordings'] ?? 0}/${_session!['total_recordings'] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Signs list
                    const Text(
                      'Signs to Record',
                      style: TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _signs.isEmpty
                        ? const Center(
                            child: Text(
                              'No signs available',
                              style: TextStyle(color: AppTheme.mutedText),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isDesktop ? 3 : 2,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: _signs.length,
                            itemBuilder: (context, index) {
                              final sign = _signs[index];
                              return _SignCard(
                                sign: sign,
                                onTap: () =>
                                    _startRecording(sign['id'], sign['label']),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.gold),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.mutedText, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.ivory,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SignCard extends StatelessWidget {
  final Map<String, dynamic> sign;
  final VoidCallback onTap;

  const _SignCard({super.key, required this.sign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.record_voice_over, color: AppTheme.teal, size: 24),
          const SizedBox(height: 8),
          Text(
            sign['label'] ?? 'Unknown Sign',
            style: const TextStyle(
              color: AppTheme.ivory,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Target: 10 reps',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
