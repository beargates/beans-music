import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';
import 'kugou_url_service.dart';
import 'weapi_utils.dart';

Map<String, dynamic> _decodeResponseMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}

class SongUrlResult {
  final String url;
  final String quality;
  final bool isAvailable;

  SongUrlResult({
    required this.url,
    required this.quality,
    this.isAvailable = true,
  });
}

class NeteaseSongUrlService {
  final Dio dio;

  NeteaseSongUrlService(this.dio);

  Future<SongUrlResult?> getSongUrl(int songId) async {
    try {
      final payload = {
        'ids': [songId],
        'level': 'lossless',
        'encodeType': 'mp3',
      };

      final body = WeapiUtils.encryptPayload(payload);

      final response = await dio.post(
        'https://music.163.com/weapi/song/enhance/player/url/v1',
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Referer': 'https://music.163.com',
            'Origin': 'https://music.163.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final responseData = _decodeResponseMap(response.data);
      final data = responseData['data'] as List? ?? [];
      final first = data.isNotEmpty ? data.first : null;
      final url = first is Map ? first['url'] as String? : null;

      if (url == null || url.isEmpty) {
        return null;
      }

      return SongUrlResult(
        url: url,
        quality: 'lossless',
        isAvailable: true,
      );
    } catch (_) {
      return null;
    }
  }
}

class QQSongUrlService {
  final Dio dio;

  QQSongUrlService(this.dio);

  Future<SongUrlResult?> getSongUrl({
    required String songMid,
    String? mediaMid,
  }) async {
    try {
      final mid = mediaMid ?? songMid;
      if (mid.isEmpty) {
        return null;
      }

      final vkeyUrl =
          'https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data={"req":{"module":"vkey.GetVkeyServer","method":"CgiGetVkey","param":{"guid":"1234567890","songmid":["$mid"],"songtype":[0],"uin":"0","loginflag":1,"platform":"20"}}}'
              .replaceAll('\n', '');

      final response = await dio.get(vkeyUrl, options: Options(headers: {
        'Referer': 'https://y.qq.com/',
        'Origin': 'https://y.qq.com',
      }));

      final responseData = _decodeResponseMap(response.data);
      final reqData = responseData['req'] is Map
          ? Map<String, dynamic>.from(responseData['req'] as Map)
          : <String, dynamic>{};
      final data = reqData['data'] is Map
          ? Map<String, dynamic>.from(reqData['data'] as Map)
          : <String, dynamic>{};
      final midUrlInfo = (data['midurlinfo'] as List?)?.firstOrNull;
      final url = midUrlInfo is Map ? midUrlInfo['purl'] as String? : null;

      if (url == null || url.isEmpty) {
        return null;
      }

      return SongUrlResult(
        url: 'https://isure.stream.qqmusic.qq.com/$url',
        quality: 'qq',
        isAvailable: true,
      );
    } catch (_) {
      return null;
    }
  }

}

class SongUrlRepository {
  final NeteaseSongUrlService netease;
  final QQSongUrlService qq;
  final KugouSongUrlService? kugou;

  SongUrlRepository({
    required this.netease,
    required this.qq,
    this.kugou,
  });

  Future<SongUrlResult?> resolveUrl(Song song) async {
    switch (song.source) {
      case SongSource.netease:
        return netease.getSongUrl(song.id);
      case SongSource.qq:
        return qq.getSongUrl(
          songMid: song.qqMid ?? '',
          mediaMid: song.qqMediaMid,
        );
      case SongSource.kugou:
        final resolved = await kugou?.getSongUrl(song.kugouHash ?? '');
        if (resolved == null) return null;
        return SongUrlResult(
          url: resolved.url,
          quality: 'kugou',
          isAvailable: resolved.isAvailable,
        );
    }
  }
}
