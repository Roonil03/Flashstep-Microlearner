import 'library_heading.dart';
import '../../../app/theme/study_colors.dart';
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

    final buttonColor = colors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Create deck')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _pageInset(context),
            8,
            _pageInset(context),
            12,
          ),
          child: SizedBox(
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
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            _pageInset(context),
            16,
            _pageInset(context),
            24,
          ),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LibraryHeading(
                    title: 'Deck details',
                    description:
                        'Create the deck first, then add up to 50 cards inside it.',
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '01 / Name your topic',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.studyTone(StudyArea.library).accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const Divider(height: 32),
                  Text(
                    '02 / Choose visibility',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.studyTone(StudyArea.library).accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PublicVisibilityControl(
                    value: _isPublic,
                    onChanged:
                        _loading
                            ? null
                            : (value) => setState(() => _isPublic = value),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _pageInset(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 1080 ? (width - 1048) / 2 : 16;
}
