import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.beans.music.audio',
    androidNotificationChannelName: 'Beans Music 播放',
    androidNotificationOngoing: true,
  );
  runApp(const BeansMusicApp());
}
