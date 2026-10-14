import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/api_client.dart';

class SignersScreen extends ConsumerStatefulWidget {
  const SignersScreen({super.key});

  @override
  ConsumerState<SignersScreen> createState() => _SignersScreenState();
}

class _SignersScreenState extends ConsumerState<SignersScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _signers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSigners();
  }

  Future<void> _loadSigners() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final signers = await _apiClient.listSigners();
      if (!mounted) return;
      setState(() {
        _signers = signers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load signers: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openCreateSigner() async {
    final created = await context.push<bool>('/signers/create');
    if (created == true && mounted) await _loadSigners();
  }

  Future<void> _createSession(String signerId) async {
    // Navigate to the new session creation screen
    context.push('/sessions/create?signerId=$signerId');
  }

  List<Map<String, dynamic>> get _filteredSigners {
    if (_searchQuery.isEmpty) {
      return _signers;
    }
    return _signers.where((signer) {
      final name = signer['name'].toString().toLowerCase();
      final code = signer['signer_id'].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          code.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Signers'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openCreateSigner),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                style: const TextStyle(color: AppTheme.ivory),
                decoration: InputDecoration(
                  hintText: 'Search signers...',
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

            // Signers list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    )
                  : _filteredSigners.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppTheme.secondarySurface,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No signers found',
                            style: TextStyle(
                              color: AppTheme.ivory,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openCreateSigner,
                            child: const Text(
                              'Add your first signer',
                              style: TextStyle(color: AppTheme.teal),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredSigners.length,
                      itemBuilder: (context, index) {
                        final signer = _filteredSigners[index];
                        return _SignerCard(
                          signer: signer,
                          onTap: () {
                            // Show dialog to create session or view details
                            _showSignerOptions(signer);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignerOptions(Map<String, dynamic> signer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondarySurface,
        title: Text(
          signer['name'],
          style: const TextStyle(color: AppTheme.ivory),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signer ID: ${signer['signer_id']}',
              style: const TextStyle(color: AppTheme.mutedText),
            ),
            const SizedBox(height: 8),
            Text(
              'Consent: ${signer['consent_status']}',
              style: const TextStyle(color: AppTheme.mutedText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: AppTheme.teal)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createSession(signer['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
            child: const Text(
              'Create Session',
              style: TextStyle(color: AppTheme.primaryBackground),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignerCard extends StatelessWidget {
  final Map<String, dynamic> signer;
  final VoidCallback onTap;

  const _SignerCard({super.key, required this.signer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final consentStatus = signer['consent_status'] as String;
    StatusType statusType;

    switch (consentStatus) {
      case 'consented':
        statusType = StatusType.success;
        break;
      case 'withdrawn':
        statusType = StatusType.error;
        break;
      default:
        statusType = StatusType.pending;
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
                      signer['name'],
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signer['signer_id'],
                      style: const TextStyle(
                        color: AppTheme.teal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: consentStatus.toUpperCase(), type: statusType),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _InfoChip(icon: Icons.category, label: signer['category']),
                const SizedBox(width: 8),
                if (signer['age'] != null)
                  _InfoChip(icon: Icons.cake, label: '${signer['age']} years'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.teal),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
