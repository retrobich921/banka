# Implementation Plan: User Username System

## Overview

This implementation plan breaks down the User Username System feature into discrete coding tasks following Clean Architecture layers (Domain → Data → Presentation). The system introduces unique usernames for all users, replacing displayName throughout the app, with automatic generation, validation, cooldown enforcement, and denormalized data propagation via Cloud Functions.

## Tasks

- [x] 1. Set up domain entities and value objects
  - Create `UserProfile` entity with new username fields (`username`, `usernameLowercase`, `usernameLastChangedAt`)
  - Create `UsernameValidationResult` sealed class with variants: `valid`, `invalid`, `taken`, `cooldownActive`
  - Update existing `UserProfile` freezed model in `lib/features/user/domain/entities/user_profile.dart`
  - _Requirements: 1.4, 1.5, 4.5, 5.1, 9.1_

- [ ]* 1.1 Write property test for UserProfile entity
  - **Property 4: Username Persistence Round-Trip**
  - **Validates: Requirements 1.4, 4.5, 9.1**
  - Test that username, usernameLowercase, and usernameLastChangedAt fields serialize/deserialize correctly

- [x] 2. Implement domain repository interface
  - Extend `UserRepository` interface with username-specific methods
  - Add `isUsernameAvailable(String username)` method
  - Add `generateUniqueUsername(String? displayName)` method
  - Add `validateUsername(String username, String userId)` method
  - Add `updateUsername(String userId, String newUsername)` method
  - Update `lib/features/user/domain/repositories/user_repository.dart`
  - _Requirements: 1.3, 3.1, 3.5, 4.3_

- [x] 3. Implement username generation use case
  - [x] 3.1 Create `GenerateUsername` use case with `GenerateUsernameParams`
    - Implement sanitization logic (remove special chars, lowercase, truncate to 20)
    - Implement fallback logic (append numbers 1-999, then random user_XXXXXX)
    - Validate format and uniqueness before returning
    - Create file `lib/features/user/domain/usecases/generate_username.dart`
    - _Requirements: 1.1, 1.2, 1.5_

  - [ ]* 3.2 Write property test for username generation
    - **Property 1: Generated Username Format Invariant**
    - **Validates: Requirements 1.5**
    - Test that all generated usernames match format: 3-20 chars, alphanumeric + underscore, not starting with digit

  - [ ]* 3.3 Write property test for displayName sanitization
    - **Property 2: Username Generation from DisplayName**
    - **Validates: Requirements 1.1, 1.2**
    - Test that displayName is correctly sanitized or falls back to user_XXXXXX format

- [ ] 4. Implement username validation use case
  - [x] 4.1 Create `ValidateUsername` use case with `ValidateUsernameParams`
    - Implement format validation (length 3-20, valid chars, not starting with digit, not all digits)
    - Implement uniqueness check (case-insensitive via repository)
    - Implement cooldown check (30 days = 2,592,000 seconds)
    - Allow user to keep their current username unchanged
    - Create file `lib/features/user/domain/usecases/validate_username.dart`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.4, 4.3, 4.4, 5.2, 5.3, 5.4_

  - [ ]* 4.2 Write property test for format validation
    - **Property 5: Format Validation Rules**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
    - Test that validator correctly identifies valid/invalid formats

  - [ ]* 4.3 Write property test for cooldown enforcement
    - **Property 8: Cooldown Period Enforcement**
    - **Validates: Requirements 4.3, 4.4, 5.2, 5.3**
    - Test that changes within 30 days are rejected with cooldown error

  - [ ]* 4.4 Write property test for first change allowance
    - **Property 9: First Change Allowance**
    - **Validates: Requirements 5.4**
    - Test that users with null usernameLastChangedAt can change without cooldown

  - [ ]* 4.5 Write unit tests for validation error messages
    - **Property 6: Validation Error Messages**
    - **Validates: Requirements 2.5, 3.3**
    - Test that appropriate error messages are returned for each validation failure

