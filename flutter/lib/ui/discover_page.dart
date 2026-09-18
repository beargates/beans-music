import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/daily_recommend_viewmodel.dart';
import '../widget/daily_recommend_section.dart';
import '../model/song.dart';
import '../model/ranking.dart';
import '../model/playlist.dart';
import '../service/cover_image.dart';

class DiscoverPage extends StatefulWidget {
  final Future<void> Function(Song song, List<Song> context)? onSongTap;
  final Future<void> Function(List<Song> songs)? onPlayAll;
  final String? currentPlayingSongId;

  const DiscoverPage({
    super.key,
    this.onSongTap,
    this.onPlayAll,
    this.currentPlayingSongId,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<DailyRecommendViewModel>();
      viewModel.loadDailySongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DailyRecommendViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: _buildGreeting(viewModel),
        toolbarHeight: 92,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final viewModel = context.read<DailyRecommendViewModel>();
          await viewModel.refresh();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: DefaultTabController(
                  length: 3,
                  initialIndex: viewModel.selectedPlatform,
                  child: TabBar(
                    onTap: viewModel.setPlatform,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: '网易云'),
                      Tab(text: 'QQ音乐'),
                      Tab(text: '酷狗音乐'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 每日推荐部分
              DailyRecommendSection(
                onViewAll: () {
                  _showAllDailySongs(viewModel);
                },
                onPlayAll: () {
                  if (widget.onPlayAll != null) {
                    widget.onPlayAll!(viewModel.dailySongs);
                  }
                },
                onPlaySong: widget.onSongTap,
                currentPlayingSongId: widget.currentPlayingSongId,
              ),
              const SizedBox(height: 28),
              RankingSection(
                viewModel: viewModel,
                onRankingTap: (ranking) => _showRanking(ranking, viewModel),
              ),
              const SizedBox(height: 32),
              if (viewModel.selectedPlatform == 0)
                PlaylistSquareSection(
                  viewModel: viewModel,
                  onPlaylistTap: (playlist) =>
                      _showPlaylist(playlist, viewModel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(DailyRecommendViewModel viewModel) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour >= 5 && hour < 12) {
      greeting = '早上好';
    } else if (hour >= 12 && hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ).createShader(bounds),
          child: Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${viewModel.getPlatformName()}为您推荐今日好音乐',
          style: TextStyle(
            fontSize: 13,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _showAllDailySongs(DailyRecommendViewModel viewModel) {
    if (viewModel.dailySongs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DailySongsModal(
          songs: viewModel.dailySongs,
          onSongTap: widget.onSongTap,
          platformName: viewModel.getPlatformName(),
        );
      },
    );
  }

  void _showRanking(
    Ranking ranking,
    DailyRecommendViewModel viewModel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RankingSongsModal(
        ranking: ranking,
        loadSongs: () => viewModel.loadRankingSongs(ranking),
        onSongTap: widget.onSongTap,
      ),
    );
  }

  void _showPlaylist(
    Playlist playlist,
    DailyRecommendViewModel viewModel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistSongsModal(
        playlist: playlist,
        loadSongs: () => viewModel.loadPlaylistSongs(playlist),
        onSongTap: widget.onSongTap,
      ),
    );
  }
}

class PlaylistSquareSection extends StatelessWidget {
  final DailyRecommendViewModel viewModel;
  final ValueChanged<Playlist> onPlaylistTap;

  const PlaylistSquareSection({
    super.key,
    required this.viewModel,
    required this.onPlaylistTap,
  });

  @override
  Widget build(BuildContext context) {
    if (viewModel.playlistsLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (viewModel.playlists.isEmpty) return const SizedBox.shrink();

    final visible = viewModel.playlists.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '歌单广场',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${viewModel.playlists.length} 个精选',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.playlistCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = viewModel.playlistCategories[index];
              final selected = category == viewModel.playlistCategory;
              return ChoiceChip(
                label: Text(category),
                selected: selected,
                onSelected: (_) => viewModel.setPlaylistCategory(category),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final playlist = visible[index];
            return _PlaylistCard(
              playlist: playlist,
              onTap: () => onPlaylistTap(playlist),
            );
          },
        ),
        if (viewModel.playlists.length > 6)
          Align(
            child: TextButton.icon(
              onPressed: () => _showAllPlaylists(context),
              icon: const Icon(Icons.expand_more),
              label: const Text('展开全部'),
            ),
          ),
      ],
    );
  }

  void _showAllPlaylists(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '歌单广场',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: viewModel.playlists.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) => _PlaylistCard(
                    playlist: viewModel.playlists[index],
                    onTap: () {
                      Navigator.pop(context);
                      onPlaylistTap(viewModel.playlists[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Icon(Icons.queue_music, size: 36)),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: playlist.coverUrl == null
                    ? placeholder
                    : CoverImage(
                        url: playlist.coverUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_) => placeholder,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (playlist.creatorName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  playlist.creatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlaylistSongsModal extends StatefulWidget {
  final Playlist playlist;
  final Future<List<Song>> Function() loadSongs;
  final Future<void> Function(Song song, List<Song> songs)? onSongTap;

  const PlaylistSongsModal({
    super.key,
    required this.playlist,
    required this.loadSongs,
    this.onSongTap,
  });

  @override
  State<PlaylistSongsModal> createState() => _PlaylistSongsModalState();
}

class _PlaylistSongsModalState extends State<PlaylistSongsModal> {
  late final Future<List<Song>> _songsFuture = widget.loadSongs();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<List<Song>>(
          future: _songsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('歌单加载失败：${snapshot.error}'));
            }
            final songs = snapshot.data ?? const <Song>[];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _RankingCover(url: song.coverUrl),
                        title: Text(song.name),
                        subtitle: Text('${song.artists} · ${song.album}'),
                        onTap: widget.onSongTap == null
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onSongTap!(song, songs);
                              },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RankingSection extends StatelessWidget {
  final DailyRecommendViewModel viewModel;
  final ValueChanged<Ranking> onRankingTap;

  const RankingSection({
    super.key,
    required this.viewModel,
    required this.onRankingTap,
  });

  @override
  Widget build(BuildContext context) {
    if (viewModel.rankingsLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (viewModel.rankings.isEmpty) return const SizedBox.shrink();

    final visibleCount = viewModel.rankingsExpanded
        ? viewModel.rankings.length.clamp(0, 10)
        : viewModel.rankings.length.clamp(0, 3);
    final visible = viewModel.rankings.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '排行榜',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                ListTile(
                  leading: _RankingCover(url: visible[index].coverUrl),
                  title: Text(
                    '${index + 1}. ${visible[index].name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    visible[index].subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onRankingTap(visible[index]),
                ),
                if (index < visible.length - 1) const Divider(height: 1),
              ],
              if (viewModel.rankings.length > 3)
                TextButton.icon(
                  onPressed: viewModel.toggleRankingsExpanded,
                  icon: Icon(
                    viewModel.rankingsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    viewModel.rankingsExpanded
                        ? '收起'
                        : '展开全部（${viewModel.rankings.length.clamp(0, 10)}）',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankingCover extends StatelessWidget {
  final String? url;

  const _RankingCover({this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 52,
      height: 52,
      color: Colors.grey.shade300,
      child: const Icon(Icons.leaderboard),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CoverImage(
        url: url,
        width: 52,
        height: 52,
        placeholder: (_) => placeholder,
      ),
    );
  }
}

class RankingSongsModal extends StatefulWidget {
  final Ranking ranking;
  final Future<List<Song>> Function() loadSongs;
  final Future<void> Function(Song song, List<Song> songs)? onSongTap;

  const RankingSongsModal({
    super.key,
    required this.ranking,
    required this.loadSongs,
    this.onSongTap,
  });

  @override
  State<RankingSongsModal> createState() => _RankingSongsModalState();
}

class _RankingSongsModalState extends State<RankingSongsModal> {
  late final Future<List<Song>> _songsFuture = widget.loadSongs();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<List<Song>>(
          future: _songsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('排行榜加载失败：${snapshot.error}'));
            }
            final allSongs = snapshot.data ?? const <Song>[];
            final query = _query.trim().toLowerCase();
            final songs = query.isEmpty
                ? allSongs
                : allSongs
                    .where((song) =>
                        song.name.toLowerCase().contains(query) ||
                        song.artists.toLowerCase().contains(query) ||
                        song.album.toLowerCase().contains(query))
                    .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.ranking.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: '搜索榜单歌曲',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _RankingCover(url: song.coverUrl),
                        title: Text(song.name),
                        subtitle: Text('${song.artists} · ${song.album}'),
                        onTap: widget.onSongTap == null
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onSongTap!(song, allSongs);
                              },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 每日推荐完整列表模态框
class DailySongsModal extends StatelessWidget {
  final List<Song> songs;
  final Future<void> Function(Song song, List<Song> context)? onSongTap;
  final String platformName;

  const DailySongsModal({
    super.key,
    required this.songs,
    this.onSongTap,
    required this.platformName,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$platformName 每日推荐',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: song.coverUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CoverImage(
                                url: song.coverUrl,
                                width: 48,
                                height: 48,
                                placeholder: (_) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.music_note),
                                ),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.music_note),
                            ),
                      title: Text(
                        song.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(song.artists),
                      trailing: song.isVip
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEE413F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'VIP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: onSongTap == null
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              await onSongTap!(song, songs);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
