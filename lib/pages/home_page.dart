import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:hive/hive.dart';
import '../models/fine_record.dart';
import 'history_page.dart';

class FineCheckHomePage extends StatefulWidget {
  const FineCheckHomePage({super.key});

  @override
  State<FineCheckHomePage> createState() => _FineCheckHomePageState();
}

class _FineCheckHomePageState extends State<FineCheckHomePage> {
  final _plateController = TextEditingController();
  String _vehicleType = '汽車'; // 預設汽車
  bool _isChecking = false;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final plate = prefs.getString('plate');
    final vehicleType = prefs.getString('vehicleType') ?? '汽車';
    final isChecking = prefs.getBool('isChecking') ?? false;

    if (plate != null) {
      _plateController.text = plate;
    }
    setState(() {
      _vehicleType = vehicleType;
      _isChecking = isChecking;
    });
  }

  Future<void> _startChecking() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return;

    final box = Hive.box<FineRecord>('fine_records');
    final hasOldFine = box.values.any((record) => record.plate == plate);
    if (hasOldFine) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("請確認已處理罰單"),
          content: const Text("若尚未處理可能導致重複扣點"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("我知道了"),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plate', plate);
    await prefs.setString('vehicleType', _vehicleType);
    await prefs.setBool('isChecking', true);

    final vehicleCode = _vehicleType == '汽車' ? 'L' : 'C';

    await Workmanager().registerPeriodicTask(
      'fine_check_task',
      'checkForFines',
      frequency: const Duration(minutes: 16),
      initialDelay: const Duration(seconds: 5),
      inputData: {
        'plate': plate,
        'vehicleType': vehicleCode,
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    await Workmanager().registerOneOffTask(
      'fine_check_immediate_${DateTime.now().millisecondsSinceEpoch}',
      'checkForFines',
      inputData: {
        'plate': plate,
        'vehicleType': vehicleCode,
      },
    );

    setState(() {
      _isChecking = true;
      _log.clear();
      _log.add('✅ 已開始檢測 $plate ($_vehicleType) 每 16 分鐘');
    });
  }

  Future<void> _stopChecking() async {
    await Workmanager().cancelByUniqueName('fine_check_task');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isChecking', false);

    setState(() {
      _isChecking = false;
      _log.add('⏹️ 已停止檢測');
    });
  }

  Widget _buildStatusLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _log.map((line) => Text(line)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('罰單檢測助手'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _plateController,
              enabled: !_isChecking,
              decoration: const InputDecoration(labelText: '車牌號碼'),
            ),
            const SizedBox(height: 16),
            const Text('車種選擇'),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('汽車'),
                    value: '汽車',
                    groupValue: _vehicleType,
                    onChanged: _isChecking
                        ? null
                        : (value) {
                            setState(() {
                              _vehicleType = value!;
                            });
                          },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('機車'),
                    value: '機車',
                    groupValue: _vehicleType,
                    onChanged: _isChecking
                        ? null
                        : (value) {
                            setState(() {
                              _vehicleType = value!;
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isChecking ? _stopChecking : _startChecking,
              child: Text(_isChecking ? '停止檢測' : '開始檢測'),
            ),
            const SizedBox(height: 20),
            const Text('狀態紀錄：'),
            ElevatedButton(
              onPressed: () {
                Workmanager().registerOneOffTask(
                  'test-task-${DateTime.now().millisecondsSinceEpoch}',
                  'checkForFines',
                  inputData: {
                    'plate': 'ma0001',
                    'vehicleType': 'L',
                  },
                );
                print('🚀 已註冊背景測試任務 (5 秒後執行)');
              },
              child: const Text('背景罰單測試'),
            ),
            ElevatedButton(
              child: const Text('查看歷史罰單紀錄'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
            ),
            _buildStatusLogs(),
          ],
        ),
      ),
    );
  }
}
