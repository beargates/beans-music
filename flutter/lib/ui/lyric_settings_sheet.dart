import 'package:flutter/material.dart';

import '../model/lyric_style.dart';
import '../service/cover_palette.dart';
import '../store/lyric_style_store.dart';
import '../widget/lyric_color_picker.dart';

/// 打开歌词设置面板。
Future<void> showLyricSettingsSheet(
  BuildContext context, {
  required LyricStyleStore store,
  required CoverPalette palette,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LyricSettingsSheet(store: store, palette: palette),
  );
}

/// 歌词设置面板（对应 Swift 播放器设置里的歌词显示 / 歌词效果 / 布局 / 歌词背景）
class LyricSettingsSheet extends StatelessWidget {
  final LyricStyleStore store;
  final CoverPalette palette;

  const LyricSettingsSheet({
    super.key,
    required this.store,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final accent = store.currentColor(palette);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '歌词设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => store.resetAll(),
                        child: Text(
                          '恢复默认',
                          style: TextStyle(color: accent),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      _card(context, '歌词显示', _displayChildren(context)),
                      _card(context, '歌词效果', _effectChildren(context)),
                      _card(context, '布局', _layoutChildren(context)),
                      _card(context, '歌词界面背景', _backgroundChildren(context)),
                      const SizedBox(height: 8),
                      Text(
                        '提示：在歌词页长按可多选复制，点击歌词行可跳转到该行播放。',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: children,
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context,
    String label,
    String valueText,
    Widget slider,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5)),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 30, child: slider),
      ],
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      value: value,
      onChanged: onChanged,
    );
  }

  List<Widget> _displayChildren(BuildContext context) {
    return [
      _sliderRow(
        context,
        '歌词字号',
        '${store.fontSize.round()} pt',
        Slider(
          value: store.fontSize,
          min: LyricStyleStore.minFontSize,
          max: LyricStyleStore.maxFontSize,
          divisions: (LyricStyleStore.maxFontSize -
                  LyricStyleStore.minFontSize)
              .round(),
          onChanged: (value) => store.fontSize = value,
        ),
      ),
      _sliderRow(
        context,
        '歌词行距',
        '${store.lineSpacing.round()} pt',
        Slider(
          value: store.lineSpacing,
          min: LyricStyleStore.minLineSpacing,
          max: LyricStyleStore.maxLineSpacing,
          divisions: (LyricStyleStore.maxLineSpacing -
                  LyricStyleStore.minLineSpacing)
              .round(),
          onChanged: (value) => store.lineSpacing = value,
        ),
      ),
      _sliderRow(
        context,
        '歌词缩放',
        '${store.scale.toStringAsFixed(2)}x',
        Slider(
          value: store.scale,
          min: LyricStyleStore.minScale,
          max: LyricStyleStore.maxScale,
          divisions: 20,
          onChanged: (value) => store.scale = value,
        ),
      ),
      _sliderRow(
        context,
        '歌词进度偏移',
        store.offsetLabel,
        Slider(
          value: store.offsetSeconds,
          min: LyricStyleStore.minOffsetSeconds,
          max: LyricStyleStore.maxOffsetSeconds,
          divisions: 200,
          onChanged: (value) => store.offsetSeconds = value,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '歌词与音频不同步时手动校正（正数提前、负数延后）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => store.offsetSeconds = 0,
            child: const Text('重置'),
          ),
        ],
      ),
      const Divider(height: 12),
      _switchRow(
        '显示歌词翻译',
        '当前播放歌词下方显示译文（网易云 tlyric / QQ trans）',
        store.translationEnabled,
        (value) => store.translationEnabled = value,
      ),
    ];
  }

  List<Widget> _effectChildren(BuildContext context) {
    return [
      _sliderRow(
        context,
        '模糊起始距离',
        '${store.blurStart.round()} 行',
        Slider(
          value: store.blurStart,
          min: LyricStyleStore.minBlurStart,
          max: LyricStyleStore.maxBlurStart,
          divisions: 4,
          onChanged: (value) => store.blurStart = value,
        ),
      ),
      _sliderRow(
        context,
        '模糊强度',
        store.blurAmountLabel,
        Slider(
          value: store.blurAmount,
          min: LyricStyleStore.minBlurAmount,
          max: LyricStyleStore.maxBlurAmount,
          divisions: 60,
          onChanged: (value) => store.blurAmount = value,
        ),
      ),
      _sliderRow(
        context,
        '3D 倾斜',
        store.tiltLabel,
        Slider(
          value: store.tilt,
          min: LyricStyleStore.minTilt,
          max: LyricStyleStore.maxTilt,
          divisions: 45,
          onChanged: (value) => store.tilt = value,
        ),
      ),
      _sliderRow(
        context,
        '左右倾斜',
        store.tiltYLabel,
        Slider(
          value: store.tiltY,
          min: LyricStyleStore.minTiltY,
          max: LyricStyleStore.maxTiltY,
          divisions: 90,
          onChanged: (value) => store.tiltY = value,
        ),
      ),
      _sliderRow(
        context,
        '歌词发光',
        store.glowLabel,
        Slider(
          value: store.glowLevel.toDouble(),
          min: 0,
          max: LyricStyleStore.maxGlowLevel.toDouble(),
          divisions: LyricStyleStore.maxGlowLevel,
          onChanged: (value) => store.glowLevel = value.round(),
        ),
      ),
      const Divider(height: 16),
      const Text('渐变预设', style: TextStyle(fontSize: 13.5)),
      const SizedBox(height: 8),
      _presetRow(context, LyricPreset.all.take(3).toList()),
      const SizedBox(height: 8),
      _presetRow(context, LyricPreset.all.skip(3).toList()),
      const Divider(height: 16),
      _switchRow(
        '保持自定义配色',
        '关闭时歌词颜色与渐变自动跟随歌曲封面取色',
        store.keepCustomColors,
        (value) => store.keepCustomColors = value,
      ),
      LyricColorField(
        label: '当前行颜色',
        hex: store.currentColorHex,
        previewColor: store.currentColor(palette),
        options: lyricCurrentColorOptions,
        onChanged: (value) {
          store.currentColorHex = value;
          if (value.isNotEmpty) store.keepCustomColors = true;
        },
      ),
      LyricColorField(
        label: '未播放行颜色',
        hex: store.dimColorHex,
        previewColor: store.dimColor(palette),
        options: lyricDimColorOptions,
        onChanged: (value) {
          store.dimColorHex = value;
          if (value.isNotEmpty) store.keepCustomColors = true;
        },
      ),
      LyricColorField(
        label: '歌词发光颜色',
        hex: store.glowColorHex,
        previewColor: store.glowColor(palette),
        options: lyricCurrentColorOptions,
        onChanged: (value) {
          store.glowColorHex = value;
          if (value.isNotEmpty) store.keepCustomColors = true;
        },
      ),
      const Divider(height: 16),
      LyricColorField(
        label: '渐变起始色',
        hex: store.gradStartHex,
        previewColor: store.gradientStart(palette),
        options: lyricCurrentColorOptions,
        onChanged: (value) {
          store.gradStartHex = value;
          if (value.isNotEmpty) store.keepCustomColors = true;
        },
      ),
      LyricColorField(
        label: '渐变结束色',
        hex: store.gradEndHex,
        previewColor: store.gradientEnd(palette, Theme.of(context).brightness),
        options: lyricCurrentColorOptions,
        onChanged: (value) {
          store.gradEndHex = value;
          if (value.isNotEmpty) store.keepCustomColors = true;
        },
      ),
      Row(
        children: [
          TextButton(
            onPressed: store.resetColors,
            child: const Text('恢复默认颜色'),
          ),
          const Spacer(),
          TextButton(
            onPressed: store.resetGradient,
            child: const Text('恢复默认渐变'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _layoutChildren(BuildContext context) {
    return [
      Row(
        children: [
          const Expanded(
            child: Text('歌词对齐样式', style: TextStyle(fontSize: 13.5)),
          ),
          Flexible(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('居中')),
                ButtonSegment(value: true, label: Text('全部居左')),
              ],
              selected: {store.alignLeft},
              onSelectionChanged: (value) => store.alignLeft = value.first,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _sliderRow(
        context,
        '歌词水平偏移',
        '${store.offsetX.round()}',
        Slider(
          value: store.offsetX,
          min: LyricStyleStore.minOffsetX,
          max: LyricStyleStore.maxOffsetX,
          divisions: 240,
          onChanged: (value) => store.offsetX = value,
        ),
      ),
      _sliderRow(
        context,
        '垂直重心',
        store.anchorY == 0 ? '居中' : '${store.anchorY.round()}',
        Slider(
          value: store.anchorY,
          min: LyricStyleStore.minAnchorY,
          max: LyricStyleStore.maxAnchorY,
          divisions: 200,
          onChanged: (value) => store.anchorY = value,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '数值越小当前行越靠上（显示更多后续歌词）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: store.resetLayout,
            child: const Text('恢复默认'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _backgroundChildren(BuildContext context) {
    return [
      _switchRow(
        '跟随封面取色',
        '歌词页背景使用当前歌曲封面主色（并作为模糊底图）',
        store.backgroundSyncCover,
        (value) => store.backgroundSyncCover = value,
      ),
      LyricColorField(
        label: '自定义背景色',
        hex: store.backgroundColorHex,
        previewColor: palette.backgroundTop,
        options: lyricCurrentColorOptions,
        autoLabel: '跟随页面背景',
        onChanged: (value) => store.backgroundColorHex = value,
      ),
      _sliderRow(
        context,
        '背景模糊',
        '${store.backgroundBlur.round()}',
        Slider(
          value: store.backgroundBlur,
          min: LyricStyleStore.minBackgroundBlur,
          max: LyricStyleStore.maxBackgroundBlur,
          divisions: 30,
          onChanged: (value) => store.backgroundBlur = value,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '当前：${store.backgroundLabel}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: store.resetBackground,
            child: const Text('恢复默认'),
          ),
        ],
      ),
    ];
  }

  Widget _presetRow(BuildContext context, List<LyricPreset> presets) {
    return Row(
      children: [
        for (var index = 0; index < presets.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _presetButton(context, presets[index])),
        ],
      ],
    );
  }

  Widget _presetButton(BuildContext context, LyricPreset preset) {
    final theme = Theme.of(context);
    final selected = store.gradStartHex.toUpperCase() ==
            preset.startHex.toUpperCase() &&
        store.gradEndHex.toUpperCase() == preset.endHex.toUpperCase();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => store.applyPreset(preset),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [preset.startColor, preset.endColor],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}