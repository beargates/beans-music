import 'dart:math' as math;

/// 单行歌词（含可选翻译），时间轴按升序排列。
class LyricLine {
  final Duration time;
  final String text;

  /// 歌词翻译（网易云 tlyric / QQ trans，可空）
  final String? translation;

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;

  /// 时间轴完全相同但内容不同的多行（如「哦~」重复），用时间 + 文本做稳定标识
  String get identityKey => '${time.inMilliseconds}-$text';

  LyricLine withTranslation(String? value) {
    return LyricLine(time: time, text: text, translation: value);
  }

  @override
  String toString() => 'LyricLine(${time.inMilliseconds}ms, $text)';
}

/// LRC 解析器（对应 Swift `LyricParser`）：
/// - 一行多个时间戳（`[00:01.00][00:05.00]歌词`）会拆成多行
/// - 支持 `[offset:+500]` 声明式偏移
/// - 支持传入翻译歌词，按时间戳合并到对应行
class LyricParser {
  static final RegExp _timePattern =
      RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _offsetPattern =
      RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

  static List<LyricLine> parse(String? raw, {String? translationRaw}) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final lines = _parseCore(raw, declaredOffsetSeconds(raw));
    if (lines.isEmpty) return const [];

    if (translationRaw == null || translationRaw.trim().isEmpty) return lines;
    final translationLines =
        _parseCore(translationRaw, declaredOffsetSeconds(translationRaw));
    if (translationLines.isEmpty) return lines;

    final byTime = <int, String>{};
    for (final line in translationLines) {
      if (line.text.isEmpty) continue;
      byTime[line.time.inMilliseconds] = line.text;
    }

    return [
      for (final line in lines)
        line.withTranslation(
          byTime[line.time.inMilliseconds] ?? line.translation,
        ),
    ];
  }

  /// 解析 `[offset:123]`（毫秒，可为负）为秒
  static double declaredOffsetSeconds(String raw) {
    final match = _offsetPattern.firstMatch(raw);
    if (match == null) return 0;
    final milliseconds = double.tryParse(match.group(1) ?? '');
    if (milliseconds == null) return 0;
    return milliseconds / 1000.0;
  }

  static List<LyricLine> _parseCore(String raw, double offsetSeconds) {
    final lines = <LyricLine>[];
    for (final sourceLine in raw.split(RegExp(r'\r?\n'))) {
      final matches = _timePattern.allMatches(sourceLine).toList();
      if (matches.isEmpty) continue;

      final text = sourceLine.replaceAll(_timePattern, '').trim();
      for (final match in matches) {
        final seconds = _toSeconds(match);
        final shifted = ((seconds + offsetSeconds) * 1000).round();
        lines.add(
          LyricLine(
            time: Duration(milliseconds: shifted < 0 ? 0 : shifted),
            text: text,
          ),
        );
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  static double _toSeconds(RegExpMatch match) {
    final minutes = double.tryParse(match.group(1) ?? '') ?? 0;
    final seconds = double.tryParse(match.group(2) ?? '') ?? 0;
    final fractionRaw = match.group(3) ?? '';
    var fraction = 0.0;
    if (fractionRaw.isNotEmpty) {
      final value = double.tryParse(fractionRaw) ?? 0;
      fraction = value / math.pow(10, fractionRaw.length);
    }
    return minutes * 60 + seconds + fraction;
  }
}

/// 歌词与播放进度的换算（对应 Swift `LyricTiming`）。
class LyricTiming {
  /// 播放进度 + 用户校正偏移（正数=歌词提前）。
  static Duration effectivePosition(Duration position, double offsetSeconds) {
    final milliseconds =
        position.inMilliseconds + (offsetSeconds * 1000).round();
    return Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
  }

  /// 点击歌词行跳转的实际进度（负偏移不会小于 0）。
  static Duration seekPosition(LyricLine line, double offsetSeconds) {
    final milliseconds =
        line.time.inMilliseconds - (offsetSeconds * 1000).round();
    return Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
  }

  /// 二分查找当前行下标（歌词按时间升序），空歌词或尚未开始时返回 null。
  static int? currentIndex(List<LyricLine> lines, Duration position) {
    if (lines.isEmpty) return null;
    var low = 0;
    var high = lines.length - 1;
    int? answer;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        answer = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return answer;
  }
}