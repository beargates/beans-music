import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';
import 'kugou_url_service.dart';
import 'weapi_utils.dart';
import 'third_party_song_url_service.dart';

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
      if (songMid.isEmpty) {
        return null;
      }

      final preferredMid =
          mediaMid == null || mediaMid.isEmpty ? songMid : mediaMid;
      final guid =
          (DateTime.now().microsecondsSinceEpoch % 900000000 + 100000000)
              .toString();
      for (final quality in const ['M800', 'M500', 'C400']) {
        final extension = quality == 'C400' ? 'm4a' : 'mp3';
        final filenames = {
          '$quality$songMid$preferredMid.$extension',
          '$quality$preferredMid.$extension',
          '$quality$songMid$songMid.$extension',
          '$quality$songMid.$extension',
        }.toList();
        final payload = {
          'comm': {'uin': 0, 'format': 'json', 'ct': 24, 'cv': 0},
          'req': {
            'module': 'CDN.SrfCdnDispatchServer',
            'method': 'GetCdnDispatch',
            'param': {'guid': guid, 'calltype': 0, 'userip': ''},
          },
          'req_0': {
            'module': 'vkey.GetVkeyServer',
            'method': 'CgiGetVkey',
            'param': {
              'guid': guid,
              'filename': filenames,
              'songmid': List.filled(filenames.length, songMid),
              'songtype': List.filled(filenames.length, 0),
              'uin': '0',
              'loginflag': 1,
              'platform': '20',
            },
          },
        };

        final response = await dio.get(
          'https://u.y.qq.com/cgi-bin/musicu.fcg',
          queryParameters: {
            'format': 'json',
            'data': jsonEncode(payload),
          },
          options: Options(headers: {
            'Referer': 'https://y.qq.com/',
            'Origin': 'https://y.qq.com',
            'Cookie': 'uin=0; qqmusic_fromtag=66',
          }),
        );
        final responseData = _decodeResponseMap(response.data);
        final request = responseData['req_0'];
        final reqData = request is Map
            ? Map<String, dynamic>.from(request)
            : <String, dynamic>{};
        final data = reqData['data'] is Map
            ? Map<String, dynamic>.from(reqData['data'] as Map)
            : <String, dynamic>{};
        final infos = (data['midurlinfo'] as List?) ?? const [];
        final info = infos.whereType<Map>().firstWhere(
              (item) => (item['purl']?.toString() ?? '').isNotEmpty,
              orElse: () => <String, dynamic>{},
            );
        final purl = info['purl']?.toString() ?? '';
        if (purl.isEmpty) continue;
        final sip = (data['sip'] as List?)?.first?.toString();
        final base = sip == null || sip.isEmpty
            ? 'https://isure.stream.qqmusic.qq.com/'
            : (sip.startsWith('http') ? sip : 'https://$sip');
        final url = purl.startsWith('http')
            ? purl
            : '${base.endsWith('/') ? base : '$base/'}$purl';
        return SongUrlResult(url: url, quality: quality);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class SongUrlRepository {
  final NeteaseSongUrlService netease;
  final QQSongUrlService qq;
  final KugouSongUrlService? kugou;
  final ThirdPartySongUrlService? thirdParty;

  SongUrlRepository({
    required this.netease,
    required this.qq,
    this.kugou,
    this.thirdParty,
  });

  Future<SongUrlResult?> resolveUrl(Song song) async {
    SongUrlResult? resolved;
    switch (song.source) {
      case SongSource.netease:
        resolved = await netease.getSongUrl(song.id);
        break;
      case SongSource.qq:
        resolved = await qq.getSongUrl(
          songMid: song.qqMid ?? '',
          mediaMid: song.qqMediaMid,
        );
        break;
      case SongSource.kugou:
        final resolved = await kugou?.getSongUrl(song.kugouHash ?? '');
        if (resolved != null) {
          return SongUrlResult(
            url: resolved.url,
            quality: 'kugou',
            isAvailable: resolved.isAvailable,
          );
        }
    }
    return resolved ?? await thirdParty?.getSongUrl(song);
  }
}
