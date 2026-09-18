import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;

import '../manager/audio_player_manager.dart';
import '../model/song.dart';
import '../service/cover_palette.dart';
import '../service/download_service.dart';
import '../service/lyric_service.dart';
import '../store/lyric_style_store.dart';
import '../widget/lyrics_view.dart';
import 'lyric_settings_sheet.dart';

/// 播放器页：封面 ⇄ 歌词双模式。
///
/// - 封面点击 / 歌词区点击切换模式（封面平滑缩到左上角）
/// - 封面模式下显示 5 行歌词预览，跟随当前播放行
/// - 歌词模式下自动跟随、点击跳转、长按多选复制、完整样式设置
class PlayerPage extends StatefulWidget {
  final Song song;
  final AudioPlayerManager playerManager;
  final LyricStyleStore style;
  final LyricService? lyricService;
  final DownloadService? downloadService;
  final CoverColorExtractor? colorExtractor;

  const PlayerPage({
    super.key,
    required this.song,
    required this.playerManager,
    required this.style,
    this.lyricService,
    this.downloadService,
    this.colorExtractor,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late Song _song;
  bool _isPlaying = false;
  bool _showLyrics = false;
  bool _downloading = false;
  bool _lyricsLoading = false;
  Lyrics? _lyrics;
  RgbColor? _dominant;
  int? _currentLineIndex;
  Duration _lastPosition = Duration.zero;
  Duration _duration = Duration.zero;
  double? _dragProgress;

  StreamSubscription<Song?>? _songSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _duration = widget.song.duration;
    _dominant = widget.colorExtractor?.cachedColor(widget.song.coverUrl);
    _bindPlayer();
    widget.style.addListener(_handleStyleChanged);
    _loadDominantColor();
    _loadLyrics(showLoading: true);
  }

  @override
  void dispose() {
    widget.style.removeListener(_handleStyleChanged);
    _songSubscription?.cancel();
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  void _bindPlayer() {
    _stateSubscription = widget.playerManager.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });

    _durationSubscription = widget.playerManager.durationStream.listen((value) {
      if (!mounted || value == null || value <= Duration.zero) return;
      if (value == _duration) return;
      setState(() => _duration = value);
    });

    _positionSubscription =
        widget.playerManager.positionStream.listen(_handlePosition);

    _songSubscription = widget.playerManager.currentSongStream.listen((song) {
      if (!mounted || song == null) return;
      if (song.identityKey == _song.identityKey) return;
      setState(() {
        _song = song;
        _lyrics = null;
        _currentLineIndex = null;
        _lastPosition = Duration.zero;
        _duration = song.duration;
        _dominant = widget.colorExtractor?.cachedColor(song.coverUrl);
        _dragProgress = null;
      });
      _loadDominantColor();
      _loadLyrics(showLoading: true);
    });
  }

  /// 播放进度变化：仅在当前行变化时重建（避免每 200ms 全量重绘）
  void _handlePosition(Duration position) {
    if (!mounted) return;
    _lastPosition = position;
    final index = _resolveLineIndex();
    if (index == _currentLineIndex) return;
    setState(() => _currentLineIndex = index);
  }

  /// 歌词偏移 / 字号等设置变化后重新计算当前行
  void _handleStyleChanged() {
    if (!mounted) return;
    final index = _resolveLineIndex();
    if (index == _currentLineIndex) return;
    setState(() => _currentLineIndex = index);
  }

  int? _resolveLineIndex() {
    final lines = _lyrics?.lines ?? const <LyricLine>[];
    return LyricTiming.currentIndex(
      lines,
      LyricTiming.effectivePosition(_lastPosition, widget.style.offsetSeconds),
    );
  }

  Future<void> _loadLyrics({
    bool showLoading = false,
    bool force = false,
  }) async {
    final service = widget.lyricService;
    if (service == null) return;
    final target = _song;
    if (showLoading && mounted) setState(() => _lyricsLoading = true);

    final lyrics = await service.fetch(target, force: force);
    if (!mounted || _song.identityKey != target.identityKey) return;
    setState(() {
      _lyrics = lyrics;
      _lyricsLoading = false;
      _currentLineIndex = _resolveLineIndex();
    });
  }

