import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/i_system_service.dart';
import '../../domain/services/i_http_server_service.dart';
import '../../infrastructure/system/system_service_impl.dart';
import '../../infrastructure/server/http_server_service_impl.dart';

// 提供系统服务实例
final systemServiceProvider = Provider<ISystemService>((ref) {
  return SystemServiceImpl();
});

// 提供HTTP服务器服务实例
final httpServerServiceProvider = Provider<IHttpServerService>((ref) {
  return HttpServerServiceImpl();
});
