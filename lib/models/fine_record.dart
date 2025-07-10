import 'package:hive/hive.dart';

part 'fine_record.g.dart';

@HiveType(typeId: 0)
class FineRecord extends HiveObject {
  @HiveField(0)
  String plate;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String description;

  FineRecord({
    required this.plate,
    required this.date,
    required this.description,
  });
}