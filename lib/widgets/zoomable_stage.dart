import 'package:flutter/material.dart';

/// Pinch to zoom, drag to pan, double-tap to toggle.
///
/// The teacher writes on a wide laptop canvas and a student reads it on a
/// phone, so anything written small is unreadable at fit-to-screen — the whole
/// board is scaled down to a few hundred pixels wide. This is the difference
/// between squinting and reading.
///
/// Zoom is reset whenever [resetKey] changes, because a magnified corner of a
/// whiteboard is meaningless once the teacher switches to a screen share or
/// wipes the board.
class ZoomableStage extends StatefulWidget {
  const ZoomableStage({
    super.key,
    required this.child,
    required this.resetKey,
  });

  final Widget child;

  /// Anything that means "what is underneath has changed" — the stage mode.
  final Object resetKey;

  @override
  State<ZoomableStage> createState() => _ZoomableStageState();
}

class _ZoomableStageState extends State<ZoomableStage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _tween;

  /// What a double-tap zooms to. Enough to read small handwriting without
  /// losing so much context that panning becomes the only way to navigate.
  static const double _doubleTapScale = 2.5;

  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _animation.addListener(() {
      final value = _tween?.value;
      if (value != null) _transform.value = value;
    });
  }

  void _onTransform() {
    final next = _transform.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() < 0.01) return;
    setState(() => _scale = next);
  }

  @override
  void didUpdateWidget(ZoomableStage old) {
    super.didUpdateWidget(old);
    if (old.resetKey != widget.resetKey) _reset();
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    );
    _animation.forward(from: 0);
  }

  void _reset() {
    if (_transform.value.isIdentity()) return;
    _animateTo(Matrix4.identity());
  }

  /// Zooms about the point tapped, so the thing under the finger is what
  /// grows. Zooming about the centre instead sends whatever the student was
  /// looking at off the edge of the screen.
  void _toggleZoomAt(Offset position) {
    if (_scale > 1.05) {
      _reset();
      return;
    }
    final target = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = _scale > 1.05;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            // onDoubleTapDown carries the position; onDoubleTap alone does not,
            // and the position is the whole point.
            onDoubleTapDown: (details) => _toggleZoomAt(details.localPosition),
            onDoubleTap: () {},
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              // Nothing beyond the edges is worth panning to, and allowing it
              // means a student can lose the board off-screen and not know how
              // to get it back.
              boundaryMargin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              child: widget.child,
            ),
          ),
        ),

        // Only shown while zoomed. A student who has panned into a corner has
        // no other obvious way back, and pinching out is fiddly one-handed.
        if (zoomed)
          Positioned(
            left: 12,
            top: 12,
            child: _ResetChip(scale: _scale, onTap: _reset),
          ),
      ],
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xcc1a2433),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.zoom_out_map, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                '${scale.toStringAsFixed(1)}× · Fit',
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
