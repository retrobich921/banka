# Implementation Plan: Feed Optimization and Post UX

## Overview

This implementation plan breaks down the Feed Optimization and Post UX feature into discrete coding tasks. The feature consists of two major areas:

1. **Multi-Group Feed with Pagination**: Load posts from all user groups with efficient pagination, real-time updates, and offline support
2. **Enhanced Post Creation UX**: Camera-first photo capture with 1:1 crop and group selection memory

All tasks build incrementally, with checkpoints to ensure stability. Property-based tests validate correctness properties from the design document.

## Tasks

- [x] 1. Set up domain layer for feed pagination
  - Create `FeedPage` entity with `posts`, `hasMore`, and `cursor` fields using `@freezed`
  - Add entity to `lib/features/post/domain/entities/feed_page.dart`
  - _Requirements: 2.1, 2.5_

- [x] 2. Implement group memory persistence (domain + data layers)
  - [x] 2.1 Create `GroupMemoryRepository` interface in domain layer
    - Define methods: `getLastSelectedGroup()`, `saveLastSelectedGroup(String)`, `clearLastSelectedGroup()`
    - Return `ResultFuture<String?>` and `ResultFuture<void>`
    - Add to `lib/features/post/domain/repositories/group_memory_repository.dart`
    - _Requirements: 4.1, 4.2, 4.5_

  - [x] 2.2 Create `GroupMemoryLocalDataSource` interface in data layer
    - Define methods: `getLastSelectedGroup()`, `saveLastSelectedGroup(String)`, `clearLastSelectedGroup()`
    - Return `Future<String?>` and `Future<void>`
    - Add to `lib/features/post/data/datasources/group_memory_local_data_source.dart`
    - _Requirements: 4.5_

  - [x] 2.3 Implement `SharedPrefsGroupMemoryDataSource`
    - Inject `SharedPreferences` via constructor
    - Use key `'last_selected_group_id'` for storage
    - Annotate with `@LazySingleton(as: GroupMemoryLocalDataSource)`
    - Add to `lib/features/post/data/datasources/group_memory_local_data_source.dart`
    - _Requirements: 4.5_

  - [x] 2.4 Implement `GroupMemoryRepositoryImpl`
    - Inject `GroupMemoryLocalDataSource` via constructor
    - Wrap data source calls with try-catch, return `Left(CacheFailure)` on error
    - Annotate with `@LazySingleton(as: GroupMemoryRepository)`
    - Add to `lib/features/post/data/repositories/group_memory_repository_impl.dart`
    - _Requirements: 4.1, 4.2, 4.5_

  - [ ]* 2.5 Write unit tests for `GroupMemoryRepositoryImpl`
    - Test successful read/write/clear operations
    - Test error handling (data source throws exception)
    - Mock `GroupMemoryLocalDataSource` with mocktail
    - _Requirements: 4.1, 4.2, 4.5_

- [x] 3. Create group memory use cases
  - [x] 3.1 Implement `GetLastSelectedGroup` use case
    - Inject `GroupMemoryRepository`
    - Call repository's `getLastSelectedGroup()`
    - Annotate with `@lazySingleton`
    - Add to `lib/features/post/domain/usecases/get_last_selected_group.dart`
    - _Requirements: 4.2_

  - [x] 3.2 Implement `SaveLastSelectedGroup` use case
    - Inject `GroupMemoryRepository`
    - Accept `String groupId` parameter
    - Call repository's `saveLastSelectedGroup(groupId)`
    - Annotate with `@lazySingleton`
    - Add to `lib/features/post/domain/usecases/save_last_selected_group.dart`
    - _Requirements: 4.1, 4.6_

  - [x] 3.3 Implement `ClearLastSelectedGroup` use case
    - Inject `GroupMemoryRepository`
    - Call repository's `clearLastSelectedGroup()`
    - Annotate with `@lazySingleton`
    - Add to `lib/features/post/domain/usecases/clear_last_selected_group.dart`
    - _Requirements: 4.4_

  - [ ]* 3.4 Write property test for invalid group cleanup
    - **Property 8: Invalid Group Cleanup**
    - **Validates: Requirements 4.4**
    - Generate random group IDs and user group lists
    - Verify stored ID is cleared when not in user's groups
    - _Requirements: 4.4_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run `flutter test` to verify group memory implementation
  - Ensure all tests pass, ask the user if questions arise

