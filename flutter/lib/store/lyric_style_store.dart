import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/lyric_style.dart';
import '../service/cover_palette.dart';

/// 歌词样式与显示设置（对应 Swift 播放器的 `beans.lyric*` 系列 @AppStorage）。
///
/// 所有配置持久化到 SharedPreferences，修改后立即通知监听者重绘歌词。
class LyricStyleStore extends ChangeNotifier {
  static const _kFontSize = 'lyric_font_size';
  static const _kLineSpacing = 'lyric_line_spacing';
  static const _kScale = 'lyric_scale';
  static const _kOffset = 'lyric_offset';
  static const _kTranslation = 'lyric_translation';
  static const _kGlow = 'lyric_glow';
  static const _kGlowColor = 'lyric_glow_color';
  static const _kCurrentColor = 'lyric_current_color';
  static const _kDimColor = 'lyric_dim_color';
  static const _kGradStart = 'lyric_grad_start';
  static const _kGradEnd = 'lyric_grad_end';
  static const _kKeepCustomColors = 'lyric_keep_custom_colors';
  static const _kBlurStart = 'lyric_blur_start';
  static const _kBlurAmount = 'lyric_blur_amount';
  static const _kTilt = 'lyric_tilt';
  static const _kTiltY = 'lyric_tilt_y';
  static const _kAlignLeft = 'lyric_align_left';
  static const _kOffsetX = 'lyric_offset_x';
  static const _kAnchorY = 'lyric_anchor_y';
  static const _kBackgroundSyncCover = 'lyric_background_sync_cover';
  static const _kBackgroundColor = 'lyric_background_color';
  static const _kBackgroundBlur = 'lyric_background_blur';

  // 取值范围（与 Swift 播放器设置里的滑杆区间一致）
  static const double minFontSize = 12;
  static const double maxFontSize = 28;
  static const double minLineSpacing = 14;
  static const double maxLineSpacing = 40;
  static const double minScale = 0.6;
  static const double maxScale = 1.6;
  static const double minOffsetSeconds = -10;
  static const double maxOffsetSeconds = 10;
  static const double minOffsetX = -120;
  static const double maxOffsetX = 120;
  static const double minAnchorY = -100;
  static const double maxAnchorY = 100;
  static const double minBlurStart = 0;
  static const double maxBlurStart = 4;
  static const double minBlurAmount = 0;
  static const double maxBlurAmount = 6;
  static const double minTilt = 0;
  static const double maxTilt = 45;
  static const double minTiltY = -45;
  static const double maxTiltY = 45;
  static const double minBackgroundBlur = 0;
  static const double maxBackgroundBlur = 30;
  static const int maxGlowLevel = 5;

  static const double defaultFontSize = 17;
  static const double defaultLineSpacing = 24;
  static const double defaultScale = 1;
  static const double defaultBlurStart = 1;
  static const double defaultBlurAmount = 1.1;
  static const double defaultBackgroundBlur = 12;

  final SharedPreferences _prefs;

  late double _fontSize;
  late double _lineSpacing;
  late double _scale;
  late double _offsetSeconds;
  late bool _translation;
  late int _glowLevel;
  late String _glowColorHex;
  late String _currentColorHex;
  late String _dimColorHex;
  late String _gradStartHex;
  late String _gradEndHex;
  late bool _keepCustomColors;
  late double _blurStart;
  late double _blurAmount;
  late double _tilt;
  late double _tiltY;
  late bool _alignLeft;
  late double _offsetX;
  late double _anchorY;
  late bool _backgroundSyncCover;
  late String _backgroundColorHex;
  late double _backgroundBlur;

