import 'package:flutter/material.dart';
import '../model/song.dart';
import '../service/cover_image.dart';

class DailyRecommendCard extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final bool isPlaying;

  const DailyRecommendCard({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: song.coverUrl == null
                      ? _CoverPlaceholder(
                          size: 108,
                          color: colorScheme.surfaceContainerHighest,
                        )
                      : CoverImage(
                          url: song.coverUrl,
                          width: 108,
                          height: 108,
                          placeholder: (_) => _CoverPlaceholder(
                            size: 108,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                ),
                // VIP标签
                if (song.isVip)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE413F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // 播放状态指示器
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isPlaying
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.play_arrow,
                              size: 12,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 歌曲名称
            Text(
              song.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // 歌手/专辑
            Text(
              song.artists.isNotEmpty ? song.artists : song.album,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  final double size;
  final Color color;

  const _CoverPlaceholder({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
      child: const Icon(Icons.music_note_rounded),
    );
  }
}
