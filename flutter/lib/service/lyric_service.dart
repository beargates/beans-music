import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/lyric_line.dart';
import '../model/song.dart';
import 'weapi_utils.dart';

export '../model/lyric_line.dart' show LyricLine, LyricParser, LyricTiming;

/// 一首歌的歌词结果（含翻译与失败原因）。
class Lyrics {
  final List<LyricLine> lines;

  /// 获取失败时的原因；成功但无歌词时为 null。
  final String? error;

  /// 原始 LRC 文本（用于「纯音乐」等兜底判断）。
  final String raw;

  const Lyrics({required this.lines, this.error, this.raw = ''});

  static const Lyrics empty = Lyrics(lines: []);

  bool get isEmpty => lines.isEmpty;

  bool get hasTranslation => lines.any((line) => line.hasTranslation);

  /// 无歌词时的提示文案
  String get emptyMessage {
    if (error != null) return error!;
    final lower = raw.toLowerCase();
    if (lower.contains('纯音乐') ||
        lower.contains('instrumental') ||
        raw.contains('此歌曲为没有填词的纯音乐')) {
      return '纯音乐，请欣赏';
    }
    return '暂无歌词';
  }
}

/// 三平台歌词获取（网易云 lrc + tlyric / QQ lyric + trans / 酷狗 lrc）。
class LyricService {
  final Dio dio;
  final Map<String, Lyrics> _cache = {};

  LyricService(this.dio);

  /// 获取歌词；同一首歌会命中内存缓存，[force] 强制刷新。
  Future<Lyrics> fetch(Song song, {bool force = false}) async {
    final key = song.identityKey;
    if (!force) {
      final cached = _cache[key];
      if (cached != null) return cached;
    }

    Lyrics lyrics;
    try {
      lyrics = switch (song.source) {
        SongSource.netease => await _netease(song.id),
        SongSource.qq => await _qq(song.qqMid ?? ''),
        SongSource.kugou => await _kugou(song.kugouHash ?? '', song.duration),
      };
    } on Object catch (error) {
      // 失败结果不写入缓存，便于网络恢复后重试
      return Lyrics(lines: const [], error: '歌词获取失败：$error');
    }

    _cache[key] = lyrics;
    return lyrics;
  }

  void clearCache() => _cache.clear();

  Future<Lyrics> _netease(int id) async {
    if (id <= 0) return Lyrics.empty;
    final body = WeapiUtils.encryptPayload({
      'id': id,
      'lv': -1,
      'kv': -1,
      'tv': -1,
    });
    final response = await dio.post(
      'https://music.163.com/weapi/song/lyric',
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
        },
      ),
    );

    final data = _asMap(response.data);
    final lrc = _asMap(data['lrc'])['lyric'] as String? ?? '';
    // 网易云翻译歌词（tlyric），用于「显示歌词翻译」
    final tlyric = _asMap(data['tlyric'])['lyric'] as String? ?? '';
    return Lyrics(
      lines: LyricParser.parse(lrc, translationRaw: tlyric),
      raw: lrc,
    );
  }

  Future<Lyrics> _qq(String mid) async {
    if (mid.isEmpty) return Lyrics.empty;
    final response = await dio.get(
      'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
      queryParameters: {
        'songmid': mid,
        'format': 'json',
        'nobase64': '1',
        'g_tk': '5381',
      },
      options: Options(
        headers: {'Referer': 'https://y.qq.com/portal/player.html'},
      ),
    );

    final data = _asMap(response.data);
    final lrc = data['lyric'] as String? ?? '';
    final trans = data['trans'] as String? ?? '';
    return Lyrics(
      lines: LyricParser.parse(lrc, translationRaw: trans),
      raw: lrc,
    );
  }

  Future<Lyrics> _kugou(String hash, Duration duration) async {
    if (hash.isEmpty) return Lyrics.empty;

    final search = await dio.get(
      'https://lyrics.kugou.com/search',
      queryParameters: {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        'hash': hash.toUpperCase(),
        'duration': duration.inMilliseconds,
      },
    );
    final searchData = _asMap(search.data);
    final candidates = searchData['candidates'] as List? ?? const [];
    if (candidates.isEmpty || candidates.first is! Map) return Lyrics.empty;

    final candidate = Map<String, dynamic>.from(candidates.first as Map);
    final download = await dio.get(
      'https://lyrics.kugou.com/download',
      queryParameters: {
        'ver': '1',
        'client': 'pc',
        'id': candidate['id'],
        'accesskey': candidate['accesskey'],
        'fmt': 'lrc',
        'charset': 'utf8',
      },
    );

    final content = _asMap(download.data)['content'] as String?;
    if (content == null || content.isEmpty) return Lyrics.empty;

    final lrc = utf8.decode(
      base64.decode(content.replaceAll('\n', '')),
      allowMalformed: true,
    );
    return Lyrics(lines: LyricParser.parse(lrc), raw: lrc);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      var text = value.trim();
      if (text.startsWith('MusicJsonCallback(')) {
        text = text.substring('MusicJsonCallback('.length, text.length - 1);
      }
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }
}