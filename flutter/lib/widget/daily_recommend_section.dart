import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/song.dart';
import '../viewmodel/daily_recommend_viewmodel.dart';
import 'daily_recommend_card.dart';

class DailyRecommendSection extends StatelessWidget {
  final VoidCallback? onViewAll;
  final VoidCallback? onPlayAll;
  final Future<void> Function(Song song, List<Song> songs)? onPlaySong;
  final String? currentPlayingSongId;

  const DailyRecommendSection({
    super.key,
    this.onViewAll,
    this.onPlayAll,
    this.onPlaySong,
    this.currentPlayingSongId,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DailyRecommendViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildHeader(context, viewModel),
        const SizedBox(height: 14),
        // 内容区域
        _buildContent(context, viewModel),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DailyRecommendViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '每日推荐',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              children: [
                Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, DailyRecommendViewModel viewModel) {
    if (viewModel.status == DailyRecommendStatus.loading) {
      return _buildLoadingState();
    }

    if (viewModel.status == DailyRecommendStatus.error) {
      return _buildErrorState(context, viewModel);
    }

    if (viewModel.dailySongs.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSongList(context, viewModel);
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 150,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, DailyRecommendViewModel viewModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: viewModel.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 40,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              '今日暂无推荐歌曲',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList(
      BuildContext context, DailyRecommendViewModel viewModel) {
    return Column(
      children: [
        // 横滑歌曲列表
        SizedBox(
          // 卡片包含 108px 封面、上下内边距和两行文字，预留足够高度
          // 避免字体缩放或不同平台的行高造成 RenderFlex 溢出。
          height: 164,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.dailySongs.length,
            itemBuilder: (context, index) {
              final song = viewModel.dailySongs[index];
              final isPlaying = currentPlayingSongId == song.identityKey;

              return DailyRecommendCard(
                song: song,
                index: index,
                isPlaying: isPlaying,
                onTap: () {
                  if (onPlaySong != null) {
                    onPlaySong!(song, viewModel.dailySongs);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // 播放全部按钮
        if (onPlayAll != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
