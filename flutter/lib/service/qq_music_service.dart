import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';

class QQMusicService {
  final Dio dio;

  QQMusicService(this.dio);

  Future<List<Song>> search(String keyword,
      {int limit = 30, int offset = 0}) async {
    final results = await _searchLegacy(
      keyword,
      limit: limit,
      offset: offset,
    );
    if (results.isNotEmpty) return results;
    return _searchMusicu(keyword, limit: limit, offset: offset);
  }

  Future<List<Song>> _searchMusicu(
    String keyword, {
    required int limit,
    required int offset,
  }) async {
    try {
      final response = await dio.post(
        'https://u.y.qq.com/cgi-bin/musicu.fcg',
        data: {
          'comm': {
            'ct': 19,
            'cv': 1859,
            'uin': '0',
            'format': 'json',
          },
          'req_1': {
            'module': 'music.search.SearchCgiService',
            'method': 'DoSearchForQQMusicDesktop',
            'param': {
              'query': keyword,
              'num_per_page': limit,
              'page_num': (offset ~/ limit) + 1,
              'search_type': 0,
              'grp': 1,
            },
          },
        },
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Referer': 'https://y.qq.com/portal/search.html',
            'Origin': 'https://y.qq.com',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final responseData = _asMap(response.data);
      final request = responseData['req_1'] is Map
          ? Map<String, dynamic>.from(responseData['req_1'] as Map)
          : <String, dynamic>{};
      final requestData = request['data'] is Map
          ? Map<String, dynamic>.from(request['data'] as Map)
          : <String, dynamic>{};
      final body = requestData['body'] is Map
          ? Map<String, dynamic>.from(requestData['body'] as Map)
          : <String, dynamic>{};
      final song = body['song'] is Map
          ? Map<String, dynamic>.from(body['song'] as Map)
          : <String, dynamic>{};
      final list = song['list'] is List ? song['list'] as List : const [];

      return list
          .whereType<Map>()
          .map((item) => Song.fromQQJson(Map<String, dynamic>.from(item)))
          .where((item) => item.name.isNotEmpty && item.qqMid != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Song>> _searchLegacy(
    String keyword, {
    required int limit,
    required int offset,
  }) async {
    final page = (offset ~/ limit) + 1;
    final encoded = Uri.encodeComponent(keyword);

    final url = 'https://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp'
        '?format=json&w=$encoded&n=$limit&p=$page&t=0';

    final response = await dio.get(
      url,
      options: Options(
        headers: {
          'Referer': 'https://y.qq.com/portal/player.html',
          'Cookie': 'uin=0; qqmusic_fromtag=66',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 QQMusic/9.0.5',
        },
      ),
    );

    final responseData = _asMap(response.data);
    final data = responseData['data'] is Map
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};
    final songData = data['song'] is Map
        ? Map<String, dynamic>.from(data['song'] as Map)
        : <String, dynamic>{};
    final list = songData['list'] is List ? songData['list'] as List : const [];

    return list
        .whereType<Map>()
        .map((item) => Song.fromQQJson(Map<String, dynamic>.from(item)))
        .toList();
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
