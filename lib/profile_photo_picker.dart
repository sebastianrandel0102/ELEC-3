import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_photo_processing.dart';

abstract class ProfilePhotoPicker {
  Future<XFile?> pick(String uid);
  Future<XFile?> recover(String uid);
}

class GalleryProfilePhotoPicker implements ProfilePhotoPicker {
  GalleryProfilePhotoPicker({ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  final ImagePicker picker;
  static const _pendingUser = 'savetrack.pendingProfilePhotoUid';

  @override
  Future<XFile?> pick(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_pendingUser, uid)) {
      throw const ProfilePhotoFailure(
        'Unable to open the gallery. Please try again.',
      );
    }
    try {
      // Bytes are read and validated by the processor on every platform.
      // No camera or broad storage permissions; no pre-validation conversion.
      return await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } finally {
      await preferences.remove(_pendingUser);
    }
  }

  @override
  Future<XFile?> recover(String uid) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final preferences = await SharedPreferences.getInstance();
    final owner = preferences.getString(_pendingUser);
    if (owner == null) {
      return null; // Leave goal-cover recovery to its workflow.
    }
    try {
      final result = await picker.retrieveLostData();
      if (owner != uid || result.isEmpty) return null;
      if (result.exception != null) {
        throw const ProfilePhotoFailure(
          'Gallery selection was interrupted. Please choose your photo again.',
        );
      }
      return result.files?.firstOrNull;
    } finally {
      await preferences.remove(_pendingUser);
    }
  }
}
