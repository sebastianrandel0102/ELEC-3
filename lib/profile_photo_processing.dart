import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ProfilePhotoFailure implements Exception {
  const ProfilePhotoFailure(this.message);
  final String message;
}

abstract final class ProfilePhotoLimits {
  static const originalBytes = 20 * 1024 * 1024;
  // Keep binary avatar documents comfortably below Firestore's 1 MiB limit.
  static const uploadBytes = 200 * 1024;
  static const legacyUploadBytes = 5 * 1024 * 1024;
  static const maxPixels = 24000000;
  static const workingEdge = 1536;
  static const avatarEdge = 512;
}

/// A bounded, oriented working image. Original bytes are discarded after this.
class PreparedProfilePhoto {
  const PreparedProfilePhoto(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

Future<PreparedProfilePhoto> prepareProfilePhoto(Uint8List bytes) =>
    compute(_prepare, bytes);

img.Image _decode(Uint8List bytes, {bool working = false, int? expectedEdge}) {
  if (bytes.isEmpty) {
    throw const ProfilePhotoFailure('Please select a valid image.');
  }
  if (bytes.length > ProfilePhotoLimits.originalBytes) {
    throw const ProfilePhotoFailure('Choose a photo smaller than 20 MB.');
  }
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final png =
      bytes.length >= 8 &&
      listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  if (!jpeg && !png) {
    throw const ProfilePhotoFailure('Please choose a JPEG or PNG image.');
  }
  try {
    final img.Decoder decoder = jpeg
        ? img.JpegDecoder(maxPixels: ProfilePhotoLimits.maxPixels)
        : img.PngDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null || info.width < 1 || info.height < 1) {
      throw const ProfilePhotoFailure('This image could not be opened.');
    }
    if (expectedEdge != null &&
        (info.width != expectedEdge || info.height != expectedEdge)) {
      throw const ProfilePhotoFailure(
        'Please preview and crop your photo first.',
      );
    }
    if (info.width > 12000 ||
        info.height > 12000 ||
        info.width * info.height > ProfilePhotoLimits.maxPixels ||
        (png &&
            bytes.length > 24 &&
            bytes[24] > 8 &&
            info.width * info.height > ProfilePhotoLimits.maxPixels ~/ 2)) {
      throw const ProfilePhotoFailure(
        'This photo is too large to process safely. Choose one up to 24 megapixels.',
      );
    }
    if (info.numFrames > 1) {
      throw const ProfilePhotoFailure(
        'Please choose a still JPEG or PNG image.',
      );
    }
    var scale = 1;
    if (jpeg && working) {
      while (scale < 8 &&
          math.max(info.width, info.height) / (scale * 2) >=
              ProfilePhotoLimits.workingEdge) {
        scale *= 2;
      }
    }
    final decoded = jpeg
        ? img.JpegDecoder(
            maxPixels: ProfilePhotoLimits.maxPixels,
            scale: scale,
          ).decode(bytes)
        : decoder.decodeFrame(0);
    if (decoded == null) {
      throw const ProfilePhotoFailure('This image could not be opened.');
    }
    // bakeOrientation also copies already-oriented images; avoid keeping two
    // full decoded originals when no rotation is needed.
    final orientation = decoded.exif.imageIfd.orientation;
    return orientation == null || orientation == 1
        ? decoded
        : img.bakeOrientation(decoded);
  } on ProfilePhotoFailure {
    rethrow;
  } catch (_) {
    throw const ProfilePhotoFailure('This image could not be opened.');
  }
}

PreparedProfilePhoto _prepare(Uint8List bytes) {
  var image = _decode(bytes, working: true);
  final longest = math.max(image.width, image.height);
  if (longest > ProfilePhotoLimits.workingEdge) {
    final ratio = ProfilePhotoLimits.workingEdge / longest;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * ratio).round()),
      height: math.max(1, (image.height * ratio).round()),
      interpolation: img.Interpolation.average,
    );
  }
  // Flatten transparency onto white and strip EXIF (including GPS) metadata.
  final clean = img.Image(width: image.width, height: image.height);
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, image);
  return PreparedProfilePhoto(
    img.encodeJpg(clean, quality: 93),
    clean.width,
    clean.height,
  );
}

/// Coordinates match the circular preview's square viewport. Position is 0..1
/// across the available overflow; zoom reduces the square crop size.
class ProfilePhotoCrop {
  const ProfilePhotoCrop({this.x = .5, this.y = .5, this.zoom = 1});
  final double x, y, zoom;
}

Future<Uint8List> cropProfilePhoto(
  PreparedProfilePhoto photo,
  ProfilePhotoCrop crop,
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
    throw const ProfilePhotoFailure('Unable to crop this photo. Try again.');
  }
  final image = _decode(bytes);
  final side = math.max(
    1,
    (math.min(image.width, image.height) / zoom).round(),
  );
  final square = img.copyCrop(
    image,
    x: ((image.width - side) * x).round(),
    y: ((image.height - side) * y).round(),
    width: side,
    height: side,
  );
  final resized = img.copyResize(
    square,
    width: ProfilePhotoLimits.avatarEdge,
    height: ProfilePhotoLimits.avatarEdge,
    interpolation: img.Interpolation.average,
  );
  for (final quality in [88, 82, 76]) {
    final output = img.encodeJpg(
      resized,
      quality: quality,
      chroma: img.JpegChroma.yuv420,
    );
    if (output.length <= ProfilePhotoLimits.uploadBytes) return output;
  }
  throw const ProfilePhotoFailure(
    'This photo could not be compressed enough. Please choose another image.',
  );
}

/// Defense in depth at the service boundary, even if a caller skips preview.
void validateProfilePhotoUpload(Uint8List bytes) {
  _validateAvatar(bytes, ProfilePhotoLimits.uploadBytes);
}

void validateLegacyProfilePhotoDownload(Uint8List bytes) {
  _validateAvatar(bytes, ProfilePhotoLimits.legacyUploadBytes);
}

void _validateAvatar(Uint8List bytes, int limit) {
  if (bytes.length > limit) {
    throw const ProfilePhotoFailure(
      'This photo is too large. Please crop it again.',
    );
  }
  if (bytes.length < 3 || bytes[0] != 0xff || bytes[1] != 0xd8) {
    throw const ProfilePhotoFailure('Please select a valid JPEG avatar.');
  }
  _decode(bytes, expectedEdge: ProfilePhotoLimits.avatarEdge);
}
