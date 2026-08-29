import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Rotation is deliberately left alone.
  //
  // The teacher writes on a wide laptop canvas, so the board is landscape. On
  // an upright phone that leaves it letterboxed into a strip; turned sideways
  // it fills the screen and the handwriting is actually readable. Locking to
  // portrait would take that away, and the room screen already lays itself out
  // both ways.
  runApp(const LynMeetApp());
}
