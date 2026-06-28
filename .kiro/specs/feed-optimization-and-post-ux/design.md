# Design Document: Feed Optimization and Post UX

## Overview

This design addresses two critical improvements to the Banka application:

1. **Unified Multi-Group Feed**: Optimize the main feed to display posts from all user groups with efficient loading, pagination, and real-time updates
2. **Enhanced Post Creation UX**: Streamline photo capture with camera-first approach (1:1 crop) and remember last selected group

### Current State

**Feed System:**
- `PostsFeedBloc` supports three scopes: global, group-specific, and brand-specific
- `watchFeed()` loads all posts ordered by `createdAt desc`
- No multi-group aggregation — global feed shows ALL posts, not filtered by user's groups
- Pagination infrastructure exists (`startAfterId`) but not used in UI
- Real-time updates via Firestore snapshots

**Post Creation:**
- `CreatePostPage` uses `image_picker.pickMultiImage()` for photo selection
- No automatic camera launch
- No 1:1 aspect ratio enforcement
- Group selection via modal sheet, no memory of last choice

### Design Goals

**Feed Optimization:**
- Load posts only from groups where user is a member
- Implement cursor-based pagination (20 posts per page)
- Parallel loading with connection pooling (max 10 concurrent)
- Real-time updates for new/updated/deleted posts
- Offline support with local caching
- Graceful error handling for partial failures

**Post Creation UX:**
- Camera-first photo capture with automatic 1:1 crop
- Remember last selected group using `SharedPreferences`
- Validate group membership before auto-selection
- Maintain existing compression (JPEG q=85, max 1600px)

## Architecture

### Layer Structure (Clean Architecture)

```
presentation/
├── bloc/
│   ├── posts_feed_bloc.dart          # Enhanced with multi-group logic
│   ├── create_post_bloc.dart         # Enhanced with group memory
│   └── camera_capture_bloc.dart      # NEW: Camera handling
├── pages/
│   ├── home_page.dart                # Updated feed initialization
│   └── create_post_page.dart         # Updated photo capture flow
└── widgets/
    ├── posts_feed_view.dart          # Enhanced with pagination
    └── camera_capture_view.dart      # NEW: Camera UI

domain/
├── entities/
│   └── feed_page.dart                # NEW: Pagination metadata
├── repositories/
│   ├── post_repository.dart          # Enhanced with multi-group feed
│   └── group_memory_repository.dart  # NEW: Group selection persistence
└── usecases/
    ├── watch_multi_group_feed.dart   # NEW: Multi-group aggregation
    ├── load_next_feed_page.dart      # NEW: Pagination
    ├── get_last_selected_group.dart  # NEW: Group memory read
    ├── save_last_selected_group.dart # NEW: Group memory write
    └── capture_photo_with_crop.dart  # NEW: Camera + crop

data/
├── datasources/
│   ├── post_remote_data_source.dart  # Enhanced with batch queries
│   └── group_memory_local_data_source.dart  # NEW: SharedPreferences
├── models/
│   └── feed_page_dto.dart            # NEW: Pagination DTO
└── repositories/
    ├── post_repository_impl.dart     # Enhanced implementation
    └── group_memory_repository_impl.dart  # NEW: Local storage
```

### Data Flow

#### Multi-Group Feed Loading

```
User opens HomePage
  ↓
PostsFeedBloc.add(PostsFeedSubscribeRequested(scope: multiGroup))
  ↓
WatchMultiGroupFeed.call(userId)
  ↓
1. WatchMyGroups.call(userId) → Stream<List<Group>>
2. For each group: watchGroupFeed(groupId, limit: 20)
3. Merge streams with StreamGroup
4. Sort by createdAt desc
5. Apply pagination cursor
  ↓
Stream<Either<Failure, FeedPage>> → PostsFeedBloc
  ↓
PostsFeedState(posts, hasMore, cursor)
  ↓
PostsFeedView renders with pagination
```

#### Pagination Flow

```
User scrolls to bottom
  ↓
PostsFeedView detects scroll threshold (80%)
  ↓
PostsFeedBloc.add(PostsFeedLoadNextPage())
  ↓
LoadNextFeedPage.call(cursor: lastPostId)
  ↓
For each group: watchGroupFeed(groupId, startAfterId: cursor, limit: 20)
  ↓
Merge + sort new batch
  ↓
Append to existing posts
  ↓
Update state with new cursor
```

