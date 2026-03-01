import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/server_state.dart';
import '../../domain/repositories/i_system_service.dart';
import '../../domain/services/i_http_server_service.dart';
import '../../core/di/providers.dart';

class ServerAppService extends Notifier<ServerState> {
  late final ISystemService _systemService;
  late final IHttpServerService _httpServerService;

  @override
  ServerState build() {
    _systemService = ref.read(systemServiceProvider);
    _httpServerService = ref.read(httpServerServiceProvider);
    
    // 初始化时获取一下 IP (可选)
    _fetchIp();
    return const ServerState();
  }

  Future<void> _fetchIp() async {
    final ip = await _systemService.getWifiIP();
    if (ip != null && ip.isNotEmpty) {
      state = state.copyWith(ipAddress: ip);
    }
  }

  Future<void> startServer() async {
    if (state.isRunning) return;

    // 1. 请求权限
    final hasPermission = await _systemService.requestStoragePermission();
    if (!hasPermission) {
      return; // 权限被拒绝，理论上可以抛异常给 UI 显示
    }

    // 2. 选择目录
    final directory = await _systemService.pickDirectory();
    if (directory == null || directory.isEmpty) {
      return; // 用户取消了选择
    }

    // 3. 开启服务器
    int port = 8080;
    const maxRetries = 10;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        final actualPort = await _httpServerService.startServer(port, directory);
        // 4. 更新状态
        await _fetchIp();
        state = state.copyWith(
          port: actualPort.toString(),
          selectedDirectory: directory,
          isRunning: true,
        );
        return; // 成功开启服务器，退出
      } catch (e) {
        // 如果是端口占用或其他 SocketException，则尝试下一个端口
        if (e.toString().contains('address already in use') || e.toString().contains('SocketException')) {
          port++;
          currentRetry++;
        } else {
          // 其它异常直接报错退出
          _resetState();
          rethrow;
        }
      }
    }

    // 重试次数达到上限
    _resetState();
    // 这里也可以抛出一个特定的异常让 UI 捕获并显示
  }

  void _resetState() {
    state = state.copyWith(
      ipAddress: '',
      port: '',
      selectedDirectory: '',
      isRunning: false,
    );
  }

  Future<void> stopServer() async {
    if (!state.isRunning) return;

    await _httpServerService.stopServer();
    _resetState();
  }
}

final serverAppServiceProvider = NotifierProvider<ServerAppService, ServerState>(() {
  return ServerAppService();
});
