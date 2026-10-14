import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../core/api_client.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _recordings = [];
  List<Map<String, dynamic>> _activities = [];
  bool _isLoadingSessions = true;
  bool _isLoadingRecordings = true;
  bool _isLoadingActivities = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _refreshDashboard();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    recordingsChanged.removeListener(_onRecordingsChanged);
    super.dispose();
  }

  void _onRecordingsChanged() {
    _refreshDashboard();
  }

  void _startRealTimeUpdates() {
    // Refresh without stacking duplicate requests when the server is busy.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _refreshDashboard();
    });
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await Future.wait([
        _loadSessions(),
        _loadRecordings(),
        _loadActivities(),
      ]);
    } finally {
      _isRefreshing = false;
    }
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

  Future<void> _loadActivities() async {
    try {
      final activities = await _apiClient.listRecentActivity();
      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  void _handleNewRecording() {
    // Navigate to the new session creation screen
    context.push('/sessions/create');
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final dateTime = DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.isNegative || difference.inSeconds < 60) {
        return 'Just now';
      }

      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return '$minutes minute${minutes == 1 ? '' : 's'} ago';
      }

      if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hour${hours == 1 ? '' : 's'} ago';
      }

      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.secondarySurface,
        elevation: 0,
        title: Row(
          children: [
            // Logo
            Image.asset(
              'assets/images/signbridge_logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gold, AppTheme.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.accessibility_new,
                    size: 24,
                    color: AppTheme.primaryBackground,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            // Welcome and dashboard title stacked
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome to SignBridge',
                    style: TextStyle(
                      color: AppTheme.ivory,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Data Collection Dashboard',
                    style: TextStyle(color: AppTheme.teal, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Navigation buttons (show labels on desktop, icons only on mobile)
          if (isDesktop) ...[
            _NavButton(
              icon: Icons.people,
              label: 'Signers',
              onTap: () => context.go('/signers'),
            ),
            _NavButton(
              icon: Icons.library_books,
              label: 'Signs',
              onTap: () => context.go('/signs'),
            ),
            _NavButton(
              icon: Icons.assessment,
              label: 'Coverage',
              onTap: () => context.go('/coverage'),
            ),
            _NavButton(
              icon: Icons.folder,
              label: 'Records',
              onTap: () => context.go('/records'),
            ),
          ] else if (screenWidth > 600) ...[
            IconButton(
              icon: const Icon(Icons.people, color: AppTheme.ivory),
              onPressed: () => context.go('/signers'),
              tooltip: 'Signers',
            ),
            IconButton(
              icon: const Icon(Icons.library_books, color: AppTheme.ivory),
              onPressed: () => context.go('/signs'),
              tooltip: 'Signs',
            ),
            IconButton(
              icon: const Icon(Icons.assessment, color: AppTheme.ivory),
              onPressed: () => context.go('/coverage'),
              tooltip: 'Coverage',
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.ivory),
              onSelected: (value) {
                if (value == 'logout') {
                  context.go('/login');
                } else {
                  context.go(value);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: '/signers', child: Text('Signers')),
                PopupMenuItem(value: '/signs', child: Text('Signs')),
                PopupMenuItem(value: '/coverage', child: Text('Coverage')),
                PopupMenuItem(value: '/records', child: Text('Records')),
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            ),
          ],
          if (screenWidth > 600) const SizedBox(width: 8),
          // Logout button (yellowish/gold)
          if (screenWidth > 600)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    context.go('/login');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.logout,
                          color: AppTheme.primaryBackground,
                          size: 20,
                        ),
                        if (isDesktop) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Logout',
                            style: TextStyle(
                              color: AppTheme.primaryBackground,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Overview
                    SizedBox(
                      width: double.infinity,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collection Progress',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ivory,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _ProgressCard(
                                    label: 'Collected',
                                    value: _recordings.length.toString(),
                                    color: AppTheme.teal,
                                  ),
                                ),
                                Expanded(
                                  child: _ProgressCard(
                                    label: 'Approved',
                                    value: _recordings
                                        .where(
                                          (r) =>
                                              r['validation_status'] ==
                                              'approved',
                                        )
                                        .length
                                        .toString(),
                                    color: AppTheme.gold,
                                  ),
                                ),
                                Expanded(
                                  child: _ProgressCard(
                                    label: 'Pending',
                                    value: _recordings
                                        .where(
                                          (r) =>
                                              r['validation_status'] ==
                                              'pending',
                                        )
                                        .length
                                        .toString(),
                                    color: AppTheme.secondarySurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ivory,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Derive the grid from the available content width so
                        // mid-sized browser windows don't squeeze six cards into
                        // a narrow row.
                        final crossAxisCount = (constraints.maxWidth / 180)
                            .floor()
                            .clamp(2, 5)
                            .toInt();
                        final childAspectRatio = switch (crossAxisCount) {
                          >= 4 => 1.25,
                          3 => 1.15,
                          _ => 1.0,
                        };
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: childAspectRatio,
                          children: [
                            _ActionCard(
                              icon: Icons.videocam,
                              label: 'New Recording',
                              isDesktop: isDesktop,
                              onTap: _handleNewRecording,
                            ),
                            _ActionCard(
                              icon: Icons.people,
                              label: 'Signers',
                              isDesktop: isDesktop,
                              onTap: () => context.go('/signers'),
                            ),
                            _ActionCard(
                              icon: Icons.library_books,
                              label: 'Sign Library',
                              isDesktop: isDesktop,
                              onTap: () => context.go('/signs'),
                            ),
                            _ActionCard(
                              icon: Icons.assessment,
                              label: 'Coverage',
                              isDesktop: isDesktop,
                              onTap: () => context.go('/coverage'),
                            ),
                            _ActionCard(
                              icon: Icons.cloud_download,
                              label: 'Datasets',
                              isDesktop: isDesktop,
                              onTap: () => context.go('/datasets'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Connection Status
                    AppCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_done,
                            color: AppTheme.teal,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connection Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.ivory,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Online - Connected to server',
                                  style: TextStyle(
                                    color: AppTheme.teal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Activity
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.ivory,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: _isLoadingActivities
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: AppTheme.gold,
                                ),
                              ),
                            )
                          : _activities.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No recent activity',
                                style: TextStyle(color: AppTheme.mutedText),
                              ),
                            )
                          : Column(
                              children: _activities
                                  .take(10)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final activity = entry.value;
                                    final eventType =
                                        activity['event_type']?.toString() ??
                                        '';
                                    final icon = eventType.contains('deleted')
                                        ? Icons.delete_outline
                                        : eventType.contains('approved')
                                        ? Icons.check_circle
                                        : eventType.contains('dataset')
                                        ? Icons.folder
                                        : Icons.videocam;
                                    return Column(
                                      children: [
                                        _ActivityItem(
                                          key: ValueKey(activity['id']),
                                          icon: icon,
                                          title:
                                              activity['message']?.toString() ??
                                              'Activity',
                                          subtitle:
                                              activity['details']?.toString() ??
                                              '',
                                          time: _formatTime(
                                            activity['created_at'],
                                          ),
                                        ),
                                        if (index <
                                            _activities.take(10).length - 1)
                                          const Divider(
                                            color: AppTheme.primaryBackground,
                                          ),
                                      ],
                                    );
                                  })
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProgressCard({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.ivory, fontSize: 14),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDesktop;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.isDesktop,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isDesktop ? 48 : 40, color: AppTheme.gold),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.ivory,
                fontSize: isDesktop ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.ivory, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: AppTheme.ivory,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(foregroundColor: AppTheme.ivory),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ivory,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.teal, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
