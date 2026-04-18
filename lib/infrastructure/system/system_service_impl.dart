import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:permission_handler/permission_handler.dart';
import '../../domain/repositories/i_system_service.dart';

class SystemServiceImpl implements ISystemService {
  final NetworkInfo _networkInfo = NetworkInfo();

  @override
  Future<String?> getWifiIP() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      return await Permission.manageExternalStorage.request().isGranted;
    }
    // 非 Android 平台默认返回 true
    return true;
  }

  @override
  Future<String?> pickDirectory() async {
    return await FilePicker.platform.getDirectoryPath();
  }

  @override
  Future<String?> getClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  @override
  Future<void> setClipboardText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

