class ServerState {
  final String ipAddress;
  final String port;
  final String selectedDirectory;
  final bool isRunning;

  const ServerState({
    this.ipAddress = '',
    this.port = '',
    this.selectedDirectory = '',
    this.isRunning = false,
  });

  ServerState copyWith({
    String? ipAddress,
    String? port,
    String? selectedDirectory,
    bool? isRunning,
  }) {
    return ServerState(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      selectedDirectory: selectedDirectory ?? this.selectedDirectory,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
