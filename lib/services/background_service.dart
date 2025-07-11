import 'dart:typed_data';
import 'dart:ui';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:fine_checker/firebase_options.dart';
import '../models/fine_record.dart';
import 'package:fine_checker/services/fine_check_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[Background] 任務開始執行 task=$task');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FineRecordAdapter());
    }
    await Hive.openBox<FineRecord>('fine_records');

    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'alert_channel',
          channelName: 'Alerts',
          channelDescription: 'Channel for fine alerts',
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
          enableLights: true,
          defaultColor: const Color(0xFF9D50DD),
          ledColor: const Color(0xFFFF0000),
        ),
        NotificationChannel(
          channelKey: 'silent_channel',
          channelName: 'Background Status',
          channelDescription: 'Background check updates (no sound)',
          importance: NotificationImportance.Low,
          playSound: false,
          enableVibration: false,
        ),
      ],
    );

    final plate = inputData?['plate'];
    final vehicleType = inputData?['vehicleType'] ?? 'L'; // 預設為汽車
    print('[Background] plate=$plate, vehicleType=$vehicleType');

    // ✅ 限制檢查時間為早上 9:00 至晚上 22:00
    final now = DateTime.now();
    if (now.hour < 9 || now.hour >= 22) {
      print('[Background] ⚠️ 非檢測時間（目前時間 ${now.hour}:00），跳過本次任務');
      return Future.value(true);
    }

    if (plate is String && vehicleType is String) {
      final hasNewFine = await checkForFine(
        plateNumber: plate,
        vehicleType: vehicleType,
      );

      if (hasNewFine == null) {
        await sendInvalidPlateNotification();
      } else if (hasNewFine) {
        await sendFineNotification();
        await recordFineToHive(plate);
      } else {
        await sendNoFineNotification();
      }
    }

    print('[Background] 任務結束，回傳成功');
    return Future.value(true);
  });
}

/// 發送「有罰單」通知（會響）
Future<void> sendFineNotification() async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channelKey: 'alert_channel',
      title: '🚨 發現新罰單',
      body: '您的車牌號碼查詢出現新的罰單紀錄，已自動停止檢測。',
      notificationLayout: NotificationLayout.Default,
      wakeUpScreen: true,
      fullScreenIntent: true,
      category: NotificationCategory.Alarm,
      locked: true,
      autoDismissible: false,
    ),
    actionButtons: [
      NotificationActionButton(
        key: 'STOP_ALARM',
        label: '停止鬧鐘',
        isDangerousOption: true,
        autoDismissible: true,
      ),
    ],
  );
}

/// 發送「無罰單」通知（靜音）
Future<void> sendNoFineNotification() async {
  final now = DateTime.now();
  final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: now.millisecondsSinceEpoch ~/ 1000,
      channelKey: 'silent_channel',
      title: '✅ 沒有檢測到罰單',
      body: '背景任務於 $formattedTime 成功執行，沒有違規紀錄。',
      notificationLayout: NotificationLayout.Default,
      autoDismissible: true,
    ),
  );
}

/// 發送「車牌無效」通知（錯誤提示）
Future<void> sendInvalidPlateNotification() async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channelKey: 'alert_channel',
      title: '🚫 查詢失敗',
      body: '查詢未跳轉到正確頁面，可能車牌未登記或輸入錯誤。',
      notificationLayout: NotificationLayout.Default,
      autoDismissible: true,
    ),
  );
}

/// 寫入 Hive 紀錄
Future<void> recordFineToHive(String plate) async {
  final box = Hive.box<FineRecord>('fine_records');
  await box.add(FineRecord(
    plate: plate,
    date: DateTime.now(),
    description: '偵測到罰單，已停止檢測',
  ));
}

/// 停止鬧鐘（未實作）
Future<void> stopAlarmSound() async {
  print('🔕 收到停止鬧鐘指令，但目前未實作停止音效');
}
