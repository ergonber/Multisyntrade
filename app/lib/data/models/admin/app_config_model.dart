class AppConfigModel {
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? appVersion;

  const AppConfigModel({
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.appVersion,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> map) {
    return AppConfigModel(
      maintenanceMode: map['maintenance_mode'] ?? false,
      maintenanceMessage: map['maintenance_message'],
      appVersion: map['app_version'],
    );
  }

  Map<String, dynamic> toMap() => {
    'maintenance_mode': maintenanceMode,
    'maintenance_message': maintenanceMessage,
    'app_version': appVersion,
  };
}
