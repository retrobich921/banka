# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Owner Cannot Approve Join Requests
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: For deterministic bugs, scope the property to the concrete failing case(s) to ensure reproducibility
  - Test that when a group owner (uid: "owner123") attempts to create a member document for another user (uid: "user456") in their group (groupId: "group789"), the operation is blocked by Security Rules
  - The test assertions should match the Expected Behavior Properties from design: owner should be able to create member documents when approving join requests
  - Concrete test case: Owner "alice" tries to approve join request from user "bob" for private group "private-collectors"
  - Run test on UNFIXED Security Rules (current `firestore.rules`)
  - **EXPECTED OUTCOME**: Test FAILS with "permission-denied" error (this is correct - it proves the bug exists)
  - Document counterexamples found: "Owner cannot create member document for another user when approving join request - Security Rules block with 'The caller does not have permission to execute the specified operation'"
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Self-Join, Self-Leave, and Protection Behaviors
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED Security Rules for non-buggy inputs:
    - User can self-join public groups (create own member document with `isSelf(memberId)`)
    - User can self-leave groups (delete own member document)
    - Non-owner users CANNOT create member documents for other users (protection against abuse)
    - Owner can update member roles (existing update rule)
    - User can create join request only for themselves
    - Owner can update join request status
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Test cases:
    1. For all users, creating their own member document in a public group succeeds
    2. For all users, deleting their own member document succeeds
    3. For all non-owner users attempting to create member documents for other users, operation is blocked
    4. For all group owners, updating member roles succeeds
    5. For all users, creating join requests for themselves succeeds
  - Run tests on UNFIXED Security Rules
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. Fix for private groups join requests bug

  - [x] 3.1 Add helper function `isGroupOwner(groupId)` to Security Rules
    - Add function in the helpers section of `firestore.rules`
    - Function checks if `request.auth.uid` matches the `ownerId` field in the group document
    - Implementation: `function isGroupOwner(groupId) { return isSignedIn() && get(/databases/$(database)/documents/groups/$(groupId)).data.ownerId == request.auth.uid; }`
    - Add comment explaining the function's purpose for join request approval
    - _Bug_Condition: isBugCondition(input) where input.operation == 'create_member' AND isGroupOwner(input.groupId, input.authUid) AND input.authUid != input.memberId_
    - _Expected_Behavior: Owner can create member documents for other users when approving join requests_
    - _Preservation: Existing helper functions remain unchanged_
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Extend `allow create` rule for member documents
    - Locate the `match /members/{memberId}` section in `firestore.rules`
    - Change `allow create: if isSelf(memberId);` to `allow create: if isSelf(memberId) || isGroupOwner(groupId);`
    - Add comment: "User can create own member document (self-join public group) OR owner can create member document for another user (when approving join request)"
    - Verify that `allow delete` and `allow update` rules remain unchanged
    - _Bug_Condition: isBugCondition(input) from design - owner creating member for another user_
    - _Expected_Behavior: expectedBehavior(result) - member document created successfully by owner_
    - _Preservation: Self-join and self-leave behaviors preserved, protection against unauthorized member creation preserved_
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

  - [x] 3.3 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Owner Can Approve Join Requests
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1 against FIXED Security Rules
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed - owner can now create member documents for other users)
    - Verify that the concrete test case (Owner "alice" approving join request from "bob") now succeeds
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.4 Verify preservation tests still pass
    - **Property 2: Preservation** - Self-Join, Self-Leave, and Protection Behaviors
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2 against FIXED Security Rules
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all preservation test cases still pass:
      1. Users can still self-join public groups
      2. Users can still self-leave groups
      3. Non-owner users still CANNOT create member documents for others
      4. Owners can still update member roles
      5. Users can still create join requests for themselves
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run all tests (bug condition test + preservation tests) against fixed Security Rules
  - Verify bug condition test passes (owner can approve join requests)
  - Verify all preservation tests pass (no regressions in existing behavior)
  - If any test fails, investigate root cause and adjust implementation
  - Ask the user if questions arise about test failures or unexpected behavior
