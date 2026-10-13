import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:myproject/main.dart';
import 'package:myproject/profile_photo_picker.dart';
import 'package:myproject/profile_photo_processing.dart';
import 'package:myproject/profile_photo_service.dart';
import 'package:myproject/profile_photo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const uid = 'owner';
const oldPath = 'users/owner/profile/avatar/AAAAAAAAAAAAAAAAAAAA.jpg';
const newPath = 'users/owner/profile/avatar/BBBBBBBBBBBBBBBBBBBB.jpg';
const foreignPath = 'users/other/profile/avatar/CCCCCCCCCCCCCCCCCCCC.jpg';

Uint8List fixture({int width = 640, int height = 480, bool png = true}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(
      pixel.x < width / 2 ? 220 : 30,
      pixel.y < height / 2 ? 140 : 70,
      pixel.x < width / 2 ? 30 : 210,
    );
  }
  return png ? img.encodePng(image) : img.encodeJpg(image, quality: 90);
}

class PhotoBackend extends ProfilePhotoBackend {
  @override
  String? currentUid = uid;
  final profile = <String, dynamic>{
    'displayName': 'Jamie Santos',
    'email': 'jamie@example.com',
    'currency': 'PHP',
    'preferredCurrencyCode': 'USD',
    'createdAt': 'existing',
    'notificationsEnabled': true,
  };
  final events = <String>[];
  final objects = <String, Uint8List>{};
  final changed = ValueNotifier<String?>(null);
  Object? uploadError, commitError, deleteError, readError;
  bool commitThenError = false;
  Completer<void>? uploadGate;
  List<String> stale = [];
  int loads = 0;
  @override
  String newPath(String uid) => newPathValue;
  String newPathValue = 'users/owner/profile/avatar/BBBBBBBBBBBBBBBBBBBB.jpg';
  @override
  Future<void> upload(
    String path,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    events.add('upload:$path');
    progress(.5);
    if (uploadGate != null) await uploadGate!.future;
    if (uploadError != null) throw uploadError!;
    objects[path] = bytes;
    progress(1);
  }

  @override
  Future<ProfilePhotoRecord> read(String uid) async {
    if (readError != null) throw readError!;
    return ProfilePhotoRecord.fromMap(profile);
  }

  @override
  Future<void> commit(String uid, String? path) async {
    events.add('commit:$uid:$path');
    if (commitError != null && !commitThenError) throw commitError!;
    final previous = profile['avatarStoragePath'];
    final queue = ProfilePhotoRecord.fromMap(profile).cleanup.toSet();
    if (previous != path && previous is String) queue.add(previous);
    if (path == null) {
      profile.remove('avatarStoragePath');
    } else {
      profile['avatarStoragePath'] = path;
    }
    profile['avatarCleanupPaths'] = queue.toList();
    changed.value = path;
    if (commitError != null) throw commitError!;
  }

  @override
  Future<void> delete(String path) async {
    events.add('delete:$path');
    if (deleteError != null) throw deleteError!;
    objects.remove(path);
  }

  @override
  Future<void> acknowledgeCleanup(String uid, String path) async {
    final queue = ProfilePhotoRecord.fromMap(profile).cleanup.toList()
      ..remove(path);
    profile['avatarCleanupPaths'] = queue;
  }

  @override
  Future<List<String>> stalePaths(String uid) async => stale;
  @override
  Future<Uint8List?> load(String path) async {
    loads++;
    return objects[path];
  }
}

class PhotoPicker implements ProfilePhotoPicker {
  XFile? selection, recovered;
  int calls = 0;
  @override
  Future<XFile?> pick(String uid) async {
    calls++;
    return selection;
  }

  @override
  Future<XFile?> recover(String uid) async => recovered;
}

class PlatformPicker extends ImagePicker {
  ImageSource? source;
  bool? metadata;
  XFile? selection;
  LostDataResponse lost = LostDataResponse.empty();
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    metadata = requestFullMetadata;
    return selection;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => lost;
}

