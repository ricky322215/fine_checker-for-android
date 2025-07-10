import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'models/fine_record.dart';
import 'pages/home_page.dart';
import 'services/background_service.dart'; // 包含 stopAlarmSound()

// 全域靜態函式，AwesomeNotifications 要求必須是全域或 static
Future<void> onActionReceivedMethod(ReceivedAction receivedNotification) async {
  print('Notification action received: ${receivedNotification.toMap()}');

  if (receivedNotification.buttonKeyPressed == 'STOP_ALARM' ||
      receivedNotification.channelKey == 'alert_channel') {
    await stopAlarmSound();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
  if (!isAllowed) {
    AwesomeNotifications().requestPermissionToSendNotifications();
  }
  });

  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'alert_channel',
        channelName: 'Alerts',
        channelDescription: 'Channel for fine alerts',
        defaultColor: Colors.red,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        soundSource: 'resource://raw/res_custom_alarm',
      ),
    ],
  );

  // 設定背景任務
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // 初始化 Hive
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  Hive.registerAdapter(FineRecordAdapter());
  await Hive.openBox<FineRecord>('fine_records');

  // 使用全域函式
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '交罰單提醒助手',
      home: const FineCheckHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}