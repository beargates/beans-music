import 'song.dart';

class Ranking {
  final int id;
  final String name;
  final String subtitle;
  final String? coverUrl;
  final SongSource source;

  const Ranking({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.source,
    this.coverUrl,
  });
}
