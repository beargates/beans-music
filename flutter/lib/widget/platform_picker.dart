import 'package:flutter/material.dart';

class PlatformPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onPlatformChanged;
  final List<String> platforms;
  final List<IconData> platformIcons;

  const PlatformPicker({
    super.key,
    required this.selectedIndex,
    required this.onPlatformChanged,
    this.platforms = const ['网易云', 'QQ音乐', '酷狗音乐'],
    this.platformIcons = const [
      Icons.music_note,
      Icons.headphones,
      Icons.audiotrack,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(platforms.length, (index) {
          final isSelected = selectedIndex == index;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onPlatformChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      platformIcons[index],
                      size: 14,
                      color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      platforms[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}