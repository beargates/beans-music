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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: DefaultTabController(
                length: 2,
                initialIndex: _tabIndex,
                child: TabBar(
                  onTap: (index) => setState(() => _tabIndex = index),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: '收藏'),
                    Tab(text: '历史'),
                  ],
                ),
              ),
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
