import 'package:flutter/material.dart';

import '../state/meeting_controller.dart';
import 'whiteboard_view.dart';

/// The live whiteboard: whatever is behind the ink, and the ink on top.
///
/// A class is taught on a photograph or a page of a document as often as on a
/// blank board now. Replaying only the strokes would show a student the
/// annotations with the thing being annotated missing — arrows pointing at
/// nothing, a circle round empty white — which is worse than showing no board
/// at all, because it looks like it is working.
///
/// The teacher's zoom and pan are applied here too. They drive it and everyone
/// follows: "look at the top left" is useless when forty people are each
/// scrolled somewhere different.
class BoardStage extends StatelessWidget {
  const BoardStage({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final view = meeting.boardView;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The server sends offsets as fractions of the board, so they only
        // become pixels once the board has a size.
        final dx = view.tx * constraints.maxWidth * view.scale;
        final dy = view.ty * constraints.maxHeight * view.scale;

        return ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translateByDouble(dx, dy, 0, 1)
              ..scaleByDouble(view.scale, view.scale, 1, 1),
            transformAlignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Backing(meeting: meeting),
                // Strokes are drawn in the board's own coordinates, so they
                // ride the same transform and stay registered with whatever is
                // underneath however far the class zooms in.
                WhiteboardView(
                  controller: meeting.whiteboard,
                  transparent: meeting.boardImage != null ||
                      meeting.boardDocument != null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The picture or page the strokes are drawn over, if there is one.
class _Backing extends StatelessWidget {
  const _Backing({required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final document = meeting.boardDocument;
    final image = meeting.boardImage;

    final path = document != null
        ? document.pageUrl(document.page)
        : image?.url;
    if (path == null) return const SizedBox.shrink();

    return ColoredBox(
      color: Colors.white,
      child: Image.network(
        meeting.assetUrl(path),
        // Signed in, not public. Without the session this is a 401 and the
        // board loses the very thing the lesson is about.
        headers: meeting.assetHeaders,
        fit: BoxFit.contain,
        // Keyed by what is being shown, so turning a page replaces the picture
        // instead of leaving the previous page under the new annotations.
        key: ValueKey(path),
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _BoardLoading(),
        errorBuilder: (context, error, stack) => _BoardFailed(
          name: document?.name,
        ),
      ),
    );
  }
}

class _BoardLoading extends StatelessWidget {
  const _BoardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: 26,
        width: 26,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _BoardFailed extends StatelessWidget {
  const _BoardFailed({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 32, color: Color(0xff9fb0c9)),
            const SizedBox(height: 10),
            Text(
              name == null
                  ? 'Could not load what the teacher is showing'
                  : 'Could not load "$name"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff7a8ba3), fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'The writing on it is still coming through.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff9fb0c9), fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip naming which board the class is on.
///
/// A student cannot switch — only a teacher can — so this reports rather than
/// offers. It is worth reporting: a board that suddenly empties is alarming
/// until you can see the class simply moved to page two.
class BoardTabsStrip extends StatelessWidget {
  const BoardTabsStrip({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final boards = meeting.boards;
    if (boards.length < 2) return const SizedBox.shrink();

    return Container(
      height: 30,
      color: const Color(0xcc0d1520),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: boards.length,
        itemBuilder: (context, index) {
          final board = boards[index];
          final live = board.id == meeting.activeBoardId;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: live ? const Color(0xff2f6bd8) : const Color(0xff1b2430),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (board.hasImage) ...[
                  Icon(
                    Icons.image_outlined,
                    size: 11,
                    color: live ? Colors.white : const Color(0xff8b9cb3),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  board.name,
                  style: TextStyle(
                    color: live ? Colors.white : const Color(0xff8b9cb3),
                    fontSize: 11,
                    fontWeight: live ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
