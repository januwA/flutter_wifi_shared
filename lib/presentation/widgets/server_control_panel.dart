import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/server_app_service.dart';

class ServerControlPanel extends ConsumerWidget {
  const ServerControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 serverAppServiceProvider 的状态
    final serverState = ref.watch(serverAppServiceProvider);
    
    // 获取 Notifier 实例执行动作
    final serverNotifier = ref.read(serverAppServiceProvider.notifier);

    return !serverState.isRunning
        ? ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            onPressed: () => serverNotifier.startServer(),
            child: const Text('开启服务器'),
          )
        : ElevatedButton(
            onPressed: () => serverNotifier.stopServer(),
            child: const Text('关闭服务器'),
          );
  }
}
