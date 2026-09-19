import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/song.dart';
import 'song_url_service.dart';

class ThirdPartySongUrlService {
  final Dio dio;
  final String apiKey;

  ThirdPartySongUrlService(this.dio, {this.apiKey = ''});

  Future<SongUrlResult?> getSongUrl(Song song) async {
    if (song.name.trim().isEmpty) return null;
    final source = switch (song.source) {
      SongSource.netease => 'wy',
      SongSource.qq => 'tx',
      SongSource.kugou => 'kg',
    };
    final songId = switch (song.source) {
      SongSource.netease => song.id.toString(),
      SongSource.qq => song.qqMid ?? '',
      SongSource.kugou => song.kugouHash ?? '',
    };
    if (songId.isEmpty) return null;

    try {
      final response = await dio.get(
        'https://source.shiqianjiang.cn/api/music/url',
        queryParameters: {
          'source': source,
          'songId': songId,
          'quality': '320k',
        },
        options: Options(
          // 第三方服务偶尔返回错误的 text/plain MIME 类型；
          // 先按纯文本接收，再自行兼容 JSON 和裸 URL。
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 7),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'BeansMusic-Preset/1.0',
            if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
          },
        ),
      );
      final body = response.data is String
          ? _decodeBody(response.data as String)
          : response.data;
      final url = _findUrl(body);
      if (url == null || url.isEmpty) return null;
      return SongUrlResult(url: url, quality: 'third-party');
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _findUrl(dynamic value) {
    if (value is String) {
      final text = value.trim();
      if (text.startsWith(RegExp(r'https?://'))) return text;
      try {
        return _findUrl(jsonDecode(text));
      } on FormatException {
        return null;
      }
    }
    if (value is Map) {
      for (final entry in value.entries) {
        final result = _findUrl(entry.value);
        if (result != null) return result;
      }
    }
    if (value is List) {
      for (final item in value) {
        final result = _findUrl(item);
        if (result != null) return result;
      }
    }
    return null;
  }

  dynamic _decodeBody(String body) {
    final text = body.trim();
    if (text.isEmpty) return text;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }
}