- [x] 5. Implement username update use case
  - [x] 5.1 Create `UpdateUsername` use case with `UpdateUsernameParams`
    - Call `ValidateUsername` use case first
    - Call repository `updateUsername` method
    - Handle validation failures and return appropriate errors
    - Create file `lib/features/user/domain/usecases/update_username.dart`
    - _Requirements: 4.3, 4.5, 5.5_

  - [ ]* 5.2 Write property test for timestamp update
    - **Property 10: Timestamp Update on Change**
    - **Validates: Requirements 5.1**
    - Test that usernameLastChangedAt is updated on successful change

- [ ] 6. Checkpoint - Ensure domain layer tests pass
  - Run `flutter test test/features/user/domain/`
  - Ensure all domain use cases are working correctly
  - Ask the user if questions arise

- [x] 7. Implement data layer DTOs and models
  - [x] 7.1 Update `UserProfileDto` with username fields
    - Add `username`, `usernameLowercase`, `usernameLastChangedAt` to `fromSnapshot` method
    - Add username fields to `toMap` method with proper Timestamp conversion
    - Update file `lib/features/user/data/models/user_profile_dto.dart`
    - _Requirements: 1.4, 4.5, 9.1, 9.2_

  - [ ]* 7.2 Write unit tests for DTO serialization
    - Test round-trip serialization with username fields
    - Test handling of null usernameLastChangedAt
    - Test usernameLowercase is correctly set

- [x] 8. Implement data layer remote data source
  - [x] 8.1 Extend `UserRemoteDataSource` interface
    - Add `isUsernameAvailable(String username)` method signature
    - Add `updateUsername(String userId, String newUsername)` method signature
    - Add `getUserByUsername(String username)` method signature
    - Update file `lib/features/user/data/datasources/user_remote_datasource.dart`
    - _Requirements: 3.1, 3.2, 4.5, 9.3_

  - [x] 8.2 Implement Firestore data source methods
    - Implement `isUsernameAvailable` with case-insensitive query on `usernameLowercase`
    - Implement `updateUsername` with batch update of username, usernameLowercase, usernameLastChangedAt
    - Implement `getUserByUsername` with query on `usernameLowercase`
    - Update file `lib/features/user/data/datasources/firestore_user_remote_datasource.dart`
    - _Requirements: 3.1, 3.2, 3.5, 4.5, 9.1, 9.2, 9.3_

  - [ ]* 8.3 Write unit tests for data source
    - Mock Firestore and test query construction
    - Test error handling and exception mapping
    - Test batch update logic

- [ ] 9. Implement data layer repository
  - [x] 9.1 Implement username methods in `UserRepositoryImpl`
    - Implement `isUsernameAvailable` by calling data source
    - Implement `generateUniqueUsername` with retry logic (up to 10 attempts)
    - Implement `validateUsername` with format, uniqueness, and cooldown checks
    - Implement `updateUsername` with validation and data source call
    - Map exceptions to appropriate Failure types
    - Update file `lib/features/user/data/repositories/user_repository_impl.dart`
    - _Requirements: 1.1, 1.2, 1.3, 2.1-2.5, 3.1-3.4, 4.3-4.5, 5.1-5.5_

  - [ ]* 9.2 Write property test for uniqueness guarantee
    - **Property 3: Username Uniqueness Guarantee**
    - **Validates: Requirements 1.3, 3.1, 3.2**
    - Test that uniqueness is verified before allowing operations

  - [ ]* 9.3 Write property test for current username preservation
    - **Property 7: Current Username Preservation**
    - **Validates: Requirements 3.4**
    - Test that users can save profile with unchanged username

  - [ ]* 9.4 Write unit tests for repository error handling
    - Test exception to Failure mapping
    - Test retry logic in generateUniqueUsername
    - Test cooldown calculation edge cases

