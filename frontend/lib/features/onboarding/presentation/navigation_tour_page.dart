import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/learning_controls.dart';

class TourScene {
  final int step;
  final String title;
  final String path;
  final String instruction;
  const TourScene(this.step, this.title, this.path, this.instruction);
}

const navigationTourScenes = <TourScene>[
  TourScene(
    1,
    'Create a new deck',
    'Home → Create deck',
    'Choose Create deck on Home. Give your topic a recognizable title, then create the deck before adding cards.',
  ),
  TourScene(
    2,
    'Make individual cards',
    'Browse decks → Open deck → Front / Back',
    'Write a question in Front and its answer in Back. Save card adds it to this deck. You can edit cards later from their actions menu.',
  ),
  TourScene(
    3,
    'Import cards from CSV',
    'Open deck → Import CSV',
    'Import CSV adds cards to an existing deck. Use exactly Front,Back as the header. Check the preview before confirming. A deck holds up to 50 cards; a deck with 2 cards has space for 48 more.',
  ),
  TourScene(
    4,
    'Browse your decks',
    'Home → Browse decks',
    'Browse decks opens your library. Search by title, open a deck to see its cards, or choose Browse public decks to discover shared decks.',
  ),
  TourScene(
    5,
    'Add a public deck',
    'Browse decks → Public decks → Add to my decks',
    'Part 1 of 2: adding a public deck creates a separate editable copy in your library. Browsing and downloading public decks need internet. Your own decks work offline.',
  ),
  TourScene(
    5,
    'Publish your own deck',
    'Create deck / Deck actions → Edit → Make this deck public',
    'Part 2 of 2: enable Make this deck public on your own deck, then save. Other learners can discover it after sync. Keep it off for a private deck.',
  ),
  TourScene(
    6,
    'Customize your personal copy',
    'Browse decks → Open copied deck → Deck / Card actions → Edit',
    'Open the downloaded copy in your library. Edit its title, description, or card content using the actions menus. Your edits do not change the original public deck.',
  ),
  TourScene(
    7,
    'Review your decks',
    'Home → Start review → Choose deck',
    'Select a deck with available cards. Think of the answer, choose Show answer, then rate Again, Hard, Good, or Easy. Your ratings guide future reviews.',
  ),
  TourScene(
    8,
    'View learning analytics',
    'Home → Analytics',
    'Open Analytics to see learning progress, reviews, retention, and due cards. Choose 7, 30, or 90 days to change the reporting range. Analytics reflects synced learning data.',
  ),
  TourScene(
    9,
    'Adjust daily limits',
    'Home → Settings → System Settings',
    'Open Settings, then System Settings. Daily review limit controls cards per day (1–500). Selective review chooses recommended decks. Review all cards overrides daily limits and due dates. Replay this guide from Settings → Relearn app navigation.',
  ),
];

/// Presentation only: this route does not import any repositories or providers.
/// Every example is in memory and every preview callback is a harmless no-op.
class NavigationTourPage extends StatefulWidget {
  final int initialScene;
  final Future<void> Function(int scene)? onProgress;
  final Future<void> Function()? onDismiss;
  const NavigationTourPage({
    super.key,
    this.initialScene = 0,
    this.onProgress,
    this.onDismiss,
  });
  @override
  State<NavigationTourPage> createState() => _NavigationTourPageState();
}

class _NavigationTourPageState extends State<NavigationTourPage> {
  late int _scene;
  final _target = GlobalKey();
  final _instructions = GlobalKey();
  double _viewportHeight = 0;
  final _nextFocus = FocusNode(debugLabel: 'Tour next step');
  Future<void> _writes = Future<void>.value();
  bool _closing = false;
  bool _allowPop = false;
  Size? _size;
  double? _textScale;

