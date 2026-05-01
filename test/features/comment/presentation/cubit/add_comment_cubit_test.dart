import 'package:banka/core/error/failures.dart';
import 'package:banka/features/comment/domain/usecases/add_comment.dart';
import 'package:banka/features/comment/presentation/cubit/add_comment_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddComment extends Mock implements AddComment {}

void main() {
  late _MockAddComment addComment;

  setUpAll(() {
    registerFallbackValue(
      const AddCommentParams(
        postId: 'p',
        authorId: 'u',
        authorName: 'Alice',
        text: 'hi',
      ),
    );
  });

  setUp(() {
    addComment = _MockAddComment();
  });

  AddCommentCubit buildCubit() => AddCommentCubit(addComment);

  group('textChanged', () {
    blocTest<AddCommentCubit, AddCommentState>(
      'обновляет text и активирует canSubmit при непустом значении',
      build: buildCubit,
      act: (c) => c.textChanged('hi'),
      expect: () => [
        isA<AddCommentState>()
            .having((s) => s.text, 'text', 'hi')
            .having((s) => s.canSubmit, 'canSubmit', true),
      ],
    );

    blocTest<AddCommentCubit, AddCommentState>(
      'обрезает text до maxLength',
      build: buildCubit,
      act: (c) => c.textChanged('a' * (AddCommentCubit.maxLength + 50)),
      verify: (cubit) {
        expect(cubit.state.text.length, AddCommentCubit.maxLength);
      },
    );

    test('пустой text → canSubmit=false', () {
      final cubit = buildCubit();
      cubit.textChanged('   ');
      expect(cubit.state.canSubmit, false);
    });
  });

  group('submit', () {
    blocTest<AddCommentCubit, AddCommentState>(
      'успешный submit: submitting → success, очищает text',
      setUp: () {
        when(
          () => addComment(any()),
        ).thenAnswer((_) async => const Right('cid'));
      },
      build: buildCubit,
      seed: () => const AddCommentState(text: 'hi'),
      act: (c) => c.submit(postId: 'p', authorId: 'u', authorName: 'Alice'),
      expect: () => [
        isA<AddCommentState>().having(
          (s) => s.status,
          'status',
          AddCommentStatus.submitting,
        ),
        isA<AddCommentState>()
            .having((s) => s.status, 'status', AddCommentStatus.success)
            .having((s) => s.text, 'text', ''),
      ],
    );

    blocTest<AddCommentCubit, AddCommentState>(
      'submit с пустым text игнорируется',
      build: buildCubit,
      act: (c) => c.submit(postId: 'p', authorId: 'u', authorName: 'Alice'),
      expect: () => <AddCommentState>[],
      verify: (_) {
        verifyNever(() => addComment(any()));
      },
    );

    blocTest<AddCommentCubit, AddCommentState>(
      'ошибка submit: error + сохраняет text для повтора',
      setUp: () {
        when(
          () => addComment(any()),
        ).thenAnswer((_) async => const Left(ServerFailure(message: 'no net')));
      },
      build: buildCubit,
      seed: () => const AddCommentState(text: 'hi'),
      act: (c) => c.submit(postId: 'p', authorId: 'u', authorName: 'Alice'),
      expect: () => [
        isA<AddCommentState>().having(
          (s) => s.status,
          'status',
          AddCommentStatus.submitting,
        ),
        isA<AddCommentState>()
            .having((s) => s.status, 'status', AddCommentStatus.error)
            .having((s) => s.errorMessage, 'msg', 'no net')
            .having((s) => s.text, 'text', 'hi'),
      ],
    );

    test('возвращает true при успехе', () async {
      when(() => addComment(any())).thenAnswer((_) async => const Right('cid'));
      final cubit = buildCubit();
      cubit.textChanged('hi');
      final ok = await cubit.submit(
        postId: 'p',
        authorId: 'u',
        authorName: 'Alice',
      );
      expect(ok, true);
    });

    test('возвращает false при ошибке', () async {
      when(
        () => addComment(any()),
      ).thenAnswer((_) async => const Left(ServerFailure(message: 'no')));
      final cubit = buildCubit();
      cubit.textChanged('hi');
      final ok = await cubit.submit(
        postId: 'p',
        authorId: 'u',
        authorName: 'Alice',
      );
      expect(ok, false);
    });
  });

  group('acknowledged', () {
    blocTest<AddCommentCubit, AddCommentState>(
      'сбрасывает status в idle и errorMessage',
      build: buildCubit,
      seed: () => const AddCommentState(
        status: AddCommentStatus.error,
        text: 'hi',
        errorMessage: 'boom',
      ),
      act: (c) => c.acknowledged(),
      expect: () => [
        isA<AddCommentState>()
            .having((s) => s.status, 'status', AddCommentStatus.idle)
            .having((s) => s.errorMessage, 'msg', isNull),
      ],
    );
  });
}
