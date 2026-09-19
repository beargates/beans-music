import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../auth/platform_auth_store.dart';
import '../model/song.dart';

class KugouMusicService {
  final Dio dio;
  final PlatformAuthStore? authStore;
  Map<String, String>? _deviceAuth;

  KugouMusicService(this.dio, {this.authStore});

  Future<List<Song>> search(String keyword, {int limit = 30}) async {
    final complete = await _searchComplete(keyword, limit: limit);
    if (complete.isNotEmpty) return complete;
    return _searchLegacy(keyword, limit: limit);
  }

  Future<List<Song>> _searchComplete(
    String keyword, {
    required int limit,
  }) async {
    try {
      final pageSize = limit.clamp(1, 50);
      final pages =
          ((limit.clamp(1, 150) + pageSize - 1) ~/ pageSize).clamp(1, 3);
      final result = <Song>[];
      final seen = <String>{};
      for (var page = 1; page <= pages; page++) {
        final songs = await _searchCompletePage(
          keyword,
          page: page,
          pageSize: pageSize,
        );
        for (final song in songs) {
          if (seen.add(song.identityKey)) {
            result.add(song);
            if (result.length >= limit) return result;
          }
        }
        if (songs.length < pageSize) break;
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<Song>> _searchCompletePage(
    String keyword, {
    required int page,
    required int pageSize,
  }) async {
    final auth = _kugouAuth();
    final params = <String, String>{
      'ab_tag': '1',
      'ability': '57343',
      'albumhide': '1',
      'apiver': '22',
      'appid': '1000',
      'area_code': '1',
      'clienttime': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'clientver': '20549',
      'com_user_type': '0',
      'cursor': '$page',
      'dfid': auth['dfid'] ?? '-',
      'is_gpay': '0',
      'iscorrection': '1',
      'keyword': keyword,
      'mid': auth['mid'] ?? '0',
      'mode_ability': '0',
      'nocollect': '0',
      'osversion': '16.0',
      'platform': 'IOSFilter',
      'recver': '2',
      'req_ai': '1',
      'search_ability': '31',
      'search_source': '手动输入',
      'sec_aggre': '1',
      'sec_aggre_bitmap': '22',
      'style_type': '3',
      'tag': 'em',
      'token': auth['token'] ?? '',
      'userid': auth['userid'] ?? '0',
      'uuid': auth['guid'] ?? auth['mid'] ?? '0',
    };
    final body = params.entries
        .where((entry) => entry.key != 'signature')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final signatureBody =
        body.map((entry) => '${entry.key}=${entry.value}').join();
    params['signature'] = md5
        .convert(utf8.encode(
          'y9tjae~n)k)vn[8$signatureBody'
          'y9tjae~n)k)vn[8',
        ))
        .toString();

    final response = await dio.get(
      'https://gateway.kugou.com/complexsearch/v3/search/mixed',
      queryParameters: params,
      options: Options(
        headers: {
          'KG-RF': 'D4407D2505656C0FDC1621BA6FA3FEB5',
          'KG-FAKE': '359933394',
          'KG-FAKE-TYPE': '29,1',
          'KG-RC': '1',
          'UNI-UserAgent': 'iOS16.0-Phone-1009-0-WiFi',
          'Accept': '*/*',
          'Accept-Language': 'zh-Hans-CN;q=1',
          'Referer': 'https://www.kugou.com/',
          'User-Agent':
              'IPhone-20549-Search#183534257/723988397/625045823/284854956-SearchGeneralInfoWithKeyWordV8',
        },
      ),
    );
    final json = _asMap(response.data);
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final groups = data['lists'] is List ? data['lists'] as List : const [];
    final songGroup = groups.whereType<Map>().cast<Map>().firstWhere(
      (group) {
        final type = group['type']?.toString().toLowerCase();
        return type == 'song' || type == 'songs';
      },
      orElse: () => <String, dynamic>{},
    );
    final rows =
        songGroup['lists'] is List ? songGroup['lists'] as List : const [];
    return rows
        .whereType<Map>()
        .map((item) => _songFromCompleteJson(
              Map<String, dynamic>.from(item),
            ))
        .where((song) => song.name.isNotEmpty && song.kugouHash != null)
        .take(pageSize)
        .toList();
  }

  Song _songFromCompleteJson(Map<String, dynamic> raw) {
    final authors = raw['authors'];
    var singer = raw['SingerName'] ?? raw['singername'];
    if ((singer == null || singer.toString().trim().isEmpty) &&
        authors is List) {
      singer = authors
          .whereType<Map>()
          .map((author) => author['author_name'] ?? author['name'])
          .where((name) => name != null && name.toString().trim().isNotEmpty)
          .join(' / ');
    }
    final normalized = <String, dynamic>{
      ...raw,
      'songname': _cleanText(
        raw['SongName'] ?? raw['FileName'] ?? raw['songname'],
      ),
      'filename': _cleanText(
        raw['FileName'] ?? raw['SongName'] ?? raw['filename'],
      ),
      'singername': _cleanText(singer),
      'album_name': _cleanText(raw['AlbumName'] ?? raw['album_name']),
      'hash': raw['FileHash'] ?? raw['Hash'] ?? raw['hash'],
      'album_id': raw['AlbumID'] ?? raw['album_id'],
      'duration': raw['Duration'] ??
          raw['duration'] ??
          raw['timeLen'] ??
          raw['timelength'],
      'album_sizable_cover': raw['Image'] ??
          raw['ImageUrl'] ??
          raw['AlbumImg'] ??
          raw['album_sizable_cover'],
      'pay_type': raw['PayType'] ?? raw['Privilege'] ?? raw['pay_type'],
      'feetype': raw['FeeType'] ?? raw['feetype'],
      'privilege': raw['Privilege'] ?? raw['privilege'],
      'pay_type_320': raw['PayType320'] ?? raw['pay_type_320'],
      'pay_type_sq': raw['PayTypeSQ'] ?? raw['pay_type_sq'],
    };
    return Song.fromKugouJson(normalized);
  }

  String _cleanText(dynamic value) {
    var text = value?.toString() ?? '';
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final codePoint = int.tryParse(match.group(1)!);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Map<String, String> _kugouAuth() {
    if (_deviceAuth != null) return _deviceAuth!;
    final saved = authStore?.kugouAuth ?? const <String, String>{};
    var guid = saved['KUGOU_API_GUID'] ?? saved['guid'] ?? '';
    var mid = saved['KUGOU_API_MID'] ?? saved['mid'] ?? '';
    if (guid.isEmpty) {
      guid = md5
          .convert(
            utf8.encode('beans-kugou-${DateTime.now().microsecondsSinceEpoch}'),
          )
          .toString();
    }
    if (mid.isEmpty) {
      final hex = md5.convert(utf8.encode(guid)).toString().substring(0, 15);
      mid = int.parse(hex, radix: 16).toString();
    }
    _deviceAuth = {
      ...saved,
      'KUGOU_API_GUID': guid,
      'KUGOU_API_MID': mid,
    };
    if (authStore != null &&
        (saved['KUGOU_API_GUID'] != guid || saved['KUGOU_API_MID'] != mid)) {
      authStore!.saveKugouAuth(_deviceAuth!);
    }
    return _deviceAuth!;
  }

  Future<List<Song>> _searchLegacy(String keyword, {required int limit}) async {
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
    final list = (data['lists'] as List?) ??
        (data['song'] as List?) ??
        (data['info'] as List?) ??
        [];

    return list
        .whereType<Map>()
        .map((item) => _songFromCompleteJson(Map<String, dynamic>.from(item)))
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
