import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/providers.dart';
import '../../settings/presentation/account_sections.dart';

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

  Widget _manualRecovery() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reportHeading('Submit directly on GitHub'),
          const Text(
            'You can submit this report yourself while the bot is unavailable. '
            'First check existing GitHub Issues for earlier attempts, including '
            'attempts before reopening the app. A previous attempt may already be queued. '
            'Sign in to GitHub, paste the title and report body, review them for '
            'private information, then submit the public issue under your GitHub account. '
            'Opening GitHub does not submit anything. Your fields stay here. '
            'Report text is copied to your clipboard only when you tap a copy button.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyReport(title: true),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy title'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyReport(title: false),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy report body'),
              ),
              OutlinedButton.icon(
                onPressed: _openingGitHub ? null : _openGitHub,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open GitHub issue form'),
              ),
            ],
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
    padding: const EdgeInsets.only(bottom: 16),
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
                      const AccountSectionHeader(
                        title: 'Before you post',
                        icon: Icons.bug_report_outlined,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reports are posted publicly to GitHub. Include only information you want everyone to see. No personal or diagnostic data is attached automatically.',
                      ),
                      const SizedBox(height: 20),
                      _reportHeading('The issue'),
                      _field('Title (required)', _title, 5, 120, lines: 1),
                      _field('Description (required)', _description, 20, 4000),
                      _reportHeading('What happened'),
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
