import 'dart:async';

import 'package:flutter/material.dart';

import '../model/song.dart';
import '../viewmodel/search_view_model.dart';

class SearchPage extends StatefulWidget {
  final SearchViewModel viewModel;
  final Future<void> Function(Song song)? onSongTap;
  final Future<void> Function(Song song, List<Song> context)? onSongTapWithContext;
  final VoidCallback? onLoginTap;

  const SearchPage({
    super.key,
    required this.viewModel,
    this.onSongTap,
    this.onSongTapWithContext,
    this.onLoginTap,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Song> _songs = [];
  SongSource _source = SongSource.netease;
  bool _loading = false;
  String? _errorMessage;
  Timer? _debounce;
  int _requestId = 0;

  Future<void> _runSearch({String? value}) async {
    _debounce?.cancel();
    final keyword = (value ?? _controller.text).trim();
    if (keyword.isEmpty) return;

    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final songs = await widget.viewModel.search(
        keyword,
        source: _source,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _songs = songs);
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _songs = [];
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      ++_requestId;
      setState(() {
        _songs = [];
        _errorMessage = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(value: value);
    });
  }

  Future<void> _changeSource(SongSource source) async {
    if (_source == source) return;
    setState(() {
      _source = source;
      _songs = [];
      _errorMessage = null;
    });
    final keyword = _controller.text.trim();
    if (keyword.isNotEmpty) {
      await _runSearch(value: keyword);
    }
  }

  String _sourceLabel(SongSource source) {
    switch (source) {
      case SongSource.netease:
        return '网易云';
      case SongSource.qq:
        return 'QQ 音乐';
      case SongSource.kugou:
        return '酷狗';
    }
  }

  IconData _sourceIcon(SongSource source) {
    switch (source) {
      case SongSource.netease:
        return Icons.cloud_rounded;
      case SongSource.qq:
        return Icons.account_circle_rounded;
      case SongSource.kugou:
        return Icons.music_note_rounded;
    }
  }

  Widget _sourceSelector(BuildContext context) {
    return PopupMenuButton<SongSource>(
      tooltip: '选择音乐平台',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 12),
      position: PopupMenuPosition.under,
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      onSelected: _changeSource,
      itemBuilder: (context) => SongSource.values
          .map(
            (source) => PopupMenuItem<SongSource>(
              value: source,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: source == _source
                            ? const Color(0xFFFFE5DD)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sourceIcon(source),
                            size: 19,
                            color: source == _source
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _sourceLabel(source),
                            style: TextStyle(
                              fontWeight: source == _source
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: source == _source
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Icon(
        _sourceIcon(_source),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '发现音乐',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.onLoginTap != null)
            IconButton(
              tooltip: '平台登录态',
              onPressed: widget.onLoginTap,
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onChanged,
                          onSubmitted: (value) => _runSearch(value: value),
                          decoration: InputDecoration(
                            hintText: '搜索歌曲、歌手或专辑',
                            prefixIcon: _sourceSelector(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        child: IconButton(
                          tooltip: '搜索',
                          onPressed: () => _runSearch(),
                          color: Colors.white,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_tethering_error_rounded,
                                  size: 42,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _runSearch(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('重试'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _songs.isEmpty && !_loading
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _controller.text.trim().isEmpty
                                        ? Icons.music_note_rounded
                                        : Icons.search_off_rounded,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _controller.text.trim().isEmpty
                                        ? '输入关键词开始探索'
                                        : '没有找到相关歌曲',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _songs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final song = _songs[index];
                                return Material(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () async {
                                      if (widget.onSongTapWithContext != null) {
                                        await widget.onSongTapWithContext!(
                                          song,
                                          _songs,
                                        );
                                      } else if (widget.onSongTap != null) {
                                        await widget.onSongTap!(song);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          _CoverThumb(song: song),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        song.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    if (song.isVip)
                                                      const _VipBadge(),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  '${song.artists} · ${song.album}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${_sourceLabel(song.source)}  ·  ${song.formattedDuration}',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.play_circle_outline_rounded,
                                            size: 28,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final Song song;

  const _CoverThumb({required this.song});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'cover-${song.identityKey}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: song.coverUrl == null
            ? Container(
                width: 58,
                height: 58,
                color: const Color(0xFFFFE5DD),
                child: const Icon(Icons.music_note_rounded),
              )
            : Image.network(
                song.coverUrl!,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 58,
                  height: 58,
                  color: const Color(0xFFFFE5DD),
                  child: const Icon(Icons.music_note_rounded),
                ),
              ),
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE6A23C),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
