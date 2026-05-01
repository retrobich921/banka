import 'dart:io';

import 'package:banka/core/error/failures.dart';
import 'package:banka/features/barcode/domain/entities/barcode.dart';
import 'package:banka/features/barcode/domain/usecases/save_barcode.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/post/domain/usecases/create_post.dart';
import 'package:banka/features/post/domain/usecases/upload_post_image.dart';
import 'package:banka/features/post/presentation/bloc/create_post_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _MockCreatePost extends Mock implements CreatePost {}

class _MockUploadPostImage extends Mock implements UploadPostImage {}

class _MockSaveBarcode extends Mock implements SaveBarcode {}

void main() {
  late _MockCreatePost createPost;
  late _MockUploadPostImage uploadPostImage;
  late _MockSaveBarcode saveBarcode;
  late Directory tmpDir;

  const authorId = 'uid-1';
  final foundDate = DateTime(2025, 5, 1);

  setUpAll(() {
    registerFallbackValue(
      CreatePostParams(
        authorId: '',
        authorName: '',
        drinkName: '',
        photos: const <PostPhoto>[],
        foundDate: DateTime(2025),
        rarity: 1,
      ),
    );
    registerFallbackValue(
      UploadPostImageParams(postId: '', index: 0, file: File('/tmp/x')),
    );
    registerFallbackValue(
      const SaveBarcodeParams(code: '0', drinkName: '', contributedBy: ''),
    );
  });

  setUp(() {
    createPost = _MockCreatePost();
    uploadPostImage = _MockUploadPostImage();
    saveBarcode = _MockSaveBarcode();
    tmpDir = Directory.systemTemp.createTempSync('banka-create-post-');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  // UploadPostImage / CreatePost мокаются — настоящих файлов на диске не
  // нужно. Генерим только пути.
  File fakeFile(String name) => File(p.join(tmpDir.path, name));

  CreatePostBloc buildBloc() =>
      CreatePostBloc(createPost, uploadPostImage, saveBarcode);

  group('field reducers', () {
    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostInitialized stores author + group context',
      build: buildBloc,
      act: (b) => b.add(
        const CreatePostInitialized(
          authorId: authorId,
          authorName: 'Albert',
          authorPhotoUrl: 'https://cdn/u.png',
          groupId: 'grp-1',
          groupName: 'Monster Lovers',
        ),
      ),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.author?.id, 'author.id', authorId)
            .having((s) => s.groupId, 'groupId', 'grp-1')
            .having((s) => s.groupName, 'groupName', 'Monster Lovers'),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostRarityChanged clamps to [1..9]',
      build: buildBloc,
      act: (b) => b
        ..add(const CreatePostRarityChanged(20))
        ..add(const CreatePostRarityChanged(0)),
      expect: () => [
        isA<CreatePostState>().having((s) => s.rarity, 'rarity', 9),
        isA<CreatePostState>().having((s) => s.rarity, 'rarity', 1),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostPhotosPicked appends and caps at 6',
      build: buildBloc,
      act: (b) {
        b.add(
          CreatePostPhotosPicked(List.generate(4, (i) => fakeFile('a$i.jpg'))),
        );
        b.add(
          CreatePostPhotosPicked(List.generate(4, (i) => fakeFile('b$i.jpg'))),
        );
      },
      verify: (b) {
        expect(b.state.pickedFiles.length, 6);
      },
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostGroupChanged with null groupId clears group',
      build: buildBloc,
      seed: () => const CreatePostState(groupId: 'g-1', groupName: 'Old'),
      act: (b) => b.add(const CreatePostGroupChanged()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.groupId, 'groupId', isNull)
            .having((s) => s.groupName, 'groupName', isNull),
      ],
    );
  });

  group('Sprint 14 — barcode reducers', () {
    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostBarcodeMatched autofills drinkName/brand and skips contribute',
      build: buildBloc,
      act: (b) => b.add(
        const CreatePostBarcodeMatched(
          code: '5449000000996',
          drinkName: 'Coca-Cola Classic',
          brandId: 'brand-coca',
          brandName: 'Coca-Cola',
        ),
      ),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.barcode, 'barcode', '5449000000996')
            .having((s) => s.barcodeContribute, 'barcodeContribute', isFalse)
            .having((s) => s.drinkName, 'drinkName', 'Coca-Cola Classic')
            .having((s) => s.brandId, 'brandId', 'brand-coca')
            .having((s) => s.brandName, 'brandName', 'Coca-Cola'),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostBarcodeUnknown stores code and flags contribute',
      build: buildBloc,
      act: (b) => b.add(const CreatePostBarcodeUnknown(code: '4607081320169')),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.barcode, 'barcode', '4607081320169')
            .having((s) => s.barcodeContribute, 'barcodeContribute', isTrue),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostBarcodeCleared resets barcode and contribute flag',
      build: buildBloc,
      seed: () =>
          const CreatePostState(barcode: '12345', barcodeContribute: true),
      act: (b) => b.add(const CreatePostBarcodeCleared()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.barcode, 'barcode', isNull)
            .having((s) => s.barcodeContribute, 'barcodeContribute', isFalse),
      ],
    );
  });

  group('CreatePostSubmitted validations', () {
    blocTest<CreatePostBloc, CreatePostState>(
      'errors when author is not set',
      build: buildBloc,
      act: (b) => b.add(const CreatePostSubmitted()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.status, 'status', CreatePostStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', contains('профиль')),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'errors when no photos',
      build: buildBloc,
      seed: () => const CreatePostState(
        author: CreatePostAuthor(id: authorId, name: 'A'),
        drinkName: 'Monster',
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.status, 'status', CreatePostStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', contains('фото')),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'errors when drinkName too short',
      build: buildBloc,
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'A'),
        pickedFiles: [fakeFile('a.jpg')],
        drinkName: 'M',
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.status, 'status', CreatePostStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Введи название'),
            ),
      ],
    );
  });

  group('CreatePostSubmitted happy path', () {
    blocTest<CreatePostBloc, CreatePostState>(
      'uploads each photo, then creates post, then emits created',
      build: () {
        when(() => uploadPostImage(any())).thenAnswer(
          (invocation) async => const Right(
            PostPhoto(url: 'https://cdn/u.jpg', thumbUrl: 'https://cdn/u.jpg'),
          ),
        );
        when(() => createPost(any())).thenAnswer(
          (_) async => Right(
            Post(
              id: 'p-new',
              authorId: authorId,
              authorName: 'Albert',
              drinkName: 'Monster',
              foundDate: foundDate,
              rarity: 7,
              createdAt: foundDate,
            ),
          ),
        );
        return buildBloc();
      },
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'Albert'),
        pickedFiles: [fakeFile('a.jpg'), fakeFile('b.jpg')],
        drinkName: 'Monster Energy',
        foundDate: foundDate,
        rarity: 7,
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      verify: (b) {
        expect(b.state.status, CreatePostStatus.created);
        expect(b.state.createdPostId, 'p-new');
        verify(() => uploadPostImage(any())).called(2);
        verify(() => createPost(any())).called(1);
      },
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'stops uploading on first failure and reports error',
      build: () {
        when(
          () => uploadPostImage(any()),
        ).thenAnswer((_) async => const Left(ServerFailure(message: 'no')));
        return buildBloc();
      },
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'Albert'),
        pickedFiles: [fakeFile('a.jpg')],
        drinkName: 'Monster',
        foundDate: foundDate,
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      verify: (b) {
        expect(b.state.status, CreatePostStatus.error);
        expect(b.state.errorMessage, contains('Не удалось загрузить'));
        verifyNever(() => createPost(any()));
      },
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'contributes new barcode after successful create when '
      'barcodeContribute=true',
      build: () {
        when(() => uploadPostImage(any())).thenAnswer(
          (_) async => const Right(
            PostPhoto(url: 'https://cdn/u.jpg', thumbUrl: 'https://cdn/u.jpg'),
          ),
        );
        when(() => createPost(any())).thenAnswer(
          (_) async => Right(
            Post(
              id: 'p-new',
              authorId: authorId,
              authorName: 'Albert',
              drinkName: 'Monster',
              foundDate: foundDate,
              rarity: 7,
              createdAt: foundDate,
            ),
          ),
        );
        when(() => saveBarcode(any())).thenAnswer(
          (_) async => Right(
            Barcode(
              id: '5449000000996',
              drinkName: 'Monster Energy',
              contributedBy: authorId,
              createdAt: foundDate,
            ),
          ),
        );
        return buildBloc();
      },
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'Albert'),
        pickedFiles: [fakeFile('a.jpg')],
        drinkName: 'Monster Energy',
        foundDate: foundDate,
        barcode: '5449000000996',
        barcodeContribute: true,
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      verify: (b) {
        expect(b.state.status, CreatePostStatus.created);
        verify(() => createPost(any())).called(1);
        verify(() => saveBarcode(any())).called(1);
      },
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'does not contribute barcode when matched (already known)',
      build: () {
        when(() => uploadPostImage(any())).thenAnswer(
          (_) async => const Right(
            PostPhoto(url: 'https://cdn/u.jpg', thumbUrl: 'https://cdn/u.jpg'),
          ),
        );
        when(() => createPost(any())).thenAnswer(
          (_) async => Right(
            Post(
              id: 'p-new',
              authorId: authorId,
              authorName: 'Albert',
              drinkName: 'Monster',
              foundDate: foundDate,
              rarity: 7,
              createdAt: foundDate,
            ),
          ),
        );
        return buildBloc();
      },
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'Albert'),
        pickedFiles: [fakeFile('a.jpg')],
        drinkName: 'Monster',
        foundDate: foundDate,
        barcode: '5449000000996',
        // barcodeContribute=false по дефолту — банка из коллективной базы.
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      verify: (b) {
        expect(b.state.status, CreatePostStatus.created);
        verifyNever(() => saveBarcode(any()));
      },
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'reports error when createPost fails after uploads succeed',
      build: () {
        when(() => uploadPostImage(any())).thenAnswer(
          (_) async => const Right(
            PostPhoto(url: 'https://cdn/u.jpg', thumbUrl: 'https://cdn/u.jpg'),
          ),
        );
        when(
          () => createPost(any()),
        ).thenAnswer((_) async => const Left(ServerFailure(message: 'denied')));
        return buildBloc();
      },
      seed: () => CreatePostState(
        author: const CreatePostAuthor(id: authorId, name: 'Albert'),
        pickedFiles: [fakeFile('a.jpg')],
        drinkName: 'Monster',
        foundDate: foundDate,
      ),
      act: (b) => b.add(const CreatePostSubmitted()),
      verify: (b) {
        expect(b.state.status, CreatePostStatus.error);
        expect(b.state.errorMessage, contains('denied'));
      },
    );
  });

  group('acknowledge / reset', () {
    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostCreationAcknowledged clears createdPostId',
      build: buildBloc,
      seed: () => const CreatePostState(
        status: CreatePostStatus.created,
        createdPostId: 'p-1',
      ),
      act: (b) => b.add(const CreatePostCreationAcknowledged()),
      expect: () => [
        isA<CreatePostState>()
            .having((s) => s.status, 'status', CreatePostStatus.initial)
            .having((s) => s.createdPostId, 'createdPostId', isNull),
      ],
    );

    blocTest<CreatePostBloc, CreatePostState>(
      'CreatePostResetRequested resets to initial',
      build: buildBloc,
      seed: () => const CreatePostState(drinkName: 'Monster', rarity: 9),
      act: (b) => b.add(const CreatePostResetRequested()),
      verify: (b) {
        expect(b.state, const CreatePostState.initial());
      },
    );
  });
}
