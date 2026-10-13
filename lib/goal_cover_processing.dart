import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'profile_photo_processing.dart';

class GoalCoverFailure implements Exception {
  const GoalCoverFailure(this.message);
  final String message;
}

abstract final class GoalCoverLimits {
  static const width = 1280;
  static const height = 720;
  static const aspectRatio = 16 / 9;
  static const uploadBytes = 1024 * 1024;
  static const firestoreWidth = 960;
  static const firestoreHeight = 540;
  static const firestoreBytes = 200 * 1024;
}

/// Reuse the bounded JPEG/PNG decoder, orientation correction and EXIF removal.
/// This does not use the avatar's square crop or its upload/storage workflow.
Future<PreparedProfilePhoto> prepareGoalCover(Uint8List bytes) async {
  try {
    return await prepareProfilePhoto(bytes);
  } on ProfilePhotoFailure catch (error) {
    throw GoalCoverFailure(error.message);
  }
}

class GoalCoverCrop {
  const GoalCoverCrop({this.x = .5, this.y = .5, this.zoom = 1});
  final double x, y, zoom;
}

/// Overflow fractions match Alignment(x*2-1,y*2-1) in the landscape preview.
Future<Uint8List> cropGoalCover(
  PreparedProfilePhoto photo,
  GoalCoverCrop crop,
) => compute(_crop, (photo.bytes, crop.x, crop.y, crop.zoom));

Uint8List _crop((Uint8List, double, double, double) input) {
  final (bytes, x, y, zoom) = input;
  if (!x.isFinite ||
      !y.isFinite ||
      !zoom.isFinite ||
      x < 0 ||
      x > 1 ||
      y < 0 ||
      y > 1 ||
      zoom < 1 ||
      zoom > 3) {
    throw const GoalCoverFailure('Please adjust the crop and try again.');
  }
  try {
    if (bytes.length > ProfilePhotoLimits.originalBytes) {
      throw const GoalCoverFailure('Choose a photo smaller than 20 MB.');
    }
    final decoder = img.JpegDecoder(maxPixels: ProfilePhotoLimits.maxPixels);
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > ProfilePhotoLimits.workingEdge ||
        info.height > ProfilePhotoLimits.workingEdge ||
        info.numFrames > 1) {
      throw const GoalCoverFailure(
        'Please choose and preview your photo again.',
      );
    }
    final image = decoder.decodeFrame(0);
    if (image == null) {
      throw const GoalCoverFailure('This photo could not be cropped.');
    }
    final baseWidth = math.min(
      image.width.toDouble(),
      image.height * GoalCoverLimits.aspectRatio,
    );
    final width = math.max(1, (baseWidth / zoom).round());
    final height = math.max(
      1,
      (baseWidth / GoalCoverLimits.aspectRatio / zoom).round(),
    );
    final cropped = img.copyCrop(
      image,
      x: ((image.width - width) * x).round(),
      y: ((image.height - height) * y).round(),
      width: width,
      height: height,
    );
    final resized = img.copyResize(
      cropped,
      width: GoalCoverLimits.width,
      height: GoalCoverLimits.height,
      interpolation: img.Interpolation.average,
    );
    final clean = img.Image(
      width: GoalCoverLimits.width,
      height: GoalCoverLimits.height,
    );
    img.compositeImage(clean, resized);
    for (final quality in [88, 80, 72]) {
      final output = img.encodeJpg(
        clean,
        quality: quality,
        chroma: img.JpegChroma.yuv420,
      );
      if (output.length <= GoalCoverLimits.uploadBytes) return output;
    }
    throw const GoalCoverFailure(
      'Choose a simpler image so the cover can be saved.',
    );
  } on GoalCoverFailure {
    rethrow;
  } catch (_) {
    throw const GoalCoverFailure(
      'This photo could not be cropped. Choose another photo.',
    );
  }
}

Future<void> validateGoalCoverUpload(Uint8List bytes) =>
    compute(_validate, bytes);

void _validate(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > GoalCoverLimits.uploadBytes) {
    throw const GoalCoverFailure(
      'The cover must be smaller than 1 MB. Please crop it again.',
    );
  }
  if (bytes.length < 3 ||
      bytes[0] != 0xff ||
      bytes[1] != 0xd8 ||
      bytes[2] != 0xff) {
    throw const GoalCoverFailure(
      'Please choose a JPEG or PNG photo and preview it first.',
    );
  }
  try {
    final decoder = img.JpegDecoder(
      maxPixels: GoalCoverLimits.width * GoalCoverLimits.height,
    );
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width != GoalCoverLimits.width ||
        info.height != GoalCoverLimits.height ||
        info.numFrames != 1 ||
        decoder.decodeFrame(0) == null) {
      throw const GoalCoverFailure(
        'Please preview the landscape crop before saving.',
      );
    }
  } on GoalCoverFailure {
    rethrow;
  } catch (_) {
    throw const GoalCoverFailure(
      'This image could not be opened. Choose another photo.',
    );
  }
}

/// Keep the approved crop while fitting a small, separate Firestore document.
Future<Uint8List> compactGoalCover(Uint8List bytes) => compute(_compact, bytes);

Uint8List _compact(Uint8List bytes) {
  _validate(bytes);
  final source = img.decodeJpg(bytes)!;
  final resized = img.copyResize(
    source,
    width: GoalCoverLimits.firestoreWidth,
    height: GoalCoverLimits.firestoreHeight,
    interpolation: img.Interpolation.average,
  );
  final clean = img.Image(
    width: GoalCoverLimits.firestoreWidth,
    height: GoalCoverLimits.firestoreHeight,
  );
  img.compositeImage(clean, resized);
  for (final quality in [86, 78, 70, 62, 54, 46, 38, 30]) {
    final output = img.encodeJpg(
      clean,
      quality: quality,
      chroma: img.JpegChroma.yuv420,
    );
    if (output.length <= GoalCoverLimits.firestoreBytes) return output;
  }
  throw const GoalCoverFailure(
    'Choose a simpler image so the cover can be saved.',
  );
}

Future<void> validateCompactGoalCover(Uint8List bytes) =>
    compute(_validateCompact, bytes);

void _validateCompact(Uint8List bytes) {
  if (bytes.length < 5 ||
      bytes.length > GoalCoverLimits.firestoreBytes ||
      bytes[0] != 0xff ||
      bytes[1] != 0xd8 ||
      bytes[2] != 0xff ||
      bytes[bytes.length - 2] != 0xff ||
      bytes.last != 0xd9) {
    throw const GoalCoverFailure('This goal photo could not be opened.');
  }
  try {
    final decoder = img.JpegDecoder(
      maxPixels:
          GoalCoverLimits.firestoreWidth * GoalCoverLimits.firestoreHeight,
    );
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width != GoalCoverLimits.firestoreWidth ||
        info.height != GoalCoverLimits.firestoreHeight ||
        info.numFrames != 1 ||
        decoder.decodeFrame(0) == null) {
      throw const GoalCoverFailure('This goal photo could not be opened.');
    }
  } on GoalCoverFailure {
    rethrow;
  } catch (_) {
    throw const GoalCoverFailure('This goal photo could not be opened.');
  }
}
