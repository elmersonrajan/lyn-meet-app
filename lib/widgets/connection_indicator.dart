import 'package:flutter/material.dart';

import '../state/connection_status.dart';

/// Three bars in the app bar saying whether the lesson is actually arriving.
///
/// Small on purpose. It has to be readable at a glance without competing with
/// the board, and it is looked at only when something feels wrong.
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key, required this.status});

  final ConnectionStatus status;

  Color _colourFor(ConnectionQuality quality) => switch (quality) {
        ConnectionQuality.good => const Color(0xff35d07f),
        ConnectionQuality.connecting => const Color(0xff9dc2ff),
        ConnectionQuality.weak => const Color(0xffffc44d),
        ConnectionQuality.failed => const Color(0xffff6b6b),
        ConnectionQuality.offline => const Color(0xffff6b6b),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: status,
      builder: (context, _) {
        final quality = status.quality;
        final colour = _colourFor(quality);
        final filled = quality.bars;

        return Tooltip(
          message: quality.isTrouble ? quality.message : 'Connected',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 4,
                      height: 6.0 + i * 4,
                      decoration: BoxDecoration(
                        // An unfilled bar stays visible rather than vanishing,
                        // so the meter reads as "one of three" instead of
                        // looking like a rendering fault.
                        color: i < filled ? colour : const Color(0xff33404f),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                // No bars lit is ambiguous on its own — it could be a meter
                // that has not loaded. The cross says the connection is gone.
                if (filled == 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.priority_high, size: 13, color: colour),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The strip that explains a bad connection in words.
///
/// Separate from the indicator because the two answer different questions: the
/// bars say how things are, this says what to do about it.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: status,
      builder: (context, _) {
        final quality = status.quality;
        if (!quality.isTrouble) return const SizedBox.shrink();
        // Connecting is the normal opening state, not a problem to announce.
        if (quality == ConnectionQuality.connecting) {
          return const SizedBox.shrink();
        }

        final severe = quality == ConnectionQuality.failed ||
            quality == ConnectionQuality.offline;

        return Container(
          width: double.infinity,
          color: severe ? const Color(0xff4a1f24) : const Color(0xff5a4218),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: quality == ConnectionQuality.offline
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xffffb3b3),
                      )
                    : Icon(
                        severe ? Icons.error_outline : Icons.network_check,
                        size: 15,
                        color: severe
                            ? const Color(0xffffb3b3)
                            : const Color(0xffffd48a),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.micPathFailed
                      ? 'You can hear the class, but your microphone cannot get through'
                      : quality.message,
                  style: TextStyle(
                    color: severe
                        ? const Color(0xffffb3b3)
                        : const Color(0xffffd48a),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
