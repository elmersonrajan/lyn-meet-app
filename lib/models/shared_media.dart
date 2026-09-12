/// A clip the teacher is playing to the class.
///
/// The server keeps the position and hands out where the class has got to, so
/// somebody joining halfway arrives at the same moment in the same video as
/// everyone else rather than at the beginning.
class SharedMedia {
  /// Currently only "youtube".
  final String kind;
  final String title;

  /// The video id alone — never the address the teacher pasted. The server
  /// reduces every accepted YouTube link to eleven characters, which is what
  /// stops a link smuggling anything else onto forty screens.
  final String videoId;

  final bool paused;

  /// How far in the class is, in seconds, at [serverTime].
  final double positionSec;
  final int serverTime;

  const SharedMedia({
    required this.kind,
    required this.title,
    required this.videoId,
    required this.paused,
    required this.positionSec,
    required this.serverTime,
  });

  bool get isYouTube => kind == 'youtube';

  /// Where the clip has reached now, allowing for the trip here.
  ///
  /// The server's figure was true when it was sent. While the clip is playing
  /// it keeps moving, so arriving late means arriving behind by however long
  /// the message took.
  double positionNow() {
    if (paused) return positionSec;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - serverTime) / 1000.0;
    return positionSec + (elapsed < 0 ? 0 : elapsed);
  }

  static SharedMedia? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final videoId = (raw['videoId'] ?? '').toString();
    if (videoId.isEmpty) return null;
    return SharedMedia(
      kind: (raw['kind'] ?? 'youtube').toString(),
      title: (raw['title'] ?? '').toString(),
      videoId: videoId,
      paused: raw['paused'] == true,
      positionSec: (raw['positionSec'] as num?)?.toDouble() ?? 0,
      serverTime: (raw['serverTime'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Where a student can watch it if the app cannot play it itself.
  Uri get watchUri => Uri.parse(
        'https://www.youtube.com/watch?v=$videoId&t=${positionNow().round()}s',
      );
}