  LyricStyleStore(SharedPreferences prefs) : _prefs = prefs {
    _fontSize = prefs.getDouble(_kFontSize) ?? defaultFontSize;
    _lineSpacing = prefs.getDouble(_kLineSpacing) ?? defaultLineSpacing;
    _scale = prefs.getDouble(_kScale) ?? defaultScale;
    _offsetSeconds = prefs.getDouble(_kOffset) ?? 0;
    _translation = prefs.getBool(_kTranslation) ?? true;
    _glowLevel = prefs.getInt(_kGlow) ?? 1;
    _glowColorHex = prefs.getString(_kGlowColor) ?? '';
    _currentColorHex = prefs.getString(_kCurrentColor) ?? '';
    _dimColorHex = prefs.getString(_kDimColor) ?? '';
    _gradStartHex = prefs.getString(_kGradStart) ?? '';
    _gradEndHex = prefs.getString(_kGradEnd) ?? '';
    _keepCustomColors = prefs.getBool(_kKeepCustomColors) ?? false;
    _blurStart = prefs.getDouble(_kBlurStart) ?? defaultBlurStart;
    _blurAmount = prefs.getDouble(_kBlurAmount) ?? defaultBlurAmount;
    _tilt = prefs.getDouble(_kTilt) ?? 0;
    _tiltY = prefs.getDouble(_kTiltY) ?? 0;
    _alignLeft = prefs.getBool(_kAlignLeft) ?? false;
    _offsetX = prefs.getDouble(_kOffsetX) ?? 0;
    _anchorY = prefs.getDouble(_kAnchorY) ?? 0;
    _backgroundSyncCover = prefs.getBool(_kBackgroundSyncCover) ?? false;
    _backgroundColorHex = prefs.getString(_kBackgroundColor) ?? '';
    _backgroundBlur = prefs.getDouble(_kBackgroundBlur) ?? defaultBackgroundBlur;
  }

  // MARK: - 歌词显示

  double get fontSize => _fontSize;

  set fontSize(double value) => _setDouble(
        _fontSize,
        value.clamp(minFontSize, maxFontSize),
        _kFontSize,
        (v) => _fontSize = v,
      );

  double get lineSpacing => _lineSpacing;

  set lineSpacing(double value) => _setDouble(
        _lineSpacing,
        value.clamp(minLineSpacing, maxLineSpacing),
        _kLineSpacing,
        (v) => _lineSpacing = v,
      );

  double get scale => _scale;

  set scale(double value) => _setDouble(
        _scale,
        value.clamp(minScale, maxScale),
        _kScale,
        (v) => _scale = v,
      );

  /// 歌词进度偏移（秒）：正数提前、负数延后
  double get offsetSeconds => _offsetSeconds;

  set offsetSeconds(double value) => _setDouble(
        _offsetSeconds,
        value.clamp(minOffsetSeconds, maxOffsetSeconds),
        _kOffset,
        (v) => _offsetSeconds = v,
      );

  bool get translationEnabled => _translation;

  set translationEnabled(bool value) =>
      _setBool(_translation, value, _kTranslation, (v) => _translation = v);

  // MARK: - 歌词效果

  int get glowLevel => _glowLevel;

  set glowLevel(int value) => _setInt(
        _glowLevel,
        value.clamp(0, maxGlowLevel),
        _kGlow,
        (v) => _glowLevel = v,
      );

  String get glowColorHex => _glowColorHex;

  set glowColorHex(String value) =>
      _setString(_glowColorHex, value, _kGlowColor, (v) => _glowColorHex = v);

  String get currentColorHex => _currentColorHex;

  set currentColorHex(String value) => _setString(
        _currentColorHex,
        value,
        _kCurrentColor,
        (v) => _currentColorHex = v,
      );

  String get dimColorHex => _dimColorHex;

  set dimColorHex(String value) =>
      _setString(_dimColorHex, value, _kDimColor, (v) => _dimColorHex = v);

  String get gradStartHex => _gradStartHex;

  set gradStartHex(String value) =>
      _setString(_gradStartHex, value, _kGradStart, (v) => _gradStartHex = v);

  String get gradEndHex => _gradEndHex;

  set gradEndHex(String value) =>
      _setString(_gradEndHex, value, _kGradEnd, (v) => _gradEndHex = v);

  /// 保持自定义配色：关闭时歌词颜色/渐变自动跟随封面取色
  bool get keepCustomColors => _keepCustomColors;

  set keepCustomColors(bool value) => _setBool(
        _keepCustomColors,
        value,
        _kKeepCustomColors,
        (v) => _keepCustomColors = v,
      );

  /// 模糊起始距离（距当前行几行开始模糊）
  double get blurStart => _blurStart;

  set blurStart(double value) => _setDouble(
        _blurStart,
        value.clamp(minBlurStart, maxBlurStart),
        _kBlurStart,
        (v) => _blurStart = v,
      );

