abstract class IHttpServerService {
  /// 开启 HTTP 服务器
  /// [port] 监听端口
  /// [sharedDirectory] 提供下载/浏览共享的物理路径
  /// [shareFile] 是否共享文件
  /// [shareClipboard] 是否共享粘贴板
  /// [getClipboard] 获取粘贴板的回调
  /// [setClipboard] 设置粘贴板的回调
  /// [getClipboardHistory] 获取粘贴板历史的回调
  Future<int> startServer(
    int port,
    String sharedDirectory, {
    bool shareFile = true,
    bool shareClipboard = true,
    Future<String?> Function()? getClipboard,
    Future<void> Function(String)? setClipboard,
    List<String> Function()? getClipboardHistory,
  });


  /// 关闭 HTTP 服务器
  Future<void> stopServer();
}


