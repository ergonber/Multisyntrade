import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/datasources/remote/supabase/supabase_client.dart';

class DeviceService {
  static const _keyDeviceId = 'syntrade_device_id';
  static const _uuid = Uuid();

  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString(_keyDeviceId, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  static Future<void> registerDevice() async {
    if (kIsWeb) return;
    try {
      final deviceId = await getDeviceId();
      await SupabaseService.client.rpc('register_device', params: {
        'p_device_id': deviceId,
      });
    } catch (e) {
      debugPrint('[DeviceService] Error registering device: $e');
    }
  }

  static Future<bool> isCurrentDevice(String? profileDeviceId) async {
    if (kIsWeb) return true;
    if (profileDeviceId == null) return true;
    final localId = await getDeviceId();
    return localId == profileDeviceId;
  }
}
