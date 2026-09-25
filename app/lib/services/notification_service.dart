import 'dart:async';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  String? _fcmToken;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  String? get fcmToken => _fcmToken;
  Stream<String> get onMessage => _messageController.stream;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('NotificationService: Push notifications not available on web yet');
      return;
    }
    try {
      // Firebase will be added when configuring for Android/iOS builds
      debugPrint('NotificationService: Native push notifications require Firebase setup');
    } catch (e) {
      debugPrint('NotificationService: Not available - $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    debugPrint('NotificationService: subscribeToTopic($topic) - requires native setup');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    debugPrint('NotificationService: unsubscribeFromTopic($topic) - requires native setup');
  }

  void dispose() {
    _messageController.close();
  }
}
