import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/study_colors.dart';
import '../../../core/network/providers.dart';

typedef _ReportDraft =
    ({
      String title,
      String description,
      String reproduction,
      String expected,
      String actual,
    });

class BugReportPage extends ConsumerStatefulWidget {
  const BugReportPage({super.key});

  @override
  ConsumerState<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends ConsumerState<BugReportPage> {
  static const _maxUncertainDrafts = 32;
  static final _githubIssueUrl = Uri.parse(
    'https://github.com/Roonil03/Flashstep-Microlearner/issues/new',
  );
  final _form = GlobalKey<FormState>();
  final _reproductionField = GlobalKey<FormFieldState<String>>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reproduction = TextEditingController();
  final _expected = TextEditingController();
  final _actual = TextEditingController();
  final _uncertainDrafts = <_ReportDraft>{};
  bool _sending = false;
  bool _confirming = false;
  bool _loadingSession = true;
  bool _manualRecoveryAvailable = false;
  bool _uncertainDraftsOverflow = false;
  bool _openingGitHub = false;
  bool _browserFailed = false;
  bool _showReproduction = false;
  String? _manualMessage;
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
    if (_sending || _confirming || _loadingSession) {
      return;
    }
    if (!_showReproduction && _reproduction.text.trim().runes.length > 3000) {
      setState(() => _showReproduction = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _form.currentState?.validate();
        final fieldContext = _reproductionField.currentContext;
        if (fieldContext != null) {
          Scrollable.ensureVisible(
            fieldContext,
            alignment: 0.2,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
      return;
    }
    if (!_form.currentState!.validate()) return;
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
      _manualRecoveryAvailable = false;
      _manualMessage = null;
      _browserFailed = false;
    });
    final draft = (
      title: _title.text.trim(),
      description: _description.text.trim(),
      reproduction: _reproduction.text.trim(),
      expected: _expected.text.trim(),
      actual: _actual.text.trim(),
    );
    final hadUncertainDelivery =
        _uncertainDraftsOverflow || _uncertainDrafts.contains(draft);
    var deliveryMayHaveStarted = false;
    var definitiveRejection = false;
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
      // A lost response may conceal a queued workflow for this exact draft.
      deliveryMayHaveStarted = true;
      final response = await http
          .post(
            ref.read(apiClientProvider).uri('/bug-reports'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title': draft.title,
              'description': draft.description,
              'reproduction': draft.reproduction,
              'expected': draft.expected,
              'actual': draft.actual,
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
        if (_isBotUnavailable(response)) {
          definitiveRejection = true;
          if (hadUncertainDelivery) {
            throw const _ReportFailure(
              'An earlier attempt may already have queued this report. '
              'Check existing GitHub Issues before filing manually. '
              'Wait one minute and retry the same report if needed.',
            );
          }
          setState(() => _manualRecoveryAvailable = true);
          throw const _ReportFailure(
            'The reporting bot is unavailable for this attempt. '
            'Check existing GitHub Issues for earlier attempts before filing manually.',
          );
        }
        if (const [
          400,
          401,
          403,
          413,
          422,
          429,
        ].contains(response.statusCode)) {
          definitiveRejection = true;
        }
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
            'Could not confirm delivery. Check existing GitHub Issues, wait one minute, '
                'and retry the same report if needed. An earlier attempt may already be queued.',
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
                  'Delivery was not confirmed. Check existing GitHub Issues, wait one minute, '
                  'and retry the same report if needed. An earlier attempt may already be queued.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Could not confirm delivery. Check your connection and existing GitHub Issues '
                  'before retrying the same report. An earlier attempt may already be queued.',
        );
      }
    } finally {
      if (deliveryMayHaveStarted && !definitiveRejection) {
        if (_uncertainDrafts.length < _maxUncertainDrafts) {
          _uncertainDrafts.add(draft);
        } else if (!_uncertainDrafts.contains(draft)) {
          // Never evict an uncertain draft and risk allowing its duplicate.
          // After the bounded history fills, guard all drafts on this page.
          _uncertainDraftsOverflow = true;
        }
      }
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isBotUnavailable(http.Response response) {
    if (response.statusCode != 503) return false;
    try {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> && data['code'] == 'bot_unavailable';
    } on FormatException {
      return false;
    }
  }

  String _manualReportBody() {
    String section(String heading, String value) {
      final text = value.trim().isEmpty ? 'Not provided' : value.trim();
      // Keep entered Markdown, HTML and mentions literal when pasted on GitHub.
      final longest = RegExp(r'`+')
          .allMatches(text)
          .fold<int>(
            2,
            (length, match) =>
                match[0]!.length > length ? match[0]!.length : length,
          );
      final fence = List.filled(longest + 1, '`').join();
      return '### $heading\n\n$fence\n$text\n$fence';
    }

    return [
      section('Description', _description.text),
      section('Steps to reproduce (optional)', _reproduction.text),
      section('Expected behavior', _expected.text),
      section('Actual behavior', _actual.text),
    ].join('\n\n');
  }

  Future<void> _copyReport({required bool title}) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              title
                  ? _title.text.trim().replaceAll('@', '＠')
                  : _manualReportBody(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _manualMessage =
            title
                ? 'Title copied. Paste it into the GitHub issue title.'
                : 'Report body copied. Paste it into the GitHub issue description.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _manualMessage = 'Could not copy. Please try again.');
    }
  }

  Future<void> _openGitHub() async {
    setState(() {
      _openingGitHub = true;
      _browserFailed = false;
    });
    try {
      // Never put report text, tokens, or account details into this URL.
      if (!await launchUrl(
        _githubIssueUrl,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _browserFailed = true);
    } finally {
      if (mounted) setState(() => _openingGitHub = false);
    }
  }

  Widget _manualRecovery() {
    final tone = context.studyTone(StudyArea.account);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tone.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _reportHeading('Submit directly on GitHub'),
            _recoveryStep('1. Check for an existing report'),
            const Text(
              'Check existing GitHub Issues, including attempts before reopening '
              'the app. An earlier attempt may already be queued.',
            ),
            const SizedBox(height: 20),
            _recoveryStep('2. Open GitHub and sign in'),
            const Text('You will post the issue under your GitHub account.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openingGitHub ? null : _openGitHub,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open GitHub issue form'),
              style: OutlinedButton.styleFrom(foregroundColor: tone.ink),
            ),
            const SizedBox(height: 20),
            _recoveryStep('3. Copy, paste, and review'),
            const Text(
              'Copy each part when you need it, then paste it into GitHub. '
              'Remove private details before submitting the public issue.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyReport(title: true),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy title'),
                  style: OutlinedButton.styleFrom(foregroundColor: tone.ink),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyReport(title: false),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy report body'),
                  style: OutlinedButton.styleFrom(foregroundColor: tone.ink),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Only the copy buttons use your clipboard. Opening GitHub does not '
              'submit anything. Your draft stays here.',
            ),
            if (_manualMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_manualMessage!)),
            ],
            if (_browserFailed) ...[
              const SizedBox(height: 12),
              const Text(
                'Could not open your browser. Open this address manually:',
              ),
              SelectableText(_githubIssueUrl.toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recoveryStep(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    int minimum,
    int maximum, {
    required String example,
    int lines = 2,
    Key? fieldKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: !_sending && !_confirming && _success == null,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 8,
        maxLength: maximum,
        textCapitalization: TextCapitalization.sentences,
        textInputAction:
            lines == 1 ? TextInputAction.next : TextInputAction.newline,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          helperText: example,
          helperMaxLines: 4,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) {
          if (!_manualRecoveryAvailable) return;
          setState(() {
            _manualRecoveryAvailable = false;
            _manualMessage = null;
            _browserFailed = false;
            _error = null;
          });
        },
        validator: (value) {
          final length = (value ?? '').trim().runes.length;
          if (length < minimum) return 'Enter at least $minimum characters.';
          if (length > maximum) return 'Use $maximum characters or fewer.';
          return null;
        },
      ),
    );
  }

  Widget _reportHeading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.studyTone(StudyArea.account);
    final fieldsEnabled = !_sending && !_confirming && _success == null;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Report a bug')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: tone.fill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Public GitHub report',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: tone.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Leave out passwords and personal details. '
                              'No diagnostics are attached automatically.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: tone.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _reportHeading('Where it happened'),
                      const Text(
                        'All fields are required unless marked optional.',
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'Short title',
                        _title,
                        5,
                        120,
                        lines: 1,
                        example: 'Example: Start review does nothing.',
                      ),
                      _field(
                        'Screen and action',
                        _description,
                        20,
                        4000,
                        lines: 3,
                        example: 'Example: On Home, I tapped Start review.',
                      ),
                      const Divider(height: 32),
                      _reportHeading('What you saw'),
                      _field(
                        'What happened',
                        _actual,
                        5,
                        2000,
                        example:
                            'Example: The loading spinner never goes away.',
                      ),
                      _field(
                        'What you expected',
                        _expected,
                        5,
                        2000,
                        example: 'Example: The review screen should open.',
                      ),
                      MergeSemantics(
                        child: Semantics(
                          expanded: _showReproduction,
                          child: OutlinedButton.icon(
                            onPressed:
                                fieldsEnabled
                                    ? () => setState(
                                      () =>
                                          _showReproduction =
                                              !_showReproduction,
                                    )
                                    : null,
                            icon: Icon(
                              _showReproduction ? Icons.remove : Icons.add,
                            ),
                            label: Text(
                              _showReproduction
                                  ? 'Hide steps (optional)'
                                  : 'Add steps to repeat it (optional)',
                            ),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        ),
                      ),
                      if (_showReproduction) ...[
                        const SizedBox(height: 16),
                        _field(
                          'Steps to repeat it',
                          _reproduction,
                          0,
                          3000,
                          lines: 3,
                          example:
                              'List the taps or actions that lead to the problem.',
                          fieldKey: _reproductionField,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'You’ll confirm before anything is posted.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      if (_manualRecoveryAvailable) ...[
                        const SizedBox(height: 16),
                        _manualRecovery(),
                      ],
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
