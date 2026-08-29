/// Whether this class is being recorded, and how the file is coming along.
///
/// Two separate things share this model because a student sees them as one
/// story. While the class runs, the server's CloudRecorder reports `active`.
/// After it stops, a render job builds the composed MP4 and reports progress
/// through recording-status. The class usually ends before the render does.
class RecordingState {
  final bool active;

  /// Recorder status while capturing, or the render job's status afterwards:
  /// "queued", "rendering", "completed", "failed".
  final String status;
  final int? startedAt;
  final int? endedAt;

  /// Finished file name, once there is one.
  final String? file;

  const RecordingState({
    required this.active,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.file,
  });

  static const idle = RecordingState(active: false, status: 'idle');

  bool get isRendering => status == 'queued' || status == 'rendering';
  bool get isDone => status == 'completed';
  bool get failed => status == 'failed';

  /// How long the recording has been running. Null when nothing is recording.
  Duration? get elapsed {
    final started = startedAt;
    if (!active || started == null) return null;
    final ms = DateTime.now().millisecondsSinceEpoch - started;
    return ms < 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  /// From the recorder snapshot carried in the join acknowledgement and the
  /// recording-started / recording-stopped broadcasts.
  factory RecordingState.fromSnapshot(Map<String, dynamic> map) {
    return RecordingState(
      active: map['active'] == true,
      status: (map['status'] ?? 'idle').toString(),
      startedAt: (map['startedAt'] as num?)?.toInt(),
      endedAt: (map['endedAt'] as num?)?.toInt(),
      file: map['file']?.toString(),
    );
  }

  /// From a recording-status broadcast, which describes the render job only —
  /// by which point capture has certainly stopped.
  factory RecordingState.fromJob(Map<String, dynamic> map) {
    return RecordingState(
      active: false,
      status: (map['status'] ?? 'queued').toString(),
      file: map['file']?.toString(),
    );
  }
}
