import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goal_cover_processing.dart';
import 'goal_cover_service.dart';

class RecoveredGoalCover {
  const RecoveredGoalCover(this.target, this.file);
  final GoalCoverTarget target;
  final XFile file;
}

class GalleryGoalCoverPicker {
  GalleryGoalCoverPicker({ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  final ImagePicker picker;
  static const pendingKey = 'savetrack.pendingGoalCover';
  Future<XFile?> pick(GoalCoverTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      pendingKey,
      jsonEncode({
        'uid': target.ownerUid,
        'goalId': target.goalId,
        'shared': target.shared,
      }),
    )) {
      throw const GoalCoverFailure(
        'Unable to open the gallery. Please try again.',
      );
    }
    try {
      return await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } finally {
      await prefs.remove(pendingKey);
    }
  }

  Future<RecoveredGoalCover?> recover(String uid) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(pendingKey);
    if (pending == null) {
      return null; // Do not consume another workflow's lost image.
    }
    try {
      final data = jsonDecode(pending) as Map<String, dynamic>;
      final result = await picker.retrieveLostData();
      if (data['uid'] != uid || result.isEmpty) return null;
      if (result.exception != null) {
        throw const GoalCoverFailure(
          'Gallery selection was interrupted. Please choose the cover again.',
        );
      }
      final file = result.files?.firstOrNull;
      if (file == null) return null;
      final target = data['shared'] == true
          ? GoalCoverTarget.shared(uid, data['goalId'] as String)
          : GoalCoverTarget.personal(uid, data['goalId'] as String);
      return RecoveredGoalCover(target, file);
    } finally {
      await prefs.remove(pendingKey);
    }
  }
}