#### Camera Capture Flow

```
User taps "Add Photo" button
  ↓
CameraCaptureBloc.add(CameraCaptureRequested())
  ↓
CapturePhotoWithCrop.call(aspectRatio: 1.0)
  ↓
1. Check camera permission
2. image_picker.pickImage(source: camera, maxWidth: 1600, maxHeight: 1600)
3. Apply 1:1 crop using image package
4. Compress JPEG (q=85)
5. Validate size (<5MB)
  ↓
Return File
  ↓
CreatePostBloc.add(CreatePostPhotosPicked([file]))
```

#### Group Memory Flow

```
User opens CreatePostPage
  ↓
CreatePostBloc.add(CreatePostInitialized())
  ↓
GetLastSelectedGroup.call()
  ↓
SharedPreferences.getString('last_selected_group_id')
  ↓
If exists: Validate membership via WatchMyGroups
  ↓
If valid: Auto-select group
If invalid: Clear stored value
  ↓
CreatePostState(groupId: auto-selected)

---

User publishes post
  ↓
CreatePostBloc.add(CreatePostSubmitted())
  ↓
After successful creation:
SaveLastSelectedGroup.call(groupId)
  ↓
SharedPreferences.setString('last_selected_group_id', groupId)
```

## Components and Interfaces

### 1. Enhanced PostsFeedBloc

**Responsibilities:**
- Subscribe to multi-group feed stream
- Handle pagination events
- Manage loading/error states
- Cache loaded posts
- Handle real-time updates (add/update/delete)

**New Events:**
```dart
sealed class PostsFeedEvent {
  // Existing
  const PostsFeedSubscribeRequested(PostsFeedScope scope);
  const PostsFeedResetRequested();
  
  // NEW
  const PostsFeedLoadNextPage();
  const PostsFeedRefreshRequested();
  const PostsFeedPostAdded(Post post);      // Real-time add
  const PostsFeedPostUpdated(Post post);    // Real-time update
  const PostsFeedPostDeleted(String postId); // Real-time delete
}
```

**Enhanced State:**
```dart
class PostsFeedState {
  final PostsFeedStatus status;
  final PostsFeedScope? scope;
  final List<Post> posts;
  final String? errorMessage;
  final bool hasMore;              // NEW: Pagination flag
  final String? cursor;            // NEW: Last post ID
  final bool isLoadingMore;        // NEW: Loading next page
  final Set<String> loadedGroupIds; // NEW: Track loaded groups
}
```

### 2. WatchMultiGroupFeed UseCase

**Purpose:** Aggregate posts from all user groups into unified feed

**Interface:**
```dart
@lazySingleton
class WatchMultiGroupFeed {
  const WatchMultiGroupFeed(
    this._postRepository,
    this._groupRepository,
  );

  final PostRepository _postRepository;
  final GroupRepository _groupRepository;

  ResultStream<FeedPage> call(WatchMultiGroupFeedParams params) async* {
    // 1. Get user's groups
    await for (final groupsResult in _groupRepository.watchMyGroups(params.userId)) {
      yield* groupsResult.fold(
        (failure) async* { yield Left(failure); },
        (groups) async* {
          if (groups.isEmpty) {
            yield Right(FeedPage.empty());
            return;
          }

          // 2. Create stream for each group (max 10 concurrent)
          final groupIds = groups.map((g) => g.id).toList();
          final streams = groupIds.take(10).map((groupId) =>
            _postRepository.watchGroupFeed(
              groupId: groupId,
              limit: params.limit,
              startAfterId: params.cursor,
            ),
          );

          // 3. Merge streams
          final merged = StreamGroup.merge(streams);
          
          // 4. Aggregate and sort
          await for (final result in merged) {
            yield* result.fold(
              (failure) async* { yield Left(failure); },
              (posts) async* {
                // Sort by createdAt desc
                posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                
                // Apply limit
                final page = posts.take(params.limit).toList();
                final hasMore = posts.length >= params.limit;
                final cursor = page.isNotEmpty ? page.last.id : null;
                
                yield Right(FeedPage(
                  posts: page,
                  hasMore: hasMore,
                  cursor: cursor,
                ));
              },
            );
          }
        },
      );
    }
  }
}

class WatchMultiGroupFeedParams {
  const WatchMultiGroupFeedParams({
    required this.userId,
    this.limit = 20,
    this.cursor,
  });

  final String userId;
  final int limit;
  final String? cursor;
}
```

