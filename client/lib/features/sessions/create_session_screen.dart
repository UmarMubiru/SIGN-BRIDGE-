import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/app_button.dart';
import '../../core/api_client.dart';
import '../../core/constants/recording_protocol.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  final String? signerId;

  const CreateSessionScreen({super.key, this.signerId});

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _apiClient = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _selectedSigner;
  LightingCondition? _selectedLighting;
  BackgroundCondition? _selectedBackground;
  bool _isLoading = false;
  bool _isLoadingSigners = true;
  List<Map<String, dynamic>> _signers = [];

  @override
  void initState() {
    super.initState();
    _loadSigners();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSigners() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSigners = true;
    });

    try {
      final signers = await _apiClient.listSigners();
      if (!mounted) return;
      setState(() {
        _signers = signers;
        _isLoadingSigners = false;

        // Pre-select signer if provided
        if (widget.signerId != null) {
          _selectedSigner = signers.firstWhere(
            (s) => s['id'] == widget.signerId,
            orElse: () => signers.isEmpty ? {} : signers.first,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSigners = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load signers: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSigner == null ||
        _selectedLighting == null ||
        _selectedBackground == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final sessionData = {
        'signer_id': _selectedSigner!['id'],
        'venue': 'Makerere University / MUDSA',
        'protocol_version': 'v1',
        'lighting_condition': _selectedLighting!.displayName,
        'background': _selectedBackground!.displayName,
      };

      final session = await _apiClient.createSession(sessionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.push('/sessions/${session['id']}/signs');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: ${e.toString()}'),
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
        leading: const NavigationBackButton(),
        title: const Text('New Recording Session'),
      ),
      body: SafeArea(
        child: _isLoadingSigners
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                padding: const EdgeInsets.fromLTRB(16, 10, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Setup',
                        style: TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        const SizedBox(height: 14),

                      // Signer Selection
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signer',
                              style: TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: _selectedSigner,
                              decoration: InputDecoration(
                                hintText: 'Select signer',
                                hintStyle: TextStyle(
                                  color: AppTheme.ivory.withOpacity(0.5),
                                ),
                                filled: true,
                                fillColor: AppTheme.primaryBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppTheme.secondarySurface,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppTheme.secondarySurface,
                                  ),
                                ),
                              ),
                              dropdownColor: AppTheme.secondarySurface,
                              style: const TextStyle(color: AppTheme.ivory),
                              items: _signers.map((signer) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: signer,
                                  child: Text(
                                    '${signer['signer_id']} - ${signer['name']}',
                                    style: const TextStyle(
                                      color: AppTheme.ivory,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSigner = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a signer';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lighting Condition
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lighting Condition',
                              style: TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...LightingCondition.values.map((condition) {
                              return RadioListTile<LightingCondition>(
                                title: Text(
                                  condition.displayName,
                                  style: const TextStyle(color: AppTheme.ivory),
                                ),
                                value: condition,
                                groupValue: _selectedLighting,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLighting = value;
                                  });
                                },
                                activeColor: AppTheme.gold,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Background Condition
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Background',
                              style: TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...BackgroundCondition.values.map((condition) {
                              return RadioListTile<BackgroundCondition>(
                                title: Text(
                                  condition.displayName,
                                  style: const TextStyle(color: AppTheme.ivory),
                                ),
                                value: condition,
                                groupValue: _selectedBackground,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBackground = value;
                                  });
                                },
                                activeColor: AppTheme.gold,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Camera Requirements Info
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Camera Requirements',
                              style: TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '720p or higher',
                                  style: TextStyle(
                                    color: AppTheme.ivory.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.teal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '30 FPS',
                                  style: TextStyle(
                                    color: AppTheme.ivory.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start Session Button
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          text: 'START SESSION',
                          onPressed: _isLoading ? null : _createSession,
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
      ),
    );
  }
}
