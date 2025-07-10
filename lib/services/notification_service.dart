import 'package:awesome_notifications/awesome_notifications.dart';

Future<void> sendFineNotification() async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      channelKey: 'alert_channel',
      title: '🚨 發現新罰單',
      body: '您的車牌號碼查詢出現新的罰單紀錄。',
    ),
  );
}