- [x] 5. Implement camera capture with 1:1 crop use case
  - [x] 5.1 Create `CapturePhotoWithCrop` use case
    - Inject `ImagePicker` and `image` package utilities
    - Check camera permission using `permission_handler`
    - Capture photo with `ImageSource.camera`, `maxWidth: 1600`, `maxHeight: 1600`
    - Load image bytes and decode with `img.decodeImage()`
    - Apply center crop to 1:1 aspect ratio using `img.copyCrop()`
    - Compress to JPEG quality 85 with `img.encodeJpg()`
    - Validate file size (<5MB), return `ValidationFailure` if exceeded
    - Save to temp directory and return `File`
    - Handle `PlatformException` and return appropriate `Failure`
    - Annotate with `@lazySingleton`
    - Add to `lib/features/post/domain/usecases/capture_photo_with_crop.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 6.1, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 5.2 Write property test for image aspect ratio preservation
    - **Property 6: Image Aspect Ratio Preservation**
    - **Validates: Requirements 3.3, 7.3**
    - Generate random images with various dimensions
    - Apply 1:1 crop logic
    - Verify output has `width == height`
    - _Requirements: 3.3, 7.3_

  - [ ]* 5.3 Write property test for image dimension constraint
    - **Property 10: Image Dimension Constraint**
    - **Validates: Requirements 7.2**
    - Generate random images with various dimensions
    - Process through compression logic
    - Verify max dimension ≤ 1600px
    - _Requirements: 7.2_

  - [ ]* 5.4 Write property test for file size validation
    - **Property 11: File Size Validation**
    - **Validates: Requirements 7.5**
    - Generate images that compress to various sizes
    - Verify images >5MB are rejected with `ValidationFailure`
    - _Requirements: 7.5_

  - [ ]* 5.5 Write unit tests for `CapturePhotoWithCrop`
    - Test permission denied scenario
    - Test user cancellation (returns `CancelledFailure`)
    - Test invalid image (returns `ValidationFailure`)
    - Test successful capture and crop
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 6.1, 6.2, 6.4, 6.5, 7.1, 7.2, 7.3, 7.5_

- [x] 6. Enhance `CreatePostBloc` with group memory and camera capture
  - [x] 6.1 Add new dependencies to `CreatePostBloc`
    - Inject `GetLastSelectedGroup`, `SaveLastSelectedGroup`, `ClearLastSelectedGroup` use cases
    - Inject `CapturePhotoWithCrop` use case
    - Inject `WatchMyGroups` use case (from group feature)
    - _Requirements: 4.2, 4.6_

  - [x] 6.2 Enhance `CreatePostInitialized` event handler
    - After setting author fields, check if `groupId` is provided (from group detail page)
    - If provided, set group and return early
    - Otherwise, call `GetLastSelectedGroup`
    - If group ID exists, validate membership by calling `WatchMyGroups` and checking if group exists
    - If valid, auto-select group in state
    - If invalid, call `ClearLastSelectedGroup`
    - _Requirements: 4.2, 4.3, 4.4, 4.7_

  - [x] 6.3 Add new event `CreatePostCameraRequested`
    - Create sealed event class
    - Add event handler that calls `CapturePhotoWithCrop`
    - On success, add captured file to `photos` list in state
    - On failure, emit error state with failure message
    - Ensure photo count doesn't exceed 6
    - Add to `lib/features/post/presentation/bloc/create_post_event.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 6.4 Enhance `CreatePostSubmitted` event handler
    - After successful post creation, call `SaveLastSelectedGroup` with `state.groupId`
    - Ignore errors from save operation (don't block user flow)
    - _Requirements: 4.6_

  - [ ]* 6.5 Write property test for photo count constraint
    - **Property 7: Photo Count Constraint**
    - **Validates: Requirements 3.6**
    - Simulate sequence of photo addition operations
    - Verify photo list never exceeds 6 items
    - _Requirements: 3.6_

  - [ ]* 6.6 Write unit tests for enhanced `CreatePostBloc`
    - Test group auto-selection on initialization
    - Test invalid group cleanup on initialization
    - Test camera capture event handling
    - Test group save on successful post creation
    - Use `bloc_test` package
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.2, 4.3, 4.4, 4.6, 4.7_

- [x] 7. Update `CreatePostPage` UI for camera-first flow
  - [ ] 7.1 Add camera button to photo selection area
    - Add "Camera" button that dispatches `CreatePostCameraRequested` event
    - Show loading indicator while capturing
    - Display error snackbar on capture failure
    - Show permission dialog if camera permission denied (with "Open Settings" button)
    - _Requirements: 3.1, 3.4, 3.5, 6.2, 6.3_

  - [ ] 7.2 Display auto-selected group on page load
    - Show selected group name if auto-selected
    - Allow user to change group manually
    - _Requirements: 4.2, 4.7_

  - [ ]* 7.3 Write widget tests for `CreatePostPage`
    - Test camera button behavior
    - Test group auto-selection display
    - Test photo grid with captured images
    - _Requirements: 3.1, 4.2, 4.7_

- [x] 8. Checkpoint - Test post creation UX end-to-end
  - Manually test camera capture flow on device
  - Verify 1:1 crop is applied
  - Verify group memory persists across app restarts
  - Ensure all tests pass, ask the user if questions arise

- [x] 9. Create `FeedPage` DTO in data layer
  - Create `FeedPageDto` class with `posts`, `hasMore`, `cursor` fields
  - Implement `toDomain()` method to convert to `FeedPage` entity
  - Implement static `fromDomain()` method
  - Add to `lib/features/post/data/models/feed_page_dto.dart`
  - _Requirements: 2.1, 2.5_

- [x] 10. Implement multi-group feed use case
  - [x] 10.1 Create `WatchMultiGroupFeed` use case
    - Inject `PostRepository` and `GroupRepository`
    - Accept `WatchMultiGroupFeedParams` with `userId`, `limit` (default 20), and optional `cursor`
    - Call `GroupRepository.watchMyGroups(userId)` to get user's groups
    - If groups empty, yield `FeedPage.empty()`
    - For each group (max 10 concurrent), call `PostRepository.watchGroupFeed(groupId, limit, startAfterId: cursor)`
    - Merge streams using `StreamGroup.merge()` from `async` package
    - Sort merged posts by `createdAt` descending
    - Apply limit and create `FeedPage` with `hasMore` flag and cursor
    - Handle partial failures: if one group fails, continue with others
    - Annotate with `@lazySingleton`
    - Add to `lib/features/post/domain/usecases/watch_multi_group_feed.dart`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]* 10.2 Write property test for feed group membership
    - **Property 1: Feed Group Membership**
    - **Validates: Requirements 1.1**
    - Generate random user with set of groups
    - Generate posts for those groups
    - Verify all posts in feed have `groupId` in user's group list
    - _Requirements: 1.1_

  - [ ]* 10.3 Write property test for feed completeness without duplicates
    - **Property 2: Feed Completeness Without Duplicates**
    - **Validates: Requirements 1.2**
    - Generate random groups and posts
    - Merge posts using feed logic
    - Verify all posts present exactly once (no duplicates, no missing)
    - _Requirements: 1.2_

  - [ ]* 10.4 Write property test for feed chronological ordering
    - **Property 3: Feed Chronological Ordering**
    - **Validates: Requirements 1.3, 5.4**
    - Generate random posts with random timestamps
    - Sort using feed logic
    - Verify descending order by `createdAt`
    - _Requirements: 1.3, 5.4_

  - [ ]* 10.5 Write property test for pagination page size
    - **Property 4: Pagination Page Size**
    - **Validates: Requirements 2.1**
    - Generate feeds with N total posts (vary N)
    - Verify first page contains exactly `min(20, N)` posts
    - _Requirements: 2.1_

  - [ ]* 10.6 Write property test for pagination cursor correctness
    - **Property 5: Pagination Cursor Correctness**
    - **Validates: Requirements 2.5**
    - Generate non-empty pages of posts
    - Verify cursor equals `id` of last post in page
    - _Requirements: 2.5_

  - [ ]* 10.7 Write property test for partial failure resilience
    - **Property 9: Partial Failure Resilience**
    - **Validates: Requirements 5.5**
    - Simulate some groups failing to load
    - Verify feed contains posts from successful groups
    - Verify feed does NOT fail completely
    - _Requirements: 5.5_

  - [ ]* 10.8 Write unit tests for `WatchMultiGroupFeed`
    - Test empty groups scenario
    - Test single group scenario
    - Test multiple groups with sorting
    - Test pagination cursor logic
    - Test concurrent limit (10 groups)
    - Test partial failure handling
    - Mock `PostRepository` and `GroupRepository` with mocktail
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 11. Enhance `PostsFeedBloc` with multi-group feed and pagination
  - [x] 11.1 Add new fields to `PostsFeedState`
    - Add `bool hasMore` (default `false`)
    - Add `String? cursor` (default `null`)
    - Add `bool isLoadingMore` (default `false`)
    - Add `Set<String> loadedGroupIds` (default empty set)
    - Update state class in `lib/features/post/presentation/bloc/posts_feed_state.dart`
    - _Requirements: 2.1, 2.2, 2.5_

  - [x] 11.2 Add new events to `PostsFeedBloc`
    - Add `PostsFeedLoadNextPage` event
    - Add `PostsFeedRefreshRequested` event
    - Add `PostsFeedPostAdded(Post post)` event for real-time additions
    - Add `PostsFeedPostUpdated(Post post)` event for real-time updates
    - Add `PostsFeedPostDeleted(String postId)` event for real-time deletions
    - Add to `lib/features/post/presentation/bloc/posts_feed_event.dart`
    - _Requirements: 2.2, 8.2, 8.3, 8.4_

  - [x] 11.3 Inject `WatchMultiGroupFeed` use case into `PostsFeedBloc`
    - Add to constructor dependencies
    - _Requirements: 1.1_

  - [x] 11.4 Update `PostsFeedSubscribeRequested` handler for multi-group scope
    - If scope is `multiGroup`, call `WatchMultiGroupFeed` with current user ID
    - Listen to stream and update state with `FeedPage` data
    - Set `posts`, `hasMore`, and `cursor` from `FeedPage`
    - Handle errors and emit error state
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.5_

  - [x] 11.5 Implement `PostsFeedLoadNextPage` event handler
    - Check if `hasMore` is `true` and not already loading more
    - Set `isLoadingMore` to `true`
    - Call `WatchMultiGroupFeed` with current `cursor`
    - Append new posts to existing `posts` list
    - Update `hasMore` and `cursor` from new `FeedPage`
    - Set `isLoadingMore` to `false`
    - Handle errors (show error, keep existing posts)
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 11.6 Implement `PostsFeedRefreshRequested` event handler
    - Reset state (clear posts, cursor, hasMore)
    - Re-subscribe to feed (call `WatchMultiGroupFeed` without cursor)
    - _Requirements: 2.6_

  - [x] 11.7 Implement real-time event handlers
    - `PostsFeedPostAdded`: Insert post at index 0 (beginning of list)
    - `PostsFeedPostUpdated`: Find post by ID and update its data
    - `PostsFeedPostDeleted`: Remove post from list by ID
    - _Requirements: 8.2, 8.3, 8.4, 8.5_

  - [ ]* 11.8 Write property test for real-time addition ordering
    - **Property 12: Real-time Addition Ordering**
    - **Validates: Requirements 8.2**
    - Generate existing feed and new post event
    - Process event
    - Verify new post appears at index 0
    - _Requirements: 8.2_

  - [ ]* 11.9 Write property test for real-time deletion completeness
    - **Property 13: Real-time Deletion Completeness**
    - **Validates: Requirements 8.3**
    - Generate existing feed and post deletion event
    - Process event
    - Verify deleted post does NOT exist in feed
    - _Requirements: 8.3_

  - [ ]* 11.10 Write property test for real-time update consistency
    - **Property 14: Real-time Update Consistency**
    - **Validates: Requirements 8.4**
    - Generate existing feed and post update event
    - Process event
    - Verify post in feed contains updated data
    - _Requirements: 8.4_

  - [ ]* 11.11 Write unit tests for enhanced `PostsFeedBloc`
    - Test multi-group subscription
    - Test pagination (load next page)
    - Test refresh
    - Test real-time add/update/delete events
    - Test error handling
    - Use `bloc_test` package
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 8.2, 8.3, 8.4, 8.5_

