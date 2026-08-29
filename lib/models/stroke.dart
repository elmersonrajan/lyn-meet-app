import 'dart:ui';

/// One pen stroke on the class whiteboard.
///
/// The server normalises every stroke before storing it, adding nx/ny in the
/// range 0..1 alongside the raw pixel coordinates (whiteboard-stroke in
/// backend/src/socket/index.js). Those normalised values are what make the
/// board work on a phone at all: the teacher draws on a wide desktop canvas,
/// and rescaling by nx/ny reproduces the drawing at any size and aspect ratio
/// without the app knowing anything about the teacher's screen.
///
/// Live strokes relayed from the teacher are *not* normalised — the server
/// forwards those verbatim — so canvasWidth/canvasHeight are the fallback.
class Stroke {
  final String color;
  final double width;
  final double canvasWidth;
  final double canvasHeight;
  final List<StrokePoint> points;

  const Stroke({
    required this.color,
    required this.width,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.points,
  });

  factory Stroke.fromMap(Map<String, dynamic> map) {
    final cw = (map['canvasWidth'] as num?)?.toDouble() ?? 1280.0;
    final ch = (map['canvasHeight'] as num?)?.toDouble() ?? 720.0;
    return Stroke(
      color: (map['color'] ?? '#163a6b').toString(),
      width: (map['width'] as num?)?.toDouble() ?? 3.0,
      canvasWidth: cw <= 0 ? 1280.0 : cw,
      canvasHeight: ch <= 0 ? 720.0 : ch,
      points: (map['points'] as List?)
              ?.whereType<Map>()
              .map((p) => StrokePoint.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          const <StrokePoint>[],
    );
  }

  static List<Stroke> listFrom(dynamic raw) {
    if (raw is! List) return <Stroke>[];
    return raw
        .whereType<Map>()
        .map((m) => Stroke.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// The stroke laid out on a canvas of [size].
  ///
  /// Ports mapPoint() from frontend/src/hooks/useWhiteboard.js, including its
  /// preference order: normalised coordinates when present, otherwise the raw
  /// pixels divided by the canvas they were drawn on.
  List<Offset> offsetsFor(Size size) {
    return points.map((p) {
      final nx = p.nx;
      final ny = p.ny;
      if (nx != null && ny != null) {
        return Offset(nx * size.width, ny * size.height);
      }
      return Offset(
        (p.x / canvasWidth) * size.width,
        (p.y / canvasHeight) * size.height,
      );
    }).toList(growable: false);
  }

  /// Pen width scaled to the rendered canvas, so a line drawn 4px wide on a
  /// 1280-wide board does not turn into a hairline on a phone.
  double strokeWidthFor(Size size) {
    final scale = size.width / canvasWidth;
    return (width * scale).clamp(1.0, 64.0);
  }

  /// Parses the "#rrggbb" the web client sends. Falls back to the teacher's
  /// default ink rather than throwing on a malformed value.
  Color get inkColor {
    var hex = color.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'ff$hex';
    final value = int.tryParse(hex, radix: 16);
    return value == null ? const Color(0xff163a6b) : Color(value);
  }
}

class StrokePoint {
  final double x;
  final double y;

  /// Normalised 0..1 coordinates, present on replayed history.
  final double? nx;
  final double? ny;

  const StrokePoint({required this.x, required this.y, this.nx, this.ny});

  factory StrokePoint.fromMap(Map<String, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      nx: (map['nx'] as num?)?.toDouble(),
      ny: (map['ny'] as num?)?.toDouble(),
    );
  }
}