  /// 模糊强度（0 = 完全关闭模糊）
  double get blurAmount => _blurAmount;

  set blurAmount(double value) => _setDouble(
        _blurAmount,
        value.clamp(minBlurAmount, maxBlurAmount),
        _kBlurAmount,
        (v) => _blurAmount = v,
      );

  /// 3D 倾斜角度（绕 X 轴，顶部向后倒）
  double get tilt => _tilt;

  set tilt(double value) =>
      _setDouble(_tilt, value.clamp(minTilt, maxTilt), _kTilt, (v) => _tilt = v);

  /// 左右倾斜角度（绕 Y 轴）
  double get tiltY => _tiltY;

  set tiltY(double value) => _setDouble(
        _tiltY,
        value.clamp(minTiltY, maxTiltY),
        _kTiltY,
        (v) => _tiltY = v,
      );

  // MARK: - 布局与背景

  /// 歌词对齐：false 居中 / true 全部居左
  bool get alignLeft => _alignLeft;

  set alignLeft(bool value) =>
      _setBool(_alignLeft, value, _kAlignLeft, (v) => _alignLeft = v);

  bool get centerAligned => !_alignLeft;

  /// 歌词水平偏移（负值向左、正值向右）
  double get offsetX => _offsetX;

  set offsetX(double value) => _setDouble(
        _offsetX,
        value.clamp(minOffsetX, maxOffsetX),
        _kOffsetX,
        (v) => _offsetX = v,
      );

  /// 垂直重心：0 居中；<0 当前行偏上（显示更多后续歌词）、>0 偏下
  double get anchorY => _anchorY;

  set anchorY(double value) => _setDouble(
        _anchorY,
        value.clamp(minAnchorY, maxAnchorY),
        _kAnchorY,
        (v) => _anchorY = v,
      );

  /// 歌词界面背景跟随封面取色
  bool get backgroundSyncCover => _backgroundSyncCover;

  set backgroundSyncCover(bool value) => _setBool(
        _backgroundSyncCover,
        value,
        _kBackgroundSyncCover,
        (v) => _backgroundSyncCover = v,
      );

  String get backgroundColorHex => _backgroundColorHex;

  set backgroundColorHex(String value) => _setString(
        _backgroundColorHex,
        value,
        _kBackgroundColor,
        (v) => _backgroundColorHex = v,
      );

  double get backgroundBlur => _backgroundBlur;

  set backgroundBlur(double value) => _setDouble(
        _backgroundBlur,
        value.clamp(minBackgroundBlur, maxBackgroundBlur),
        _kBackgroundBlur,
        (v) => _backgroundBlur = v,
      );

  // MARK: - 派生显示值

  /// 发光强度对应的模糊半径（0 关闭，最大 32）
  double get glowRadius =>
      const <double>[0, 6, 12, 18, 25, 32][_glowLevel.clamp(0, maxGlowLevel)];

  String get glowLabel => switch (_glowLevel) {
        0 => '关闭',
        1 => '柔和',
        2 => '标准',
        _ => '强烈',
      };

  /// 当前行在视口中的垂直锚点（0 = 顶部，1 = 底部）
  double get anchorFactor => (0.5 + _anchorY / 200).clamp(0.15, 0.85);

  double get effectiveFontSize => (_fontSize * _scale).clamp(8, 60);

  String get offsetLabel {
    if (_offsetSeconds.abs() < 0.05) return '同步';
    return _offsetSeconds > 0
        ? '提前 ${_offsetSeconds.toStringAsFixed(1)}s'
        : '延后 ${(-_offsetSeconds).toStringAsFixed(1)}s';
  }

  String get tiltLabel => _tilt == 0 ? '关闭' : '${_tilt.round()}°';

  String get tiltYLabel => _tiltY == 0 ? '关闭' : '${_tiltY.round()}°';

  String get blurAmountLabel =>
      _blurAmount < 0.05 ? '关闭' : _blurAmount.toStringAsFixed(1);

  String get backgroundLabel {
    if (_backgroundSyncCover) return '跟随封面取色';
    if (colorFromHex(_backgroundColorHex) != null) return '自定义背景色';
    return '跟随页面背景';
  }

