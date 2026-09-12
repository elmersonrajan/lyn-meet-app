import 'stroke.dart';

/// One of the whiteboards in a class, as it appears in the tab strip.
class BoardTab {
  final String id;
  final String name;
  final int strokeCount;

  /// Whether something is drawn on rather than a blank page — an image or a
  /// document. Shown as a small mark so a student can tell the tabs apart
  /// before switching is even possible for them.
  final bool hasImage;

  const BoardTab({
    required this.id,
    required this.name,
    required this.strokeCount,
    required this.hasImage,
  });

  factory BoardTab.fromMap(Map<String, dynamic> map) {
    return BoardTab(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Whiteboard').toString(),
      strokeCount: (map['strokeCount'] as num?)?.toInt() ?? 0,
      hasImage: map['hasImage'] == true,
    );
  }

  static List<BoardTab> listFrom(dynamic raw) {
    if (raw is! List) return const <BoardTab>[];
    return raw
        .whereType<Map>()
        .map((m) => BoardTab.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// A picture the teacher is drawing over.
class BoardImage {
  final String id;

  /// Path on the server, not a full address. It is fetched with the session
  /// cookie attached, because the server requires a signed-in account to serve
  /// it — a class's material is not public.
  final String url;

  const BoardImage({required this.id, required this.url});

  static BoardImage? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final url = (raw['url'] ?? '').toString();
    if (url.isEmpty) return null;
    return BoardImage(id: (raw['id'] ?? '').toString(), url: url);
  }
}

/// A document open on a board, at the page the class is being shown.
class BoardDocument {
  final String id;
  final String url;
  final String name;

  /// Which page. The teacher turns it; everyone follows.
  final int page;

  const BoardDocument({
    required this.id,
    required this.url,
    required this.name,
    required this.page,
  });

  static BoardDocument? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final url = (raw['url'] ?? '').toString();
    if (url.isEmpty) return null;
    return BoardDocument(
      id: (raw['id'] ?? '').toString(),
      url: url,
      name: (raw['name'] ?? 'Document').toString(),
      page: (raw['page'] as num?)?.toInt() ?? 1,
    );
  }

  /// The address for one page.
  ///
  /// The server renders each page as its own file, so turning a page is
  /// fetching a different one rather than moving within a single document.
  String pageUrl(int wanted) =>
      url.contains('{page}') ? url.replaceAll('{page}', '$wanted') : url;
}

/// Where in a board the class is looking.
///
/// The teacher drives this and everyone follows, which is the point: "look at
/// the top left" is useless when forty people are each scrolled somewhere
/// different. Scale is 1 or more, and the offsets are fractions of the board,
/// already clamped by the server so a bad value cannot push the page off
/// everybody's screen at once.
class BoardView {
  final double scale;
  final double tx;
  final double ty;

  const BoardView({this.scale = 1, this.tx = 0, this.ty = 0});

  static const flat = BoardView();

  bool get isFlat => scale <= 1.001 && tx.abs() < 0.0001 && ty.abs() < 0.0001;

  factory BoardView.fromMap(dynamic raw) {
    if (raw is! Map) return flat;
    double num_(dynamic v, double fallback) {
      final parsed = v is num ? v.toDouble() : double.tryParse('$v');
      return parsed == null || !parsed.isFinite ? fallback : parsed;
    }

    return BoardView(
      scale: num_(raw['scale'], 1).clamp(1.0, 8.0),
      tx: num_(raw['tx'], 0),
      ty: num_(raw['ty'], 0),
    );
  }
}

/// Everything on one board at once.
class BoardContent {
  final List<Stroke> strokes;
  final BoardImage? image;
  final BoardDocument? document;
  final BoardView view;

  const BoardContent({
    this.strokes = const [],
    this.image,
    this.document,
    this.view = BoardView.flat,
  });

  /// Whether there is anything behind the ink.
  bool get hasBacking => image != null || document != null;

  factory BoardContent.fromMap(Map<String, dynamic> map) {
    return BoardContent(
      strokes: Stroke.listFrom(map['strokes']),
      image: BoardImage.fromMap(map['image']),
      document: BoardDocument.fromMap(map['document']),
      view: BoardView.fromMap(map['view']),
    );
  }
}
