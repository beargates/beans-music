import '../model/song.dart';
import 'kugou_music_service.dart';
import 'netease_music_service.dart';
import 'qq_music_service.dart';

class MusicRepository {
  final NeteaseMusicService netease;
  final QQMusicService qq;
  final KugouMusicService kugou;

  MusicRepository({
    required this.netease,
    required this.qq,
    required this.kugou,
  });

  Future<List<Song>> searchAll(String keyword, {int limit = 30}) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final errors = <String>[];
    final futures = await Future.wait([
      _searchProvider('网易云', () => netease.search(trimmed, limit: limit), errors),
      _searchProvider('QQ', () => qq.search(trimmed, limit: limit), errors),
      _searchProvider('酷狗', () => kugou.search(trimmed, limit: limit), errors),
    ]);

    if (futures.every((list) => list.isEmpty) && errors.length == futures.length) {
      throw StateError('所有平台搜索失败：${errors.join('；')}');
    }

    final merged = <Song>[];
    final seen = <String>{};

    for (final list in futures) {
      for (final song in list) {
        if (seen.add(song.identityKey)) {
          merged.add(song);
        }
      }
    }

    return merged;
  }

  Future<List<Song>> searchBySource(
    SongSource source,
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return Future.value([]);

    switch (source) {
      case SongSource.netease:
        return netease.search(trimmed, limit: limit, offset: offset);
      case SongSource.qq:
        return qq.search(trimmed, limit: limit, offset: offset);
      case SongSource.kugou:
        return kugou.search(trimmed, limit: limit);
    }
  }

  Future<List<Song>> _searchProvider(
    String provider,
    Future<List<Song>> Function() search,
    List<String> errors,
  ) async {
    try {
      return await search();
    } catch (error) {
      errors.add('$provider：$error');
      return [];
    }
  }
}
