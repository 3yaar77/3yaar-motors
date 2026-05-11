import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:autoreel/providers/accessory_provider.dart';

class AccessoryService {
  final CollectionReference<Map<String, dynamic>> col =
      FirebaseFirestore.instance.collection('accessories').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (data, _) => data,
          );

  Future<void> create(Accessory a) async {
    try {
      final doc = col.doc();
      final data = a.copyWith(id: doc.id).toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await doc.set(data);
    } catch (e) {
      debugPrint('AccessoryService.create error: $e');
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await col.doc(id).update(data);
    } catch (e) {
      debugPrint('AccessoryService.update error: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('AccessoryService.delete error: $e');
      rethrow;
    }
  }
}
