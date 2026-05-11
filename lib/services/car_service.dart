import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:autoreel/providers/car_provider.dart';

/// Service responsible for loading car listings strictly from Firestore.
class CarService {
  Future<List<Car>> loadCars() async {
    try {
      final col = FirebaseFirestore.instance.collection('listings');
      final base = col
          .where('status', isEqualTo: 'active')
          .where('category', isEqualTo: 'Cars');
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await base.orderBy('createdAt', descending: true).limit(200).get();
      } on FirebaseException catch (e) {
        final msg = (e.message ?? e.code).toLowerCase();
        if (msg.contains('failed-precondition') || msg.contains('requires an index')) {
          debugPrint('CarService: falling back to query without orderBy(createdAt)');
          snap = await base.limit(200).get();
        } else {
          rethrow;
        }
      }

      String _readString(Map<String, dynamic> m, String key) {
        final v = m[key];
        return v == null ? '' : v.toString();
      }

      int _readInt(Map<String, dynamic> m, String key) {
        final v = m[key];
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.round();
        if (v is String) {
          final d = v.replaceAll(RegExp(r'[^0-9]'), '');
          return int.tryParse(d) ?? 0;
        }
        return 0;
      }

      DateTime _readTime(Map<String, dynamic> m) {
        final v = m['createdAt'] ?? m['created_at'];
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return DateTime.now();
      }

      List<String> _readList(Map<String, dynamic> m, String key) {
        final v = m[key];
        if (v is List) {
          return v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).cast<String>().toList();
        }
        return const <String>[];
      }

      bool _isHttp(String s) => s.toLowerCase().startsWith('http');

      String _primaryImage(Map<String, dynamic> m) {
        final listImages = _readList(m, 'images');
        // New rule: primary is images[0] if valid; ignore coverImageUrl and legacy fields
        if (listImages.isNotEmpty && _isHttp(listImages.first)) return listImages.first;
        return '';
      }

      final List<Car> out = [];
      for (final d in snap.docs) {
        try {
          final data = d.data();
          final m = <String, dynamic>{'id': d.id, ...data};
          final imagesAlt = _readList(m, 'images');
          final primary = _primaryImage(m);
          // Build images list strictly from images[]; drop non-http and dups
          final all = <String>[...imagesAlt];
          final seen = <String>{};
          final httpImages = <String>[];
          for (final u in all) {
            final t = (u).trim();
            if (t.isEmpty) continue;
            if (!_isHttp(t)) continue;
            if (!seen.add(t)) continue;
            httpImages.add(t);
          }

          final car = Car(
            id: m['id'] as String,
            make: _readString(m, 'brand').isNotEmpty ? _readString(m, 'brand') : _readString(m, 'make'),
            model: _readString(m, 'model'),
            year: _readInt(m, 'year'),
            price: _readInt(m, 'price'),
            mileage: _readInt(m, 'mileage'),
            location: _readString(m, 'location'),
            imageUrl: primary,
            imageUrls: httpImages,
            sellerPhone: _readString(m, 'ownerPhone').isNotEmpty ? _readString(m, 'ownerPhone') : _readString(m, 'phone'),
            description: _readString(m, 'description'),
            createdAt: _readTime(m),
            isLiked: false,
            isFeatured: (m['isFeatured'] as bool?) ?? false,
            isPinned: (m['isPinned'] as bool?) ?? false,
            isVip: (m['isVip'] as bool?) ?? false,
            promotionExpiry: null,
            lastPaymentId: _readString(m, 'lastPaymentId').isNotEmpty ? _readString(m, 'lastPaymentId') : null,
            promotedAt: null,
            ownerId: _readString(m, 'ownerId'),
            status: _readString(m, 'status').isNotEmpty ? _readString(m, 'status') : 'active',
            isBlocked: (m['isBlocked'] as bool?) ?? false,
            reportCount: (m['reportCount'] is num) ? (m['reportCount'] as num).toInt() : 0,
            viewsCount: (m['viewsCount'] is num) ? (m['viewsCount'] as num).toInt() : 0,
            isUrgent: (m['isUrgent'] as bool?) ?? false,
          );
          out.add(car);
        } catch (e) {
          debugPrint('CarService: skip invalid listings doc ${d.id}: $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('CarService.loadCars Firestore error: $e');
      return <Car>[]; // No local fallback
    }
  }

  Future<void> saveCars(List<Car> cars) async {
    // No client-side persistence; Firestore is the source of truth.
  }
}