  // MARK: - 配色解析（跟随封面取色 / 保持自定义配色）

  /// 当前行颜色：保持自定义配色关闭时自动跟随封面取色
  Color currentColor(CoverPalette palette) {
    if (!_keepCustomColors) return palette.accent;
    return colorFromHex(_currentColorHex) ?? palette.accent;
  }

  /// 未播放歌词颜色：保持自定义配色关闭时自动跟随封面取色
  Color dimColor(CoverPalette palette) {
    if (!_keepCustomColors) return palette.secondary;
    return colorFromHex(_dimColorHex) ?? palette.secondary;
  }

  /// 当前行渐变起始色
  Color gradientStart(CoverPalette palette) {
    if (_keepCustomColors) {
      final custom = colorFromHex(_gradStartHex);
      if (custom != null) return custom;
    }
    return currentColor(palette);
  }

  /// 当前行渐变结束色（未自定义时从起始色派生，深浅模式自适应）
  Color gradientEnd(CoverPalette palette, Brightness brightness) {
    if (_keepCustomColors) {
      final custom = colorFromHex(_gradEndHex);
      if (custom != null) return custom;
    }
    return mixColors(
      currentColor(palette),
      brightness == Brightness.dark ? Colors.white : Colors.black,
      0.45,
    );
  }

  /// 发光颜色（未自定义时跟随渐变起始色 / 封面取色）
  Color glowColor(CoverPalette palette) =>
      colorFromHex(_glowColorHex) ?? gradientStart(palette);

  /// 歌词界面背景：返回 null 表示不额外绘制背景（沿用宿主页面背景）
  ({Color top, Color bottom})? backgroundColors(CoverPalette palette) {
    if (_backgroundSyncCover) {
      return (top: palette.backgroundTop, bottom: palette.backgroundBottom);
    }
    final custom = colorFromHex(_backgroundColorHex);
    if (custom != null) {
      return (
        top: custom.withValues(alpha: 0.94),
        bottom: custom.withValues(alpha: 0.80),
      );
    }
    return null;
  }

  // MARK: - 预设与重置

  /// 应用渐变预设（同时开启自定义配色，避免被封面取色覆盖）
  void applyPreset(LyricPreset preset) {
    gradStartHex = preset.startHex;
    gradEndHex = preset.endHex;
    glowLevel = preset.glowLevel;
    keepCustomColors = true;
  }

  void resetColors() {
    currentColorHex = '';
    dimColorHex = '';
    glowColorHex = '';
    keepCustomColors = false;
  }

  void resetGradient() {
    gradStartHex = '';
    gradEndHex = '';
    keepCustomColors = false;
  }

  void resetLayout() {
    alignLeft = false;
    offsetX = 0;
    anchorY = 0;
  }

  void resetBackground() {
    backgroundSyncCover = false;
    backgroundColorHex = '';
    backgroundBlur = defaultBackgroundBlur;
  }

  void resetEffects() {
    blurStart = defaultBlurStart;
    blurAmount = defaultBlurAmount;
    tilt = 0;
    tiltY = 0;
    glowLevel = 1;
  }

  /// 恢复全部歌词设置默认值
  void resetAll() {
    fontSize = defaultFontSize;
    lineSpacing = defaultLineSpacing;
    scale = defaultScale;
    offsetSeconds = 0;
    translationEnabled = true;
    resetEffects();
    resetColors();
    resetGradient();
    resetLayout();
    resetBackground();
  }

  void _setDouble(
    double current,
    double next,
    String key,
    void Function(double) assign,
  ) {
    if (next == current) return;
    assign(next);
    _prefs.setDouble(key, next);
    notifyListeners();
  }

  void _setBool(bool current, bool next, String key, void Function(bool) assign) {
    if (next == current) return;
    assign(next);
    _prefs.setBool(key, next);
    notifyListeners();
  }

  void _setInt(int current, int next, String key, void Function(int) assign) {
    if (next == current) return;
    assign(next);
    _prefs.setInt(key, next);
    notifyListeners();
  }

  void _setString(
    String current,
    String next,
    String key,
    void Function(String) assign,
  ) {
    if (next == current) return;
    assign(next);
    _prefs.setString(key, next);
    notifyListeners();
  }
}