### 3. FeedPage Entity

**Purpose:** Encapsulate paginated feed data

```dart
@freezed
class FeedPage with _$FeedPage {
  const factory FeedPage({
    required List<Post> posts,
    required bool hasMore,
    String? cursor,
  }) = _FeedPage;

  factory FeedPage.empty() => const FeedPage(
    posts: [],
    hasMore: false,
  );
}
```

### 4. GroupMemoryRepository

**Purpose:** Persist and retrieve last selected group

**Interface:**
```dart
abstract interface class GroupMemoryRepository {
  ResultFuture<String?> getLastSelectedGroup();
  ResultFuture<void> saveLastSelectedGroup(String groupId);
  ResultFuture<void> clearLastSelectedGroup();
}
```

**Implementation:**
```dart
@LazySingleton(as: GroupMemoryRepository)
class GroupMemoryRepositoryImpl implements GroupMemoryRepository {
  const GroupMemoryRepositoryImpl(this._local);

  final GroupMemoryLocalDataSource _local;

  @override
  ResultFuture<String?> getLastSelectedGroup() async {
    try {
      final groupId = await _local.getLastSelectedGroup();
      return Right(groupId);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> saveLastSelectedGroup(String groupId) async {
    try {
      await _local.saveLastSelectedGroup(groupId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> clearLastSelectedGroup() async {
    try {
      await _local.clearLastSelectedGroup();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
```

### 5. GroupMemoryLocalDataSource

**Purpose:** SharedPreferences wrapper for group memory

```dart
abstract interface class GroupMemoryLocalDataSource {
  Future<String?> getLastSelectedGroup();
  Future<void> saveLastSelectedGroup(String groupId);
  Future<void> clearLastSelectedGroup();
}

@LazySingleton(as: GroupMemoryLocalDataSource)
class SharedPrefsGroupMemoryDataSource implements GroupMemoryLocalDataSource {
  const SharedPrefsGroupMemoryDataSource(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'last_selected_group_id';

  @override
  Future<String?> getLastSelectedGroup() async {
    return _prefs.getString(_key);
  }

  @override
  Future<void> saveLastSelectedGroup(String groupId) async {
    await _prefs.setString(_key, groupId);
  }

  @override
  Future<void> clearLastSelectedGroup() async {
    await _prefs.remove(_key);
  }
}
```

### 6. CapturePhotoWithCrop UseCase

**Purpose:** Handle camera capture with 1:1 aspect ratio

```dart
@lazySingleton
class CapturePhotoWithCrop {
  const CapturePhotoWithCrop(this._picker, this._compressor);

  final ImagePicker _picker;
  final ImageCompressor _compressor;

  ResultFuture<File> call() async {
    try {
      // 1. Check camera permission
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final requested = await Permission.camera.request();
        if (!requested.isGranted) {
          return Left(PermissionFailure(message: 'Camera permission denied'));
        }
      }

      // 2. Capture photo with max dimensions
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 100, // Compress later
      );

      if (xFile == null) {
        return Left(CancelledFailure(message: 'User cancelled'));
      }

      // 3. Load image for cropping
      final bytes = await xFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return Left(ValidationFailure(message: 'Invalid image'));
      }

      // 4. Crop to 1:1 (center crop)
      final size = min(image.width, image.height);
      final offsetX = (image.width - size) ~/ 2;
      final offsetY = (image.height - size) ~/ 2;
      final cropped = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: size,
        height: size,
      );

      // 5. Compress JPEG (q=85)
      final compressed = img.encodeJpg(cropped, quality: 85);

      // 6. Validate size (<5MB)
      if (compressed.length > 5 * 1024 * 1024) {
        return Left(ValidationFailure(message: 'Image exceeds 5MB'));
      }

      // 7. Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(compressed);

      return Right(file);
    } on PlatformException catch (e) {
      return Left(PlatformFailure(message: e.message ?? e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
```

