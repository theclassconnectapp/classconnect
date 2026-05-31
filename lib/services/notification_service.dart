import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'user_repository.dart';

class NotificationService {
  NotificationService({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  final UserRepository _userRepository;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({required String uid}) async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await FirebaseMessaging.instance.requestPermission();
    final String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _userRepository.saveFcmToken(uid: uid, token: token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((String nextToken) async {
      await _userRepository.saveFcmToken(uid: uid, token: nextToken);
    });

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final RemoteNotification? notification = message.notification;
      if (notification == null) {
        return;
      }
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'classconnect_messages',
            'ClassConnect Messages',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }
}
