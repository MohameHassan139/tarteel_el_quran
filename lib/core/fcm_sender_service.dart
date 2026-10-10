import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'fcm_config.dart';

class FcmSenderService {
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';

  /// Sends a push notification directly to a target FCM device token using the Firebase Server Key.
  /// Works without Firebase Cloud Functions and without needing a paid/Blaze plan.
  static Future<bool> sendNotification({
    required String toToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String channelId = 'teacher_note_channel',
  }) async {
    final serverKey = FcmConfig.serverKey.trim();
    if (serverKey.isEmpty || serverKey == 'PASTE_YOUR_SERVER_KEY_HERE') {
      debugPrint('FcmSenderService: Server key is not configured in lib/core/fcm_config.dart');
      return false;
    }

    try {
      final payload = {
        'to': toToken,
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'android_channel_id': channelId,
          'sound': 'default',
          'default_sound': true,
          'default_vibrate_timings': true,
        },
        'data': {
          if (data != null) ...data,
          'title': title,
          'body': body,
          'channel_id': channelId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        debugPrint('FcmSenderService response: ${response.statusCode}');
      }
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmSenderService send error: $e');
      }
      return false;
    }
  }
}