### 7. Enhanced CreatePostBloc

**New Initialization Logic:**
```dart
Future<void> _onInitialized(
  CreatePostInitialized event,
  Emitter<CreatePostState> emit,
) async {
  emit(state.copyWith(
    authorId: event.authorId,
    authorName: event.authorName,
    authorPhotoUrl: event.authorPhotoUrl,
  ));

  // Auto-select group if provided (from group detail page)
  if (event.groupId != null) {
    emit(state.copyWith(
      groupId: event.groupId,
      groupName: event.groupName,
    ));
    return;
  }

  // Otherwise, try to load last selected group
  final result = await _getLastSelectedGroup();
  result.fold(
    (_) {}, // Ignore errors, just don't auto-select
    (groupId) async {
      if (groupId == null) return;

      // Validate membership
      final groups = await _watchMyGroups(event.authorId).first;
      groups.fold(
        (_) {},
        (myGroups) {
          final group = myGroups.firstWhereOrNull((g) => g.id == groupId);
          if (group != null) {
            emit(state.copyWith(
              groupId: group.id,
              groupName: group.name,
            ));
          } else {
            // Group no longer exists or user not a member
            _clearLastSelectedGroup();
          }
        },
      );
    },
  );
}
```

**Save Group on Submit:**
```dart
Future<void> _onSubmitted(
  CreatePostSubmitted event,
  Emitter<CreatePostState> emit,
) async {
  // ... existing creation logic ...

  final result = await _createPost(params);
  result.fold(
    (failure) => emit(state.copyWith(
      status: CreatePostStatus.error,
      errorMessage: failure.message,
    )),
    (post) async {
      // Save last selected group
      if (state.groupId != null) {
        await _saveLastSelectedGroup(state.groupId!);
      }

      emit(state.copyWith(
        status: CreatePostStatus.created,
        createdPostId: post.id,
      ));
    },
  );
}
```

## Data Models

### FeedPage DTO

```dart
class FeedPageDto {
  const FeedPageDto({
    required this.posts,
    required this.hasMore,
    this.cursor,
  });

  final List<PostDto> posts;
  final bool hasMore;
  final String? cursor;

  FeedPage toDomain() => FeedPage(
    posts: posts.map((dto) => dto.toDomain()).toList(),
    hasMore: hasMore,
    cursor: cursor,
  );

  static FeedPageDto fromDomain(FeedPage page) => FeedPageDto(
    posts: page.posts.map(PostDto.fromDomain).toList(),
    hasMore: page.hasMore,
    cursor: page.cursor,
  );
}
```

## Error Handling

### Feed Loading Errors

**Partial Group Failure:**
- If one group query fails, continue loading others
- Display partial results with warning banner
- Log failed group IDs for debugging

**Complete Failure:**
- Show error state with retry button
- Preserve cached posts if available
- Offer offline mode

**Network Errors:**
- Detect offline state
- Switch to cached data
- Show offline indicator
- Auto-retry when connection restored

### Camera Errors

**Permission Denied:**
- Show dialog explaining camera need
- Provide "Open Settings" button
- Fallback to gallery picker

**Capture Cancelled:**
- Return to create post page
- No error message (user action)

**Image Processing Errors:**
- Show error snackbar
- Allow retry
- Log error details

### Group Memory Errors

**Read Failure:**
- Log error
- Continue without auto-selection
- Don't block user flow

**Write Failure:**
- Log error
- Don't show to user
- Retry on next successful post

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Feed Group Membership

*For any* user and their set of groups, all posts in the loaded feed SHALL have a `groupId` that exists in the user's group membership list.

**Validates: Requirements 1.1**

### Property 2: Feed Completeness Without Duplicates

*For any* set of groups and their posts, the merged feed SHALL contain all posts from all groups exactly once (no duplicates, no missing posts).

**Validates: Requirements 1.2**

### Property 3: Feed Chronological Ordering

*For any* set of posts with timestamps, the feed SHALL be sorted in descending order by `createdAt` (newest first).

**Validates: Requirements 1.3, 5.4**

