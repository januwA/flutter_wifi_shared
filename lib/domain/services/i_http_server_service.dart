abstract class IHttpServerService {
  /// 开启 HTTP 服务器
  /// [port] 监听端口
  /// [sharedDirectory] 提供下载/浏览共享的物理路径
  Future<int> startServer(int port, String sharedDirectory);

  /// 关闭 HTTP 服务器
  Future<void> stopServer();
}
