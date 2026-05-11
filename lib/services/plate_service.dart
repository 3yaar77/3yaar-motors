import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/providers/plate_provider.dart';

/// Service responsible for loading plate listings strictly from Firestore.
class PlateService {
  Future<List<Plate>> loadPlates() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final List<Plate> out = [];

      // Primary: dedicated 'plates' collection
      final platesSnap = await firestore.collection('plates').limit(200).get();
      for (final d in platesSnap.docs) {
        try {
          final data = d.data();
          final map = <String, dynamic>{'id': d.id, ...data};
          out.add(Plate.fromJson(map));
        } catch (e) {
          debugPrint('PlateService: skip invalid plates doc ${d.id}: $e');
        }
      }

      // Also accept from unified 'listings' where category == 'Plates'
      final listingsSnap = await firestore
          .collection('listings')
          .where('category', isEqualTo: 'Plates')
          .where('status', isEqualTo: 'active')
          .limit(200)
          .get();
      for (final d in listingsSnap.docs) {
        try {
          final data = d.data();
          final map = <String, dynamic>{'id': d.id, ...data};
          out.add(Plate.fromJson(map));
        } catch (e) {
          debugPrint('PlateService: skip invalid listings doc ${d.id}: $e');
        }
      }

      // Sort newest first
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (e) {
      debugPrint('PlateService.loadPlates Firestore error: $e');
      return <Plate>[]; // No local fallback
    }
  }

  Future<void> savePlates(List<Plate> plates) async {
    // No client-side persistence; Firestore is the source of truth.
  }
}
