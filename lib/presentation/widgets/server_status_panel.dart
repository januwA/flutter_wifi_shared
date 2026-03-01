import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/server_app_service.dart';

class ServerStatusPanel extends ConsumerWidget {
  const ServerStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverAppServiceProvider);

    if (!serverState.isRunning) {
      return const SizedBox.shrink(); // 未运行时不展示状态
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('网络地址: http://${serverState.ipAddress}:${serverState.port}'),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制网络地址',
              onPressed: () async {
                final url = 'http://${serverState.ipAddress}:${serverState.port}';
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('地址已复制')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('分享的目录: ${serverState.selectedDirectory}'),
      ],
    );
  }
}
