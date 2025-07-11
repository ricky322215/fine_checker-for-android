// 新版 main.dart：重構為互動控制頁面
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/fine_record.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 ValueListenableBuilder 監聽 box 變化，自動更新畫面
    final box = Hive.box<FineRecord>('fine_records');

    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史罰單紀錄'),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<FineRecord> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('目前沒有罰單紀錄'));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final record = box.getAt(index)!;
              return ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(record.plate),
                subtitle: Text(record.description),
                trailing: Text(
                  // 格式化日期：年月日時分
                  '${record.date.year}/${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')} '
                  '${record.date.hour.toString().padLeft(2, '0')}:${record.date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}