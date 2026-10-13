import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myproject/goal_cover_picker.dart';
import 'package:myproject/goal_cover_cache.dart';
import 'package:myproject/goal_cover_processing.dart';
import 'package:myproject/goal_cover_service.dart';
import 'package:myproject/profile_photo_processing.dart';
import 'package:myproject/shared_savings_models.dart';

import 'profile_photo_test.dart' show PlatformPicker;

const personal = GoalCoverTarget.personal('owner', 'goalA');
const shared = GoalCoverTarget.shared('owner', 'sharedA');
String version(GoalCoverTarget target, int n) =>
    '${target.photoFolder}/${n.toString().padLeft(20, '0')}';
Uint8List picture({int width = 160, int height = 90}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        y < height ~/ 2 ? 230 : 20,
        80,
        y < height ~/ 2 ? 20 : 230,
      );
    }
  }
  return img.encodePng(image);
}

class CoverBackend implements GoalCoverBackend {
  @override
  String? currentUid = 'owner';
  String? path;
  bool uploadFails = false,
      commitFails = false,
      cleanupFails = false,
      missing = false,
      ambiguous = false;
  Object? uploadError;
  void Function()? duringUpload;
  Completer<void>? uploadGate;
  int id = 0;
  final events = <String>[];
  final objects = <String>{}, journals = <String>{};
  final finances = {
    'savedAmount': 123.0,
    'targetAmount': 1000.0,
    'currencyCode': 'PHP',
  };
  @override
  String newPath(GoalCoverTarget target) => version(target, ++id);
  @override
  Future<GoalCoverRecord> read(GoalCoverTarget target) async {
    events.add('read');
    if (missing) throw const GoalCoverFailure('Goal deleted.');
    return GoalCoverRecord(path: path);
  }

  @override
  Future<void> journal(GoalCoverTarget target, String path) async {
    events.add('journal');
    journals.add(path);
  }

