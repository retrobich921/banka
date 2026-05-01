import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/post/domain/repositories/post_repository.dart';
import 'package:banka/features/search/domain/entities/search_filters.dart';
import 'package:banka/features/search/domain/usecases/search_posts.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PostRepository {}

void main() {
  late _MockRepo repo;
  late SearchPosts usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = SearchPosts(repo);
  });

  test('forwards query + filters to repository.searchPosts', () async {
    when(
      () => repo.searchPosts(
        query: any(named: 'query'),
        rarityMin: any(named: 'rarityMin'),
        rarityMax: any(named: 'rarityMax'),
        brandId: any(named: 'brandId'),
        groupId: any(named: 'groupId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right<Failure, List<Post>>(<Post>[]));

    await usecase(
      const SearchPostsParams(
        query: 'monster',
        filters: SearchFilters(
          rarityMin: 3,
          rarityMax: 8,
          brandId: 'b1',
          groupId: 'g1',
        ),
      ),
    );

    verify(
      () => repo.searchPosts(
        query: 'monster',
        rarityMin: 3,
        rarityMax: 8,
        brandId: 'b1',
        groupId: 'g1',
      ),
    ).called(1);
  });
}