- [ ] 10. Checkpoint - Ensure data layer tests pass
  - Run `flutter test test/features/user/data/`
  - Ensure all data layer components work correctly
  - Ask the user if questions arise

- [x] 11. Implement presentation layer BLoC events
  - Add `ProfileUsernameChanged` event with username field
  - Add `ProfileUsernameValidationRequested` event with username field
  - Add `ProfileSaveRequested` event
  - Update file `lib/features/user/presentation/bloc/profile_event.dart`
  - _Requirements: 4.1, 4.2_

- [x] 12. Implement presentation layer BLoC state
  - Add `usernameValidation` field of type `UsernameValidationResult?`
  - Add `isValidatingUsername` boolean field
  - Add `isSaving` boolean field
  - Update file `lib/features/user/presentation/bloc/profile_state.dart`
  - _Requirements: 4.2, 4.6_

- [x] 13. Implement presentation layer BLoC logic
  - [x] 13.1 Handle `ProfileUsernameChanged` event
    - Debounce username input (300ms)
    - Trigger validation use case
    - Emit state with validation result
    - Update file `lib/features/user/presentation/bloc/profile_bloc.dart`
    - _Requirements: 4.2_

  - [x] 13.2 Handle `ProfileSaveRequested` event
    - Call `UpdateUsername` use case
    - Handle success and error cases
    - Emit appropriate states
    - _Requirements: 4.3, 4.4, 4.5_

  - [ ]* 13.3 Write BLoC tests
    - Test username validation flow
    - Test save flow with success/error cases
    - Test cooldown error handling
    - Use `bloc_test` package

- [ ] 14. Implement profile edit UI
  - [x] 14.1 Add username text field to ProfileEditPage
    - Add TextFormField with label "Username"
    - Add helper text: "3-20 символов: буквы, цифры, подчёркивание"
    - Wire up to `ProfileUsernameChanged` event
    - Display validation icon (check/error/loading)
    - Update file `lib/features/user/presentation/pages/profile_edit_page.dart`
    - _Requirements: 4.1, 4.2, 10.1, 10.2_

  - [x] 14.2 Add validation error display
    - Show error text based on `UsernameValidationResult`
    - Map validation results to Russian error messages
    - _Requirements: 4.2, 10.1, 10.2, 10.3_

  - [x] 14.3 Add cooldown warning banner
    - Display warning when cooldown is active
    - Show next available date in format "dd.MM.yyyy"
    - Style with orange color and info icon
    - _Requirements: 4.6, 10.3_

  - [ ]* 14.4 Write widget tests for profile edit UI
    - Test username field rendering
    - Test validation feedback display
    - Test cooldown warning display

- [ ] 15. Update username display throughout the app
  - [x] 15.1 Update GroupMember display widgets
    - Replace displayName with username in member lists
    - Add fallback to displayName if username is empty
    - Update relevant widgets in `lib/features/group/presentation/widgets/`
    - _Requirements: 6.1, 6.6_

  - [x] 15.2 Update Comment display widgets
    - Replace displayName with username in comment cards
    - Add fallback to displayName if username is empty
    - Update relevant widgets in `lib/features/comment/presentation/widgets/`
    - _Requirements: 6.2, 6.6_

  - [x] 15.3 Update Post display widgets
    - Replace authorName (displayName) with username in post cards
    - Add fallback to displayName if username is empty
    - Update relevant widgets in `lib/features/post/presentation/widgets/`
    - _Requirements: 6.3, 6.6_

  - [x] 15.4 Update User Profile Page
    - Display username in profile header
    - Update file `lib/features/user/presentation/pages/user_profile_page.dart`
    - _Requirements: 6.4, 8.1_

  - [ ] 15.5 Update Search results display
    - Replace displayName with username in search result items
    - Add fallback to displayName if username is empty
    - Update relevant widgets in `lib/features/search/presentation/widgets/`
    - _Requirements: 6.5, 6.6_

  - [ ]* 15.6 Write property test for username display consistency
    - **Property 11: Username Display Consistency**
    - **Validates: Requirements 6.1-6.6**
    - Test that username is displayed with displayName fallback across all UI components

