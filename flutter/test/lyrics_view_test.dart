import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beans_music_flutter/service/cover_palette.dart';
import 'package:beans_music_flutter/service/lyric_service.dart';
import 'package:beans_music_flutter/store/lyric_style_store.dart';
import 'package:beans_music_flutter/widget/lyrics_view.dart';

void main() {
  late LyricStyleStore store;
  late StreamController<Duration> position;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LyricStyleStore(await SharedPreferences.getInstance());
    position = StreamController<Duration>.broadcast();
  });

  tearDown(() => position.close());

  Future<void> pumpLyrics(
    WidgetTester tester, {
    required ValueChanged<LyricLine> onTapLine,
    String raw = '[00:00.00]第一行\n[00:05.00]第二行\n[00:10.00]第三行',
    String emptyMessage = '暂无歌词',
    VoidCallback? onRetry,
  }) async {
    final lines = LyricParser.parse(raw);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: LyricsView(
              lines: lines,
              positionStream: position.stream,
              style: store,
              palette: CoverPalette.fallback(
                ColorScheme.fromSeed(seedColor: const Color(0xFFE5654B)),
              ),
              emptyMessage: emptyMessage,
              onTapLine: onTapLine,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染歌词行并高亮当前行', (tester) async {
    await pumpLyrics(tester, onTapLine: (_) {});
    expect(find.text('第一行'), findsOneWidget);
    expect(find.text('第二行'), findsOneWidget);
    expect(find.text('第三行'), findsOneWidget);

    // 播放到 6 秒：当前行切换到第二行
    position.add(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // 当前行为渐变 + 光晕两层，其中至少一层使用加粗样式
    final currentTexts = tester.widgetList<Text>(find.text('第二行')).toList();
    expect(currentTexts, isNotEmpty);
    expect(
      currentTexts.any((text) => text.style?.fontWeight == FontWeight.w700),
      isTrue,
    );

    final firstTexts = tester.widgetList<Text>(find.text('第一行')).toList();
    expect(firstTexts.length, 1);
    expect(firstTexts.first.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('点击歌词行回调该行', (tester) async {
    LyricLine? tapped;
    await pumpLyrics(tester, onTapLine: (line) => tapped = line);
    expect(tapped, isNull);

    await tester.tap(find.text('第三行'));
    await tester.pumpAndSettle();
    expect(tapped?.text, '第三行');
    expect(tapped?.time, const Duration(seconds: 10));
  });

  testWidgets('长按进入多选模式并可全选 / 取消', (tester) async {
    await pumpLyrics(tester, onTapLine: (_) {});

    await tester.longPress(find.text('第一行'));
    await tester.pumpAndSettle();
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('复制 (1)'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('复制 (3)'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('全选'), findsNothing);
  });

  testWidgets('无歌词时显示兜底文案与重试入口', (tester) async {
    var retried = false;
    await pumpLyrics(
      tester,
      onTapLine: (_) {},
      raw: '',
      emptyMessage: '纯音乐，请欣赏',
      onRetry: () => retried = true,
    );

    expect(find.text('纯音乐，请欣赏'), findsOneWidget);
    await tester.tap(find.text('重新获取'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });

  testWidgets('无翻译数据时切换翻译开关不报错', (tester) async {
    await pumpLyrics(
      tester,
      onTapLine: (_) {},
      raw: '[00:00.00]Hello',
    );
    expect(find.text('Hello'), findsOneWidget);

    position.add(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    store.translationEnabled = false;
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('显示网易云翻译歌词', (tester) async {
    final lyrics = Lyrics(
      lines: LyricParser.parse(
        '[00:00.00]Hello',
        translationRaw: '[00:00.00]你好',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: LyricsView(
              lines: lyrics.lines,
              positionStream: position.stream,
              style: store,
              palette: CoverPalette.fallback(
                ColorScheme.fromSeed(seedColor: const Color(0xFFE5654B)),
              ),
              onTapLine: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    position.add(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('你好'), findsOneWidget);
    expect(lyrics.hasTranslation, isTrue);

    store.translationEnabled = false;
    await tester.pumpAndSettle();
    expect(find.text('你好'), findsNothing);
  });
}