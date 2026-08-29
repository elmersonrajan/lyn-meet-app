import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/stroke.dart';

/// The whiteboard is the lesson. If coordinates are mapped wrongly the board
/// still draws — just in the wrong place — which is the kind of fault nobody
/// notices until a class is halfway through.
void main() {
  group('Stroke coordinate mapping', () {
    test('replays a normalised stroke onto any canvas size', () {
      final stroke = Stroke.fromMap({
        'color': '#163a6b',
        'width': 4,
        'canvasWidth': 1280,
        'canvasHeight': 720,
        'points': [
          {'x': 640, 'y': 360, 'nx': 0.5, 'ny': 0.5},
          {'x': 1280, 'y': 720, 'nx': 1.0, 'ny': 1.0},
        ],
      });

      // A phone in portrait: nothing like the teacher's canvas.
      final points = stroke.offsetsFor(const Size(360, 640));
      expect(points[0], const Offset(180, 320));
      expect(points[1], const Offset(360, 640));
    });

    test('falls back to raw pixels for a live stroke, which is not normalised', () {
      // The server relays live strokes verbatim — only stored history gets
      // nx/ny — so this path is what a student sees while the teacher writes.
      final stroke = Stroke.fromMap({
        'canvasWidth': 1000,
        'canvasHeight': 500,
        'points': [
          {'x': 500, 'y': 250},
        ],
      });

      expect(stroke.offsetsFor(const Size(200, 100)), [const Offset(100, 50)]);
    });

    test('scales the pen so a line does not become a hairline on a phone', () {
      final stroke = Stroke.fromMap({
        'width': 8,
        'canvasWidth': 1280,
        'canvasHeight': 720,
        'points': [
          {'x': 0, 'y': 0},
        ],
      });

      // Board scaled to roughly a quarter width, so the pen scales with it.
      expect(stroke.strokeWidthFor(const Size(320, 180)), 2.0);
      // Never thinner than a pixel, however small the canvas.
      expect(stroke.strokeWidthFor(const Size(10, 6)), 1.0);
    });

    test('survives a stroke with no usable size', () {
      final stroke = Stroke.fromMap({
        'canvasWidth': 0,
        'canvasHeight': 0,
        'points': [
          {'x': 10, 'y': 10},
        ],
      });
      // Falls back to the default board rather than dividing by zero.
      expect(stroke.canvasWidth, 1280);
      expect(stroke.offsetsFor(const Size(1280, 720)).first, const Offset(10, 10));
    });
  });

  group('Stroke colour', () {
    test('parses the hex the web client sends', () {
      expect(Stroke.fromMap({'color': '#163a6b'}).inkColor, const Color(0xff163a6b));
    });

    test('expands shorthand and falls back on rubbish', () {
      expect(Stroke.fromMap({'color': '#f00'}).inkColor, const Color(0xffff0000));
      expect(Stroke.fromMap({'color': 'not-a-colour'}).inkColor, const Color(0xff163a6b));
    });
  });
}