- [x] 12. Update `PostsFeedView` widget with pagination UI
  - [x] 12.1 Add scroll detection for pagination trigger
    - Attach `ScrollController` to list view
    - Listen for scroll position
    - When scroll reaches 80% of max extent, dispatch `PostsFeedLoadNextPage` event
    - _Requirements: 2.2_

  - [x] 12.2 Add loading indicator for pagination
    - Show circular progress indicator at bottom of list when `isLoadingMore` is `true`
    - _Requirements: 2.3_

  - [x] 12.3 Add error handling UI for pagination
    - Show error message and retry button if pagination fails
    - Dispatch `PostsFeedLoadNextPage` on retry button tap
    - _Requirements: 2.6_

  - [x] 12.4 Add empty state UI
    - Show message when feed is empty
    - Provide buttons to navigate to groups list or create post
    - Show special message if user is not in any groups
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [x] 12.5 Add offline indicator
    - Show banner at top of feed when offline
    - Display cached posts
    - Auto-hide banner when connection restored
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 12.6 Write widget tests for `PostsFeedView`
    - Test pagination trigger on scroll
    - Test loading indicators
    - Test empty state
    - Test error state
    - Test offline indicator
    - _Requirements: 2.2, 2.3, 2.6, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3_

- [x] 13. Update `HomePage` to use multi-group feed scope
  - Modify feed initialization to use `PostsFeedScope.multiGroup` instead of `PostsFeedScope.global`
  - Pass current user ID to feed subscription
  - _Requirements: 1.1_

