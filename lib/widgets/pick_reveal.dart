import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

enum RevealChoice { answer, skip }

/// Full-screen, class-facing reveal of the called student.
///
/// When [shuffleFrom] has more than one name, the screen cycles through them,
/// slows down and lands on [picked] with a short vibration. Returns the
/// teacher's choice, or [RevealChoice.skip] if they back out.
Future<RevealChoice> showPickReveal(
  BuildContext context, {
  required String picked,
  List<String> shuffleFrom = const [],
  String? note,
}) async {
  final result = await Navigator.of(context).push<RevealChoice>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PickRevealScreen(
        picked: picked,
        names: shuffleFrom,
        note: note,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  return result ?? RevealChoice.skip;
}

class _PickRevealScreen extends StatefulWidget {
  const _PickRevealScreen({
    required this.picked,
    required this.names,
    required this.note,
  });

  final String picked;
  final List<String> names;
  final String? note;

  @override
  State<_PickRevealScreen> createState() => _PickRevealScreenState();
}

class _PickRevealScreenState extends State<_PickRevealScreen>
    with SingleTickerProviderStateMixin {
  static const _ticks = 18;

  late final bool _shuffles = widget.names.length > 1;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late bool _landed = !_shuffles;

  @override
  void initState() {
    super.initState();
    if (_shuffles) {
      _controller.forward().whenComplete(() {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() => _landed = true);
      });
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _currentName() {
    if (_landed) return widget.picked;
    final names = widget.names;
    final pickedIndex =
        names.indexOf(widget.picked).clamp(0, names.length - 1);
    // Start so the last tick lands exactly on the picked name.
    final start = (pickedIndex - _ticks) % names.length;
    final t = Curves.easeOutCubic.transform(_controller.value);
    return names[(start + (t * _ticks).floor()) % names.length];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Scale the name with the screen so it reads from across a classroom.
    final nameSize = (size.shortestSide * 0.11).clamp(34.0, 76.0);

    return PopScope(
      canPop: _landed,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Brand.navy,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xs),
                    child: AnimatedOpacity(
                      opacity: _landed ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        tooltip: 'Close',
                        color: Colors.white70,
                        onPressed: _landed
                            ? () => Navigator.pop(context, RevealChoice.skip)
                            : null,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.xl,
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) =>
                            _NameBlock(
                              name: _currentName(),
                              landed: _landed,
                              nameSize: nameSize,
                              caption: _landed
                                  ? widget.note
                                  : 'Picking a student…',
                            ),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _landed ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_landed,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.page,
                        0,
                        Space.page,
                        Space.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              key: const Key('letAnswer'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: Brand.amber,
                                foregroundColor: Brand.navy,
                              ),
                              onPressed: () => Navigator.pop(
                                context,
                                RevealChoice.answer,
                              ),
                              child: const Text('Let them answer'),
                            ),
                            const SizedBox(height: Space.xs),
                            TextButton(
                              key: const Key('skipCall'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: () =>
                                  Navigator.pop(context, RevealChoice.skip),
                              child: const Text('Skip for now'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.name,
    required this.landed,
    required this.nameSize,
    required this.caption,
  });

  final String name;
  final bool landed;
  final double nameSize;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final avatarSize = nameSize * 1.9;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: landed ? 1 : 0.86,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: landed
                  ? Brand.amber
                  : Colors.white.withValues(alpha: 0.08),
            ),
            child: Text(
              StudentAvatar.initials(name),
              style: TextStyle(
                fontSize: avatarSize * 0.36,
                fontWeight: FontWeight.w700,
                color: landed ? Brand.navy : Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: nameSize * 0.6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.displaySmall?.copyWith(
            fontSize: nameSize,
            color: landed ? Colors.white : Colors.white.withValues(alpha: 0.6),
            height: 1.1,
          ),
        ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 24,
          child: caption == null
              ? null
              : Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w400,
                  ),
                ),
        ),
      ],
    );
  }
}
