import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/stroke.dart';
import 'package:lynmeet/state/whiteboard_controller.dart';

/// The board must keep the teacher's shape. Painting a 16:9 laptop canvas into
/// a 9:16 phone stretches the handwriting into something legible but wrong,
/// and a diagram drawn to scale stops being to scale.
void main() {
  Stroke strokeOn(double w, double h) => Stroke.fromMap({
        'canvasWidth': w,
        'canvasHeight': h,
        'points': [
          {'x': 0, 'y': 0, 'nx': 0.0, 'ny': 0.0},
        ],
      });

  group('boardAspect', () {
    test('defaults to 16:9 for an empty board', () {
      expect(WhiteboardController().boardAspect, closeTo(16 / 9, 0.0001));
    });

    test('follows the canvas the teacher actually drew on', () {
      final board = WhiteboardController()..add(strokeOn(1440, 900));
      expect(board.boardAspect, closeTo(1.6, 0.0001));
    });

    test('follows the newest stroke when the teacher resizes their window', () {
      final board = WhiteboardController()
        ..add(strokeOn(1280, 720))
        ..add(strokeOn(1000, 1000));
      expect(board.boardAspect, closeTo(1.0, 0.0001));
    });

    test('ignores a stroke with no usable canvas', () {
      // Stroke.fromMap already substitutes the default board for a zero size,
      // so this must not produce a division by zero or an absurd ratio.
      final board = WhiteboardController()..add(strokeOn(0, 0));
      expect(board.boardAspect, closeTo(16 / 9, 0.0001));
    });
  });

  group('replay', () {
    test('clearing empties the board and bumps the revision', () {
      final board = WhiteboardController()..add(strokeOn(1280, 720));
      final before = board.revision;
      board.clear();
      expect(board.isEmpty, isTrue);
      expect(board.revision, greaterThan(before));
    });

    test('a stroke with no points is not a stroke', () {
      final board = WhiteboardController()
        ..add(Stroke.fromMap({'points': <dynamic>[]}));
      expect(board.isEmpty, isTrue);
    });

    test('replaceAll swaps in the joining snapshot', () {
      final board = WhiteboardController()..add(strokeOn(1280, 720));
      board.replaceAll([strokeOn(800, 600), strokeOn(800, 600)]);
      expect(board.strokes.length, 2);
      expect(board.boardAspect, closeTo(4 / 3, 0.0001));
    });
  });
}