- [x] 14. Add required dependencies to `pubspec.yaml`
  - Add `shared_preferences: ^2.2.2` for group memory
  - Add `permission_handler: ^11.0.1` for camera permissions
  - Add `image: ^4.1.3` for image cropping
  - Verify `async: ^2.11.0` is present for `StreamGroup`
  - Run `flutter pub get`
  - _Requirements: 3.3, 4.5, 6.1_

- [x] 15. Run code generation
  - Execute `dart run build_runner build --delete-conflicting-outputs`
  - Verify all `*.freezed.dart` and `*.g.dart` files are generated
  - Verify `injector.config.dart` is updated with new dependencies

- [x] 16. Checkpoint - Ensure all tests pass
  - Run `flutter test` to verify all unit and property tests pass
  - Run `flutter analyze` to ensure no lint errors
  - Ensure all tests pass, ask the user if questions arise

- [-] 17. Integration testing on device
  - [ ] 17.1 Test multi-group feed loading
    - Create test user with multiple groups
    - Add posts to different groups
    - Verify feed shows posts from all groups sorted by date
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ] 17.2 Test pagination
    - Create feed with >20 posts
    - Scroll to bottom and verify next page loads
    - Verify loading indicator appears
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ] 17.3 Test camera capture with 1:1 crop
    - Open create post page
    - Tap camera button
    - Capture photo
    - Verify photo is cropped to 1:1 aspect ratio
    - Verify photo is compressed (<5MB)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ] 17.4 Test group memory
    - Create post and select group A
    - Close app and reopen
    - Open create post page
    - Verify group A is auto-selected
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6, 4.7_

  - [ ] 17.5 Test real-time updates
    - Open feed on device A
    - Create post on device B
    - Verify post appears at top of feed on device A
    - Delete post on device B
    - Verify post disappears from feed on device A
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [ ] 17.6 Test offline support
    - Load feed with posts
    - Disable network connection
    - Verify cached posts are still visible
    - Verify offline indicator appears
    - Re-enable network
    - Verify feed updates and offline indicator disappears
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 18. Final checkpoint - Deploy to device
  - Run `flutter run -d <device_id>` to deploy to device
  - Perform manual smoke test of all features
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from design document
- Unit tests validate specific examples and edge cases
- Integration tests verify end-to-end flows on actual device
- All code follows Clean Architecture with strict layer separation
- Use `@freezed` for entities, `@injectable` for DI, `dartz` for error handling
- Run `dart run build_runner build` after creating/modifying freezed or injectable classes
