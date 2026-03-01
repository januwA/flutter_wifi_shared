import 'package:flutter/material.dart';
import '../widgets/server_control_panel.dart';
import '../widgets/server_status_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('文件分享'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 20),
            ServerControlPanel(),
            ServerStatusPanel(),
          ],
        ),
      ),
    );
  }
}
