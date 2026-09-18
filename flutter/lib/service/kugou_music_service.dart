import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';

class KugouMusicService {
  final Dio dio;

  KugouMusicService(this.dio);

  Future<List<Song>> search(String keyword, {int limit = 30}) async {
    final url =
        'https://songsearch.kugou.com/song_search_v2?keyword=${Uri.encodeComponent(keyword)}&page=1&pagesize=${limit < 1 ? 1 : limit}';

    final response = await dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://www.kugou.com/',
        },
      ),
    );

    final json = _asMap(response.data);
    final data = json['data'] is Map
      ? Map<String, dynamic>.from(json['data'] as Map)
      : <String, dynamic>{};
    final list = (data['lists'] as List?) ?? (data['song'] as List?) ?? (data['info'] as List?) ?? [];

    return list
      .whereType<Map>()
      .map((item) => Song.fromKugouJson(Map<String, dynamic>.from(item)))
        .toList();
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
