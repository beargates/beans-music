import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';
import 'weapi_utils.dart';

class NeteaseMusicService {
  final Dio dio;

  NeteaseMusicService(this.dio);

  Future<List<Song>> search(String keyword, {int limit = 30, int offset = 0}) async {
    final payload = {
      's': keyword,
      'type': 1,
      'limit': limit,
      'offset': offset,
      'total': true,
    };

    final encrypted = WeapiUtils.encryptPayload(payload);

    final response = await dio.post(
      'https://music.163.com/weapi/cloudsearch/pc',
      data: encrypted,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Cookie': 'os=pc; appver=2.9.7',
        },
      ),
    );

    final responseData = _asMap(response.data);
    final result = responseData['result'] is Map
      ? Map<String, dynamic>.from(responseData['result'] as Map)
      : <String, dynamic>{};
    final songsJson = result['songs'] is List ? result['songs'] as List : const [];

    return songsJson
      .whereType<Map>()
      .map((item) => Song.fromNeteaseJson(Map<String, dynamic>.from(item)))
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
