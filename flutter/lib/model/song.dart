enum SongSource { netease, qq, kugou }

class Song {
  final int id;
  final String name;
  final String artists;
  final String album;
  final String? coverUrl;
  final Duration duration;
  final SongSource source;
  final String? qqMid;
  final String? qqMediaMid;
  final String? kugouHash;
  final String? kugouAlbumAudioId;
  final String? kugouAlbumId;
  final Map<String, String>? kugouQualityHashes;
  final int fee;

  Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    this.coverUrl,
    required this.duration,
    required this.source,
    this.qqMid,
    this.qqMediaMid,
    this.kugouHash,
    this.kugouAlbumAudioId,
    this.kugouAlbumId,
    this.kugouQualityHashes,
    this.fee = 0,
  });

  String get identityKey => '${source.name}-$id';

  bool get isVip => fee > 0;

  String get formattedDuration {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artists': artists,
      'album': album,
      'coverUrl': coverUrl,
      'durationMs': duration.inMilliseconds,
      'source': source.name,
      'qqMid': qqMid,
      'qqMediaMid': qqMediaMid,
      'kugouHash': kugouHash,
      'kugouAlbumAudioId': kugouAlbumAudioId,
      'kugouAlbumId': kugouAlbumId,
      'kugouQualityHashes': kugouQualityHashes,
      'fee': fee,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source'] as String? ?? SongSource.netease.name;
    final source = SongSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => SongSource.netease,
    );
    final qualityHashes = json['kugouQualityHashes'] is Map
        ? Map<String, String>.from(
            (json['kugouQualityHashes'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
        : null;

    return Song(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      artists: json['artists'] as String? ?? '',
      album: json['album'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      source: source,
      qqMid: json['qqMid'] as String?,
      qqMediaMid: json['qqMediaMid'] as String?,
      kugouHash: json['kugouHash'] as String?,
      kugouAlbumAudioId: json['kugouAlbumAudioId'] as String?,
      kugouAlbumId: json['kugouAlbumId'] as String?,
      kugouQualityHashes: qualityHashes,
      fee: json['fee'] as int? ?? 0,
    );
  }

  factory Song.fromNeteaseJson(Map<String, dynamic> json) {
    final artists = ((json['ar'] as List?) ?? [])
        .map((e) => (e as Map)['name'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .join(' / ');

    final album = (json['al'] as Map<String, dynamic>? ?? {});
    final cover = album['picUrl'] as String? ?? '';

    return Song(
      id: (json['id'] as int?) ?? 0,
      name: json['name'] as String? ?? '',
      artists: artists,
      album: album['name'] as String? ?? '',
      coverUrl: cover.isEmpty ? null : cover,
      duration: Duration(milliseconds: (json['dt'] as int?) ?? 0),
      source: SongSource.netease,
      fee: (json['fee'] as int?) ?? 0,
    );
  }

  factory Song.fromQQJson(Map<String, dynamic> json) {
    final singer = ((json['singer'] as List?) ?? [])
        .map((e) => (e as Map)['name'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .join(' / ');

    final pay = json['pay'] as Map<String, dynamic>? ?? {};
    final fee =
        (json['fee'] as int?) ?? (pay['pay_play'] as int?) ?? (pay['payplay'] as int?) ?? 0;

    final album = json['album'] is Map
      ? Map<String, dynamic>.from(json['album'] as Map)
      : <String, dynamic>{};
    final albumMid = json['albummid'] as String? ??
      json['albumMID'] as String? ??
      album['mid'] as String?;
    final file = json['file'] as Map<String, dynamic>? ?? {};
    final mediaMid = file['media_mid'] as String? ??
        json['strMediaMid'] as String? ??
        json['media_mid'] as String?;

    return Song(
        id: (json['songid'] as int?) ?? (json['id'] as int?) ?? 0,
        name: json['songname'] as String? ?? json['name'] as String? ?? '',
      artists: singer,
        album: json['albumname'] as String? ??
          json['albumName'] as String? ??
          album['name'] as String? ??
          '',
      coverUrl: albumMid == null
          ? null
          : 'https://y.gtimg.cn/music/photo_new/T002R300x300M000$albumMid.jpg',
      duration: Duration(seconds: (json['interval'] as int?) ?? 0),
      source: SongSource.qq,
      qqMid: json['songmid'] as String? ?? json['mid'] as String?,
      qqMediaMid: mediaMid,
      fee: fee,
    );
  }

  factory Song.fromKugouJson(Map<String, dynamic> json) {
    final albumName = json['album_name'] as String? ??
      json['albumName'] as String? ??
      json['AlbumName'] as String? ??
      '';
    final artistName = json['singername'] as String? ??
      json['singer_name'] as String? ??
      json['SingerName'] as String? ??
      ((json['Singers'] as List?)?.firstOrNull as Map?)?['name'] as String? ??
      '';
    final hash = json['hash'] as String? ??
      json['Hash'] as String? ??
      json['FileHash'] as String? ??
      json['HQFileHash'] as String? ??
      '';
    final albumId = (json['album_id'] ?? json['albumID'] ?? json['AlbumID'])?.toString() ?? '';
    final cover = json['img'] as String? ??
      json['cover'] as String? ??
      json['album_img'] as String? ??
      json['ImageUrl'] as String? ??
      '';
    final rawCover = json['Image'] as String? ??
      json['AlbumImage'] as String? ??
      cover;
    final coverUrl = rawCover
      .replaceAll('{size}', '400')
      .replaceFirst('http://', 'https://');
    final durationSec = (json['duration'] as int?) ??
      (json['Duration'] as int?) ??
      (json['time'] as int?) ??
      0;
    final privilege = (json['PayType'] as int?) ??
      (json['Privilege'] as int?) ??
      (json['HQPrivilege'] as int?) ??
      0;
    final rawId = json['id'] ?? json['ID'] ?? json['Audioid'];
    final id = int.tryParse(rawId?.toString() ?? '') ?? hash.hashCode;

    return Song(
      id: id,
      name: json['songname'] as String? ??
        json['name'] as String? ??
        json['SongName'] as String? ??
        '',
      artists: artistName,
      album: albumName,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      duration: Duration(seconds: durationSec),
      source: SongSource.kugou,
      kugouHash: hash,
      kugouAlbumId: albumId,
      fee: privilege,
    );
  }
}