Future<void> pumpEditor(
  WidgetTester tester,
  PhotoBackend backend,
  PhotoPicker picker, {
  GlobalKey? capture,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = ProfilePhotoService(backend);
  backend.changed.value = backend.profile['avatarStoragePath'] as String?;
  await tester.pumpWidget(
    MaterialApp(
      theme: const bool.fromEnvironment('SAVE_UI_PREVIEWS')
          ? SaveTrackDesign.theme.copyWith(
              textTheme: SaveTrackDesign.theme.textTheme.apply(
                fontFamily: 'Roboto',
              ),
            )
          : SaveTrackDesign.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: RepaintBoundary(
        child: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: backend.changed,
            builder: (_, path, child) => ProfileContent(
              name: 'Jamie Santos',
              email: 'jamie@example.com',
              onPassword: () {},
              onSignOut: () {},
              avatar: ProfilePhotoEditor(
                uid: uid,
                name: 'Jamie Santos',
                path: path ?? backend.profile['avatarStoragePath'] as String?,
                service: service,
                picker: picker,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pumpAndSettle();
}

Future<void> openGallery(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('change-profile-picture')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from Gallery'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> finishAsync(WidgetTester tester, Finder target) async {
  // compute() executes real isolates; allow completion outside fake widget time.
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pumpAndSettle();
  expect(target, findsOneWidget);
}

Future<void> screenshot(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('SAVE_UI_PREVIEWS')) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/profile-photo-previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List avatar;
  setUpAll(() async {
    if (const bool.fromEnvironment('SAVE_UI_PREVIEWS')) {
      final config = jsonDecode(
        await File('.dart_tool/package_config.json').readAsString(),
      ) as Map<String, dynamic>;
      final flutter = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((package) => package['name'] == 'flutter');
      final sdk = Uri.parse('${flutter['rootUri']}/').resolve('../../');
      for (final entry in {
        'Roboto': 'bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        'MaterialIcons':
            'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      }.entries) {
        final file = File.fromUri(sdk.resolve(entry.value));
        final loader = FontLoader(entry.key)
          ..addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    avatar = await cropProfilePhoto(
      await prepareProfilePhoto(fixture()),
      const ProfilePhotoCrop(),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('validation and optimization', () {
    test(
      'compresses a noisy 512-pixel avatar under the Firestore binary limit',
      () async {
        final random = math.Random(8);
        final image = img.Image(width: 512, height: 512);
        for (final pixel in image) {
          pixel.setRgb(
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
          );
        }
        final photo = await prepareProfilePhoto(img.encodePng(image));
        final bytes = await cropProfilePhoto(photo, const ProfilePhotoCrop());
        expect(bytes.length, lessThanOrEqualTo(200 * 1024));
        expect(img.decodeJpg(bytes)!.width, 512);
        validateProfilePhotoUpload(bytes);
      },
    );
    test(
      'recognizes owned Firestore photo references and denies path traversal',
      () {
        expect(
          ownsAvatarPath(uid, 'users/owner/profilePhotos/AAAAAAAAAAAAAAAAAAAA'),
          true,
        );
        expect(
          ownsAvatarPath(uid, 'users/other/profilePhotos/AAAAAAAAAAAAAAAAAAAA'),
          false,
        );
        expect(
          ownsAvatarPath(
            uid,
            'users/owner/profilePhotos/../AAAAAAAAAAAAAAAAAAAA',
          ),
          false,
        );
      },
    );
    test(
      'decodes real PNG/JPEG bytes regardless of a filename and bounds output',
      () async {
        for (final bytes in [fixture(), fixture(png: false)]) {
          final photo = await prepareProfilePhoto(bytes);
          final output = await cropProfilePhoto(
            photo,
            const ProfilePhotoCrop(),
          );
          final decoded = img.decodeJpg(output)!;
          expect((decoded.width, decoded.height), (512, 512));
          expect(output.length, lessThan(ProfilePhotoLimits.uploadBytes));
          validateProfilePhotoUpload(output);
        }
      },
    );
    test('resizes a large image before preview', () async {
      final photo = await prepareProfilePhoto(
        fixture(width: 2000, height: 1000),
      );
      expect((photo.width, photo.height), (1536, 768));
    });
    test('rejects empty, executable, GIF and damaged image data', () async {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([77, 90, 0, 0]),
        Uint8List.fromList('GIF89a'.codeUnits),
        Uint8List.fromList([255, 216, 255]),
      ]) {
        await expectLater(
          prepareProfilePhoto(bytes),
          throwsA(isA<ProfilePhotoFailure>()),
        );
      }
    });
    test('enforces original and processed byte limits', () async {
      await expectLater(
        prepareProfilePhoto(Uint8List(ProfilePhotoLimits.originalBytes + 1)),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(
        () => validateProfilePhotoUpload(
          Uint8List(ProfilePhotoLimits.uploadBytes + 1),
        ),
        throwsA(isA<ProfilePhotoFailure>()),
      );
    });
    test(
      'rejects pathological image dimensions before pixel decoding',
      () async {
        final bytes = fixture();
        ByteData.sublistView(bytes).setUint32(16, 50000);
        await expectLater(
          prepareProfilePhoto(bytes),
          throwsA(isA<ProfilePhotoFailure>()),
        );
      },
    );
    test('zoom and position change the actual saved crop', () async {
      final photo = await prepareProfilePhoto(fixture());
      final left = img.decodeJpg(
        await cropProfilePhoto(
          photo,
          const ProfilePhotoCrop(x: 0, y: 0, zoom: 2),
        ),
      )!;
      final right = img.decodeJpg(
        await cropProfilePhoto(
          photo,
          const ProfilePhotoCrop(x: 1, y: 1, zoom: 2),
        ),
      )!;
      expect(left.getPixel(256, 256).r, greaterThan(180));
      expect(right.getPixel(256, 256).b, greaterThan(180));
    });
    test('respects EXIF orientation and strips original metadata', () async {
      final image = img.Image(width: 80, height: 40);
      image.exif.imageIfd.orientation = 6;
      final photo = await prepareProfilePhoto(img.encodeJpg(image));
      expect((photo.width, photo.height), (40, 80));
      expect(img.decodeJpg(photo.bytes)!.exif.imageIfd.orientation, isNull);
    });
    test('service validation rejects non-JPEG and unprocessed photos', () {
      expect(
        () => validateProfilePhotoUpload(fixture()),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(
        () => validateProfilePhotoUpload(fixture(png: false)),
        throwsA(isA<ProfilePhotoFailure>()),
      );
    });
  });

  group('secure upload workflow', () {
    test('missing Android Storage bucket gives actionable feedback without changing the profile', () async {
      final backend = PhotoBackend()
        ..profile['avatarStoragePath'] = oldPath
        ..uploadError = FirebaseException(
          plugin: 'firebase_storage',
          code: 'object-not-found',
        );
      await expectLater(
        ProfilePhotoService(backend).save(uid, avatar, onProgress: (_) {}),
        throwsA(
          isA<ProfilePhotoFailure>().having(
            (error) => error.message,
            'message',
            'Photo storage is not available yet. Please contact support.',
          ),
        ),
      );
      expect(backend.profile['avatarStoragePath'], oldPath);
      expect(
        backend.events.where((event) => event.startsWith('commit:')),
        isEmpty,
      );
      expect(backend.events, isNot(contains('delete:$oldPath')));
    });
    test('Storage-prefixed codes are recognized and a missing profile is not misreported as missing storage', () {
      expect(
        profilePhotoErrorMessage(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'storage/object-not-found',
          ),
          duringUpload: true,
        ),
        contains('Photo storage'),
      );
      expect(
        profilePhotoErrorMessage(
          FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        ),
        isNot(contains('Photo storage')),
      );
      expect(
        profilePhotoErrorMessage(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
          ),
        ),
        isNot(contains('Photo storage')),
      );
    });
    test('uploads before metadata, deletes old only after commit and preserves other profile fields', () async {
      final backend = PhotoBackend()..profile['avatarStoragePath'] = oldPath;
      final previous = Map<String, dynamic>.from(backend.profile)
        ..remove('avatarStoragePath');
      final service = ProfilePhotoService(backend);
      await service.save(uid, avatar, onProgress: (_) {});
      await service.maintain(uid);
      expect(backend.profile['avatarStoragePath'], newPath);
      expect(backend.events, [
        'upload:$newPath',
        'commit:$uid:$newPath',
        'delete:$oldPath',
      ]);
      for (final entry in previous.entries) {
        expect(backend.profile[entry.key], entry.value);
      }
      expect(backend.profile['avatarCleanupPaths'], isEmpty);
    });
    test('rejects unauthenticated and different-user operations', () async {
      for (final session in [null, 'other']) {
        final backend = PhotoBackend()..currentUid = session;
        final service = ProfilePhotoService(backend);
        await expectLater(
          service.save(uid, avatar, onProgress: (_) {}),
          throwsA(isA<ProfilePhotoFailure>()),
        );
        await expectLater(
          service.remove(uid),
          throwsA(isA<ProfilePhotoFailure>()),
        );
        expect(backend.events, isEmpty);
      }
    });
    test('rejects foreign storage destinations and references', () async {
      final backend = PhotoBackend()..newPathValue = foreignPath;
      final service = ProfilePhotoService(backend);
      await expectLater(
        service.save(uid, avatar, onProgress: (_) {}),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(await service.load(uid, foreignPath), isNull);
      expect(backend.events, isEmpty);
    });
    test('failed upload cannot update metadata or delete old photo', () async {
      final backend = PhotoBackend()
        ..profile['avatarStoragePath'] = oldPath
        ..uploadError = StateError('network');
      await expectLater(
        ProfilePhotoService(backend).save(uid, avatar, onProgress: (_) {}),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(backend.profile['avatarStoragePath'], oldPath);
      expect(backend.events.where((e) => e.startsWith('commit:')), isEmpty);
      expect(backend.events, isNot(contains('delete:$oldPath')));
    });
    test(
      'failed metadata update rolls back new upload and keeps old reference',
      () async {
        final backend = PhotoBackend()
          ..profile['avatarStoragePath'] = oldPath
          ..commitError = StateError('metadata');
        await expectLater(
          ProfilePhotoService(backend).save(uid, avatar, onProgress: (_) {}),
          throwsA(isA<ProfilePhotoFailure>()),
        );
        expect(backend.objects, isEmpty);
        expect(backend.profile['avatarStoragePath'], oldPath);
        expect(backend.events.last, 'delete:$newPath');
      },
    );
    test(
      'lost commit response verifies server state and retains committed image',
      () async {
        final backend = PhotoBackend()
          ..commitError = TimeoutException('lost response')
          ..commitThenError = true;
        final service = ProfilePhotoService(backend);
        await service.save(uid, avatar, onProgress: (_) {});
        await service.maintain(uid);
        expect(backend.profile['avatarStoragePath'], newPath);
        expect(backend.objects[newPath], isNotNull);
        expect(backend.events, isNot(contains('delete:$newPath')));
      },
    );
    test(
      'uncertain commit and unreadable server do not destroy uploaded image',
      () async {
        final backend = PhotoBackend()
          ..commitError = TimeoutException('lost response')
          ..readError = StateError('offline');
        await expectLater(
          ProfilePhotoService(backend).save(uid, avatar, onProgress: (_) {}),
          throwsA(isA<ProfilePhotoFailure>()),
        );
        expect(backend.objects[newPath], isNotNull);
        expect(backend.events, isNot(contains('delete:$newPath')));
      },
    );
    test('duplicate submissions cannot trigger two uploads', () async {
      final backend = PhotoBackend()..uploadGate = Completer<void>();
      final service = ProfilePhotoService(backend);
      final first = service.save(uid, avatar, onProgress: (_) {});
      await expectLater(
        service.save(uid, avatar, onProgress: (_) {}),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      backend.uploadGate!.complete();
      await first;
      await service.maintain(uid);
      expect(
        backend.events.where((e) => e.startsWith('upload:')),
        hasLength(1),
      );
    });
    test('session change during upload cannot write another profile', () async {
      final backend = PhotoBackend()..uploadGate = Completer<void>();
      final service = ProfilePhotoService(backend);
      final saving = service.save(uid, avatar, onProgress: (_) {});
      while (backend.events.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      backend.currentUid = 'other';
      backend.uploadGate!.complete();
      await expectLater(saving, throwsA(isA<ProfilePhotoFailure>()));
      expect(backend.events.where((e) => e.startsWith('commit:')), isEmpty);
    });
    test('removes reference before deletion and never deletes active or foreign paths', () async {
      final backend = PhotoBackend()
        ..profile['avatarStoragePath'] = oldPath
        ..profile['avatarCleanupPaths'] = [foreignPath];
      final service = ProfilePhotoService(backend);
      await service.remove(uid);
      await service.maintain(uid);
      expect(backend.profile.containsKey('avatarStoragePath'), isFalse);
      expect(backend.events, ['commit:$uid:null', 'delete:$oldPath']);
      backend.profile['avatarStoragePath'] = newPath;
      backend.stale = [newPath, foreignPath];
      await service.maintain(uid);
      expect(backend.events, isNot(contains('delete:$newPath')));
      expect(backend.events, isNot(contains('delete:$foreignPath')));
    });
    test(
      'cleanup failure preserves committed picture and retries later',
      () async {
        final backend = PhotoBackend()
          ..profile['avatarStoragePath'] = oldPath
          ..deleteError = StateError('offline');
        final service = ProfilePhotoService(backend);
        await service.save(uid, avatar, onProgress: (_) {});
        await service.maintain(uid);
        expect(backend.profile['avatarStoragePath'], newPath);
        expect(backend.profile['avatarCleanupPaths'], contains(oldPath));
        backend.deleteError = null;
        await service.maintain(uid);
        expect(backend.profile['avatarCleanupPaths'], isEmpty);
      },
    );
    test(
      'failed upload never reports success or deletes an already active object',
      () async {
        final backend = PhotoBackend()
          ..profile['avatarStoragePath'] = newPath
          ..uploadError = StateError('object already exists');
        await expectLater(
          ProfilePhotoService(backend).save(uid, avatar, onProgress: (_) {}),
          throwsA(isA<ProfilePhotoFailure>()),
        );
        expect(backend.events, isNot(contains('delete:$newPath')));
      },
    );
    test(
      'private downloads are validated and reused from a bounded session cache',
      () async {
        final backend = PhotoBackend()..objects[newPath] = avatar;
        final service = ProfilePhotoService(backend);
        expect(await service.load(uid, newPath), avatar);
        expect(await service.load(uid, newPath), avatar);
        expect(backend.loads, 1);
        backend.objects[oldPath] = Uint8List.fromList([77, 90]);
        await expectLater(
          service.load(uid, oldPath),
          throwsA(isA<ProfilePhotoFailure>()),
        );
      },
    );
    test('removal failure preserves old profile reference', () async {
      final backend = PhotoBackend()
        ..profile['avatarStoragePath'] = oldPath
        ..commitError = StateError('offline');
      await expectLater(
        ProfilePhotoService(backend).remove(uid),
        throwsA(isA<ProfilePhotoFailure>()),
      );
      expect(backend.profile['avatarStoragePath'], oldPath);
      expect(backend.events, isNot(contains('delete:$oldPath')));
    });
    test(
      'reads persisted metadata through a fresh service for a restored session',
      () async {
        final backend = PhotoBackend();
        final service = ProfilePhotoService(backend);
        await service.save(uid, avatar, onProgress: (_) {});
        await service.maintain(uid);
        final restored = ProfilePhotoService(backend);
        expect(
          await restored.load(uid, (await backend.read(uid)).path!),
          avatar,
        );
      },
    );
  });

  test('picker requests gallery without full metadata and ordinary cancellation clears marker', () async {
    final platform = PlatformPicker();
    expect(await GalleryProfilePhotoPicker(picker: platform).pick(uid), isNull);
    expect(platform.source, ImageSource.gallery);
    expect(platform.metadata, false);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'savetrack.pendingProfilePhotoUid',
      ),
      isNull,
    );
  });
  test('Android recovers only the selecting account and never uploads automatically', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final file = XFile.fromData(fixture(), name: 'selected.png');
    final platform = PlatformPicker()
      ..lost = LostDataResponse(files: [file], type: RetrieveType.image);
    SharedPreferences.setMockInitialValues({
      'savetrack.pendingProfilePhotoUid': uid,
    });
    expect(
      await GalleryProfilePhotoPicker(picker: platform).recover(uid),
      file,
    );
    SharedPreferences.setMockInitialValues({
      'savetrack.pendingProfilePhotoUid': 'other',
    });
    expect(
      await GalleryProfilePhotoPicker(picker: platform).recover(uid),
      isNull,
    );
  });

  test('initials handle names and empty values', () {
    expect(profileInitials(' Alex Rivera '), 'AR');
    expect(profileInitials('Jamie'), 'J');
    expect(profileInitials('First Middle Last'), 'FL');
    expect(profileInitials(''), '');
  });
  testWidgets(
    'avatar and edit icon open working gallery action; cancel is silent',
    (tester) async {
      final backend = PhotoBackend();
      final picker = PhotoPicker();
      await pumpEditor(tester, backend, picker);
      await openGallery(tester);
      expect(picker.calls, 1);
      expect(backend.events, isEmpty);
      expect(find.text('Uploading Profile Picture'), findsNothing);
      await tester.tap(find.byTooltip('Change profile picture'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Picture'), findsOneWidget);
      expect(find.text('Remove Profile Picture'), findsNothing);
    },
  );
  testWidgets(
    'actual selection previews without uploading and cancel preserves current photo',
    (tester) async {
      final backend = PhotoBackend()
        ..profile['avatarStoragePath'] = oldPath
        ..objects[oldPath] = avatar;
      final picker = PhotoPicker()
        ..selection = XFile.fromData(fixture(), name: 'selected.png');
      await pumpEditor(tester, backend, picker);
      await openGallery(tester);
      await finishAsync(tester, find.text('Preview Profile Picture'));
      expect(
        find.byKey(const ValueKey('selected-profile-photo-preview')),
        findsOneWidget,
      );
      expect(backend.events, isEmpty);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(backend.profile['avatarStoragePath'], oldPath);
      expect(backend.events, isEmpty);
    },
  );
  testWidgets('save uploads once and committed avatar appears immediately', (
    tester,
  ) async {
    final backend = PhotoBackend();
    final picker = PhotoPicker()
      ..selection = XFile.fromData(fixture(), name: 'photo.png');
    await pumpEditor(tester, backend, picker);
    await openGallery(tester);
    await finishAsync(tester, find.text('Preview Profile Picture'));
    await tester.ensureVisible(find.text('Save Profile Picture'));
    await tester.tap(find.text('Save Profile Picture'));
    await tester.pump();
    await finishAsync(tester, find.text('Profile picture updated.'));
    expect(backend.profile['avatarStoragePath'], newPath);
    expect(backend.events.where((e) => e.startsWith('upload:')), hasLength(1));
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).storagePath,
      newPath,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('remove requires confirmation and restores fallback', (
    tester,
  ) async {
    final backend = PhotoBackend()
      ..profile['avatarStoragePath'] = oldPath
      ..objects[oldPath] = avatar;
    await pumpEditor(tester, backend, PhotoPicker());
    await tester.tap(find.byKey(const ValueKey('change-profile-picture')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Profile Picture'));
    await tester.pumpAndSettle();
    expect(backend.events, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backend.profile['avatarStoragePath'], oldPath);
    await tester.tap(find.byKey(const ValueKey('change-profile-picture')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Profile Picture'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-profile-photo')),
    );
    await tester.pumpAndSettle();
    expect(backend.profile.containsKey('avatarStoragePath'), isFalse);
    expect(find.text('JS'), findsOneWidget);
    expect(find.text('Profile picture removed.'), findsOneWidget);
  });
  testWidgets(
    'failed downloads, invalid provider URL and damaged images use initials',
    (tester) async {
      for (final loader in [
        Future<Uint8List?>.error(StateError('network')),
        Future<Uint8List?>.value(Uint8List.fromList([0, 1, 2])),
      ]) {
        // Attach an error handler before pumping to avoid an unhandled future.
        final future = loader.catchError((Object _) => null);
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileAvatar(
              key: UniqueKey(),
              name: 'Alex Rivera',
              storagePath: oldPath,
              googlePhotoUrl: 'invalid',
              load: (_) => future,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('AR'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'avatar caches requests across builds and refreshes versioned replacement',
    (tester) async {
      var calls = 0;
      Future<Uint8List?> load(String path) async {
        calls++;
        return avatar;
      }

      Widget avatarWidget(String path) => MaterialApp(
        home: ProfileAvatar(name: 'Jamie', storagePath: path, load: load),
      );
      await tester.pumpWidget(avatarWidget(oldPath));
      await tester.pumpAndSettle();
      await tester.pumpWidget(avatarWidget(oldPath));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(avatarWidget(newPath));
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(640, 320),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'photo UI fits $size with large text and retains account controls',
      (tester) async {
        await pumpEditor(
          tester,
          PhotoBackend(),
          PhotoPicker(),
          size: size,
          scale: 2,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('change-profile-picture')),
          180,
        );
        await tester.tap(find.byKey(const ValueKey('change-profile-picture')));
        await tester.pumpAndSettle();
        expect(find.text('Choose from Gallery'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('capture profile and actual crop preview', (tester) async {
    final capture = GlobalKey();
    final picker = PhotoPicker()
      ..selection = XFile.fromData(fixture(), name: 'photo.png');
    await pumpEditor(tester, PhotoBackend(), picker, capture: capture);
    await screenshot(tester, capture, 'profile');
    await openGallery(tester);
    await finishAsync(tester, find.text('Preview Profile Picture'));
    expect(tester.takeException(), isNull);
    await screenshot(tester, capture, 'preview');
  });
}
