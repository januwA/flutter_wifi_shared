class ServerState {
  final String ipAddress;
  final String port;
  final String selectedDirectory;
  final bool isRunning;
  final bool shareFile;
  final bool shareClipboard;
  final List<String> clipboardHistory;

  const ServerState({
    this.ipAddress = '',
    this.port = '',
    this.selectedDirectory = '',
    this.isRunning = false,
    this.shareFile = true,
    this.shareClipboard = true,
    this.clipboardHistory = const [],
  });

  ServerState copyWith({
    String? ipAddress,
    String? port,
    String? selectedDirectory,
    bool? isRunning,
    bool? shareFile,
    bool? shareClipboard,
    List<String>? clipboardHistory,
  }) {
    return ServerState(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      selectedDirectory: selectedDirectory ?? this.selectedDirectory,
      isRunning: isRunning ?? this.isRunning,
      shareFile: shareFile ?? this.shareFile,
      shareClipboard: shareClipboard ?? this.shareClipboard,
      clipboardHistory: clipboardHistory ?? this.clipboardHistory,
    );
  }
}



