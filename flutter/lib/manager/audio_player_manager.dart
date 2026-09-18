import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../model/song.dart';

enum PlaybackMode {
  sequential,
  repeatAll,
  repeatOne,
  shuffle,
}

class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<Song?> _songController =
      StreamController<Song?>.broadcast();
  final List<Song> _queue = [];
  int _currentIndex = -1;
  PlaybackMode playbackMode = PlaybackMode.sequential;
  Future<String?> Function(Song song)? resolveUrl;

  AudioPlayerManager() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_advanceAfterCompletion());
      }
    });
  }

  AudioPlayer get player => _player;

  List<Song> get queue => List.unmodifiable(_queue);

  int get currentIndex => _currentIndex;

  Song? get currentSong => _queue.length > _currentIndex && _currentIndex >= 0
      ? _queue[_currentIndex]
      : null;

  Stream<Song?> get currentSongStream => _songController.stream;

  Future<void> playUrl(
    String url, {
    Map<String, String>? headers,
    Song? metadataSong,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('无效的音频播放地址');
    }
    await _player.setAudioSource(
      AudioSource.uri(
        uri,
        tag: MediaItem(
          id: uri.toString(),
          title: metadataSong?.name ?? currentSong?.name ?? 'Beans Music',
          artist: metadataSong?.artists ?? currentSong?.artists,
          album: metadataSong?.album ?? currentSong?.album,
          artUri: metadataSong?.coverUrl == null
              ? null
              : Uri.tryParse(metadataSong!.coverUrl!),
        ),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
          ...?headers,
        },
      ),
    );
    await _player.play();
  }

  Future<void> playSongs(
    List<Song> songs, {
    int startAt = 0,
    bool skipUnavailable = false,
  }) async {
    if (songs.isEmpty) return;
    _queue
      ..clear()
      ..addAll(songs);
    await playQueueIndex(startAt, skipUnavailable: skipUnavailable);
  }

  Future<void> playQueueIndex(
    int index, {
    bool skipUnavailable = true,
  }) async {
    if (index < 0 || index >= _queue.length) return;
    if (resolveUrl == null) {
      throw StateError('播放器尚未配置播放地址解析器');
    }

    Object? lastError;
    final attempts = skipUnavailable ? _queue.length : 1;
    for (var offset = 0; offset < attempts; offset++) {
      final candidateIndex = (index + offset) % _queue.length;
      final song = _queue[candidateIndex];
      try {
        final url = await resolveUrl!(song);
        if (url == null || url.isEmpty) {
          lastError = StateError(
            '无法获取播放地址：${song.name}（${song.source.name}）',
          );
          continue;
        }
        _currentIndex = candidateIndex;
        _songController.add(song);
        await playUrl(url, metadataSong: song);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError('队列中没有可播放的歌曲：$lastError');
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (playbackMode == PlaybackMode.shuffle && _queue.length > 1) {
      final candidates = List<int>.generate(_queue.length, (index) => index)
        ..remove(_currentIndex);
      await playQueueIndex(candidates[
          DateTime.now().microsecondsSinceEpoch % candidates.length]);
      return;
    }
    if (_currentIndex + 1 < _queue.length) {
      await playQueueIndex(_currentIndex + 1);
    } else if (playbackMode == PlaybackMode.repeatAll) {
      await playQueueIndex(0);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await playQueueIndex(_currentIndex - 1);
    } else if (playbackMode == PlaybackMode.repeatAll) {
      await playQueueIndex(_queue.length - 1);
    }
  }

  Future<void> _advanceAfterCompletion() async {
    if (_queue.isEmpty) return;
    if (playbackMode == PlaybackMode.repeatOne) {
      await playQueueIndex(_currentIndex);
      return;
    }
    await next();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> dispose() async {
    await _songController.close();
    await _player.dispose();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}
