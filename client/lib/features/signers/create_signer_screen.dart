import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../app/widgets/app_button.dart';
import '../../app/widgets/app_card.dart';
import '../../core/api_client.dart';

class CreateSignerScreen extends ConsumerStatefulWidget {
  const CreateSignerScreen({super.key});

  @override
  ConsumerState<CreateSignerScreen> createState() => _CreateSignerScreenState();
}

class _CreateSignerScreenState extends ConsumerState<CreateSignerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _educationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  final _apiClient = ApiClient();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _educationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleCreateSigner() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final signerData = {
          'name': _nameController.text.trim(),
          'category': _categoryController.text.trim(),
          'age': int.tryParse(_ageController.text),
          'gender': _genderController.text.trim(),
          'education_level': _educationController.text.trim(),
          'notes': _notesController.text.trim(),
        };

        await _apiClient.createSigner(signerData);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signer created successfully!'),
              backgroundColor: AppTheme.teal,
            ),
          );
          // Return a result so the existing list route can refresh safely.
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create signer: ${e.toString()}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
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
        title: const Text('Create Signer'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 24,
              vertical: isDesktop ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signer Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ivory,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: AppTheme.ivory),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person, color: AppTheme.teal),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter name';
                          }
                          if (value.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      TextFormField(
                        controller: _categoryController,
                        style: const TextStyle(color: AppTheme.ivory),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g., student, teacher, community_member',
                          prefixIcon: Icon(
                            Icons.category,
                            color: AppTheme.teal,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Age
                      TextFormField(
                        controller: _ageController,
                        style: const TextStyle(color: AppTheme.ivory),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age (optional)',
                          hintText: 'Enter age',
                          prefixIcon: Icon(Icons.cake, color: AppTheme.teal),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gender
                      TextFormField(
                        controller: _genderController,
                        style: const TextStyle(color: AppTheme.ivory),
                        decoration: const InputDecoration(
                          labelText: 'Gender (optional)',
                          hintText: 'e.g., male, female, other',
                          prefixIcon: Icon(Icons.wc, color: AppTheme.teal),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Education Level
                      TextFormField(
                        controller: _educationController,
                        style: const TextStyle(color: AppTheme.ivory),
                        decoration: const InputDecoration(
                          labelText: 'Education Level (optional)',
                          hintText: 'e.g., primary, secondary, university',
                          prefixIcon: Icon(Icons.school, color: AppTheme.teal),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        style: const TextStyle(color: AppTheme.ivory),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Additional information',
                          prefixIcon: Icon(Icons.note, color: AppTheme.teal),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          text: 'Create Signer',
                          onPressed: _handleCreateSigner,
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
