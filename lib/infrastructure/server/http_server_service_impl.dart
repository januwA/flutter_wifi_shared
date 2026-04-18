import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../../domain/services/i_http_server_service.dart';
import '../../domain/entities/server_state.dart';

class HttpServerServiceImpl implements IHttpServerService {
  HttpServer? _server;
  String _selectedDirectory = '';
  bool _shareFile = true;
  bool _shareClipboard = true;
  Future<String?> Function()? _getClipboard;
  Future<void> Function(String)? _setClipboard;
  List<String> Function()? _getClipboardHistory;

  @override
  Future<int> startServer(
    int port,
    String sharedDirectory, {
    bool shareFile = true,
    bool shareClipboard = true,
    Future<String?> Function()? getClipboard,
    Future<void> Function(String)? setClipboard,
    List<String> Function()? getClipboardHistory,
  }) async {
    if (_server != null) {
      return _server!.port; // Already running
    }

    _selectedDirectory = sharedDirectory;
    _shareFile = shareFile;
    _shareClipboard = shareClipboard;
    _getClipboard = getClipboard;
    _setClipboard = setClipboard;
    _getClipboardHistory = getClipboardHistory;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    // 监听请求不阻塞当前的 Future (所以不用 await for)
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  @override
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _selectedDirectory = '';
      _getClipboard = null;
      _setClipboard = null;
      _getClipboardHistory = null;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // 增加 CORS 支持
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (_shareClipboard && (request.uri.path == '/api/clipboard' || request.uri.path == '/api/clipboard/history')) {
      await _handleClipboardApi(request);
      return;
    }

    if (_shareFile && request.method == 'POST' && request.headers.contentType?.mimeType == 'multipart/form-data') {
      await _handleFileUpload(request);
      return;
    }

    if (request.uri.path.contains('favicon.ico')) {
      request.response.close();
      return;
    }

    await _handleGetOrDownload(request);
  }

