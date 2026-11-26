import '../../../core/network/api_errors.dart';
import '../../../core/widgets/learning_controls.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../data/data_sync_service.dart';
import '../data/deck_repository.dart';

class CreateDeckPage extends ConsumerStatefulWidget {
  const CreateDeckPage({super.key});

  @override
  ConsumerState<CreateDeckPage> createState() => _CreateDeckPageState();
}

class _CreateDeckPageState extends ConsumerState<CreateDeckPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = false;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDeck() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final repository = ref.read(deckRepositoryProvider);
      final syncService = ref.read(deckSyncServiceProvider);

      final deckId = await repository.createDeckOffline(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (!mounted) return;

      unawaited(syncService.syncNow());

      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.deckDetail, arguments: deckId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create deck: ${networkErrorMessage(e)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final borderColor = colors.outlineVariant;
    final buttonColor = colors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Create deck')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colors.surface,
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Deck details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create the deck first, then add up to 50 cards inside it.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                    decoration: learningInputDecoration(
                      'Deck title',
                      helperText: 'Choose a recognizable name for your topic.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a deck title';
                      }
                      if (value.trim().runes.length > 255) {
                        return 'Title must be 255 characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_loading,
                    maxLines: 4,
                    decoration: learningInputDecoration(
                      'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  PublicVisibilityControl(
                    value: _isPublic,
                    onChanged:
                        _loading
                            ? null
                            : (value) => setState(() => _isPublic = value),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _saveDeck,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _loading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Create deck'),
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
