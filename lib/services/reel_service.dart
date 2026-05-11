import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autoreel/providers/reel_provider.dart';

class ReelService {
  static const _storageKey = 'reels_json_v1';
  static const _likesKey = 'reel_likes_local_v1';
  static const _commentsKey = 'reel_comments_json_v1';

  // Temporary: force a known-good test video for all reels
  static const String _testVideoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  Future<List<ReelItem>> loadReels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return <ReelItem>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ReelItem>[];
      final List<ReelItem> reels = [];
      for (final item in decoded) {
        try {
          ReelItem? parsed;
          if (item is Map<String, dynamic>) {
            parsed = ReelItem.fromJson(item);
          } else if (item is Map) {
            parsed = ReelItem.fromJson(item.cast<String, dynamic>());
          }
          if (parsed == null) continue;
          // Remove invalid or empty video_url entries
          if (parsed.videoUrl.trim().isEmpty) {
            debugPrint('Dropping reel with empty video_url: ${parsed.id}');
            continue;
          }
          // Keep the actual uploaded URL; no test override
          reels.add(parsed);
        } catch (e) {
          debugPrint('Skipping invalid reel entry: $e');
        }
      }
      // Sanitize storage with only valid entries
      await saveReels(reels);
      return reels;
    } catch (e) {
      debugPrint('ReelService.loadReels error: $e');
      return <ReelItem>[];
    }
  }

  Future<void> saveReels(List<ReelItem> reels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Enforce sanitization on save as well: keep only items with non-empty URLs
      final sanitized = reels.where((r) => r.videoUrl.trim().isNotEmpty).toList(growable: false);
      final jsonList = sanitized.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('ReelService.saveReels error: $e');
    }
  }

  // Likes persistence (device-local)
  Future<Set<String>> loadLikedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_likesKey);
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return <String>{};
    } catch (e) {
      debugPrint('ReelService.loadLikedIds error: $e');
      return <String>{};
    }
  }

  Future<void> saveLikedIds(Set<String> liked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_likesKey, jsonEncode(liked.toList()));
    } catch (e) {
      debugPrint('ReelService.saveLikedIds error: $e');
    }
  }

  // Comments persistence (device-local)
  Future<Map<String, List<ReelComment>>> loadComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_commentsKey);
      if (raw == null || raw.isEmpty) return <String, List<ReelComment>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<ReelComment>>{};
      final Map<String, List<ReelComment>> out = {};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        final list = <ReelComment>[];
        if (val is List) {
          for (final item in val) {
            try {
              if (item is Map<String, dynamic>) {
                list.add(ReelComment.fromJson(item));
              } else if (item is Map) {
                list.add(ReelComment.fromJson(item.cast<String, dynamic>()));
              }
            } catch (e) {
              debugPrint('Skipping invalid comment: $e');
            }
          }
        }
        out[key] = list;
      }
      return out;
    } catch (e) {
      debugPrint('ReelService.loadComments error: $e');
      return <String, List<ReelComment>>{};
    }
  }

  Future<void> saveComments(Map<String, List<ReelComment>> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, List<Map<String, dynamic>>>{};
      comments.forEach((key, value) {
        map[key] = value.map((c) => c.toJson()).toList();
      });
      await prefs.setString(_commentsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('ReelService.saveComments error: $e');
    }
  }
}