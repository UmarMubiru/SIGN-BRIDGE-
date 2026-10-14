import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/api_client.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await _apiClient.listSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sessions: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Collection Sessions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 64,
                            color: AppTheme.secondarySurface,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No sessions yet',
                            style: TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            text: 'Create Session',
                            onPressed: () {
                              context.go('/signers');
                            },
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return _SessionCard(
                          session: session,
                          onTap: () {
                            // Navigate to sign recording screen
                            context.push('/sessions/${session['id']}/signs');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () {
          _showCreateSessionDialog();
        },
        child: const Icon(Icons.add, color: AppTheme.primaryBackground),
      ),
    );
  }

  void _showCreateSessionDialog() {
    // Navigate to the new session creation screen
    context.push('/sessions/create');
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const _SessionCard({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = session['status'] as String;
    final totalRecordings = session['total_recordings'] as int;
    final successfulRecordings = session['successful_recordings'] as int;
    final venue = session['venue'] as String;
    final protocol = session['protocol_version'] as String;

    StatusType statusType;
    switch (status.toLowerCase()) {
      case 'completed':
        statusType = StatusType.success;
        break;
      case 'cancelled':
        statusType = StatusType.error;
        break;
      case 'in_progress':
        statusType = StatusType.warning;
        break;
      default:
        statusType = StatusType.info;
    }

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
                      session['public_id'],
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: status.toUpperCase(), type: statusType),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.verified, size: 14, color: AppTheme.teal),
                const SizedBox(width: 4),
                Text(
                  'Protocol $protocol',
                  style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.videocam, size: 14, color: AppTheme.gold),
                const SizedBox(width: 4),
                Text(
                  '$successfulRecordings/$totalRecordings recordings',
                  style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