  @override
  void initState() {
    super.initState();
    _scene = widget.initialScene.clamp(0, navigationTourScenes.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nextFocus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (_size != size || _textScale != scale) {
      _size = size;
      _textScale = scale;
      _reveal();
    }
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _target.currentContext;
      if (!mounted || targetContext == null) return;
      final targetBox = targetContext.findRenderObject() as RenderBox?;
      final instructionContext = _instructions.currentContext;
      final instructionBox =
          instructionContext?.findRenderObject() as RenderBox?;
      // Keep the explanation readable when a large preview cannot fit beside it.
      final fits =
          (targetBox?.size.height ?? 0) +
              (instructionBox?.size.height ?? 0) +
              36 <=
          _viewportHeight;
      Scrollable.ensureVisible(
        fits ? targetContext : (instructionContext ?? targetContext),
        duration: Duration.zero,
        alignmentPolicy:
            fits
                ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _move(int offset) {
    if (_closing) return;
    final next = (_scene + offset).clamp(0, navigationTourScenes.length - 1);
    if (next == _scene) return;
    setState(() => _scene = next);
    _writes = _writes.then((_) async {
      try {
        await widget.onProgress?.call(next);
      } catch (_) {
        /* Guide storage must not block navigation. */
      }
    });
    _reveal();
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _writes;
    try {
      await widget.onDismiss?.call();
    } catch (_) {
      /* Nonfatal local preference failure. */
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _nextFocus.dispose();
    super.dispose();
  }

  static void _noop() {}
  Widget _field(String label, String value) => TextFormField(
    key: ValueKey('$label-$_scene'),
    initialValue: value,
    readOnly: true,
    decoration: learningInputDecoration(label),
  );
  Widget _action(IconData icon, String label) =>
      LearningAction(icon: icon, label: label, onPressed: _noop);
  Widget _preview() {
    final widgets = switch (_scene) {
      0 => <Widget>[
        _action(Icons.add_circle_outline, 'Create deck'),
        _field('Deck title', 'Everyday Spanish'),
        FilledButton(onPressed: _noop, child: const Text('Create deck')),
      ],
      1 => <Widget>[
        _field('Front', 'How do you say hello?'),
        _field('Back', 'Hola'),
        FilledButton(onPressed: _noop, child: const Text('Save card')),
      ],
      2 => <Widget>[
        _action(Icons.upload_file_outlined, 'Import CSV'),
        const Text('CSV example: Front,Back\nHello,Hola'),
        const Text(
          'Preview before import • 2 / 50 cards used • 48 spaces left',
        ),
      ],
      3 => <Widget>[
        _action(Icons.explore_outlined, 'Browse decks'),
        _field('Search decks', 'Spanish'),
        const ListTile(
          title: Text('Everyday Spanish'),
          subtitle: Text('2 cards • Private deck'),
        ),
        _action(Icons.public, 'Browse public decks'),
      ],
      4 => <Widget>[
        const ListTile(
          title: Text('Everyday Spanish'),
          subtitle: Text('Public deck • 2 cards'),
        ),
        _action(Icons.download_rounded, 'Add to my decks'),
      ],
      5 => <Widget>[
        PublicVisibilityControl(value: true, onChanged: (_) {}),
        FilledButton(onPressed: _noop, child: const Text('Save changes')),
      ],
      6 => <Widget>[
        _action(Icons.edit_outlined, 'Deck actions → Edit'),
        _field('Deck title', 'My Spanish practice'),
        _action(Icons.edit_outlined, 'Card actions → Edit'),
        _field('Front', 'My own question'),
        _field('Back', 'My own answer'),
      ],
      7 => <Widget>[
        _action(Icons.play_circle_outline, 'Start review'),
        const ListTile(
          title: Text('Everyday Spanish'),
          subtitle: Text('2 cards available'),
        ),
        FilledButton(onPressed: _noop, child: const Text('Show answer')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rating in ['Again', 'Hard', 'Good', 'Easy'])
              OutlinedButton(onPressed: _noop, child: Text(rating)),
          ],
        ),
      ],
      8 => <Widget>[
        _action(Icons.bar_chart_outlined, 'Analytics'),
        AnalyticsRangeControl(currentValue: 30, onChanged: (_) {}),
        const Text(
          'Example progress: 12 reviews • 80% retention • 2 cards due',
        ),
      ],
      _ => <Widget>[
        _action(Icons.settings_outlined, 'Settings → System Settings'),
        DailyReviewLimitTile(limit: 25, onTap: _noop),
        SwitchListTile.adaptive(
          value: true,
          onChanged: (_) {},
          title: const Text('Use selective review decks'),
          subtitle: const Text('Show recommended decks'),
        ),
        SwitchListTile.adaptive(
          value: false,
          onChanged: (_) {},
          title: const Text('Review all cards'),
          subtitle: const Text(
            'When enabled, ignores daily limits and due dates',
          ),
        ),
      ],
    };
    return ExcludeFocus(
      child: AbsorbPointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in widgets)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: item),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = navigationTourScenes[_scene];
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape):
              () => unawaited(_close()),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('App navigation guide'),
            leading: IconButton(
              tooltip: 'Exit guide',
              icon: const Icon(Icons.close),
              onPressed: _closing ? null : _close,
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportHeight = constraints.maxHeight;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Safe preview • Examples are never saved',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        header: true,
                        child: Text(
                          'Step ${scene.step} of 9: ${scene.title}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(scene.path),
                      const SizedBox(height: 12),
                      Card(
                        key: _instructions,
                        color: scheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            scene.instruction,
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                      // The connector is in the same scroll layout as its instruction and
                      // target, so it stays attached through resizing and text scaling.
                      SizedBox(
                        height: 36,
                        child: CustomPaint(
                          painter: TourArrowPainter(scheme.primary),
                        ),
                      ),
                      Container(
                        key: _target,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.primary, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _preview(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _closing ? null : _close,
                    child: const Text('Skip tour'),
                  ),
                  OutlinedButton(
                    onPressed: _scene == 0 || _closing ? null : () => _move(-1),
                    child: const Text('Back'),
                  ),
                  FilledButton(
                    focusNode: _nextFocus,
                    onPressed:
                        _closing
                            ? null
                            : () {
                              if (_scene == navigationTourScenes.length - 1) {
                                unawaited(_close());
                              } else {
                                _move(1);
                              }
                            },
                    child: Text(
                      _scene == navigationTourScenes.length - 1
                          ? 'Finish'
                          : 'Next',
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

class TourArrowPainter extends CustomPainter {
  final Color color;
  const TourArrowPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height - 5), paint);
    canvas.drawPath(
      Path()
        ..moveTo(x - 7, size.height - 13)
        ..lineTo(x, size.height - 5)
        ..lineTo(x + 7, size.height - 13),
      paint,
    );
  }

  @override
  bool shouldRepaint(TourArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
