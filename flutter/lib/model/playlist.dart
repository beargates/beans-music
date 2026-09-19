import 'song.dart';
import '../service/cover_image.dart';

class Playlist {
  final int id;
  final String name;
  final String? coverUrl;
  final int trackCount;
  final String creatorName;
  final SongSource source;

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.trackCount = 0,
    this.creatorName = '',
    this.source = SongSource.netease,
  });

  factory Playlist.fromNeteaseJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final cover = [
      json['coverImgUrl'],
      json['picUrl'],
      json['coverUrl'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final coverId = json['coverImgId_str'] ?? json['coverImgId'];
    final creator = json['creator'];
    return Playlist(
      id: int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      coverUrl: cover.isNotEmpty
          ? _simplifyNeteaseCover(cover)
          : _neteaseCoverProxy(coverId),
      trackCount: int.tryParse(
            (json['trackCount'] ?? json['trackNumber'] ?? 0).toString(),
          ) ??
          0,
      creatorName: creator is Map ? creator['nickname']?.toString() ?? '' : '',
    );
  }

  static String? _neteaseCoverProxy(dynamic id) {
    final value = id?.toString().trim() ?? '';
    if (value.isEmpty || value == '0') return null;
    return 'https://music.163.com/api/img/blur/$value?param=300y300';
  }

  static String _simplifyNeteaseCover(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return normalizeCoverUrl(value);
    final match = RegExp(r'/(\d+)\.[^/]+$').firstMatch(uri.path);
    if (match == null) return normalizeCoverUrl(value);
    return uri
        .replace(
          scheme: 'https',
          queryParameters: {'param': '300y300'},
          fragment: '',
        )
        .toString();
  }

  factory Playlist.fromKugouJson(Map<String, dynamic> json) {
    final rawCover = json['imgurl'] ??
        json['pic'] ??
        json['cover'] ??
        json['sizable_cover'] ??
        json['list_pic'];
    return Playlist(
      id: int.tryParse(
            (json['specialid'] ?? json['listid'] ?? json['id'] ?? 0).toString(),
          ) ??
          0,
      name: (json['specialname'] ??
              json['listname'] ??
              json['name'] ??
              json['title'] ??
              '')
          .toString(),
      coverUrl: normalizeCoverUrl(rawCover?.toString()),
      trackCount: int.tryParse(
            (json['songcount'] ?? json['song_count'] ?? json['count'] ?? 0)
                .toString(),
          ) ??
          0,
      creatorName:
          (json['nickname'] ?? json['username'] ?? json['creatorname'] ?? '')
              .toString(),
      source: SongSource.kugou,
    );
  }
}
