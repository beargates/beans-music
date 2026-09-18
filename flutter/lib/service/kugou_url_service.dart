import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import '../model/song.dart';

class KugouUrlResult {
  final String url;
  final bool isAvailable;

  KugouUrlResult({
    required this.url,
    this.isAvailable = true,
  });
}

class KugouSongUrlService {
  final Dio dio;

  KugouSongUrlService(this.dio);

  Future<KugouUrlResult?> getSongUrl(String hash) async {
    try {
      if (hash.isEmpty) return null;
      const appId = '3116';
      const version = '11440';
      const mid = '0';
      const userId = '0';
      final normalizedHash = hash.toUpperCase();
      final signature = md5.convert(
        utf8.encode('$normalizedHash' 'kgcloudv2' '$appId$mid$userId'),
      ).toString();

      final response = await dio.get(
        'https://trackercdn.kugou.com/i/v2/',
        queryParameters: {
          'cmd': '26',
          'hash': normalizedHash,
          'behavior': 'play',
          'appid': appId,
          'pid': '2',
          'mid': mid,
          'userid': userId,
          'version': version,
          'vipType': '0',
          'token': '0',
          'key': signature,
        },
        options: Options(
          headers: {
            'Referer': 'https://www.kugou.com/',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final data = _asMap(response.data);
      final urls = data['url'] is List ? data['url'] as List : const [];
      final audioUrl = urls.whereType<String>().firstWhere(
        (url) => url.isNotEmpty,
        orElse: () => '',
          );

      if (audioUrl.isEmpty) {
        return null;
      }

      return KugouUrlResult(
        url: audioUrl.replaceFirst('http://', 'https://'),
        isAvailable: true,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }
}

class KugouUrlRepository {
  final KugouSongUrlService kugou;

  KugouUrlRepository({required this.kugou});

  Future<KugouUrlResult?> resolveUrl(Song song) async {
    if (song.source != SongSource.kugou) return null;
    return kugou.getSongUrl(song.kugouHash ?? '');
  }
}
