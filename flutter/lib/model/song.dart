import '../service/cover_image.dart';

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
    final cover = normalizeCoverUrl(album['picUrl'] as String?);

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
    final fee = (json['fee'] as int?) ??
        (pay['pay_play'] as int?) ??
        (pay['payplay'] as int?) ??
        0;

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
    final albumName = _stringValue(
      json['album_name'] ??
          json['albumName'] ??
          json['AlbumName'] ??
          (json['albuminfo'] is Map
              ? (json['albuminfo'] as Map)['name']
              : null),
    );
    var artistName = _stringValue(
      json['singername'] ??
          json['singer_name'] ??
          json['SingerName'] ??
          json['author_name'] ??
          json['singer'] ??
          json['artist'],
    );
    if (artistName.isEmpty && json['authors'] is List) {
      artistName = (json['authors'] as List)
          .whereType<Map>()
          .map((author) => _stringValue(
                author['author_name'] ?? author['name'],
              ))
          .where((name) => name.isNotEmpty)
          .join(' / ');
    }
    final hash = _stringValue(json['hash'] ??
        json['Hash'] ??
        json['FileHash'] ??
        json['HQFileHash'] ??
        json['file_hash'] ??
        json['audio_hash']);
    final albumId = _stringValue(
      json['album_id'] ?? json['albumID'] ?? json['AlbumID'] ?? json['albumid'],
    );
    final cover = _stringValue(json['img'] ??
        json['cover'] ??
        json['album_img'] ??
        json['album_sizable_cover'] ??
        json['ImageUrl'] ??
        json['image'] ??
        json['AlbumImg'] ??
        (json['trans_param'] is Map
            ? (json['trans_param'] as Map)['union_cover']
            : null));
    final rawCover = _stringValue(
      json['Image'] ?? json['AlbumImage'] ?? cover,
    );
    final coverUrl = rawCover
        .replaceAll('{size}', '400')
        .replaceAll('%7Bsize%7D', '400')
        .replaceFirst('http://', 'https://');
    final rawDuration = _intValue(
      json['duration'] ??
          json['Duration'] ??
          json['time'] ??
          json['timelength'] ??
          json['timeLen'] ??
          json['interval'],
    );
    final durationSec = rawDuration > 1000 ? rawDuration ~/ 1000 : rawDuration;
    final privilege = _kugouVipFee(json);
    final rawId = json['id'] ?? json['ID'] ?? json['Audioid'];
    final id = int.tryParse(rawId?.toString() ?? '') ?? hash.hashCode;
    var songName = _stringValue(
      json['songname'] ?? json['song_name'] ?? json['name'] ?? json['SongName'],
    );
    final fileName = _stringValue(json['filename'] ?? json['FileName']);
    if (fileName.isNotEmpty) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        if (artistName.isEmpty) artistName = parts.first.trim();
        if (songName.isEmpty || songName == fileName) {
          songName = parts.skip(1).join(' - ').trim();
        }
      } else if (songName.isEmpty) {
        songName = fileName;
      }
    }

    return Song(
      id: id,
      name: songName,
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

  static String _stringValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(_stringValue(value)) ?? 0;
  }

  static int _kugouVipFee(Map<String, dynamic> json) {
    var explicit = 0;
    var privilege = 0;
    var flagged = false;

    void visit(dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key
              .toString()
              .toLowerCase()
              .replaceAll('_', '')
              .replaceAll('-', '');
          final child = entry.value;
          if ({
            'fee',
            'feetype',
            'paytype',
            'paytype320',
            'paytypesq',
            'mediapaytype',
            'needpay',
          }.contains(key)) {
            explicit =
                explicit > _intValue(child) ? explicit : _intValue(child);
          }
          if ({
            'privilege',
            'mediaprivilege',
            '320privilege',
            'sqprivilege',
          }.contains(key)) {
            privilege =
                privilege > _intValue(child) ? privilege : _intValue(child);
          }
          if ({
            'vip',
            'isvip',
            'onlyvipplayable',
            'viprequired',
            'needvip',
          }.contains(key)) {
            final text = _stringValue(child).toLowerCase();
            flagged = flagged ||
                (child is bool && child) ||
                _intValue(child) > 0 ||
                text == 'true' ||
                text.contains('vip') ||
                text.contains('会员');
          }
          visit(child);
        }
      } else if (value is List) {
        for (final child in value) {
          visit(child);
        }
      }
    }

    visit(json);
    if (explicit > 0) return explicit;
    if (privilege >= 9 || flagged) return 1;
    return 0;
  }
}