  Future<void> _loadDominantColor() async {
    final extractor = widget.colorExtractor;
    final song = _song;
    final cached = extractor?.cachedColor(song.coverUrl);
    if (cached != null) {
      if (mounted) setState(() => _dominant = cached);
      return;
    }

    final color = await extractor?.dominantColor(song.coverUrl);
    if (!mounted || _song.identityKey != song.identityKey) return;
    if (color == _dominant) return;
    setState(() => _dominant = color);
  }

  CoverPalette _palette(BuildContext context) => CoverPalette.make(
        dominant: _dominant,
        scheme: Theme.of(context).colorScheme,
      );

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await widget.playerManager.pause();
    } else {
      await widget.playerManager.resume();
    }
  }

  Future<void> _seekTo(Duration position) async {
    final clamped = position < Duration.zero ? Duration.zero : position;
    await widget.playerManager.seek(clamped);
  }

  Future<void> _seekBy(int seconds) =>
      _seekTo(_lastPosition + Duration(seconds: seconds));

  /// 点击歌词行跳转到该行（自动应用歌词进度偏移）
  void _handleLyricTap(LyricLine line) {
    _seekTo(LyricTiming.seekPosition(line, widget.style.offsetSeconds));
  }

  void _openLyricSettings(BuildContext context) {
    showLyricSettingsSheet(
      context,
      store: widget.style,
      palette: _palette(context),
    );
  }

  Future<void> _downloadSong() async {
    final service = widget.downloadService;
    if (service == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final file = await service.download(_song);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到 ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final queue = widget.playerManager.queue;
        if (queue.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('播放队列为空')),
          );
        }
        return SafeArea(
          top: false,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final song = queue[index];
              final current = index == widget.playerManager.currentIndex;
              return ListTile(
                selected: current,
                leading: current
                    ? const Icon(Icons.equalizer_rounded)
                    : Text('${index + 1}'),
                title: Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await widget.playerManager.playQueueIndex(index);
                },
              );
            },
          ),
        );
      },
    );
  }

  // MARK: - 构建

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.backgroundTop, palette.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final coverSize = math.min(constraints.maxWidth * 0.68, 300.0);
              return Column(
                children: [
                  _buildTopBar(context, palette),
                  Expanded(
                    child: _buildStage(
                      context,
                      palette,
                      constraints,
                      coverSize,
                    ),
                  ),
                  _buildProgress(context, palette),
                  _buildControls(context, palette),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 顶栏：返回 / 歌曲信息 / 歌词设置 / 队列 / 下载 / 更多
  Widget _buildTopBar(BuildContext context, CoverPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.text),
          ),
          Expanded(
            child: Text(
              _showLyrics ? '歌词' : '正在播放',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: palette.secondary,
              ),
            ),
          ),
          IconButton(
            tooltip: '歌词设置',
            onPressed: () => _openLyricSettings(context),
            icon: Icon(Icons.tune_rounded, color: palette.text),
          ),
          IconButton(
            tooltip: '播放队列',
            onPressed: _showQueue,
            icon: Icon(Icons.queue_music_rounded, color: palette.text),
          ),
          if (widget.downloadService != null)
            IconButton(
              tooltip: '下载',
              onPressed: _downloading ? null : _downloadSong,
              icon: _downloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.text,
                      ),
                    )
                  : Icon(Icons.download_rounded, color: palette.text),
            ),
        ],
      ),
    );
  }

  /// 舞台：封面模式与歌词模式共用一块区域，封面平滑飞入左上角
  Widget _buildStage(
    BuildContext context,
    CoverPalette palette,
    BoxConstraints constraints,
    double coverSize,
  ) {
    const miniSize = 46.0;
    return Stack(
      children: [
        _buildLyricsLayer(palette, miniSize),
        _buildLyricsHeader(palette, miniSize),
        _buildCoverContent(palette, coverSize),
        _buildFlyingCover(palette, coverSize, miniSize),
      ],
    );
  }

  /// 歌词层（歌词模式下淡入并接管交互）
  Widget _buildLyricsLayer(CoverPalette palette, double miniSize) {
    final lyrics = _lyrics;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showLyrics,
        child: AnimatedOpacity(
          opacity: _showLyrics ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          child: Padding(
            padding: EdgeInsets.only(top: miniSize + 26),
            child: LyricsView(
              lines: lyrics?.lines ?? const [],
              positionStream: widget.playerManager.positionStream,
              style: widget.style,
              palette: palette,
              coverUrl: _song.coverUrl,
              isPlaying: _isPlaying,
              emptyMessage: _lyricsLoading
                  ? '歌词加载中…'
                  : (lyrics?.emptyMessage ?? '暂无歌词'),
              onTapLine: _handleLyricTap,
              onRetry: widget.lyricService == null
                  ? null
                  : () => _loadLyrics(showLoading: true, force: true),
            ),
          ),
        ),
      ),
    );
  }

  /// 歌词模式：左上角歌曲信息（与小封面并排）
  Widget _buildLyricsHeader(CoverPalette palette, double miniSize) {
    return Positioned(
      left: 0,
      right: 16,
      top: 12,
      child: IgnorePointer(
        ignoring: !_showLyrics,
        child: AnimatedOpacity(
          opacity: _showLyrics ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          child: Row(
            children: [
              SizedBox(width: miniSize + 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _song.artists,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 封面模式：标题 / 歌手 / 歌词预览（顶部为封面预留空间）
  Widget _buildCoverContent(CoverPalette palette, double coverSize) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _showLyrics,
        child: AnimatedOpacity(
          opacity: _showLyrics ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          child: Column(
            children: [
              SizedBox(height: coverSize + 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _song.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _song.artists,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: palette.secondary),
                ),
              ),
              const SizedBox(height: 16),
              _buildLyricPreview(palette),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// 封面本体：封面模式居中，歌词模式缩到左上角（点击切换）
  Widget _buildFlyingCover(
    CoverPalette palette,
    double coverSize,
    double miniSize,
  ) {
    const switchDuration = Duration(milliseconds: 320);
    return Align(
      alignment: _showLyrics ? Alignment.topLeft : Alignment.topCenter,
      child: AnimatedPadding(
        duration: switchDuration,
        curve: Curves.easeInOut,
        padding: _showLyrics
            ? const EdgeInsets.only(left: 20, top: 8)
            : EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => setState(() => _showLyrics = !_showLyrics),
          child: AnimatedContainer(
            duration: switchDuration,
            curve: Curves.easeInOut,
            width: _showLyrics ? miniSize : coverSize,
            height: _showLyrics ? miniSize : coverSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_showLyrics ? 14 : 26),
              color: palette.accentSoft,
              boxShadow: _showLyrics
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_showLyrics ? 14 : 26),
              child: _buildCoverImage(palette, miniSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(CoverPalette palette, double miniSize) {
    final coverUrl = _song.coverUrl;
    final placeholder = Center(
      child: Icon(
        Icons.music_note_rounded,
        size: _showLyrics ? miniSize * 0.5 : 84,
        color: palette.secondary,
      ),
    );
    if (coverUrl == null || coverUrl.isEmpty) return placeholder;
    return Image.network(
      coverUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  /// 封面下的歌词预览：最多 5 行，跟随当前播放行
  Widget _buildLyricPreview(CoverPalette palette) {
    final rows = _previewRows;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showLyrics = true),
      child: SizedBox(
        height: 5 * 22,
        child: rows.isEmpty
            ? Center(
                child: Text(
                  _lyricsLoading ? '歌词加载中…' : '暂无歌词，点击封面查看完整歌词',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.secondary.withValues(alpha: 0.85),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final row in rows)
                    Text(
                      row.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            row.isCurrent ? FontWeight.w700 : FontWeight.w400,
                        color: row.isCurrent
                            ? palette.text
                            : palette.secondary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<({String text, bool isCurrent})> get _previewRows {
    final lines = _lyrics?.lines ?? const <LyricLine>[];
    if (lines.isEmpty) return const [];
    final index = _currentLineIndex;
    final start = index == null
        ? 0
        : math.max(0, math.min(index - 2, math.max(0, lines.length - 5)));
    final end = math.min(lines.length, start + 5);
    return [
      for (var i = start; i < end; i++)
        (
          text: lines[i].text.isEmpty ? ' ' : lines[i].text,
          isCurrent: i == index,
        ),
    ];
  }

  /// 进度条（拖动时显示拖动位置，松手才 seek）
  Widget _buildProgress(BuildContext context, CoverPalette palette) {
    return StreamBuilder<Duration>(
      stream: widget.playerManager.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: widget.playerManager.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? _duration;
            final total = duration.inMilliseconds;
            final value = total <= 0
                ? 0.0
                : (position.inMilliseconds / total).clamp(0.0, 1.0);
            final display = _dragProgress ?? value;
            final displayPosition =
                _dragProgress == null ? position : duration * display;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: palette.accent,
                      inactiveTrackColor:
                          palette.secondary.withValues(alpha: 0.3),
                      thumbColor: palette.accent,
                      overlayColor: palette.accent.withValues(alpha: 0.15),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: display,
                      onChanged: (value) =>
                          setState(() => _dragProgress = value),
                      onChangeEnd: (value) async {
                        final target = duration * value;
                        setState(() => _dragProgress = null);
                        await _seekTo(target);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(displayPosition),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.secondary,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 底部控制栏：播放模式 / 上一首 / 播放暂停 / 下一首 / 快进退
  Widget _buildControls(BuildContext context, CoverPalette palette) {
    final mode = widget.playerManager.playbackMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PopupMenuButton<PlaybackMode>(
            tooltip: '播放模式',
            initialValue: mode,
            icon: Icon(_playbackModeIcon(mode), color: palette.secondary),
            onSelected: (value) =>
                setState(() => widget.playerManager.playbackMode = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: PlaybackMode.sequential,
                child: Text('顺序播放'),
              ),
              PopupMenuItem(
                value: PlaybackMode.repeatAll,
                child: Text('列表循环'),
              ),
              PopupMenuItem(
                value: PlaybackMode.repeatOne,
                child: Text('单曲循环'),
              ),
              PopupMenuItem(
                value: PlaybackMode.shuffle,
                child: Text('随机播放'),
              ),
            ],
          ),
          IconButton(
            tooltip: '上一首',
            onPressed: () => widget.playerManager.previous(),
            iconSize: 34,
            icon: Icon(Icons.skip_previous_rounded, color: palette.text),
          ),
          _buildPlayButton(palette),
          IconButton(
            tooltip: '下一首',
            onPressed: () => widget.playerManager.next(),
            iconSize: 34,
            icon: Icon(Icons.skip_next_rounded, color: palette.text),
          ),
          PopupMenuButton<int>(
            tooltip: '快进 / 快退',
            icon: Icon(Icons.av_timer_rounded, color: palette.secondary),
            onSelected: _seekBy,
            itemBuilder: (context) => const [
              PopupMenuItem(value: -15, child: Text('快退 15 秒')),
              PopupMenuItem(value: 15, child: Text('快进 15 秒')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(CoverPalette palette) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.accent,
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        tooltip: _isPlaying ? '暂停' : '播放',
        onPressed: _togglePlay,
        iconSize: 34,
        icon: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
        PlaybackMode.sequential => Icons.playlist_play_rounded,
        PlaybackMode.repeatAll => Icons.repeat_rounded,
        PlaybackMode.repeatOne => Icons.repeat_one_rounded,
        PlaybackMode.shuffle => Icons.shuffle_rounded,
      };

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}