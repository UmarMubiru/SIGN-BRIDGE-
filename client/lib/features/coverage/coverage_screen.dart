import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';

class CoverageScreen extends ConsumerStatefulWidget {
  const CoverageScreen({super.key});

  @override
  ConsumerState<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends ConsumerState<CoverageScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _signs = [];
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    recordingsChanged.addListener(_onRecordingsChanged);
    _loadData();
  }

  void _onRecordingsChanged() {
    _loadData();
  }

  @override
  void dispose() {
    recordingsChanged.removeListener(_onRecordingsChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final signs = await _apiClient.listSigns();
      final recordings = await _apiClient.listRecordings();
      if (mounted) {
        setState(() {
          _signs = signs;
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
        title: const Text('Coverage'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Progress
                _buildOverallProgress(),
                const SizedBox(height: 32),
                // Sign Coverage Grid
                const Text(
                  'Sign Coverage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivory,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSignCoverageGrid(isDesktop),
                const SizedBox(height: 32),
                // Breakdown by Status
                const Text(
                  'Status Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivory,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusBreakdown(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallProgress() {
    // Calculate actual progress from real data
    final collected = _signs.fold<int>(
      0,
      (sum, sign) => sum + _formatsForSign(sign['id']).length,
    );
    final target = _signs.length * CAPTURE_FORMATS.length;
    final progress = target > 0 ? collected / target : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ivory,
                ),
              ),
              Text(
                '$collected / $target samples',
                style: const TextStyle(
                  color: AppTheme.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.secondarySurface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            minHeight: 12,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% complete',
            style: const TextStyle(color: AppTheme.ivory, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCoverageGrid(bool isDesktop) {
    // Calculate coverage for each sign from real data
    final signCoverage = _signs.map((sign) {
      final signId = sign['id'];
      final collected = _formatsForSign(signId).length;
      final target = CAPTURE_FORMATS.length;
      final progress = target > 0 ? collected / target : 0.0;
      final isComplete = collected >= target;

      return {
        'sign': sign,
        'collected': collected,
        'target': target,
        'progress': progress,
        'isComplete': isComplete,
      };
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 5 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: signCoverage.length,
      itemBuilder: (context, index) {
        final coverage = signCoverage[index];
        final sign = coverage['sign'] as Map<String, dynamic>;
        final collected = coverage['collected'] as int;
        final target = coverage['target'] as int;
        final progress = coverage['progress'] as double;
        final isComplete = coverage['isComplete'] as bool;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sign['display_name'] ?? sign['sign_code'] ?? 'Unknown',
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isComplete)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.teal,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.secondarySurface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? AppTheme.teal : AppTheme.gold,
                ),
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '$collected / $target',
                style: const TextStyle(color: AppTheme.teal, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Set<String> _formatsForSign(dynamic signId) => _recordings
      .where(
        (r) =>
            r['sign_id'] == signId &&
            r['validation_status'] == 'approved' &&
            r['file_url'] != null &&
            r['file_url'].toString().isNotEmpty,
      )
      .map((r) => r['capture_format']?.toString() ?? '')
      .where((id) => CAPTURE_FORMATS.any((format) => format.id == id))
      .toSet();

  Widget _buildStatusBreakdown() {
    // Calculate actual status breakdown from recordings
    final included = _recordings.where((r) => r['status'] == 'included').length;
    final review = _recordings
        .where(
          (r) =>
              r['status'] == 'review_pending' ||
              r['status'] == 'quality_passed',
        )
        .length;
    final validation = _recordings
        .where((r) => r['status'] == 'validation_pending')
        .length;
    final excluded = _recordings
        .where(
          (r) => r['status'] == 'excluded' || r['status'] == 'quality_failed',
        )
        .length;

    final statuses = [
      {'status': 'Included', 'count': included, 'color': AppTheme.teal},
      {'status': 'Review', 'count': review, 'color': AppTheme.gold},
      {'status': 'Validation', 'count': validation, 'color': AppTheme.warning},
      {'status': 'Excluded', 'count': excluded, 'color': AppTheme.error},
    ];

    return AppCard(
      child: Column(
        children: [
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      status['status'].toString(),
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${status['count']}',
                    style: const TextStyle(
                      color: AppTheme.teal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