### Property 4: Pagination Page Size

*For any* feed with N total posts, the first page SHALL contain exactly `min(20, N)` posts.

**Validates: Requirements 2.1**

### Property 5: Pagination Cursor Correctness

*For any* non-empty page of posts, the pagination cursor SHALL equal the `id` of the last post in that page.

**Validates: Requirements 2.5**

### Property 6: Image Aspect Ratio Preservation

*For any* captured image, after applying 1:1 crop, the output image SHALL have `width == height`.

**Validates: Requirements 3.3, 7.3**

### Property 7: Photo Count Constraint

*For any* sequence of photo addition operations, the resulting photo list SHALL never exceed 6 items.

**Validates: Requirements 3.6**

### Property 8: Invalid Group Cleanup

*For any* stored group ID and user's current group list, if the stored ID is not in the user's groups, it SHALL be cleared from storage.

**Validates: Requirements 4.4**

### Property 9: Partial Failure Resilience

*For any* set of groups where some fail to load, the feed SHALL contain posts from all successfully loaded groups and SHALL NOT fail completely.

**Validates: Requirements 5.5**

### Property 10: Image Dimension Constraint

*For any* processed image, the maximum dimension (max of width and height) SHALL be less than or equal to 1600 pixels.

**Validates: Requirements 7.2**

### Property 11: File Size Validation

*For any* compressed image file, if the file size exceeds 5 MB, it SHALL be rejected with a validation error.

**Validates: Requirements 7.5**

### Property 12: Real-time Addition Ordering

*For any* existing feed and new post event, after processing the event, the new post SHALL appear at index 0 (first position) in the feed.

**Validates: Requirements 8.2**

### Property 13: Real-time Deletion Completeness

*For any* existing feed and post deletion event, after processing the event, the deleted post SHALL NOT exist in the feed.

**Validates: Requirements 8.3**

### Property 14: Real-time Update Consistency

*For any* existing feed and post update event, after processing the event, the post in the feed SHALL contain the updated data fields.

**Validates: Requirements 8.4**

## Testing Strategy

### Property-Based Tests

All correctness properties above SHALL be implemented as property-based tests using the appropriate PBT library for Dart (e.g., `test` package with custom generators or `faker` for data generation).

**Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with: `Feature: feed-optimization-and-post-ux, Property {number}: {property_text}`
- Use custom generators for: User, Group, Post, Image, FeedPage

**Example Test Structure:**
```dart
test(
  'Property 3: Feed Chronological Ordering',
  () {
    // Tag: Feature: feed-optimization-and-post-ux, Property 3: Feed is sorted by createdAt descending
    
    for (int i = 0; i < 100; i++) {
      // Generate random posts with random timestamps
      final posts = generateRandomPosts(count: Random().nextInt(50) + 1);
      
      // Sort using feed logic
      final sorted = feedSorter.sort(posts);
      
      // Verify descending order
      for (int j = 0; j < sorted.length - 1; j++) {
        expect(
          sorted[j].createdAt.isAfter(sorted[j + 1].createdAt) ||
          sorted[j].createdAt.isAtSameMomentAs(sorted[j + 1].createdAt),
          isTrue,
          reason: 'Post at index $j should be newer than or equal to post at ${j + 1}',
        );
      }
    }
  },
);
```

### Unit Tests

**PostsFeedBloc:**
- Multi-group subscription
- Pagination logic
- Real-time update handling
- Error state management
- Cache behavior

**WatchMultiGroupFeed:**
- Stream merging
- Sorting logic
- Pagination cursor
- Concurrent limit (10)
- Empty groups handling

**CreatePostBloc:**
- Group memory initialization
- Auto-selection validation
- Save on submit

**CapturePhotoWithCrop:**
- Permission handling
- 1:1 crop logic
- Compression
- Size validation

**GroupMemoryRepository:**
- SharedPreferences read/write
- Error handling

### Integration Tests

**Feed Loading:**
- Load posts from multiple groups
- Verify sorting (createdAt desc)
- Test pagination (load more)
- Real-time updates (add/update/delete)

**Post Creation:**
- Camera capture flow
- Group auto-selection
- Group memory persistence

### Widget Tests

