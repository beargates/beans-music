import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../model/song.dart';

class DownloadService {
  final Dio dio;
  final Future<String?> Function(Song song) resolveUrl;

  DownloadService({
    required this.dio,
    required this.resolveUrl,
  });

  Future<File> download(Song song) async {
    final url = await resolveUrl(song);
    if (url == null || url.isEmpty) {
      throw StateError('该歌曲没有可用下载地址');
    }

    final directory = await getApplicationDocumentsDirectory();
    final downloads = Directory('${directory.path}/BeansMusic/Downloads');
    await downloads.create(recursive: true);
    final file = File('${downloads.path}/${_safeName(song)}.mp3');
    await dio.download(url, file.path, deleteOnError: true);
    return file;
  }

  String _safeName(Song song) {
    final raw = '${song.name} - ${song.artists}'.trim();
    final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return safe.isEmpty ? song.identityKey : safe;
  }
}