  Future<void> _handleClipboardApi(HttpRequest request) async {
    if (request.uri.path == '/api/clipboard/history') {
      final history = _getClipboardHistory?.call() ?? [];
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'history': history}))
        ..close();
      return;
    }

    if (request.method == 'GET') {
      final text = await _getClipboard?.call() ?? '';
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'text': text}))
        ..close();
    } else if (request.method == 'POST') {
      final content = await utf8.decoder.bind(request).join();
      try {
        final data = jsonDecode(content);
        final text = data['text'] as String?;
        if (text != null) {
          await _setClipboard?.call(text);
          request.response
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({'success': true}))
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..close();
        }
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..close();
      }
    }
  }

  Future<void> _handleFileUpload(HttpRequest request) async {
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

          // 保存文件到服务器指定的分享目录中
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
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(e.toString())
        ..close();
    }
  }

  Future<void> _handleGetOrDownload(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;

    String resData = '''
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WiFi Shared</title>
    <style>
        body { font-family: sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; background-color: #f5f5f5; }
        .section { background-color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        textarea { width: 100%; height: 100px; margin-bottom: 10px; padding: 10px; border-radius: 4px; border: 1px solid #ccc; font-size: 16px; box-sizing: border-box; }
        button { padding: 8px 16px; font-size: 14px; cursor: pointer; background-color: #6200ee; color: white; border: none; border-radius: 4px; transition: background 0.3s; margin-right: 5px; }
        button:hover { background-color: #3700b3; }
        .status { margin-top: 10px; color: #666; font-size: 14px; }
        h2 { margin-top: 0; color: #333; font-size: 18px; }
        .file-item { display: flex; align-items: center; padding: 8px 0; border-bottom: 1px solid #eee; }
        .file-item:last-child { border-bottom: none; }
        .file-item a { text-decoration: none; color: #6200ee; flex-grow: 1; }
        .icon { margin-right: 10px; }
        .history-item { background: #f9f9f9; padding: 10px; border-radius: 4px; margin-bottom: 8px; border-left: 4px solid #6200ee; white-space: pre-wrap; cursor: pointer; }
        .history-item:hover { background: #f0f0f0; }
    </style>
</head>
<body>
''';

    if (_shareClipboard) {
      final history = _getClipboardHistory?.call() ?? [];
      final latest = history.isNotEmpty ? history.first : '';
      resData += '''
    <div class="section">
        <h2>粘贴板</h2>
        <textarea id="clipboardText" placeholder="在此输入内容保存到手机">$latest</textarea>
        <div>
          <button onclick="updateClipboard()">保存到手机</button>
          <button onclick="refreshHistory()">刷新列表</button>
        </div>
        <div id="clipboardStatus" class="status"></div>
        <div id="historyList" style="margin-top: 15px;">
''';
      for (var item in history) {
        resData += '<div class="history-item" onclick="copyToTextarea(this)">${_escapeHtml(item)}</div>';
      }
      resData += '''
        </div>
    </div>
    <script>
        function copyToTextarea(el) {
            document.getElementById('clipboardText').value = el.innerText;
        }
        function updateClipboard() {
            const text = document.getElementById('clipboardText').value;
            const status = document.getElementById('clipboardStatus');
            status.innerText = '正在保存...';
            fetch('/api/clipboard', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ text: text })
            })
            .then(res => res.json())
            .then(data => {
                if (data.success) { status.innerText = '保存成功！'; setTimeout(() => { status.innerText = ''; refreshHistory(); }, 1000); }
                else status.innerText = '保存失败';
            })
            .catch(err => status.innerText = '保存出错: ' + err);
        }
        function refreshHistory() {
            const list = document.getElementById('historyList');
            const status = document.getElementById('clipboardStatus');
            status.innerText = '正在刷新...';
            fetch('/api/clipboard/history').then(res => res.json()).then(data => {
                list.innerHTML = '';
                data.history.forEach(item => {
                    const div = document.createElement('div');
                    div.className = 'history-item';
                    div.onclick = function() { copyToTextarea(this); };
                    div.innerText = item;
                    list.appendChild(div);
                });
                status.innerText = '已刷新';
                setTimeout(() => status.innerText = '', 1000);
            }).catch(err => status.innerText = '刷新出错: ' + err);
        }
    </script>
''';
    }

    if (_shareFile) {
      resData += '<div class="section"><h2>文件列表</h2>';
      
      String? target = request.uri.queryParameters["target"];
      var files = Directory(_selectedDirectory).list();

      if (target != null && target.startsWith(_selectedDirectory)) {
        final file = File(target);
        final dir = Directory(target);

        if (await file.exists()) {
          request.response.headers
            ..add('Content-Disposition', 'attachment; filename="${path.basename(target)}"')
            ..contentType = ContentType.binary;
          await request.response.addStream(file.openRead());
          request.response.close();
          return;
        }

        if (await dir.exists()) {
          files = dir.list();
        }
      }

      resData += '''
        <form id="uploadForm">
          <input type="file" id="fileInput" name="file" required>
          <button type="submit">上传文件</button>
        </form>
        <div id="uploadStatus" class="status"></div>
        <div style="margin-top: 20px;">
      ''';

      try {
        await for (FileSystemEntity file in files) {
          final isDirectory = file.statSync().type == FileSystemEntityType.directory;
          final icon = isDirectory ? '📂' : '📄';
          resData += '''
          <div class="file-item">
            <span class="icon">$icon</span>
            <a href="./?target=${file.path}">${path.basename(file.path)}</a>
          </div>
          ''';
        }
      } catch (e) {}

      resData += '''
        </div>
    </div>
    <script>
    document.getElementById('uploadForm').addEventListener('submit', function (e) {
      e.preventDefault();
      const fileInput = document.getElementById('fileInput');
      const file = fileInput.files[0];
      if (!file) return;
      const formData = new FormData();
      formData.append('file', file);
      const xhr = new XMLHttpRequest();
      const status = document.getElementById('uploadStatus');
      xhr.upload.addEventListener('progress', function (event) {
        if (event.lengthComputable) {
          const percent = (event.loaded / event.total) * 100;
          status.innerHTML = '上传进度: ' + percent.toFixed(2) + '%';
        }
      });
      xhr.addEventListener('load', function () { status.innerHTML = '上传完成！'; setTimeout(()=>location.reload(), 1000); });
      xhr.addEventListener('error', function () { status.innerHTML = '上传失败！'; });
      xhr.open('POST', '/', true);
      xhr.send(formData);
    });
    </script>
      ''';
    }

    resData += '</body></html>';
    request.response
      ..write(resData)
      ..close();
  }

  String _escapeHtml(String text) {
    return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }
}