**PostsFeedView:**
- Pagination trigger (scroll threshold)
- Loading indicators
- Empty state
- Error state

**CreatePostPage:**
- Camera button behavior
- Group auto-selection display
- Photo grid with cropped images

## Performance Considerations

### Feed Optimization

**Connection Pooling:**
- Limit concurrent Firestore queries to 10
- Use `StreamGroup.merge()` for efficient multiplexing
- Cancel streams on dispose

**Caching Strategy:**
- Cache loaded posts in BLoC state
- Use Firestore offline persistence
- Implement memory-efficient pagination

**Real-time Updates:**
- Use Firestore snapshots for live data
- Debounce rapid updates (100ms)
- Batch UI updates with `setState()`

### Image Processing

**Compression:**
- JPEG quality 85 (balance size/quality)
- Max dimension 1600px
- Target <5MB per image

**Async Processing:**
- Run crop/compress in isolate
- Show progress indicator
- Cancel on navigation

## Security Considerations

### Firestore Rules

**Multi-Group Feed:**
```javascript
// Existing rule - no changes needed
match /posts/{postId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null 
    && request.resource.data.authorId == request.auth.uid;
}
```

**Group Membership Validation:**
- Client validates membership before auto-selecting group
- Server validates on post creation (existing rule)

### Local Storage

**SharedPreferences:**
- Store only group ID (no sensitive data)
- Clear on logout (handled by app reset)

## Migration Strategy

### Phase 1: Feed Enhancement (Sprint 15)

1. Add `FeedPage` entity and DTO
2. Implement `WatchMultiGroupFeed` usecase
3. Enhance `PostsFeedBloc` with pagination
4. Update `PostsFeedView` with scroll detection
5. Add loading/error states

### Phase 2: Post UX (Sprint 15)

1. Add `GroupMemoryRepository` and data source
2. Implement `CapturePhotoWithCrop` usecase
3. Enhance `CreatePostBloc` with group memory
4. Update `CreatePostPage` with camera button
5. Add permission handling

### Phase 3: Testing & Polish (Sprint 15)

1. Unit tests for all new components
2. Integration tests for feed and post creation
3. Performance profiling
4. Error handling refinement

## Dependencies

### New Packages

```yaml
dependencies:
  shared_preferences: ^2.2.2  # Group memory
  permission_handler: ^11.0.1 # Camera permissions
  image: ^4.1.3               # Image cropping
  stream_transform: ^2.1.0    # Stream utilities (existing)
  async: ^2.11.0              # StreamGroup (existing)

dev_dependencies:
  mocktail: ^1.0.1            # Mocking (existing)
  bloc_test: ^9.1.5           # BLoC testing (existing)
```

### Existing Packages (No Changes)

- `image_picker`: Photo capture
- `flutter_image_compress`: Compression (if needed)
- `cloud_firestore`: Backend
- `flutter_bloc`: State management
- `dartz`: Functional error handling
- `get_it` + `injectable`: DI

## Open Questions

1. **Feed Refresh Strategy**: Should we implement pull-to-refresh or rely on real-time updates?
   - **Decision**: Implement pull-to-refresh for manual control, keep real-time for automatic updates

2. **Pagination Page Size**: Is 20 posts per page optimal?
   - **Decision**: Start with 20, monitor performance, adjust if needed

3. **Camera Preview**: Should we show preview before accepting photo?
   - **Decision**: Yes, use `image_picker` built-in preview

4. **Group Memory Scope**: Should we remember group per-user or globally?
   - **Decision**: Per-device (SharedPreferences), cleared on logout

5. **Offline Post Creation**: Should we queue posts for later upload?
   - **Decision**: Out of scope for this sprint, show error if offline

## Future Enhancements (Out of Scope)

- **Smart Feed Ranking**: ML-based post ranking by user interests
- **Infinite Scroll**: Automatic pagination without "Load More" button
- **Feed Filters**: Filter by rarity, brand, date range
- **Draft Posts**: Save incomplete posts locally
- **Batch Upload**: Queue multiple posts for background upload
- **Feed Personalization**: User preferences for feed content
- **Advanced Camera**: Manual focus, flash control, filters

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Status**: Ready for Review
