import 'package:flutter/material.dart';

import '../models/stroke.dart';
import '../state/whiteboard_controller.dart';

/// The class whiteboard, replayed.
///
/// The board is white regardless of the app's dark theme: it is a photograph
/// of the teacher's board, and inverting it would change what the ink means.
class WhiteboardView extends StatelessWidget {
  const WhiteboardView({super.key, required this.controller});

  final WhiteboardController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          color: Colors.white,
          child: controller.isEmpty
              ? const _EmptyBoard()
              : CustomPaint(
                  painter: _WhiteboardPainter(
                    strokes: controller.strokes,
                    revision: controller.revision,
                  ),
                  size: Size.infinite,
                ),
        );
      },
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 40, color: Color(0xff9fb0c9)),
          SizedBox(height: 12),
          Text(
            'The board is empty',
            style: TextStyle(color: Color(0xff7a8ba3), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter({required this.strokes, required this.revision});

  final List<Stroke> strokes;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final points = stroke.offsetsFor(size);
      if (points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.inkColor
        ..strokeWidth = stroke.strokeWidthFor(size)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      canvas.drawPath(_pathFor(points), paint);
    }
  }

  /// Smooths a stroke with quadratic midpoints.
  ///
  /// The same curve the web client draws (strokePath in useWhiteboard.js).
  /// Joining the raw points with straight lines instead makes handwriting look
  /// visibly faceted on a phone, where each sampled point is several pixels
  /// apart after scaling a desktop-sized board down.
  Path _pathFor(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    if (points.length == 1) {
      // A dot: a zero-length path draws nothing, so give it a hair of length.
      path.lineTo(points.first.dx + 0.01, points.first.dy);
      return path;
    }
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }

    final last = points[points.length - 1];
    final prev = points[points.length - 2];
    path.quadraticBezierTo(prev.dx, prev.dy, last.dx, last.dy);
    return path;
  }

  @override
  bool shouldRepaint(_WhiteboardPainter old) => old.revision != revision;
}
