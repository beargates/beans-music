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
    final cover = json['coverImgUrl'] ?? json['picUrl'];
    final creator = json['creator'];
    return Playlist(
      id: int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      coverUrl: normalizeCoverUrl(cover?.toString()),
      trackCount: int.tryParse(
            (json['trackCount'] ?? json['trackNumber'] ?? 0).toString(),
          ) ??
          0,
      creatorName: creator is Map
          ? creator['nickname']?.toString() ?? ''
          : '',
    );
  }
}
