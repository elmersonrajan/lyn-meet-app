import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // A class is watched in portrait, one-handed, often propped on a desk.
  // Letting it rotate mid-lesson tears down and rebuilds the video views for
  // no gain.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const LynMeetApp());
}
