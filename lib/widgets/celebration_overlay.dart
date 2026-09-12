import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/appreciation.dart';

/// The congratulations, when a teacher gives one.
///
/// It takes over the screen for a moment on purpose. Praise that arrives as a
/// line in a list is praise nobody notices, and a student watching a lesson on
/// a phone is looking at the board, not at a feed — so this lands in front of
/// the board, says who gave it, and then gets out of the way by itself.
///
/// Everything is drawn rather than fetched: no image, no sound file, nothing
/// to download on a classroom connection that is already carrying video.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.appreciation,
    required this.onDone,
  });

  final Appreciation appreciation;

  /// Called once the celebration has finished and cleared itself away.
  final VoidCallback onDone;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final List<_Confetto> _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = _makeConfetti();

    // A short buzz. The class may be muted, or the student may be reading
    // rather than watching, and this is the one moment worth interrupting for.
    HapticFeedback.mediumImpact();

    _card.forward();
    _burst.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    // A second award while the first is still on screen restarts the whole
    // thing rather than queueing, so praise never lags behind the lesson.
    if (old.appreciation.at != widget.appreciation.at) {
      setState(() => _confetti = _makeConfetti());
      HapticFeedback.mediumImpact();
      _card.forward(from: 0);
      _burst.forward(from: 0);
    }
  }

  /// Seeded from the award's timestamp so the pattern differs each time while
  /// staying stable across the rebuilds of a single celebration.
  List<_Confetto> _makeConfetti() {
    final random = math.Random(widget.appreciation.at);
    return List.generate(48, (_) => _Confetto.random(random));
  }

  @override
  void dispose() {
    _burst.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final award = widget.appreciation;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Just enough shade to lift the card off the board without hiding
            // what the teacher is drawing — the lesson carries on underneath.
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _burst,
                  curve: const Interval(0, 0.12),
                  reverseCurve: const Interval(0.75, 1),
                ),
              ),
              child: Container(color: const Color(0x55000000)),
            ),

            Positioned.fill(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    confetti: _confetti,
                    progress: _burst.value,
                  ),
                ),
              ),
            ),

            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _card,
                  // Overshoots and settles. A card that simply appears reads as
                  // a notification; one that springs reads as applause.
                  curve: Curves.elasticOut,
                ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0).animate(
                    CurvedAnimation(parent: _burst, curve: const Interval(0.82, 1)),
                  ),
                  child: _AwardCard(award: award),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award});

  final Appreciation award;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      constraints: BoxConstraints(maxWidth: width * 0.82),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1e3a63), Color(0xff17202e)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffffc44d), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(award.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            award.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          if (award.by.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'from ${award.by}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffffd48a), fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

/// One piece of paper, with everything about it decided up front.
class _Confetto {
  final double x;
  final double delay;
  final double drift;
  final double size;
  final double spin;
  final Color colour;
  final bool round;

  const _Confetto({
    required this.x,
    required this.delay,
    required this.drift,
    required this.size,
    required this.spin,
    required this.colour,
    required this.round,
  });

  static const _palette = [
    Color(0xffffc44d),
    Color(0xff35d07f),
    Color(0xff5b9bff),
    Color(0xffff8b8b),
    Color(0xffffffff),
    Color(0xffb57bff),
  ];

  factory _Confetto.random(math.Random r) {
    return _Confetto(
      x: r.nextDouble(),
      // Staggered starts, so it falls as a shower rather than a single line.
      delay: r.nextDouble() * 0.35,
      drift: (r.nextDouble() - 0.5) * 0.35,
      size: 6 + r.nextDouble() * 8,
      spin: (r.nextDouble() - 0.5) * 10,
      colour: _palette[r.nextInt(_palette.length)],
      round: r.nextBool(),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.confetti, required this.progress});

  final List<_Confetto> confetti;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final piece in confetti) {
      // Each piece runs its own clock, starting late and finishing early, so
      // the shower thins out rather than stopping all at once.
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Falls with a little acceleration, and fades over the last third.
      final y = (t * t * 0.7 + t * 0.45) * (size.height + 80) - 40;
      final x = (piece.x + piece.drift * t) * size.width;
      final fade = t < 0.7 ? 1.0 : 1 - ((t - 0.7) / 0.3);

      paint.color = piece.colour.withValues(alpha: fade.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
