import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deductPoint(String plate) async {
  final docRef = FirebaseFirestore.instance.collection('users').doc(plate);
  final doc = await docRef.get();
  final current = doc.data()?['points'] ?? 0;
  if (current > 0) await docRef.update({'points': current - 1});
}