- [x] 16. Implement profile page edit button visibility
  - Add conditional rendering: show edit button only if profile.id == currentUser.id
  - Update file `lib/features/user/presentation/pages/user_profile_page.dart`
  - _Requirements: 8.5, 8.6_

- [ ]* 16.1 Write property test for edit button visibility
  - **Property 13: Profile Edit Button Visibility**
  - **Validates: Requirements 8.5, 8.6**
  - Test that edit button is visible if and only if viewing own profile

- [ ] 17. Implement profile page statistics display
  - Display cansCount, likesReceived, groupsCount, avgRarity, topBrandId
  - Update file `lib/features/user/presentation/pages/user_profile_page.dart`
  - _Requirements: 8.3, 8.4_

- [ ]* 17.1 Write property test for stats display
  - **Property 15: Stats Display Completeness**
  - **Validates: Requirements 8.3, 8.4**
  - Test that all statistics are displayed on profile page

- [ ] 18. Implement profile page posts display
  - Load posts with filter `authorId == userId`
  - Order posts chronologically (newest first)
  - Update file `lib/features/user/presentation/pages/user_profile_page.dart`
  - _Requirements: 8.2, 8.7_

- [ ]* 18.1 Write property test for chronological ordering
  - **Property 14: Chronological Post Ordering**
  - **Validates: Requirements 8.2**
  - Test that posts are ordered newest first

- [ ] 19. Checkpoint - Ensure presentation layer tests pass
  - Run `flutter test test/features/user/presentation/`
  - Manually test profile edit flow in app
  - Ask the user if questions arise

- [ ] 20. Implement username generation on login
  - [ ] 20.1 Add username check in AuthBloc after successful login
    - Check if user.username is empty or null
    - Call `GenerateUsername` use case if needed
    - Call `UpdateUsername` use case to save generated username
    - Update file `lib/features/auth/presentation/bloc/auth_bloc.dart`
    - _Requirements: 7.1, 7.2_

  - [ ]* 20.2 Write property test for migration trigger
    - **Property 12: Migration Trigger on Login**
    - **Validates: Requirements 7.1, 7.2**
    - Test that username is generated when absent on login

- [ ] 21. Implement username prefix search
  - [ ] 21.1 Add search method to UserRepository
    - Add `searchUsersByUsername(String prefix, int limit)` method
    - Use Firestore query with `startAt` and `endAt` on `usernameLowercase`
    - Limit results to 20 for autocomplete
    - Update files in `lib/features/user/domain/repositories/` and `lib/features/user/data/`
    - _Requirements: 9.5_

  - [ ]* 21.2 Write property test for prefix search
    - **Property 16: Prefix Search Functionality**
    - **Validates: Requirements 9.5**
    - Test that search returns all usernames starting with prefix (case-insensitive)

- [ ] 22. Implement Cloud Functions for denormalized data propagation
  - [ ] 22.1 Create `onUsernameChanged` Cloud Function
    - Trigger on `users/{userId}` update where username changes
    - Query all posts, comments, and group members for the user
    - Update `authorName` and `displayName` fields in batches of 500
    - Handle batch splitting for >500 documents
    - Add error logging and retry logic
    - Create/update file `functions/index.js`
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 12.3, 12.4, 12.5_

  - [ ]* 22.2 Write property test for batch splitting
    - **Property 17: Batch Operation Splitting**
    - **Validates: Requirements 11.4**
    - Test that updates affecting >500 documents are split into multiple batches

  - [ ] 22.3 Create `generateUsernameOnSignup` Cloud Function
    - Trigger on `users/{userId}` create
    - Skip if username already set
    - Generate username from displayName with sanitization
    - Check uniqueness and retry with alternatives
    - Update user document with username and usernameLowercase
    - Add error logging
    - Update file `functions/index.js`
    - _Requirements: 1.1, 1.2, 1.3, 7.1, 7.2_

  - [ ] 22.4 Add helper functions for username generation
    - Implement `sanitizeDisplayName(displayName)` function
    - Implement `isUsernameTaken(username)` function
    - Update file `functions/index.js`
    - _Requirements: 1.1, 1.2_

