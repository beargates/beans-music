import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../model/lyric_line.dart';
import '../service/cover_palette.dart';
import '../store/lyric_style_store.dart';

/// 歌词视图（对应 Swift `LyricsSection`）：
/// - 当前行高亮放大 + 渐变，已播放行与未播放行按距离变暗、变模糊
/// - 跟随播放自动滚动；用户手动滚动时暂停 3 秒后自动恢复
/// - 点击歌词行跳转播放；长按进入多选复制模式（全选 / 复制 / 取消）
/// - 3D 倾斜、上下渐隐遮罩、对齐与水平偏移、歌词翻译
class LyricsView extends StatefulWidget {
  final List<LyricLine> lines;
  final Stream<Duration> positionStream;
  final bool isPlaying;
  final LyricStyleStore style;
  final CoverPalette palette;
  final String emptyMessage;
  final EdgeInsets padding;

  /// 封面地址（歌词背景「跟随封面取色」时作为底图）
  final String? coverUrl;

  /// 点击歌词行（宿主负责 seek 到该行）
  final ValueChanged<LyricLine> onTapLine;

  /// 无歌词时是否提供重试入口
  final VoidCallback? onRetry;

  const LyricsView({
    super.key,
    required this.lines,
    required this.positionStream,
    required this.style,
    required this.palette,
    required this.onTapLine,
    this.isPlaying = false,
    this.emptyMessage = '暂无歌词',
    this.padding = EdgeInsets.zero,
    this.onRetry,
    this.coverUrl,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  Timer? _resumeTimer;

  List<GlobalKey> _rowKeys = [];
  int? _currentIndex;
  bool _userScrolling = false;
  bool _selectionMode = false;
  final Set<int> _selected = {};
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _resetRows();
    widget.style.addListener(_handleStyleChanged);
    _subscribePosition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(animate: false);
    });
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.style, widget.style)) {
      oldWidget.style.removeListener(_handleStyleChanged);
      widget.style.addListener(_handleStyleChanged);
    }
    if (!identical(oldWidget.positionStream, widget.positionStream)) {
      _subscribePosition();
    }
    if (oldWidget.lines.length != widget.lines.length ||
        !identical(oldWidget.lines, widget.lines)) {
      _resetRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrent(animate: false);
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _resumeTimer?.cancel();
    widget.style.removeListener(_handleStyleChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _resetRows() {
    // 长度不变时保留已有 key，避免父级重建导致高亮与滚动状态被清空
    if (_rowKeys.length != widget.lines.length) {
      _rowKeys = List.generate(widget.lines.length, (_) => GlobalKey());
    }
    _selectionMode = false;
    _selected.clear();
    _userScrolling = false;
    _currentIndex = _resolveIndex();
  }

  void _subscribePosition() {
    _positionSubscription?.cancel();
    _positionSubscription = widget.positionStream.listen(_handlePosition);
  }

  GlobalKey _rowKey(int index) {
    while (_rowKeys.length <= index) {
      _rowKeys.add(GlobalKey());
    }
    return _rowKeys[index];
  }

  Duration get _effectivePosition => LyricTiming.effectivePosition(
        _lastPosition,
        widget.style.offsetSeconds,
      );

  int? _resolveIndex() =>
      LyricTiming.currentIndex(widget.lines, _effectivePosition);

  /// 播放进度变化：只有当前行变化时才重建歌词树（避免每 200ms 全量重绘）
  void _handlePosition(Duration position) {
    if (!mounted) return;
    _lastPosition = position;
    final index = _resolveIndex();
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (!_userScrolling) _scrollToCurrent(animate: true);
  }

  /// 样式变化（如歌词偏移、字号）：重算当前行并重新对齐
  void _handleStyleChanged() {
    if (!mounted) return;
    final index = _resolveIndex();
    setState(() => _currentIndex = index);
    if (!_userScrolling) _scrollToCurrent(animate: false);
  }

  // MARK: - 自动滚动

  /// 滚动到当前行：优先用真实布局精确对齐；目标行尚未构建时先估算定位再校正。
  void _scrollToCurrent({bool animate = true, bool allowRefine = true}) {
    final index = _currentIndex;
    if (index == null || !_scrollController.hasClients) return;

    final box = _rowKey(index).currentContext?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport != null) {
        _scrollTo(
          viewport.getOffsetToReveal(box, widget.style.anchorFactor).offset,
          animate: animate,
        );
        return;
      }
    }

    if (!allowRefine) return;
    // 先跳到估算位置让目标行进入构建范围，下一帧再用真实布局校正
    _scrollTo(_estimatedOffsetFor(index), animate: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(animate: animate, allowRefine: false);
    });
  }

  double _estimatedOffsetFor(int index) {
    final style = widget.style;
    final rowExtent = style.effectiveFontSize * 1.4 +
        style.lineSpacing +
        (style.translationEnabled ? style.effectiveFontSize * 0.8 : 0);
    final viewportHeight = _scrollController.position.viewportDimension;
    return (index + 0.5) * rowExtent - viewportHeight * style.anchorFactor;
  }

  void _scrollTo(double offset, {required bool animate}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = offset.clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final dragging = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (!dragging) return false;

    // 用户手动滚动：暂停自动跟随，3 秒后恢复
    if (!_userScrolling) setState(() => _userScrolling = true);
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _userScrolling = false);
      _scrollToCurrent(animate: true);
    });
    return false;
  }

  // MARK: - 多选复制

  void _enterSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = true;
      _selected
        ..clear()
        ..add(index);
    });
  }

  void _toggleSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _selectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _selected
        ..clear()
        ..addAll(List<int>.generate(widget.lines.length, (index) => index));
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  Future<void> _copySelected() async {
    final indices = _selected.toList()..sort();
    final content = indices
        .where((index) => index >= 0 && index < widget.lines.length)
        .map((index) => widget.lines[index].text)
        .where((line) => line.isNotEmpty)
        .join('\n');
    if (content.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: content));
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final count = indices.length;
    _exitSelection();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('已复制 $count 行歌词')),
    );
  }

  // MARK: - 构建

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final background = style.backgroundColors(widget.palette);

    Widget body = widget.lines.isEmpty
        ? _buildEmpty(style)
        : Stack(
            children: [
              _buildList(context, style),
              if (_selectionMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSelectionBar(context, style),
                ),
            ],
          );

    if (background != null) {
      body = Stack(
        children: [
          Positioned.fill(child: _buildBackground(style, background)),
          Positioned.fill(child: body),
        ],
      );
    }
    return body;
  }

  /// 歌词界面背景：跟随封面时用封面作为模糊底图 + 主色渐变叠加
  Widget _buildBackground(
    LyricStyleStore style,
    ({Color top, Color bottom}) background,
  ) {
    final coverUrl = widget.coverUrl;
    if (style.backgroundSyncCover && coverUrl != null && coverUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: style.backgroundBlur,
                sigmaY: style.backgroundBlur,
              ),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  background.top.withValues(alpha: 0.74),
                  background.bottom.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.top, background.bottom],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, LyricStyleStore style) {
    Widget list = LayoutBuilder(
      builder: (context, constraints) {
        // 上下留白：让首尾歌词也能滚动到锚点位置
        final verticalPadding =
            (constraints.maxHeight * 0.42).clamp(120.0, 280.0);
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: widget.padding.add(
              EdgeInsets.symmetric(vertical: verticalPadding),
            ),
            itemCount: widget.lines.length,
            itemBuilder: (context, index) => _buildRow(context, index),
          ),
        );
      },
    );

    // 上下渐隐遮罩：歌词接近顶部 / 底部时自然淡出
    list = ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.10, 0.90, 1],
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: list,
    );

    // 3D 倾斜：绕 X 轴顶部向后倒
    if (style.tilt != 0) {
      list = Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(style.tilt * math.pi / 180),
        child: list,
      );
    }
    // 左右倾斜：绕 Y 轴以中心为支点
    if (style.tiltY != 0) {
      list = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(style.tiltY * math.pi / 180),
        child: list,
      );
    }
    // 水平偏移
    if (style.offsetX != 0) {
      list = Transform.translate(offset: Offset(style.offsetX, 0), child: list);
    }
    return list;
  }

  /// 单行歌词：当前行最大最亮（渐变 + 双层光晕），其余行按距离变暗、变模糊
  Widget _buildRow(BuildContext context, int index) {
    final style = widget.style;
    final palette = widget.palette;
    final brightness = Theme.of(context).brightness;
    final line = widget.lines[index];
    final currentIndex = _currentIndex;

    final isCurrent = index == currentIndex;
    final isPlayed = currentIndex != null && index < currentIndex;
    final distance = currentIndex == null ? 4 : (index - currentIndex).abs();

    final opacity = (isCurrent
            ? 1.0
            : (isPlayed ? 0.38 : 0.72) - math.min(distance, 4) * 0.05)
        .clamp(0.15, 1.0);
    final fontSize = isCurrent
        ? style.effectiveFontSize + 4
        : style.effectiveFontSize - math.min(distance, 2) * 1.5;
    final blurRadius = isCurrent
        ? 0.0
        : math.min(
            math.max(distance - style.blurStart, 0) * style.blurAmount, 6.0);

    final accent = style.currentColor(palette);
    final dimColor = style.dimColor(palette);
    final glowRadius = style.glowRadius;
    final showTranslation =
        isCurrent && style.translationEnabled && line.hasTranslation;

    // 双层光晕：内层亮、外层宽，发光更明显
    final shadows = (isCurrent && glowRadius > 0)
        ? <Shadow>[
            Shadow(
              color: style.glowColor(palette).withValues(alpha: 0.9),
              blurRadius: glowRadius * 0.45,
            ),
            Shadow(
              color: style.glowColor(palette).withValues(alpha: 0.55),
              blurRadius: glowRadius,
            ),
          ]
        : const <Shadow>[];

    final crossAxisAlignment =
        style.alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = style.alignLeft ? TextAlign.left : TextAlign.center;

    final textContent = line.text.isEmpty ? ' ' : line.text;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.28,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      color: isCurrent ? Colors.white : dimColor,
    );

    Widget text = Text(textContent, textAlign: textAlign, style: baseStyle);

    if (isCurrent) {
      // 当前行使用渐变（跟随封面取色或自定义渐变）
      final gradientLayer = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            style.gradientStart(palette),
            style.gradientEnd(palette, brightness),
          ],
        ).createShader(rect),
        child: text,
      );

      if (shadows.isEmpty) {
        text = gradientLayer;
      } else {
        // 光晕单独一层：避免被渐变遮罩染色，保持自定义发光颜色
        text = Stack(
          alignment: style.alignLeft ? Alignment.centerLeft : Alignment.center,
          children: [
            Text(
              textContent,
              textAlign: textAlign,
              style: baseStyle.copyWith(
                color: Colors.transparent,
                shadows: shadows,
              ),
            ),
            gradientLayer,
          ],
        );
      }
    }

    Widget content = SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          text,
          if (showTranslation) ...[
            const SizedBox(height: 3),
            Text(
              line.translation!,
              textAlign: textAlign,
              style: TextStyle(
                fontSize: style.effectiveFontSize * 0.68,
                height: 1.2,
                color: palette.secondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );

    if (blurRadius > 0.05) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blurRadius,
          sigmaY: blurRadius,
        ),
        child: content,
      );
    }

    content = AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedScale(
        scale: isCurrent ? 1.05 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: content,
      ),
    );

    return GestureDetector(
      key: _rowKey(index),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(index);
        } else {
          widget.onTapLine(line);
        }
      },
      onLongPress: () => _enterSelection(index),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: style.lineSpacing / 2,
          horizontal: style.alignLeft ? 40 : 36,
        ),
        child: Stack(
          children: [
            content,
            if (_selectionMode)
              Positioned(
                top: 2,
                right: 0,
                child: Icon(
                  _selected.contains(index)
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: _selected.contains(index)
                      ? accent
                      : dimColor.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 纯音乐 / 无歌词兜底
  Widget _buildEmpty(LyricStyleStore style) {
    final palette = widget.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 54,
              color: palette.secondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.secondary,
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新获取'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 多选复制工具条：全选 / 复制 / 取消
  Widget _buildSelectionBar(BuildContext context, LyricStyleStore style) {
    final theme = Theme.of(context);
    final accent = style.currentColor(widget.palette);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              TextButton(
                onPressed: _selectAll,
                child: Text(
                  '全选',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              TextButton(
                onPressed: _selected.isEmpty ? null : _copySelected,
                child: Text(
                  _selected.isEmpty ? '复制' : '复制 (${_selected.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _exitSelection,
                child: Text(
                  '取消',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
