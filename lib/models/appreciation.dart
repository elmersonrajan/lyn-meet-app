/// A piece of praise the teacher has given the class.
///
/// The wording and the emoji are the server's, not the app's — the same four
/// awards reach the web client and this one, so a class watching on both sees
/// the same thing said the same way. Inventing the text here would be how
/// "Well Done!" on a laptop becomes something else on a phone.
class Appreciation {
  /// "great-job", "excellent", "well-done", "outstanding".
  final String id;
  final String emoji;
  final String message;

  /// Who gave it.
  final String by;
  final int at;

  const Appreciation({
    required this.id,
    required this.emoji,
    required this.message,
    required this.by,
    required this.at,
  });

  factory Appreciation.fromMap(Map<String, dynamic> map) {
    return Appreciation(
      id: (map['id'] ?? '').toString(),
      emoji: (map['emoji'] ?? '🎉').toString(),
      message: (map['message'] ?? 'Well Done!').toString(),
      by: (map['by'] ?? '').toString(),
      at: (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// The catalogue an administrator can choose from.
  ///
  /// Mirrors APPRECIATIONS in backend/src/socket/sharedStage.js. Only the id
  /// is sent — the server looks up its own wording and refuses an id it does
  /// not recognise, so this list is for drawing the buttons, never the source
  /// of what the class is told.
  static const List<Appreciation> catalogue = [
    Appreciation(id: 'great-job', emoji: '👏', message: 'Great Job!', by: '', at: 0),
    Appreciation(id: 'excellent', emoji: '🌟', message: 'Excellent!', by: '', at: 0),
    Appreciation(id: 'well-done', emoji: '🎉', message: 'Well Done!', by: '', at: 0),
    Appreciation(id: 'outstanding', emoji: '🏆', message: 'Outstanding!', by: '', at: 0),
  ];
}