- [ ] 23. Update Post and Comment creation to use username
  - [ ] 23.1 Update Post creation to store username in authorName
    - Modify `CreatePost` use case to use `user.username` instead of `user.displayName`
    - Update file `lib/features/post/domain/usecases/create_post.dart`
    - _Requirements: 12.1_

  - [ ] 23.2 Update Comment creation to store username in authorName
    - Modify `CreateComment` use case to use `user.username` instead of `user.displayName`
    - Update file `lib/features/comment/domain/usecases/create_comment.dart`
    - _Requirements: 12.2_

  - [ ]* 23.3 Write property test for denormalized data persistence
    - **Property 18: Denormalized Data Persistence**
    - **Validates: Requirements 12.1, 12.2**
    - Test that username is stored in authorName field on creation

- [ ] 24. Update Firestore Security Rules
  - Add username validation rules to users collection
  - Validate format: 3-20 chars, alphanumeric + underscore, not starting with digit
  - Validate usernameLowercase matches username.toLowerCase()
  - Validate cooldown period (30 days = 2,592,000,000 ms)
  - Update file `firestore.rules`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.3, 4.4, 5.2, 5.3, 9.2_

- [ ] 25. Update Firestore indexes
  - Add single-field index on `users.usernameLowercase` (ascending)
  - Add composite index on `users.usernameLowercase` (ascending) + `users.createdAt` (descending)
  - Add collection group index on `members.userId` (ascending)
  - Add collection group index on `comments.authorId` (ascending)
  - Update file `firestore.indexes.json`
  - _Requirements: 3.5, 9.3, 9.4, 11.1_

- [ ] 26. Deploy Firestore configuration
  - Run `firebase deploy --only firestore:rules,firestore:indexes`
  - Verify indexes are created in Firebase Console
  - _Requirements: 3.5, 9.4_

- [ ] 27. Deploy Cloud Functions
  - Run `cd functions && npm install`
  - Run `firebase deploy --only functions`
  - Verify functions are deployed in Firebase Console
  - Test function triggers manually
  - _Requirements: 7.2, 11.1-11.4, 12.3-12.5_

- [ ] 28. Run code generation
  - Run `dart run build_runner build --delete-conflicting-outputs`
  - Ensure all freezed and json_serializable code is generated
  - Fix any generation errors

- [ ] 29. Run full test suite
  - Run `flutter test`
  - Ensure all unit tests, property tests, and widget tests pass
  - Fix any failing tests

- [ ] 30. Manual end-to-end testing
  - Test new user registration with automatic username generation
  - Test username change in profile with validation feedback
  - Test cooldown enforcement (may need to mock timestamp)
  - Test username display across all screens (groups, posts, comments, profile, search)
  - Test username search functionality
  - Test Cloud Function triggers (create user, change username)
  - Verify denormalized data updates in Firestore Console

- [ ] 31. Final checkpoint - Production readiness check
  - All tests passing
  - Cloud Functions deployed and tested
  - Firestore rules and indexes deployed
  - Manual testing complete
  - Error messages in Russian
  - Performance acceptable (<100ms for username lookups)
  - Ask the user if ready to merge

## Notes

- Tasks marked with `*` are optional property-based and unit tests that can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at layer boundaries
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Cloud Functions provide eventual consistency for denormalized data
- The implementation follows Clean Architecture: Domain → Data → Presentation
- Username generation uses lazy migration strategy (on login) for zero downtime
- All error messages must be in Russian as per requirement 10.5
