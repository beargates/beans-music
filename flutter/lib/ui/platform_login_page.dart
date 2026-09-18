import 'package:flutter/material.dart';

import '../auth/platform_auth_store.dart';

class PlatformLoginPage extends StatefulWidget {
  final PlatformAuthStore store;

  const PlatformLoginPage({
    super.key,
    required this.store,
  });

  @override
  State<PlatformLoginPage> createState() => _PlatformLoginPageState();
}

class _PlatformLoginPageState extends State<PlatformLoginPage> {
  late final TextEditingController _qqCookieController;
  late final TextEditingController _kugouUserIdController;
  late final TextEditingController _kugouTokenController;
  late final TextEditingController _kugouMidController;
  late final TextEditingController _kugouDfidController;
  late final TextEditingController _kugouGuidController;

  @override
  void initState() {
    super.initState();
    final qqCookies = widget.store.qqCookies;
    final kugou = widget.store.kugouAuth;
    _qqCookieController = TextEditingController(text: _cookieHeader(qqCookies));
    _kugouUserIdController = TextEditingController(text: kugou['userid'] ?? '');
    _kugouTokenController = TextEditingController(text: kugou['token'] ?? '');
    _kugouMidController = TextEditingController(
      text: kugou['KUGOU_API_MID'] ?? kugou['mid'] ?? '',
    );
    _kugouDfidController = TextEditingController(text: kugou['dfid'] ?? '');
    _kugouGuidController = TextEditingController(
      text: kugou['KUGOU_API_GUID'] ?? '',
    );
  }

  @override
  void dispose() {
    _qqCookieController.dispose();
    _kugouUserIdController.dispose();
    _kugouTokenController.dispose();
    _kugouMidController.dispose();
    _kugouDfidController.dispose();
    _kugouGuidController.dispose();
    super.dispose();
  }

  String _cookieHeader(Map<String, String> cookies) {
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  Map<String, String> _parseCookieHeader(String value) {
    final cookies = <String, String>{};
    for (final part in value.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final key = part.substring(0, separator).trim();
      final cookieValue = part.substring(separator + 1).trim();
      if (key.isNotEmpty && cookieValue.isNotEmpty) {
        cookies[key] = cookieValue;
      }
    }
    return cookies;
  }

  Future<void> _saveQQ() async {
    final cookies = _parseCookieHeader(_qqCookieController.text);
    if (cookies['uin'] == null || cookies['uin']!.isEmpty) {
      _showMessage('QQ Cookie 中缺少 uin');
      return;
    }
    final hasCredential = [
      'p_skey',
      'skey',
      'qqmusic_key',
      'qm_keyst',
      'music_key',
      'musickey',
    ].any((key) => (cookies[key] ?? '').isNotEmpty);
    if (!hasCredential) {
      _showMessage('QQ Cookie 中缺少有效登录凭证');
      return;
    }
    await widget.store.saveQQCookies(cookies);
    if (mounted) _showMessage('QQ 登录态已保存');
  }

  Future<void> _saveKugou() async {
    final userId = _kugouUserIdController.text.trim();
    final token = _kugouTokenController.text.trim();
    if (userId.isEmpty || token.isEmpty) {
      _showMessage('酷狗用户 ID 和 token 不能为空');
      return;
    }
    await widget.store.saveKugouAuth({
      'userid': userId,
      'token': token,
      'KUGOU_API_MID': _kugouMidController.text.trim(),
      'dfid': _kugouDfidController.text.trim(),
      'KUGOU_API_GUID': _kugouGuidController.text.trim(),
    });
    if (mounted) _showMessage('酷狗登录态已保存');
  }

  Future<void> _clearQQ() async {
    await widget.store.clearQQ();
    _qqCookieController.clear();
    if (mounted) setState(() {});
  }

  Future<void> _clearKugou() async {
    await widget.store.clearKugou();
    for (final controller in [
      _kugouUserIdController,
      _kugouTokenController,
      _kugouMidController,
      _kugouDfidController,
      _kugouGuidController,
    ]) {
      controller.clear();
    }
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台登录态')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'QQ 音乐',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('在 y.qq.com 登录后，从请求 Headers 复制完整 Cookie。'),
          const SizedBox(height: 8),
          TextField(
            controller: _qqCookieController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'QQ Cookie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saveQQ,
                  child: const Text('保存 QQ 登录态'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '清除 QQ 登录态',
                onPressed: _clearQQ,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const Divider(height: 36),
          const Text(
            '酷狗音乐',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('填写酷狗登录接口返回的用户 ID 和 token。设备字段可选。'),
          const SizedBox(height: 8),
          TextField(
            controller: _kugouUserIdController,
            decoration: const InputDecoration(
              labelText: '用户 ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kugouTokenController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kugouMidController,
            decoration: const InputDecoration(
              labelText: '设备 MID（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kugouDfidController,
            decoration: const InputDecoration(
              labelText: 'DFID（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kugouGuidController,
            decoration: const InputDecoration(
              labelText: 'GUID（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saveKugou,
                  child: const Text('保存酷狗登录态'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '清除酷狗登录态',
                onPressed: _clearKugou,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
