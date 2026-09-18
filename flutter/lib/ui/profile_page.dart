import 'package:flutter/material.dart';

import '../auth/netease_auth_store.dart';
import '../auth/platform_auth_store.dart';
import 'platform_login_page.dart';

class ProfilePage extends StatelessWidget {
  final NeteaseAuthStore neteaseStore;
  final PlatformAuthStore platformStore;

  const ProfilePage({
    super.key,
    required this.neteaseStore,
    required this.platformStore,
  });

  @override
  Widget build(BuildContext context) {
    final qqLoggedIn = platformStore.qqCookies.isNotEmpty;
    final kugouLoggedIn = platformStore.kugouAuth['token']?.isNotEmpty == true;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('网易云音乐'),
              subtitle: Text(
                neteaseStore.isLoggedIn
                    ? (neteaseStore.user?.nickname ?? '已登录')
                    : '未登录',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('QQ 音乐'),
              subtitle: Text(qqLoggedIn ? '已保存登录态' : '未登录'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('酷狗音乐'),
              subtitle: Text(kugouLoggedIn ? '已保存登录态' : '未登录'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlatformLoginPage(store: platformStore),
                ),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('管理平台登录态'),
          ),
        ],
      ),
    );
  }
}
