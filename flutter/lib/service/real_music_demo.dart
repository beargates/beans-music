import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/netease_auth_store.dart';
import '../auth/platform_auth_store.dart';
import '../manager/audio_player_manager.dart';
import '../model/song.dart';
import 'kugou_music_service.dart';
import 'kugou_url_service.dart';
import 'music_repository.dart';
import 'netease_music_service.dart';
import 'qq_music_service.dart';
import 'dio_client.dart';
import 'song_url_service.dart';

class RealMusicDemo {
  final Dio dio;
  late final MusicRepository musicRepository;
  late final SongUrlRepository songUrlRepository;
  late final AudioPlayerManager playerManager;

  RealMusicDemo._(this.dio) {
    musicRepository = MusicRepository(
      netease: NeteaseMusicService(dio),
      qq: QQMusicService(dio),
      kugou: KugouMusicService(dio),
    );

    songUrlRepository = SongUrlRepository(
      netease: NeteaseSongUrlService(dio),
      qq: QQSongUrlService(dio),
      kugou: KugouSongUrlService(dio),
    );

    playerManager = AudioPlayerManager();
  }

  static Future<RealMusicDemo> create() async {
    final prefs = await SharedPreferences.getInstance();
    final client = DioClient(
      authStore: NeteaseAuthStore(prefs),
      platformAuthStore: PlatformAuthStore(prefs),
    );
    return RealMusicDemo._(client.dio);
  }

  Future<List<Song>> search(String keyword) async {
    return musicRepository.searchAll(keyword, limit: 20);
  }

  Future<void> playSong(Song song) async {
    final resolved = await songUrlRepository.resolveUrl(song);
    if (resolved == null || !resolved.isAvailable) {
      throw StateError('Failed to resolve song URL for ${song.name}');
    }

    await playerManager.playUrl(resolved.url);
  }
}
