abstract class ISystemService {
  /// 获取当前局域网内的 WIFI IP 地址
  Future<String?> getWifiIP();

  /// 请求文件读取/管理权限 (主要针对 Android)
  Future<bool> requestStoragePermission();

  /// 弹出目录选择器，让用户选择要分享的目录
  Future<String?> pickDirectory();
}