  @override
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    events.add('upload');
    progress(.25);
    if (uploadGate != null) await uploadGate!.future;
    duringUpload?.call();
    if (uploadError != null) throw uploadError!;
    if (uploadFails) throw const GoalCoverFailure('Upload failed.');
    objects.add(path);
    progress(1);
  }

  @override
  Future<void> commit(
    GoalCoverTarget target,
    String? expectedPath,
    String? next,
  ) async {
    events.add('commit');
    if (commitFails) throw const GoalCoverFailure('Metadata failed.');
    if (path != expectedPath) throw const GoalCoverFailure('Cover conflict.');
    path = next;
    if (ambiguous) throw TimeoutException('Lost acknowledgement');
  }

  @override
  Future<void> cleanup(GoalCoverTarget target, String path) async {
    events.add('cleanup:$path');
    if (cleanupFails) throw const GoalCoverFailure('Cleanup unavailable.');
    if (this.path != path && target.ownsPath(path)) {
      objects.remove(path);
      journals.remove(path);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List cover;
  setUpAll(() async {
    cover = await cropGoalCover(
      await prepareGoalCover(picture()),
      const GoalCoverCrop(),
    );
  });
  test('missing bucket on a new upload is identified and preserves the existing cover', () async {
    final backend = CoverBackend()
      ..path = version(personal, 0)
      ..uploadError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );
    backend.objects.add(backend.path!);
    await expectLater(
      GoalCoverService(backend).replace(personal, cover),
      throwsA(
        isA<GoalCoverFailure>().having(
          (error) => error.message,
          'message',
          contains('Firebase Storage bucket must be enabled'),
        ),
      ),
    );
    expect(backend.path, version(personal, 0));
    expect(backend.objects, {version(personal, 0)});
    expect(backend.events, isNot(contains('commit')));
  });
  test('Storage-prefixed setup errors are normalized without mislabeling a deleted goal', () {
    expect(
      goalCoverError(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'storage/object-not-found',
        ),
        duringUpload: true,
      ),
      contains('Firebase Storage bucket must be enabled'),
    );
    expect(
      goalCoverError(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'storage/bucket-not-found',
        ),
      ),
      contains('create its Firebase Storage bucket'),
    );
    expect(
      goalCoverError(
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      ),
      contains('goal is no longer available'),
    );
    expect(
      goalCoverError(
        FirebaseException(plugin: 'firebase_storage', code: 'object-not-found'),
      ),
      isNot(contains('must be enabled')),
    );
  });
  test(
    'gallery picker returns actual selection and clears only its own marker',
    () async {
      SharedPreferences.setMockInitialValues({
        'savetrack.pendingProfilePhotoUid': 'owner',
      });
      final file = XFile.fromData(picture(), name: 'selected.png');
      final platform = PlatformPicker()..selection = file;
      expect(
        await GalleryGoalCoverPicker(picker: platform).pick(personal),
        same(file),
      );
      expect(platform.source, ImageSource.gallery);
      expect(platform.metadata, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GalleryGoalCoverPicker.pendingKey), isNull);
      expect(prefs.getString('savetrack.pendingProfilePhotoUid'), 'owner');
    },
  );
  test('gallery cancellation is a normal result without an upload', () async {
    SharedPreferences.setMockInitialValues({});
    expect(
      await GalleryGoalCoverPicker(picker: PlatformPicker()).pick(personal),
      isNull,
    );
  });
  test('Android activity recovery retains goal identity and rejects another account', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final file = XFile.fromData(picture(), name: 'recovered.png');
    final platform = PlatformPicker()
      ..lost = LostDataResponse(files: [file], type: RetrieveType.image);
    for (final uid in ['owner', 'other']) {
      SharedPreferences.setMockInitialValues({
        GalleryGoalCoverPicker.pendingKey: jsonEncode({
          'uid': 'owner',
          'goalId': 'sharedA',
          'shared': true,
        }),
      });
      final recovered = await GalleryGoalCoverPicker(picker: platform)
          .recover(uid);
      if (uid == 'owner') {
        expect(recovered!.target.documentPath, shared.documentPath);
        expect(recovered.file, same(file));
      } else {
        expect(recovered, isNull);
      }
    }
  });
  test('legacy metadata and invalid foreign references use the fallback', () {
    expect(GoalCoverRecord.fromMap({}, personal).path, isNull);
    expect(
      GoalCoverRecord.fromMap({
        'coverStoragePath': version(shared, 1),
      }, personal).path,
      isNull,
    );
    expect(
      GoalCoverRecord.fromMap({'coverStoragePath': 42}, personal).path,
      isNull,
    );
    expect(
      GoalCoverRecord.fromMap({
        'coverStoragePath': version(personal, 1),
      }, personal).path,
      version(personal, 1),
    );
  });
  test('shared model retains financial values and parses its own cover', () {
    final goal = SharedSavingsGoal('sharedA', {
      'ownerId': 'owner',
      'currentAmount': 10,
      'targetAmount': 20,
      'coverStoragePath': version(shared, 1),
    });
    expect(goal.cover.path, version(shared, 1));
    expect(goal.balance, 10);
    expect(goal.progress, .5);
  });
  test('paths separate owners, goals, shared covers and profile photos', () {
    expect(personal.ownsPath(version(personal, 1)), isTrue);
    final legacy = '${personal.folder}/AAAAAAAAAAAAAAAAAAAA.jpg';
    expect(personal.ownsPath(legacy), true);
    expect(personal.ownsStoragePath(legacy), true);
    expect(personal.ownsFirestorePath(legacy), false);
    expect(personal.ownsFirestorePath(version(personal, 1)), true);
    for (final path in [
      version(shared, 1),
      version(const GoalCoverTarget.personal('other', 'goalA'), 1),
      version(const GoalCoverTarget.personal('owner', 'goalB'), 1),
      'users/owner/profile/avatar/00000000000000000001.jpg',
      '${personal.folder}/bad.jpg',
      '${personal.folder}/../../photo.jpg',
    ]) {
      expect(personal.ownsPath(path), isFalse);
    }
  });
  test('JPEG and PNG content decode without relying on extensions', () async {
    final png = await prepareGoalCover(picture());
    expect(png.width, 160);
    final jpeg = await prepareGoalCover(
      img.encodeJpg(img.decodePng(picture())!),
    );
    expect(jpeg.height, 90);
  });
  test('corrupt, unsupported and oversized selections are rejected', () async {
    for (final data in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([0xff, 0xd8, 0xff, 0]),
      Uint8List(ProfilePhotoLimits.originalBytes + 1),
    ]) {
      await expectLater(
        prepareGoalCover(data),
        throwsA(isA<GoalCoverFailure>()),
      );
    }
  });
  test('portrait crop preserves the selected focal region at 16:9', () async {
    final photo = await prepareGoalCover(picture(width: 160, height: 320));
    final top = img.decodeJpg(
      await cropGoalCover(photo, const GoalCoverCrop(y: 0)),
    )!;
    final bottom = img.decodeJpg(
      await cropGoalCover(photo, const GoalCoverCrop(y: 1)),
    )!;
    expect(top.width, 1280);
    expect(top.height, 720);
    expect(top.getPixel(640, 360).r, greaterThan(200));
    expect(bottom.getPixel(640, 360).b, greaterThan(200));
    expect(cover.length, lessThanOrEqualTo(GoalCoverLimits.uploadBytes));
    expect(img.decodeJpg(cover)!.exif.gpsIfd.isEmpty, isTrue);
  });
  test('invalid crop and corrupt working image fail safely', () async {
    final photo = await prepareGoalCover(picture());
    for (final crop in [
      const GoalCoverCrop(zoom: 0),
      const GoalCoverCrop(x: -1),
      GoalCoverCrop(y: double.nan),
    ]) {
      await expectLater(
        cropGoalCover(photo, crop),
        throwsA(isA<GoalCoverFailure>()),
      );
    }
    await expectLater(
      cropGoalCover(
        PreparedProfilePhoto(Uint8List(4), 2, 2),
        const GoalCoverCrop(),
      ),
      throwsA(isA<GoalCoverFailure>()),
    );
  });
  test(
    'upload boundary enforces crop dimensions, file size and JPEG content',
    () async {
      await validateGoalCoverUpload(cover);
      for (final data in [
        picture(),
        img.encodeJpg(img.decodePng(picture())!),
        Uint8List(GoalCoverLimits.uploadBytes + 1),
      ]) {
        await expectLater(
          validateGoalCoverUpload(data),
          throwsA(isA<GoalCoverFailure>()),
        );
      }
    },
  );
  test(
    'upload journals before transfer and commits only after success',
    () async {
      final backend = CoverBackend(), progress = <double>[];
      await GoalCoverService(backend)
          .replace(personal, cover, onProgress: progress.add);
      expect(backend.events.take(4), ['read', 'journal', 'upload', 'commit']);
      expect(backend.path, version(personal, 1));
      expect(progress, [.25, 1]);
      expect(backend.finances, {
        'savedAmount': 123.0,
        'targetAmount': 1000.0,
        'currencyCode': 'PHP',
      });
    },
  );
  test('shared upload uses the shared ID and owner account', () async {
    final backend = CoverBackend();
    await GoalCoverService(backend).replace(shared, cover);
    expect(backend.path, version(shared, 1));
  });
  test(
    'invalid bytes, non-owner and deleted goal never commit an upload',
    () async {
      final backend = CoverBackend(),
          service = GoalCoverService(
            CoverBackend()..currentUid = 'contributor',
          );
      await expectLater(
        service.replace(shared, cover),
        throwsA(isA<GoalCoverFailure>()),
      );
      await expectLater(
        GoalCoverService(backend).replace(personal, picture()),
        throwsA(isA<GoalCoverFailure>()),
      );
      backend.missing = true;
      await expectLater(
        GoalCoverService(backend).replace(personal, cover),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(backend.events, ['read']);
      expect(backend.objects, isEmpty);
    },
  );
  test('replacement commits new image before deleting the old one', () async {
    final backend = CoverBackend()..path = version(personal, 0);
    backend.objects.add(backend.path!);
    await GoalCoverService(backend).replace(personal, cover);
    expect(backend.objects, {version(personal, 1)});
    expect(
      backend.events.indexOf('commit'),
      lessThan(backend.events.indexOf('cleanup:${version(personal, 0)}')),
    );
  });
  for (final failure in ['upload', 'metadata']) {
    test(
      '$failure failure preserves old cover and safely cleans unreferenced upload',
      () async {
        final backend = CoverBackend()
          ..path = version(personal, 0)
          ..uploadFails = failure == 'upload'
          ..commitFails = failure == 'metadata';
        backend.objects.add(backend.path!);
        await expectLater(
          GoalCoverService(backend).replace(personal, cover),
          throwsA(isA<GoalCoverFailure>()),
        );
        expect(backend.path, version(personal, 0));
        expect(backend.objects, {version(personal, 0)});
        expect(backend.journals, isEmpty);
      },
    );
  }
  test('ambiguous commit is resolved against server reference without a duplicate retry', () async {
    final backend = CoverBackend()..ambiguous = true;
    await GoalCoverService(backend).replace(personal, cover);
    expect(backend.path, version(personal, 1));
    expect(backend.objects.length, 1);
  });
  test(
    'cleanup failure retains journal and does not undo confirmed metadata',
    () async {
      final backend = CoverBackend()
        ..path = version(personal, 0)
        ..cleanupFails = true;
      backend.objects.add(backend.path!);
      backend.journals.add(backend.path!);
      await GoalCoverService(backend).replace(personal, cover);
      expect(backend.path, version(personal, 1));
      expect(backend.journals, contains(version(personal, 0)));
    },
  );
  test(
    'concurrent update rejects delayed cover and never deletes the winner',
    () async {
      final backend = CoverBackend()..path = version(personal, 0);
      final winner = version(personal, 5);
      backend.duringUpload = () {
        backend.path = winner;
        backend.objects.add(winner);
      };
      await expectLater(
        GoalCoverService(backend).replace(personal, cover),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(backend.path, winner);
      expect(backend.objects, contains(winner));
      expect(backend.objects, isNot(contains(version(personal, 1))));
    },
  );
  test('retry after failure releases lock and updates same goal', () async {
    final backend = CoverBackend()..uploadFails = true,
        service = GoalCoverService(CoverBackend());
    final retry = GoalCoverService(backend);
    await expectLater(
      retry.replace(personal, cover),
      throwsA(isA<GoalCoverFailure>()),
    );
    expect(service.isBusy(personal), isFalse);
    backend.uploadFails = false;
    await retry.replace(personal, cover);
    expect(backend.path, version(personal, 2));
    expect(backend.objects.length, 1);
  });
  test('duplicate submissions across service instances are blocked', () async {
    final backend = CoverBackend()..uploadGate = Completer<void>();
    final first = GoalCoverService(backend).replace(personal, cover);
    while (!backend.events.contains('upload')) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await expectLater(
      GoalCoverService(backend).replace(personal, cover),
      throwsA(isA<GoalCoverFailure>()),
    );
    backend.uploadGate!.complete();
    await first;
    expect(backend.id, 1);
  });
  test('session change during transfer cannot attach or delete images as another user', () async {
    final backend = CoverBackend()..duringUpload = null;
    backend.duringUpload = () => backend.currentUid = 'other';
    await expectLater(
      GoalCoverService(backend).replace(personal, cover),
      throwsA(isA<GoalCoverFailure>()),
    );
    expect(backend.path, isNull);
    expect(backend.events, isNot(contains('commit')));
    expect(backend.journals.length, 1);
  });
  test(
    'removal clears metadata before cleanup and preserves savings',
    () async {
      final backend = CoverBackend()..path = version(personal, 0);
      backend.objects.add(backend.path!);
      await GoalCoverService(backend).remove(personal);
      expect(backend.path, isNull);
      expect(backend.objects, isEmpty);
      expect(backend.finances['savedAmount'], 123);
    },
  );
  test('failed removal preserves cover', () async {
    final backend = CoverBackend()
      ..path = version(personal, 0)
      ..commitFails = true;
    await expectLater(
      GoalCoverService(backend).remove(personal),
      throwsA(isA<GoalCoverFailure>()),
    );
    expect(backend.path, version(personal, 0));
  });
  test('cache deduplicates reads and versions refresh independently', () async {
    var calls = 0;
    final cache = GoalCoverCache(
      currentUid: () => 'owner',
      download: (_) async {
        calls++;
        return cover;
      },
    );
    await Future.wait([
      cache.load('owner', personal, version(personal, 1)),
      cache.load('owner', personal, version(personal, 1)),
    ]);
    await cache.load('owner', personal, version(personal, 1));
    expect(calls, 1);
    await cache.load('owner', personal, version(personal, 2));
    expect(calls, 2);
    cache.dispose();
  });
  test('cache cannot expose late downloads after switching accounts', () async {
    String? uid = 'owner';
    final gate = Completer<Uint8List?>();
    final cache = GoalCoverCache(
      currentUid: () => uid,
      download: (_) => gate.future,
    );
    final load = cache.load('owner', personal, version(personal, 1));
    uid = 'other';
    cache.clear();
    gate.complete(cover);
    expect(await load, isNull);
    expect(await cache.load('owner', personal, version(personal, 1)), isNull);
    cache.dispose();
  });
  test('revoked shared membership discards in-flight downloads', () async {
    final gate = Completer<Uint8List?>(),
        cache = GoalCoverCache(
          currentUid: () => 'owner',
          download: (_) async => null,
        );
    final revoked = GoalCoverCache(
      currentUid: () => 'owner',
      download: (_) => gate.future,
    );
    final load = revoked.load('owner', shared, version(shared, 1));
    revoked.retainShared('owner', {});
    gate.complete(cover);
    expect(await load, isNull);
    expect(await cache.load('owner', personal, version(personal, 1)), isNull);
    cache.dispose();
    revoked.dispose();
  });
  test('cache is bounded and failed downloads return fallback data', () async {
    var calls = 0;
    final cache = GoalCoverCache(
      currentUid: () => 'owner',
      download: (_) async {
        calls++;
        return cover;
      },
    );
    for (var n = 0; n < 25; n++) {
      await cache.load('owner', personal, version(personal, n));
    }
    await cache.load('owner', personal, version(personal, 0));
    expect(calls, 26);
    cache.dispose();
    final failed = GoalCoverCache(
      currentUid: () => 'owner',
      download: (_) async => throw StateError('offline'),
    );
    expect(await failed.load('owner', personal, version(personal, 1)), isNull);
    failed.dispose();
  });
}
