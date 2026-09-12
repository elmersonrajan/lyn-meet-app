import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/appreciation.dart';
import 'package:lynmeet/models/board.dart';
import 'package:lynmeet/models/peer.dart';
import 'package:lynmeet/models/shared_media.dart';

void main() {
  group('praise', () {
    test('takes its words from the server, not from the app', () {
      // The app sends only an id and the server decides the wording, so both
      // clients say the same thing. Anything invented here would be a phone
      // putting words in a teacher's mouth.
      final award = Appreciation.fromMap({
        'id': 'outstanding',
        'emoji': '🏆',
        'message': 'Outstanding!',
        'by': 'Mrs Rao',
        'at': 1700000000000,
      });
      expect(award.message, 'Outstanding!');
      expect(award.by, 'Mrs Rao');
    });

    test('still shows something if a field is missing', () {
      final award = Appreciation.fromMap({'id': 'great-job'});
      expect(award.message, isNotEmpty);
      expect(award.emoji, isNotEmpty);
    });

    test('the catalogue matches the four the server accepts', () {
      expect(
        Appreciation.catalogue.map((a) => a.id).toList(),
        ['great-job', 'excellent', 'well-done', 'outstanding'],
      );
    });
  });

  group('the board view the teacher drives', () {
    test('a flat board is recognised as flat', () {
      expect(BoardView.fromMap({'scale': 1, 'tx': 0, 'ty': 0}).isFlat, isTrue);
    });

    test('reads a zoomed view', () {
      final view = BoardView.fromMap({'scale': 2.5, 'tx': 0.1, 'ty': -0.2});
      expect(view.scale, 2.5);
      expect(view.tx, 0.1);
      expect(view.isFlat, isFalse);
    });

    test('never scales below 1, whatever arrives', () {
      // Below 1 would shrink the board inside its own frame and leave a gap
      // the class would all be staring at.
      expect(BoardView.fromMap({'scale': 0.2}).scale, 1);
      expect(BoardView.fromMap({'scale': -4}).scale, 1);
    });

    test('survives nonsense rather than throwing mid-lesson', () {
      expect(BoardView.fromMap({'scale': 'abc', 'tx': null}).isFlat, isTrue);
      expect(BoardView.fromMap(null).isFlat, isTrue);
    });
  });

  group('what the ink is drawn over', () {
    test('a board with an image reports a backing', () {
      final content = BoardContent.fromMap({
        'strokes': [],
        'image': {'id': 'i1', 'url': '/board-images/i1.png'},
      });
      expect(content.hasBacking, isTrue);
      expect(content.image!.url, '/board-images/i1.png');
    });

    test('a document carries the page the class is on', () {
      final content = BoardContent.fromMap({
        'document': {
          'id': 'd1',
          'url': '/documents/d1/{page}.png',
          'name': 'Chapter 4.docx',
          'page': 3,
        },
      });
      expect(content.document!.page, 3);
      expect(content.document!.pageUrl(3), '/documents/d1/3.png');
    });

    test('an empty url is no backing at all', () {
      // Better to draw on white than to ask for an address that cannot load.
      expect(BoardImage.fromMap({'id': 'x', 'url': ''}), isNull);
      expect(BoardContent.fromMap({}).hasBacking, isFalse);
    });
  });

  group('a clip the class is watching', () {
    test('a paused clip stays where it was', () {
      final clip = SharedMedia.fromMap({
        'kind': 'youtube',
        'videoId': 'dQw4w9WgXcQ',
        'paused': true,
        'positionSec': 42.0,
        'serverTime': DateTime.now().millisecondsSinceEpoch - 5000,
      })!;
      expect(clip.positionNow(), 42.0);
    });

    test('a playing clip has moved on since the message was sent', () {
      // Arriving late means arriving behind. Without this a student opening
      // the video would start five seconds before the rest of the class.
      final clip = SharedMedia.fromMap({
        'videoId': 'dQw4w9WgXcQ',
        'paused': false,
        'positionSec': 10.0,
        'serverTime': DateTime.now().millisecondsSinceEpoch - 4000,
      })!;
      expect(clip.positionNow(), greaterThan(13.5));
    });

    test('no video id is no clip', () {
      expect(SharedMedia.fromMap({'kind': 'youtube'}), isNull);
      expect(SharedMedia.fromMap(null), isNull);
    });
  });

  group('reactions', () {
    Peer student(String? reaction) => Peer.fromMap({
          'id': 'p1',
          'name': 'A',
          'role': 'student',
          if (reaction != null) 'reaction': reaction,
        });

    test('a thumb down is read as being lost', () {
      expect(student('down').isConfused, isTrue);
      expect(student('down').isFollowing, isFalse);
    });

    test('no reaction is neither', () {
      expect(student(null).isConfused, isFalse);
      expect(student(null).isFollowing, isFalse);
    });

    test('clearing takes the reaction and its timestamp away together', () {
      final before = Peer.fromMap({
        'id': 'p1',
        'name': 'A',
        'role': 'student',
        'reaction': 'up',
        'reactionAt': 123,
      });
      final after = before.copyWith(clearReaction: true);
      expect(after.reaction, isNull);
      expect(after.reactionAt, isNull);
    });

    test('changing a reaction leaves the microphone alone', () {
      final before = Peer.fromMap({
        'id': 'p1',
        'name': 'A',
        'role': 'student',
        'audioMuted': true,
      });
      expect(before.copyWith(reaction: 'down').audioMuted, isTrue);
    });
  });
}
