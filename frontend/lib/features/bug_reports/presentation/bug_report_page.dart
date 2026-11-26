import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/providers.dart';

class BugReportPage extends ConsumerStatefulWidget {
  const BugReportPage({super.key});

  @override
  ConsumerState<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends ConsumerState<BugReportPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reproduction = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  bool _sending = false;
  bool _confirming = false;
  bool _loadingSession = true;
  String? _accountId;
  String? _accountToken;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _readSession();
  }

  Future<void> _readSession() async {
    try {
      final storage = ref.read(sessionStorageProvider);
      final accountId = await storage.readUserId();
      final token = await storage.readToken();
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _accountToken = token;
        _loadingSession = false;
        if (accountId == null ||
            accountId.isEmpty ||
            token == null ||
            token.isEmpty) {
          _error = 'Sign in to report a bug.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingSession = false;
          _error =
              'Could not read your session. Sign in again to report a bug.';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _reproduction,
      _expected,
      _actual,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending ||
        _confirming ||
        _loadingSession ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            scrollable: true,
            title: const Text('Post this report publicly?'),
            content: const Text(
              'The text you entered will be sent to GitHub and published as a public issue in '
              'Roonil03/Flashstep-Microlearner by our bot. Anyone can read or copy it. '
              'Remove passwords, email addresses, names, and other private information before posting. '
              'No account details, logs, device identifiers, or learning data are attached automatically.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Review report'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post publicly'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final storage = ref.read(sessionStorageProvider);
      final userId = await storage.readUserId();
      final token = await storage.readToken();
      if (token == null ||
          token.isEmpty ||
          userId == null ||
          userId.isEmpty ||
          token != _accountToken ||
          userId != _accountId) {
        throw const _ReportFailure(
          'Your account changed. Reopen this page after signing in.',
        );
      }
      final response = await http
          .post(
            ref.read(apiClientProvider).uri('/bug-reports'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              'reproduction': _reproduction.text.trim(),
              'expected': _expected.text.trim(),
              'actual': _actual.text.trim(),
              'public_confirmed': true,
            }),
          )
          .timeout(const Duration(seconds: 25));
      // A response may belong to a session that was replaced while in flight.
      if (!mounted) return;
      if (await storage.readUserId() != userId ||
          await storage.readToken() != token) {
        throw const _ReportFailure(
          'Your account changed. Sign in again before submitting.',
        );
      }
      if (response.statusCode != 202) {
        final message = switch (response.statusCode) {
          400 => 'Check the report fields and try again.',
          401 => 'Your session expired. Sign in again to report a bug.',
          403 =>
            'You do not have permission to submit this report. Sign in again and try again.',
          413 => 'This report is too large. Shorten the fields and try again.',
          422 => 'Check the report fields and try again.',
          429 =>
            'Report limit reached. Wait before trying again (up to 24 hours).',
          _ =>
            'Could not confirm delivery. Wait one minute and retry the same report safely.',
        };
        throw _ReportFailure(message);
      }
      if (!mounted) return;
      setState(() {
        _success =
            'Report queued for public posting on GitHub. Posting may take a few minutes.';
      });
    } on _ReportFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Delivery was not confirmed. Wait one minute and retry the same report safely.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Could not reach the server. Check your connection and retry the same report safely.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int minimum,
    int maximum, {
    int lines = 4,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_sending && !_confirming && _success == null,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 8,
        maxLength: maximum,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          final length = (value ?? '').trim().runes.length;
          if (length < minimum) return 'Enter at least $minimum characters.';
          if (length > maximum) return 'Use $maximum characters or fewer.';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Report a Bug')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Before you post',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reports are posted publicly to GitHub. Include only information you want everyone to see. No personal or diagnostic data is attached automatically.',
                      ),
                      const SizedBox(height: 20),
                      _field('Title (required)', _title, 5, 120, lines: 1),
                      _field('Description (required)', _description, 20, 4000),
                      _field(
                        'Steps to reproduce (optional)',
                        _reproduction,
                        0,
                        3000,
                      ),
                      _field(
                        'Expected behavior (required)',
                        _expected,
                        5,
                        2000,
                      ),
                      _field('Actual behavior (required)', _actual, 5, 2000),
                      if (_error != null || _success != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error ?? _success!,
                            style: TextStyle(
                              color:
                                  _error == null
                                      ? null
                                      : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        onPressed:
                            _loadingSession ||
                                    (_accountId?.isEmpty ?? true) ||
                                    (_accountToken?.isEmpty ?? true) ||
                                    _sending ||
                                    _confirming ||
                                    _success != null
                                ? null
                                : _submit,
                        icon:
                            _sending
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.bug_report_outlined),
                        label: Text(
                          _sending ? 'Submitting report…' : 'Review and submit',
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

class _ReportFailure implements Exception {
  const _ReportFailure(this.message);
  final String message;
}
