import 'package:flutter/material.dart';

const _coverUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36';

String normalizeCoverUrl(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.host.isEmpty) return value.trim();
  return uri.replace(scheme: 'https').toString();
}

List<String> coverImageCandidates(String? value) {
  final normalized = normalizeCoverUrl(value);
  if (normalized.isEmpty) return const [];
  final uri = Uri.tryParse(normalized);
  if (uri == null) return [normalized];

  final candidates = <String>[];
  if (uri.host.contains('kugou.com')) {
    for (final host in const ['imge.kugou.com', 'imgessl.kugou.com']) {
      for (final size in const ['400', '300', '240']) {
        candidates.add(
          uri
              .replace(scheme: 'https', host: host)
              .toString()
              .replaceAll('{size}', size)
              .replaceAll('%7Bsize%7D', size),
        );
      }
    }
  }
  if (uri.host.endsWith('music.126.net')) {
    final match = RegExp(r'/(\d+)\.[^/]+$').firstMatch(uri.path);
    if (match != null) {
      candidates.add(
        'https://music.163.com/api/img/blur/${match.group(1)}?param=300y300',
      );
    }
  }
  final hosts = <String>[
    uri.host,
    if (uri.host.endsWith('music.126.net')) 'p1.music.126.net',
    if (uri.host.endsWith('music.126.net')) 'p2.music.126.net',
    if (uri.host.endsWith('music.126.net')) 'p3.music.126.net',
    if (uri.host.endsWith('music.126.net')) 'p4.music.126.net',
  ];
  candidates.addAll(hosts
      .map(
        (host) => uri.replace(
          host: host,
          queryParameters: {
            ...uri.queryParameters,
            'param': uri.queryParameters['param'] ?? '300y300',
          },
        ).toString(),
      )
      .toList());
  return candidates.toSet().toList();
}

Map<String, String> coverImageHeaders(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  final referer = host.contains('qq.com')
      ? 'https://y.qq.com/'
      : host.contains('kugou.com')
          ? 'https://www.kugou.com/'
          : 'https://music.163.com/';
  return {'Referer': referer, 'User-Agent': _coverUserAgent};
}

class CoverImage extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext context)? placeholder;
  final BorderRadius? borderRadius;

  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  });

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  late List<String> _candidates;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _candidates = coverImageCandidates(widget.url);
  }

  @override
  void didUpdateWidget(covariant CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _candidates = coverImageCandidates(widget.url);
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.placeholder?.call(context) ??
        const ColoredBox(
          color: Color(0xFFE9E7E2),
          child: Center(child: Icon(Icons.music_note_rounded)),
        );
    if (_index >= _candidates.length) return fallback;

    final image = Image.network(
      _candidates[_index],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      headers: coverImageHeaders(_candidates[_index]),
      errorBuilder: (_, __, ___) {
        if (_index < _candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
        }
        return fallback;
      },
    );
    return widget.borderRadius == null
        ? image
        : ClipRRect(borderRadius: widget.borderRadius!, child: image);
  }
}
