import 'dart:io';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../../domain/services/i_http_server_service.dart';

class HttpServerServiceImpl implements IHttpServerService {
  HttpServer? _server;
  String _selectedDirectory = '';

  @override
  Future<int> startServer(int port, String sharedDirectory) async {
    if (_server != null) {
      return _server!.port; // Already running
    }
    
    _selectedDirectory = sharedDirectory;
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
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method == 'POST' && request.headers.contentType?.mimeType == 'multipart/form-data') {
      await _handleFileUpload(request);
      return;
    }

    if (request.uri.path.contains('favicon.ico')) {
      request.response.close();
      return;
    }

    await _handleGetOrDownload(request);
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
    String? target = request.uri.queryParameters["target"];
    var files = Directory(_selectedDirectory).list();

    if (target != null && target.startsWith(_selectedDirectory)) {
      final file = File(target);
      final dir = Directory(target);

      if (await file.exists()) {
        // 下载文件
        request.response.headers
          ..add('Content-Disposition', 'attachment; filename="${path.basename(target)}"')
          ..contentType = ContentType.binary;
        await request.response.addStream(file.openRead());
        request.response.close();
        return;
      }

      if (await dir.exists()) {
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

    try {
      await for (FileSystemEntity file in files) {
        final isDirectory = file.statSync().type == FileSystemEntityType.directory;
        final title = isDirectory ? 'open dir' : 'download file';
        final icon = isDirectory ? '📂' : '';
        resData += '''
        <p title="$title">
          $icon<a href="./?target=${file.path}">${path.basename(file.path)}</a>
        </p>
        ''';
      }
    } catch (e) {
       // 如果读取目录遇到权限或其它错误忽略
    }

    resData += '</html>';
    request.response
      ..write(resData)
      ..close();
  }
}
