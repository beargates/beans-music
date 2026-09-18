import '../auth/netease_auth_store.dart';
import '../model/netease_user.dart';
import 'netease_auth_service.dart';

class NeteaseLoginRepository {
  final NeteaseAuthService authService;
  final NeteaseAuthStore authStore;

  NeteaseLoginRepository({
    required this.authService,
    required this.authStore,
  });

  Future<String> getQrKey() async {
    final key = await authService.qrKey();
    return key;
  }

  String buildQrUrl(String key) => authService.qrLoginUrl(key);

  Future<int> pollQrLogin(String key) async {
    final code = await authService.qrCheck(key);
    if (code == 800) {
      authStore.setLoggedIn(false);
    }
    if (code == 803) {
      final user = await authService.account();
      await authStore.saveUser(user);
      await authStore.setLoggedIn(true);
    }
    return code;
  }

  Future<NeteaseUser?> restoreSession() async {
    if (!authStore.isLoggedIn) return null;
    final user = authStore.user;
    if (user == null) return null;
    return user;
  }

  Future<void> logout() async {
    await authStore.clear();
  }
}
