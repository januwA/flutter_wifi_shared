import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/server_app_service.dart';
import '../../domain/entities/server_state.dart';


class ServerControlPanel extends ConsumerWidget {
  const ServerControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 serverAppServiceProvider 的状态
    final serverState = ref.watch(serverAppServiceProvider);
    
    // 获取 Notifier 实例执行动作
    final serverNotifier = ref.read(serverAppServiceProvider.notifier);

    if (serverState.isRunning) {
      return ElevatedButton(
        onPressed: () => serverNotifier.stopServer(),
        child: const Text('关闭服务器'),
      );
    }

    return Column(
      children: [
        CheckboxListTile(
          title: const Text('分享文件/目录'),
          value: serverState.shareFile,
          onChanged: (val) => serverNotifier.toggleShareFile(val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          title: const Text('分享粘贴板'),
          value: serverState.shareClipboard,
          onChanged: (val) => serverNotifier.toggleShareClipboard(val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            minimumSize: const Size(200, 50),
          ),
          onPressed: () => serverNotifier.startServer(),
          child: const Text('开启服务器'),
        ),
      ],
    );
  }
}


