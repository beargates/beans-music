import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';

class QQMusicService {
  final Dio dio;

  QQMusicService(this.dio);

  Future<List<Song>> search(String keyword, {int limit = 30, int offset = 0}) async {
    final modernResults = await _searchMusicu(
      keyword,
      limit: limit,
      offset: offset,
    );
    if (modernResults.isNotEmpty) return modernResults;

    return _searchLegacy(keyword, limit: limit, offset: offset);
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

    final url =
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp'
        '?ct=24&qqmusic_ver=1298&new_json=1'
        '&remoteplace=txt.yqq.song'
        '&searchid=0&t=0&aggr=1&cr=1'
        '&lossless=0&flag_qc=0'
        '&p=$page'
        '&n=$limit'
        '&w=$encoded'
        '&format=json';

    final response = await dio.get(url);

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
