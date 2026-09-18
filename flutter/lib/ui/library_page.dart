import 'package:flutter/material.dart';

import '../model/song.dart';
import '../store/library_store.dart';

class LibraryPage extends StatefulWidget {
  final LibraryStore store;
  final Future<void> Function(Song song, List<Song> context) onSongTap;

  const LibraryPage({
    super.key,
    required this.store,
    required this.onSongTap,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _tabIndex = 1;

  List<Song> get _songs =>
      _tabIndex == 0 ? widget.store.favorites : widget.store.history;

  Future<void> _toggleFavorite(Song song) async {
    await widget.store.toggleFavorite(song);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    await widget.store.clearHistory();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isHistory = _tabIndex == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐库'),
        actions: [
          if (isHistory && _songs.isNotEmpty)
            IconButton(
              tooltip: '清空历史',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('收藏')),
                ButtonSegment(value: 1, label: Text('历史')),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (value) {
                setState(() => _tabIndex = value.first);
              },
            ),
          ),
          Expanded(
            child: _songs.isEmpty
                ? Center(
                    child: Text(isHistory ? '还没有播放历史' : '还没有收藏歌曲'),
                  )
                : ListView.builder(
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final favorite = widget.store.isFavorite(song);
                      return ListTile(
                        leading: song.coverUrl == null
                            ? const Icon(Icons.music_note)
                            : Image.network(
                                song.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.music_note),
                              ),
                        title: Text(song.name),
                        subtitle: Text('${song.artists} · ${song.album}'),
                        trailing: IconButton(
                          tooltip: favorite ? '取消收藏' : '收藏',
                          onPressed: () => _toggleFavorite(song),
                          icon: Icon(
                            favorite ? Icons.favorite : Icons.favorite_border,
                            color: favorite ? Colors.red : null,
                          ),
                        ),
                        onTap: () => widget.onSongTap(song, _songs),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
