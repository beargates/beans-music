import 'package:flutter/material.dart';

import '../model/lyric_style.dart';

/// 色盘选择结果：`hex` 为空字符串表示「跟随封面 / 自动」。
class LyricColorPickerResult {
  final String hex;

  const LyricColorPickerResult(this.hex);

  const LyricColorPickerResult.auto() : hex = '';
}

/// 歌词颜色设置入口：显示当前颜色值，点击打开色盘。
class LyricColorField extends StatelessWidget {
  final String label;
  final String? caption;
  final String hex;
  final Color previewColor;
  final String autoLabel;
  final List<LyricColorOption> options;
  final ValueChanged<String> onChanged;

  const LyricColorField({
    super.key,
    required this.label,
    required this.hex,
    required this.previewColor,
    required this.options,
    required this.onChanged,
    this.caption,
    this.autoLabel = '跟随封面',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = colorFromHex(hex);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final result = await showLyricColorPicker(
          context,
          initialColor: custom ?? previewColor,
          options: options,
          autoLabel: autoLabel,
        );
        if (result == null) return;
        onChanged(result.hex);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              custom == null ? autoLabel : hex.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            LyricColorSwatch(
              color: custom ?? previewColor,
              dashed: custom == null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开色盘弹窗；返回 null 表示取消。
Future<LyricColorPickerResult?> showLyricColorPicker(
  BuildContext context, {
  required Color initialColor,
  required List<LyricColorOption> options,
  String autoLabel = '跟随封面',
}) {
  return showDialog<LyricColorPickerResult>(
    context: context,
    builder: (_) => _LyricColorPickerDialog(
      initialColor: initialColor,
      options: options,
      autoLabel: autoLabel,
    ),
  );
}

/// 色块（虚线描边表示「跟随封面」的预览色）。
class LyricColorSwatch extends StatelessWidget {
  final Color color;
  final bool dashed;
  final double size;

  const LyricColorSwatch({
    super.key,
    required this.color,
    this.dashed = false,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: dashed ? 1.6 : 1,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
    );
  }
}

class _LyricColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final List<LyricColorOption> options;
  final String autoLabel;

  const _LyricColorPickerDialog({
    required this.initialColor,
    required this.options,
    required this.autoLabel,
  });

  @override
  State<_LyricColorPickerDialog> createState() =>
      _LyricColorPickerDialogState();
}

class _LyricColorPickerDialogState extends State<_LyricColorPickerDialog> {
  late HSVColor _hsv;
  late String _hex;
  bool _auto = false;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hex = hexFromColor(widget.initialColor);
  }

  void _applyHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hex = hexFromColor(value.toColor());
      _auto = false;
    });
  }

  void _selectOption(LyricColorOption option) {
    if (option.isAuto) {
      setState(() => _auto = true);
      return;
    }
    final color = option.resolve(widget.initialColor);
    setState(() {
      _hsv = HSVColor.fromColor(color);
      _hex = hexFromColor(color);
      _auto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _auto ? widget.initialColor : _hsv.toColor();

    return AlertDialog(
      title: const Text('色盘'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in widget.options)
                    Tooltip(
                      message: option.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _selectOption(option),
                        child: option.isAuto
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _auto
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    width: _auto ? 1.8 : 1,
                                  ),
                                ),
                                child: Text(
                                  widget.autoLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _auto
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : LyricColorSwatch(
                                size: 30,
                                color: option.resolve(widget.initialColor),
                                dashed: _hex.toUpperCase() == option.hex,
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              LyricSaturationValuePicker(color: _hsv, onChanged: _applyHsv),
              const SizedBox(height: 12),
              LyricHueSlider(color: _hsv, onChanged: _applyHsv),
              const SizedBox(height: 16),
              Row(
                children: [
                  LyricColorSwatch(color: preview, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    _auto ? widget.autoLabel : _hex.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _auto
                ? const LyricColorPickerResult.auto()
                : LyricColorPickerResult(_hex),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 饱和度 / 明度取色面板（横向 = 饱和度，纵向 = 明度）。
class LyricSaturationValuePicker extends StatelessWidget {
  static const double _height = 150;

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const LyricSaturationValuePicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset local) {
          onChanged(
            color
                .withSaturation((local.dx / width).clamp(0.0, 1.0))
                .withValue((1 - local.dy / _height).clamp(0.0, 1.0)),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: width,
              height: _height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: color.saturation * width - 9,
                    top: (1 - color.value) * _height - 9,
                    child: const _PickerThumb(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 色相滑条（0~360，7 段彩虹渐变）。
class LyricHueSlider extends StatelessWidget {
  static const double _height = 28;

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const LyricHueSlider({
    super.key,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      for (var i = 0; i <= 6; i++)
        HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset local) {
          onChanged(
            color.withHue(((local.dx / width).clamp(0.0, 1.0)) * 360),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: SizedBox(
            width: width,
            height: _height,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: _height,
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (color.hue / 360) * width - 9,
                  child: _PickerThumb(color: color.toColor()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PickerThumb extends StatelessWidget {
  final Color? color;

  const _PickerThumb({this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}