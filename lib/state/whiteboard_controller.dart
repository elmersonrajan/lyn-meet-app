import 'package:flutter/foundation.dart';

import '../models/stroke.dart';

/// The class whiteboard, as a student sees it: read-only.
///
/// Drawing is teacher-only and the server enforces it — whiteboard-stroke
/// calls requireTeacher — so there is no input path here at all, only replay.
///
/// Two sources feed the same list. On join, the server sends the whole board
/// so a student arriving late sees what is already drawn; after that, each new
/// stroke arrives on its own. Both go through [add] / [replaceAll], and the
/// painter cannot tell them apart.
class WhiteboardController extends ChangeNotifier {
  final List<Stroke> _strokes = [];

  /// Bumped on every change. The painter compares this instead of the list,
  /// which lets shouldRepaint stay O(1) on a board with thousands of strokes.
  int _revision = 0;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  int get revision => _revision;
  bool get isEmpty => _strokes.isEmpty;

  /// The shape of the teacher's canvas, width over height.
  ///
  /// This matters more than it looks. The teacher writes on a wide laptop
  /// canvas; a phone held upright is tall. Stretching one into the other turns
  /// round letters into ovals and pulls a diagram out of proportion — the
  /// board was legible but wrong. Painting into this ratio and letterboxing
  /// the remainder keeps the writing the shape the teacher made it.
  ///
  /// Taken from the strokes themselves, since every stroke carries the canvas
  /// it was drawn on, and defaulting to 16:9 for an empty board.
  double get boardAspect {
    for (final stroke in _strokes.reversed) {
      if (stroke.canvasWidth > 0 && stroke.canvasHeight > 0) {
        return stroke.canvasWidth / stroke.canvasHeight;
      }
    }
    return 16 / 9;
  }

  void replaceAll(List<Stroke> strokes) {
    _strokes
      ..clear()
      ..addAll(strokes);
    _revision++;
    notifyListeners();
  }

  void add(Stroke stroke) {
    if (stroke.points.isEmpty) return;
    _strokes.add(stroke);
    // The same cap the server keeps, so a long class cannot grow the board
    // until the phone runs out of memory redrawing it.
    if (_strokes.length > 4000) {
      _strokes.removeRange(0, _strokes.length - 4000);
    }
    _revision++;
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _revision++;
    notifyListeners();
  }
}
