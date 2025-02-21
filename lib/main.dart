import 'dart:io';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _ipAddress = '';
  String _port = '';
  HttpServer? _server;
  String _selectedDirectory = ''; // 用于存储选择的目录路径

  Future<void> _getIpAddress() async {
    final networkInfo = NetworkInfo();
    try {
      String? ip = await networkInfo.getWifiIP();
      setState(() {
        _ipAddress = ip ?? '';
      });
    } catch (e) {
      setState(() {
        _ipAddress = '';
      });
    }
  }

  Future<void> _startServer() async {
    if(_port.isNotEmpty) {
      return;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
        // 权限已授予
      } else {
        // 权限被拒绝
        return;
      }
    }
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      // 用户取消了选择
      return;
    }

    setState(() {
      _selectedDirectory = selectedDirectory;
    });

    int port = 8080;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _getIpAddress();
      setState(() {
        _port = port.toString();
      });

      // 监听请求
      _server!.listen((HttpRequest request) async {
        if(request.method == 'POST' && request.headers.contentType?.mimeType == 'multipart/form-data') {
          try {
            // 解析 multipart/form-data 请求
            var boundary = request.headers.contentType?.parameters['boundary'];
            if (boundary == null) {
              request.response
                ..statusCode = HttpStatus.badRequest
                ..write('Invalid content type')
                ..close();
              return;
            }

            // 解析 multipart 数据
            final MimeMultipartTransformer transformer = MimeMultipartTransformer(boundary);
            final bodyStream = transformer.bind(request);
            // final bodyStream = request.transform(transformer as StreamTransformer<Uint8List, dynamic>);

            // 处理每个部分
            await for (var part in bodyStream) {
              var contentDisposition = part.headers['content-disposition'];
              if (contentDisposition != null && contentDisposition.contains('filename')) {
                // 提取文件名
                var filename = RegExp(r'filename="([^"]+)"')
                    .firstMatch(contentDisposition)
                    ?.group(1);
                if (filename == null) {
                  request.response
                    ..statusCode = HttpStatus.badRequest
                    ..write('Invalid filename')
                    ..close();
                  return;
                }

                // 保存文件到服务器
                var file = File(path.join(_selectedDirectory, filename));
                await file.create(recursive: true); // 创建目录（如果不存在）
                await part.pipe(file.openWrite());
              }
            }

            // 返回成功响应
            request.response
              ..statusCode = HttpStatus.ok
              ..write('File uploaded successfully')
              ..close();
            return;
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write(e.toString())
              ..close();
            return;
          }
        }

        if(request.uri.path.contains('favicon.ico')) {
          request.response.close();
          return;
        }

        request.response.headers.contentType = ContentType.html;
        String? target = request.uri.queryParameters["target"];
        var files = Directory(selectedDirectory).list();

        if(target != null && target.startsWith(_selectedDirectory)) {
          final file =  File(target);
          final dir =  Directory(target);

          if(await file.exists()) {
              // 下载文件
              request.response.headers
                ..add('Content-Disposition', 'attachment; filename="${path.basename(target)}"')
                ..contentType = ContentType.binary;
              await request.response .addStream(file.openRead());
              request.response.close();
              return;
          }

          if(await dir.exists()) {
          // 展示目录下的文件
            files = dir.list();
          }
        }

        String resData = '<html>';
        resData += '''
        <h1>文件上传</h1>
        <form id="uploadForm">
          <input type="file" id="fileInput" name="file" required>
          <button type="submit">Upload</button>
        </form>
        <div id="progress" style="margin-top: 20px;"></div>
        
        <script>
        document.getElementById('uploadForm').addEventListener('submit', function (e) {
          e.preventDefault(); // 阻止表单默认提交行为
    
          const fileInput = document.getElementById('fileInput');
          const file = fileInput.files[0];
          if (!file) {
            alert('请选择一个文件');
            return;
          }
    
          const formData = new FormData();
          formData.append('file', file);
    
          const xhr = new XMLHttpRequest();
    
          // 监听上传进度
          xhr.upload.addEventListener('progress', function (event) {
            if (event.lengthComputable) {
              const percent = (event.loaded / event.total) * 100;
              document.getElementById('progress').innerHTML = '上传进度: ' + percent.toFixed(2) + '%';
            }
          });
    
          // 监听上传完成
          xhr.addEventListener('load', function () {
            document.getElementById('progress').innerHTML = '上传完成！';
          });
    
          // 监听上传错误
          xhr.addEventListener('error', function () {
            document.getElementById('progress').innerHTML = '上传失败！';
          });
    
          // 打开连接并发送请求
          xhr.open('POST', '/', true);
          xhr.send(formData);
        });
      </script>
        ''';
        await for (FileSystemEntity file in files) {
          final isDirectory = file.statSync().type == FileSystemEntityType.directory;
          final title = isDirectory?'open dir':'download file';
          final icon = isDirectory ? '📂' : '';
          resData += '''
          <p title="$title">
            $icon<a href="./?target=${file.path}">${path.basename(file.path)}</a>
          </p>
          ''';
        }
        resData += '</html>';
        // 处理请求
        request.response
          ..write(resData)
          ..close();
      });
    } catch (e) {
      setState(() {
        _ipAddress = '';
        _port = '';
        _selectedDirectory = '';
      });
    }
  }

  Future<void> _stopServer() async {
    if (_server != null) {
      await _server!.close();
      setState(() {
        _ipAddress = '';
        _port = '';
        _selectedDirectory = '';
        _server = null;
      });
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('文件分享'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (_server == null) ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              ),
              onPressed: _startServer,
              child: const Text('开启服务器'),
            ) else ElevatedButton(
              onPressed: _stopServer,
              child: const Text('关闭服务器'),
            ),
            const SizedBox(height: 20),
            if (_server != null) ...[
              Text('网络地址: http://$_ipAddress:$_port'),
              Text('分享的目录: $_selectedDirectory')
            ]
          ],
        ),
      ),
    );
  }
}
