import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockStorageClient extends Mock implements SupabaseStorageClient {}

class _MockFileApi extends Mock implements StorageFileApi {}

void main() {
  late _MockFileApi fileApi;
  late SupabaseStorageDataSource dataSource;
  late File image;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  setUp(() {
    final client = _MockSupabaseClient();
    final auth = _MockGoTrueClient();
    final user = _MockUser();
    final storage = _MockStorageClient();
    fileApi = _MockFileApi();

    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn('user-1');
    when(() => client.storage).thenReturn(storage);
    when(() => storage.from(any())).thenReturn(fileApi);
    when(() => fileApi.getPublicUrl(any())).thenAnswer(
      (inv) => 'https://cdn.example.com/${inv.positionalArguments[0]}',
    );

    dataSource = SupabaseStorageDataSource(
      supabaseClient: client,
      uploadTimeout: const Duration(milliseconds: 50),
    );

    final dir = Directory.systemTemp.createTempSync('storage_ds_test');
    image = File('${dir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  void stubUpload(Future<String> Function() answer) {
    when(
      () => fileApi.uploadBinary(
        any(),
        any(),
        fileOptions: any(named: 'fileOptions'),
      ),
    ).thenAnswer((_) => answer());
  }

  Matcher serverError(String message) =>
      isA<ServerException>().having((e) => e.message, 'message', message);

  group('uploadBookImage', () {
    test('returns the public URL under the user folder', () async {
      stubUpload(() async => 'ok');

      final url = await dataSource.uploadBookImage(image);

      expect(url, startsWith('https://cdn.example.com/user-1/book_'));
      expect(url, endsWith('.jpg'));
    });

    test('times out instead of hanging on a stalled connection', () async {
      stubUpload(() => Completer<String>().future);

      await expectLater(
        dataSource.uploadBookImage(image),
        throwsA(serverError(uploadTimeoutMessage)),
      );
    });

    test('maps DNS/socket failures to a no-connection message', () async {
      stubUpload(
        () => Future.error(const SocketException('Failed host lookup')),
      );

      await expectLater(
        dataSource.uploadBookImage(image),
        throwsA(serverError(noConnectionMessage)),
      );
    });

    test('maps http ClientException to a no-connection message', () async {
      stubUpload(
        () => Future.error(http.ClientException('Failed host lookup')),
      );

      await expectLater(
        dataSource.uploadBookImage(image),
        throwsA(serverError(noConnectionMessage)),
      );
    });
  });

  group('uploadProfilePicture', () {
    test('times out instead of hanging on a stalled connection', () async {
      stubUpload(() => Completer<String>().future);

      await expectLater(
        dataSource.uploadProfilePicture(image),
        throwsA(serverError(uploadTimeoutMessage)),
      );
    });
  });
}
