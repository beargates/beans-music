import 'dart:convert';
import 'package:dio/dio.dart';
import '../model/song.dart';
import '../model/ranking.dart';
import '../model/playlist.dart';
import 'weapi_utils.dart';
import 'cover_image.dart';

/// 每日推荐API服务（使用项目统一的Dio配置）
class DailyRecommendService {
  final Dio _dio;
  static const String _baseUrl = 'https://music.163.com';

  DailyRecommendService(Dio dio) : _dio = dio;

  /// 获取网易云每日推荐歌曲
  Future<List<Song>> getDailySongs() async {
    try {
      final response = await _dio.post(
        '$_baseUrl/weapi/v3/discovery/recommend/songs',
        data: WeapiUtils.encryptPayload({}),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final jsonData = _asMap(response.data);
      final data = jsonData['data'] is Map
          ? Map<String, dynamic>.from(jsonData['data'] as Map)
          : <String, dynamic>{};
      final dailySongs =
          data['dailySongs'] is List ? data['dailySongs'] as List : const [];

      return dailySongs
          .whereType<Map>()
          .map((songJson) =>
              Song.fromNeteaseJson(Map<String, dynamic>.from(songJson)))
          .where((song) => song.id != 0)
          .toList();
    } catch (e) {
      throw Exception('获取每日推荐失败: $e');
    }
  }

  /// 获取QQ音乐每日推荐
  Future<List<Song>> getQQDailySongs() async {
    try {
      final results = await Future.wait(
        [26, 27, 62].map(_getQQTopSongs),
      );
      final songs = <Song>[];
      final seen = <String>{};
      for (final result in results) {
        for (final song in result) {
          if (seen.add(song.identityKey)) songs.add(song);
        }
      }
      songs.shuffle();
      return songs.take(30).toList();
    } catch (e) {
      throw Exception('获取QQ音乐每日推荐失败: $e');
    }
  }

  /// 获取酷狗音乐每日推荐
  Future<List<Song>> getKugouDailySongs() async {
    try {
      final response = await _dio.get(
        'https://songsearch.kugou.com/song_search_v2',
        queryParameters: {
          'keyword': '热门歌曲',
          'page': '1',
          'pagesize': '30',
        },
        options: Options(
          headers: {
            'Referer': 'https://www.kugou.com/',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final jsonData = _asMap(response.data);
      final data = jsonData['data'] is Map
          ? Map<String, dynamic>.from(jsonData['data'] as Map)
          : <String, dynamic>{};
      final list = data['lists'] is List
          ? data['lists'] as List
          : (data['song'] is List ? data['song'] as List : const []);

      return list
          .whereType<Map>()
          .map((songJson) =>
              Song.fromKugouJson(Map<String, dynamic>.from(songJson)))
          .where((song) => song.id != 0)
          .toList();
    } catch (e) {
      throw Exception('获取酷狗音乐每日推荐失败: $e');
    }
  }

  Future<List<Ranking>> getRankings(SongSource source) async {
    switch (source) {
      case SongSource.netease:
        return _getNeteaseRankings();
      case SongSource.qq:
        return _getQQRankings();
      case SongSource.kugou:
        return _getKugouRankings();
    }
  }

  Future<List<Song>> getRankingSongs(Ranking ranking) async {
    switch (ranking.source) {
      case SongSource.netease:
        final response = await _dio.post(
          '$_baseUrl/weapi/v3/playlist/detail',
          data: WeapiUtils.encryptPayload({
            'id': ranking.id,
            'n': 100,
            's': 8,
          }),
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        final json = _asMap(response.data);
        final playlist = json['playlist'] is Map
            ? Map<String, dynamic>.from(json['playlist'] as Map)
            : <String, dynamic>{};
        final tracks =
            playlist['tracks'] is List ? playlist['tracks'] as List : const [];
        return tracks
            .whereType<Map>()
            .map(
                (item) => Song.fromNeteaseJson(Map<String, dynamic>.from(item)))
            .where((song) => song.id != 0)
            .toList();
      case SongSource.qq:
        return _getQQTopSongs(ranking.id, limit: 100);
      case SongSource.kugou:
        final response = await _dio.get(
          'https://m.kugou.com/rank/info',
          queryParameters: {
            'rankid': ranking.id,
            'page': '1',
            'json': 'true',
          },
        );
        final json = _asMap(response.data);
        final songs = json['songs'] is Map
            ? Map<String, dynamic>.from(json['songs'] as Map)
            : <String, dynamic>{};
        final list = songs['list'] is List ? songs['list'] as List : const [];
        return list
            .whereType<Map>()
            .map((item) => Song.fromKugouJson(Map<String, dynamic>.from(item)))
            .where((song) => song.id != 0)
            .toList();
    }
  }

  /// 获取网易云歌单广场的热门歌单。
  Future<List<Playlist>> getPlaylistSquare({
    String category = '全部',
    int limit = 12,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/weapi/playlist/list',
        data: WeapiUtils.encryptPayload({
          'cat': category,
          'order': 'hot',
          'limit': limit,
          'offset': 0,
          'total': true,
        }),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final json = _asMap(response.data);
      final list =
          json['playlists'] is List ? json['playlists'] as List : const [];
      return list
          .whereType<Map>()
          .map((item) =>
              Playlist.fromNeteaseJson(Map<String, dynamic>.from(item)))
          .where((playlist) => playlist.id != 0 && playlist.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('获取歌单广场失败: $e');
    }
  }

  Future<List<String>> getPlaylistCategories() async {
    try {
      final response = await _dio.post(
        '$_baseUrl/weapi/playlist/catlist',
        data: WeapiUtils.encryptPayload({}),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final json = _asMap(response.data);
      final sub = json['sub'] is List ? json['sub'] as List : const [];
      return sub
          .whereType<Map>()
          .map((item) => item['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .take(18)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取网易云歌单歌曲。
  Future<List<Song>> getPlaylistSongs(Playlist playlist) async {
    if (playlist.source != SongSource.netease) {
      throw UnsupportedError('暂不支持该平台的歌单详情');
    }
    try {
      final response = await _dio.post(
        '$_baseUrl/weapi/v3/playlist/detail',
        data: WeapiUtils.encryptPayload({
          'id': playlist.id,
          'n': 100,
          's': 8,
        }),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final json = _asMap(response.data);
      final detail = json['playlist'] is Map
          ? Map<String, dynamic>.from(json['playlist'] as Map)
          : <String, dynamic>{};
      final tracks =
          detail['tracks'] is List ? detail['tracks'] as List : const [];
      return tracks
          .whereType<Map>()
          .map((item) => Song.fromNeteaseJson(Map<String, dynamic>.from(item)))
          .where((song) => song.id != 0)
          .toList();
    } catch (e) {
      throw Exception('获取歌单歌曲失败: $e');
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  Future<List<Ranking>> _getNeteaseRankings() async {
    final response = await _dio.post(
      '$_baseUrl/weapi/toplist/detail',
      data: WeapiUtils.encryptPayload({}),
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final json = _asMap(response.data);
    final list = json['list'] is List ? json['list'] as List : const [];
    final rankings = list
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return Ranking(
            id: value['id'] as int? ?? 0,
            name: value['name'] as String? ?? '',
            subtitle: value['updateFrequency'] as String? ?? '',
            coverUrl: normalizeCoverUrl(value['coverImgUrl'] as String?),
            source: SongSource.netease,
          );
        })
        .where((item) => item.id != 0)
        .take(12)
        .toList();
    final hotIndex = rankings.indexWhere((item) => item.name.contains('热歌榜'));
    if (hotIndex > 0) {
      final hot = rankings.removeAt(hotIndex);
      rankings.insert(0, hot);
    }
    return rankings;
  }

  Future<List<Ranking>> _getQQRankings() async {
    final response = await _dio.get(
      'https://c.y.qq.com/v8/fcg-bin/fcg_myqq_toplist.fcg',
      queryParameters: {'format': 'json'},
    );
    final json = _asMap(response.data);
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final list = data['topList'] is List ? data['topList'] as List : const [];
    return list
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return Ranking(
            id: value['id'] as int? ?? 0,
            name:
                value['topTitle'] as String? ?? value['title'] as String? ?? '',
            subtitle: 'QQ 峰尖榜',
            coverUrl: value['picUrl'] as String?,
            source: SongSource.qq,
          );
        })
        .where((item) => item.id != 0)
        .take(10)
        .toList();
  }

  Future<List<Ranking>> _getKugouRankings() async {
    final response = await _dio.get(
      'https://m.kugou.com/rank/list',
      queryParameters: {'json': 'true'},
    );
    final json = _asMap(response.data);
    final rank = json['rank'] is Map
        ? Map<String, dynamic>.from(json['rank'] as Map)
        : <String, dynamic>{};
    final list = rank['list'] is List ? rank['list'] as List : const [];
    return list
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return Ranking(
            id: value['rankid'] as int? ??
                int.tryParse('${value['rankid']}') ??
                0,
            name: value['rankname'] as String? ?? '',
            subtitle: value['update_frequency'] as String? ?? '',
            coverUrl: value['img'] as String?,
            source: SongSource.kugou,
          );
        })
        .where((item) => item.id != 0)
        .take(10)
        .toList();
  }

  Future<List<Song>> _getQQTopSongs(int topId, {int limit = 12}) async {
    try {
      final response = await _dio.get(
        'https://c.y.qq.com/v8/fcg-bin/fcg_v8_toplist_cp.fcg',
        queryParameters: {
          'format': 'json',
          'page': 'detail',
          'type': 'top',
          'topid': topId,
          'song_begin': 0,
          'song_num': limit,
        },
        options: Options(
          headers: {
            'Referer': 'https://y.qq.com/n/ryqq/toplist',
            'Origin': 'https://y.qq.com',
          },
        ),
      );
      final jsonData = _asMap(response.data);
      final rawList = jsonData['songlist'] is List
          ? jsonData['songlist'] as List
          : const [];
      return rawList
          .whereType<Map>()
          .map((item) {
            final data = item['data'] is Map ? item['data'] as Map : item;
            return Song.fromQQJson(Map<String, dynamic>.from(data));
          })
          .where((song) => song.id != 0 && song.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
