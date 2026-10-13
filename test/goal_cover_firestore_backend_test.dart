import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myproject/goal_cover_processing.dart';
import 'package:myproject/goal_cover_service.dart';

import 'goal_cover_test.dart' show picture;
import 'profile_photo_firestore_backend_test.dart'
    show PhotoAuth, PhotoDatabase;

const target = GoalCoverTarget.personal('owner', 'goalA');
const shared = GoalCoverTarget.shared('owner', 'sharedA');
const photoPath = 'users/owner/goals/goalA/coverPhotos/FFFFFFFFFFFFFFFFFFFF';

PhotoDatabase database() => PhotoDatabase()
  ..documents[target.documentPath] = {
    'title': 'Travel',
    'savedAmount': 123.0,
    'targetAmount': 1000.0,
    'currencyCode': 'PHP',
  };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List cover;
  setUpAll(() async {
    cover = await cropGoalCover(
      await prepareGoalCover(picture()),
      const GoalCoverCrop(),
    );
  });

  test(
    'compact encoding keeps the approved landscape crop and removes metadata',
    () async {
      final compact = await compactGoalCover(cover);
      expect(compact.length, lessThanOrEqualTo(GoalCoverLimits.firestoreBytes));
      final decoded = img.decodeJpg(compact)!;
      expect((decoded.width, decoded.height), (960, 540));
      expect(decoded.getPixel(480, 70).r, greaterThan(200));
      expect(decoded.getPixel(480, 470).b, greaterThan(200));
      expect(decoded.exif.isEmpty, true);
      await validateCompactGoalCover(compact);
    },
  );

  test('detailed images fit the 200 KiB document budget', () async {
    final image = img.Image(width: 1280, height: 720);
    final random = Random(87);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(
          x,
          y,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
    }
    final compact = await compactGoalCover(
      img.encodeJpg(image, quality: 88, chroma: img.JpegChroma.yuv420),
    );
    expect(compact.length, lessThanOrEqualTo(200 * 1024));
    await validateCompactGoalCover(compact);
  });

  test('Firestore upload stores real compact bytes without initializing Storage or inventing progress', () async {
    final db = database();
    final backend = FirestoreGoalCoverBackend(auth: PhotoAuth(), firestore: db);
    expect(backend.newPath(target), photoPath);
    final progress = <double>[];
    await backend.upload(photoPath, cover, progress.add);
    expect(progress, isEmpty);
    final photo = db.documents[photoPath]!;
    expect(photo.keys.toSet(), {
      'bytes',
      'contentType',
      'width',
      'height',
      'createdAt',
    });
    expect(photo['createdAt'], isA<Timestamp>());
    expect(photo['bytes'], isA<Blob>());
    await validateCompactGoalCover((photo['bytes'] as Blob).bytes);
    expect(db.documents[target.documentPath]!['savedAmount'], 123);
  });

  test('replace and remove journal, commit and clean up without changing financial or profile documents', () async {
    final db = database();
    final old = photoPath.replaceFirst(
      'FFFFFFFFFFFFFFFFFFFF',
      'BBBBBBBBBBBBBBBBBBBB',
    );
    db.documents[target.documentPath]!['coverStoragePath'] = old;
    db.documents[old] = {'existing': true};
    final backend = FirestoreGoalCoverBackend(auth: PhotoAuth(), firestore: db);
    final service = GoalCoverService(backend);
    await service.replace(target, cover);
    expect(db.documents[target.documentPath]!['coverStoragePath'], photoPath);
    expect(db.documents[target.documentPath]!['savedAmount'], 123);
    expect(db.documents[target.documentPath]!['targetAmount'], 1000);
    expect(db.documents[target.documentPath]!['currencyCode'], 'PHP');
    expect(db.documents['users/owner']!['displayName'], 'Jamie');
    expect(db.documents.containsKey(old), false);
    expect(
      db.documents['users/owner/goalCoverUploads/FFFFFFFFFFFFFFFFFFFF']!['storagePath'],
      photoPath,
    );
    final goalWrites = db.writes.where(
      (entry) => entry.$1 == target.documentPath,
    );
    expect(goalWrites.single.$2.keys.toSet(), {
      'coverStoragePath',
      'coverUpdatedAt',
    });
    await service.remove(target);
    expect(
      db.documents[target.documentPath]!.containsKey('coverStoragePath'),
      false,
    );
    expect(db.documents.containsKey(photoPath), false);
    expect(
      db.documents.containsKey(
        'users/owner/goalCoverUploads/FFFFFFFFFFFFFFFFFFFF',
      ),
      false,
    );
  });

  test(
    'metadata commit rejects missing photo and a concurrent cover change',
    () async {
      final db = database();
      final backend = FirestoreGoalCoverBackend(
        auth: PhotoAuth(),
        firestore: db,
      );
      await expectLater(
        backend.commit(target, null, photoPath),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(db.writes, isEmpty);
      db.documents[target.documentPath]!['coverStoragePath'] =
          '${target.folder}/AAAAAAAAAAAAAAAAAAAA.jpg';
      db.documents[photoPath] = {'existing': true};
      await expectLater(
        backend.commit(target, null, photoPath),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(db.writes, isEmpty);
    },
  );

  test('referenced photo is protected and orphan cleanup works after personal goal deletion', () async {
    final db = database();
    final backend = FirestoreGoalCoverBackend(auth: PhotoAuth(), firestore: db);
    db.documents[target.documentPath]!['coverStoragePath'] = photoPath;
    db.documents[photoPath] = {'existing': true};
    await backend.cleanup(target, photoPath);
    expect(db.deletions, isEmpty);
    db.documents.remove(target.documentPath);
    await backend.cleanup(target, photoPath);
    expect(db.deletions, contains(photoPath));
  });

  test(
    'immutable photo collision and missing goal leave documents intact',
    () async {
      final db = database();
      final backend = FirestoreGoalCoverBackend(
        auth: PhotoAuth(),
        firestore: db,
      );
      db.documents[photoPath] = {'existing': true};
      await expectLater(
        backend.upload(photoPath, cover, (_) {}),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(db.documents[photoPath], {'existing': true});
      db.documents.remove(target.documentPath);
      await expectLater(
        backend.upload(photoPath, cover, (_) {}),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(db.writes, isEmpty);
    },
  );

  test(
    'foreign paths, signed-out sessions and shared non-owners cannot upload',
    () async {
      final db = database();
      final auth = PhotoAuth();
      final backend = FirestoreGoalCoverBackend(auth: auth, firestore: db);
      for (final path in [
        photoPath.replaceFirst('/owner/', '/other/'),
        '${target.photoFolder}/bad',
        'public/coverPhotos/FFFFFFFFFFFFFFFFFFFF',
      ]) {
        await expectLater(
          backend.upload(path, cover, (_) {}),
          throwsA(isA<GoalCoverFailure>()),
        );
      }
      db.documents[shared.documentPath] = {'ownerId': 'other'};
      await expectLater(
        backend.upload(backend.newPath(shared), cover, (_) {}),
        throwsA(isA<GoalCoverFailure>()),
      );
      auth.session = null;
      await expectLater(
        backend.upload(photoPath, cover, (_) {}),
        throwsA(isA<GoalCoverFailure>()),
      );
      expect(db.writes, isEmpty);
    },
  );

  test('authenticated document loader uses the server and rejects oversized or forged image metadata', () async {
    final db = database();
    final backend = FirestoreGoalCoverBackend(auth: PhotoAuth(), firestore: db);
    await backend.upload(photoPath, cover, (_) {});
    expect(
      await loadFirestoreGoalCover(db, photoPath),
      (db.documents[photoPath]!['bytes'] as Blob).bytes,
    );
    expect(db.reads.last, (photoPath, Source.server));
    db.documents[photoPath]!['width'] = 1280;
    await expectLater(
      loadFirestoreGoalCover(db, photoPath),
      throwsA(isA<GoalCoverFailure>()),
    );
    db.documents[photoPath]!['width'] = 960;
    db.documents[photoPath]!['bytes'] = Blob(Uint8List(200 * 1024 + 1));
    await expectLater(
      loadFirestoreGoalCover(db, photoPath),
      throwsA(isA<GoalCoverFailure>()),
    );
  });
}
