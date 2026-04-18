import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/server_state.dart';
import '../../domain/repositories/i_system_service.dart';
import '../../domain/services/i_http_server_service.dart';
import '../../core/di/providers.dart';

class ServerAppService extends Notifier<ServerState> {
  late final ISystemService _systemService;
  late final IHttpServerService _httpServerService;
  Timer? _clipboardTimer;
  String _lastClipboardText = '';

  @override
  ServerState build() {
    _systemService = ref.read(systemServiceProvider);
    _httpServerService = ref.read(httpServerServiceProvider);
    
    _fetchIp();

    // 销毁时清理定时器
    ref.onDispose(() {
      _clipboardTimer?.cancel();
    });

    return const ServerState();
  }

  Future<void> _fetchIp() async {
    final ip = await _systemService.getWifiIP();
    if (ip != null && ip.isNotEmpty) {
      state = state.copyWith(ipAddress: ip);
    }
  }

  void toggleShareFile(bool value) {
    if (state.isRunning) return;
    state = state.copyWith(shareFile: value);
  }

  void toggleShareClipboard(bool value) {
    if (state.isRunning) return;
    state = state.copyWith(shareClipboard: value);
  }

  void _startClipboardMonitoring() {
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final text = await _systemService.getClipboardText();
      if (text != null && text.isNotEmpty && text != _lastClipboardText) {
        _lastClipboardText = text;
        
        final history = List<String>.from(state.clipboardHistory);
        // 如果已经存在则先移除，然后放到最前面 (类似于最近使用的逻辑，或者保持单纯的顺序)
        // 这里采用单纯的顺序：如果有新内容就插到最前面
        if (!history.contains(text)) {
          history.insert(0, text);
          if (history.length > 50) history.removeLast();
          state = state.copyWith(clipboardHistory: history);
        }
      }
    });
  }

  Future<void> startServer() async {
    if (state.isRunning) return;
    if (!state.shareFile && !state.shareClipboard) return;

    String directory = '';
    if (state.shareFile) {
      final hasPermission = await _systemService.requestStoragePermission();
      if (!hasPermission) return;

      final picked = await _systemService.pickDirectory();
      if (picked == null || picked.isEmpty) return;
      directory = picked;
    }

    int port = 8080;
    const maxRetries = 10;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        final actualPort = await _httpServerService.startServer(
          port,
          directory,
          shareFile: state.shareFile,
          shareClipboard: state.shareClipboard,
          getClipboard: _systemService.getClipboardText,
          setClipboard: (text) async {
             await _systemService.setClipboardText(text);
             // 设置后立即更新本地监控状态，避免重复添加
             _lastClipboardText = text;
             if (!state.clipboardHistory.contains(text)) {
                final history = [text, ...state.clipboardHistory];
                if (history.length > 50) history.removeLast();
                state = state.copyWith(clipboardHistory: history);
             }
          },
          getClipboardHistory: () => state.clipboardHistory,
        );
        
        if (state.shareClipboard) {
          _startClipboardMonitoring();
        }

        await _fetchIp();
        state = state.copyWith(
          port: actualPort.toString(),
          selectedDirectory: directory,
          isRunning: true,
        );
        return;
      } catch (e) {
        if (e.toString().contains('address already in use') || e.toString().contains('SocketException')) {
          port++;
          currentRetry++;
        } else {
          _resetState();
          rethrow;
        }
      }
    }

    _resetState();
  }

  void _resetState() {
    _clipboardTimer?.cancel();
    _clipboardTimer = null;
    _lastClipboardText = '';

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
