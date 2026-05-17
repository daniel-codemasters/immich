import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
// ----------- daniel -------------
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
// ---------------------------------
import 'package:immich_mobile/infrastructure/repositories/backup.repository.dart';
// ----------- daniel -------------
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
// ---------------------------------
import 'package:immich_mobile/utils/option.dart';

import '../repository_context.dart';

void main() {
  late MediumRepositoryContext ctx;
  late DriftBackupRepository sut;

  setUp(() {
    ctx = MediumRepositoryContext();
    sut = DriftBackupRepository(ctx.db);
  });

  tearDown(() async {
    await ctx.dispose();
  });

  group('getAllCounts', () {
    late String userId;

    setUp(() async {
      final user = await ctx.newUser();
      userId = user.id;
    });

    test('returns zeros when no albums exist', () async {
      final result = await sut.getAllCounts(userId);
      expect(result.total, 0);
      expect(result.remainder, 0);
      expect(result.processing, 0);
    });

    test('returns zeros when no selected albums exist', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.none);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 0);
      expect(result.remainder, 0);
      expect(result.processing, 0);
    });

    test('counts asset in selected album as total and remainder', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
      expect(result.remainder, 1);
      expect(result.processing, 0);
    });

    test('backed up asset reduces remainder', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final remote = await ctx.newRemoteAsset(ownerId: userId);
      final local = await ctx.newLocalAsset(checksum: remote.checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
      expect(result.remainder, 0);
      expect(result.processing, 0);
    });

    test('asset with null checksum is counted as processing', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset(checksumOption: const Option.none());
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
      expect(result.remainder, 1);
      expect(result.processing, 1);
    });

    test('asset in excluded album is not counted even if also in selected album', () async {
      final selectedAlbum = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final excludedAlbum = await ctx.newLocalAlbum(backupSelection: BackupSelection.excluded);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: selectedAlbum.id, assetId: asset.id);
      await ctx.newLocalAlbumAsset(albumId: excludedAlbum.id, assetId: asset.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 0);
      expect(result.remainder, 0);
    });

    test('counts assets across multiple selected albums without duplicates', () async {
      final album1 = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final album2 = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset();
      // Same asset in two selected albums
      await ctx.newLocalAlbumAsset(albumId: album1.id, assetId: asset.id);
      await ctx.newLocalAlbumAsset(albumId: album2.id, assetId: asset.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
    });

    test('backed up asset for different user is still counted as remainder', () async {
      final otherUser = await ctx.newUser();
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final remote = await ctx.newRemoteAsset(ownerId: otherUser.id);
      final local = await ctx.newLocalAsset(checksum: remote.checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
      expect(result.remainder, 1);
    });

    test('mixed assets produce correct combined counts', () async {
      final selectedAlbum = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);

      // backed up
      final remote1 = await ctx.newRemoteAsset(ownerId: userId);
      final local1 = await ctx.newLocalAsset(checksum: remote1.checksum);
      await ctx.newLocalAlbumAsset(albumId: selectedAlbum.id, assetId: local1.id);

      // not backed up, has checksum
      final local2 = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: selectedAlbum.id, assetId: local2.id);

      // processing (null checksum)
      final local3 = await ctx.newLocalAsset(checksumOption: const Option.none());
      await ctx.newLocalAlbumAsset(albumId: selectedAlbum.id, assetId: local3.id);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 3);
      expect(result.remainder, 2); // local2 + local3
      expect(result.processing, 1); // local3
    });
  });

  group('getCandidates', () {
    late String userId;

    setUp(() async {
      final user = await ctx.newUser();
      userId = user.id;
    });

    test('returns empty list when no selected albums exist', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.none);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getCandidates(userId);
      expect(result, isEmpty);
    });

    test('returns asset in selected album that is not backed up', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getCandidates(userId);
      expect(result.length, 1);
      expect(result.first.id, asset.id);
    });

    test('excludes asset already backed up for the same user', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final remote = await ctx.newRemoteAsset(ownerId: userId);
      final local = await ctx.newLocalAsset(checksum: remote.checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);

      final result = await sut.getCandidates(userId);
      expect(result, isEmpty);
    });

    test('includes asset backed up for a different user', () async {
      final otherUser = await ctx.newUser();
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final remote = await ctx.newRemoteAsset(ownerId: otherUser.id);
      final local = await ctx.newLocalAsset(checksum: remote.checksum);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: local.id);

      final result = await sut.getCandidates(userId);
      expect(result.length, 1);
      expect(result.first.id, local.id);
    });

    test('excludes asset in excluded album even if also in selected album', () async {
      final selectedAlbum = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final excludedAlbum = await ctx.newLocalAlbum(backupSelection: BackupSelection.excluded);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: selectedAlbum.id, assetId: asset.id);
      await ctx.newLocalAlbumAsset(albumId: excludedAlbum.id, assetId: asset.id);

      final result = await sut.getCandidates(userId);
      expect(result, isEmpty);
    });

    test('excludes asset with null checksum when onlyHashed is true', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset(checksumOption: const Option.none());
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getCandidates(userId);
      expect(result, isEmpty);
    });

    test('includes asset with null checksum when onlyHashed is false', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset(checksumOption: const Option.none());
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset.id);

      final result = await sut.getCandidates(userId, onlyHashed: false);
      expect(result.length, 1);
      expect(result.first.id, asset.id);
    });

    test('returns assets ordered by createdAt descending', () async {
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset1 = await ctx.newLocalAsset(createdAt: DateTime(2024, 1, 1));
      final asset2 = await ctx.newLocalAsset(createdAt: DateTime(2024, 3, 1));
      final asset3 = await ctx.newLocalAsset(createdAt: DateTime(2024, 2, 1));
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset1.id);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset2.id);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: asset3.id);

      final result = await sut.getCandidates(userId);
      expect(result.map((a) => a.id).toList(), [asset2.id, asset3.id, asset1.id]);
    });

    test('does not return duplicate when asset is in multiple selected albums', () async {
      final album1 = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final album2 = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final asset = await ctx.newLocalAsset();
      await ctx.newLocalAlbumAsset(albumId: album1.id, assetId: asset.id);
      await ctx.newLocalAlbumAsset(albumId: album2.id, assetId: asset.id);

      final result = await sut.getCandidates(userId);
      expect(result.length, 1);
      expect(result.first.id, asset.id);
    });
  });

  // ----------- daniel -------------
  // Backup cutoff date: only assets created on/after AppSettingsEnum.backupCutoffDate
  // are backed up. The cutoff is read from the Store, so this group initialises a
  // StoreService (the other groups run without it and exercise the fail-open path).
  group('backup cutoff date', () {
    late MediumRepositoryContext storeCtx;
    late String userId;
    late String oldAssetId;
    late String newAssetId;

    // Assets straddling the cutoff (createdAt is the asset's creation date).
    final cutoff = DateTime(2024, 6, 1);

    setUpAll(() async {
      storeCtx = MediumRepositoryContext();
      await StoreService.init(storeRepository: DriftStoreRepository(storeCtx.db), listenUpdates: false);
    });

    tearDownAll(() async {
      await Store.dispose();
      await storeCtx.dispose();
    });

    setUp(() async {
      final user = await ctx.newUser();
      userId = user.id;
      final album = await ctx.newLocalAlbum(backupSelection: BackupSelection.selected);
      final oldAsset = await ctx.newLocalAsset(createdAt: DateTime(2024, 5, 31));
      final newAsset = await ctx.newLocalAsset(createdAt: DateTime(2024, 6, 2));
      oldAssetId = oldAsset.id;
      newAssetId = newAsset.id;
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: oldAsset.id);
      await ctx.newLocalAlbumAsset(albumId: album.id, assetId: newAsset.id);
    });

    tearDown(() async {
      // Reset so other tests/groups see no cutoff.
      await Store.put(StoreKey.backupCutoffDate, 0);
    });

    test('getCandidates returns every asset when no cutoff is set', () async {
      final result = await sut.getCandidates(userId);
      expect(result.map((a) => a.id).toSet(), {oldAssetId, newAssetId});
    });

    test('getCandidates excludes assets created before the cutoff', () async {
      await Store.put(StoreKey.backupCutoffDate, cutoff.millisecondsSinceEpoch);

      final result = await sut.getCandidates(userId);
      expect(result.length, 1);
      expect(result.single.id, newAssetId);
    });

    test('getAllCounts excludes assets created before the cutoff', () async {
      await Store.put(StoreKey.backupCutoffDate, cutoff.millisecondsSinceEpoch);

      final result = await sut.getAllCounts(userId);
      expect(result.total, 1);
      expect(result.remainder, 1);
    });
  });
  // ---------------------------------
}
