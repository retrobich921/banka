# Security Rules Bug Condition Exploration Tests

## Overview

This directory contains integration tests that demonstrate the bug in Firestore Security Rules for private groups join requests.

**Bug**: Group owners cannot approve join requests because Security Rules block them from creating member documents for other users.

## Prerequisites

1. **Java 21+**: Firebase Emulator Suite requires Java 21 or higher
   - Check your Java version: `java -version`
   - Download Java 21+ from: https://adoptium.net/

2. **Firebase CLI**: Install Firebase CLI globally
   ```bash
   npm install -g firebase-tools
   ```

3. **Firebase Emulator Suite**: The tests require Firebase Emulator Suite to be running
   ```bash
   firebase emulators:start --only firestore,auth
   ```

## Running the Tests

### Option 1: Integration Test with Emulator (Recommended)

1. Ensure Java 21+ is installed and set as default

2. Start Firebase Emulator Suite in a separate terminal:
   ```bash
   firebase emulators:start --only firestore,auth
   ```

3. Run the bug condition exploration test:
   ```bash
   flutter test test/features/group/security_rules/bug_condition_exploration_test.dart
   ```

### Option 2: Conceptual Test (No Emulator Required)

If you cannot run the emulator (e.g., Java version < 21), you can run the conceptual test that demonstrates the bug logic:

```bash
flutter test test/features/group/security_rules/bug_condition_conceptual_test.dart
```

This test uses mocks to simulate the Security Rules behavior and demonstrates the bug without requiring the emulator.

## Expected Behavior

**CRITICAL**: The test in `bug_condition_exploration_test.dart` is EXPECTED TO FAIL on unfixed Security Rules.

### Why the Test Should Fail

The test demonstrates the bug by attempting to:
1. Create a private group owned by "alice"
2. Have user "bob" create a join request
3. Have "alice" (the owner) approve the request by creating a member document for "bob"

**Expected Result**: Step 3 fails with `permission-denied` error because the current Security Rule is:
```
allow create: if isSelf(memberId);
```

This rule only allows users to create their own member documents. It does not allow group owners to create member documents for other users when approving join requests.

### Counterexample Documentation

When the test fails, it confirms the bug exists:
- **Input**: Owner "alice" attempts to create member document for user "bob"
- **Expected**: Member document should be created (owner approving join request)
- **Actual**: `FirebaseException` with code `permission-denied`
- **Root Cause**: Security Rules do not have an exception for group owners

## After the Fix

After implementing the fix (adding `isGroupOwner(groupId)` helper and updating the `allow create` rule), this same test should PASS, confirming that:
1. The bug is fixed
2. Owners can now approve join requests
3. The expected behavior is satisfied

## Test Structure

- `bug_condition_exploration_test.dart`: Integration test with Firebase Emulator (requires Java 21+)
  - Test 1: Generic case - owner cannot create member document for another user
  - Test 2: Concrete case - Alice approves Bob's request for "private-collectors" group

- `bug_condition_conceptual_test.dart`: Conceptual test without emulator
  - Demonstrates the bug logic using mocks
  - Does not require Firebase Emulator
  - Useful for understanding the bug without infrastructure setup

## Notes

- Integration tests use Firebase Emulator Suite, not production Firestore
- The emulator must be running before executing integration tests
- Tests automatically clear Firestore data between runs
- Authentication is simulated using the Auth Emulator
- If Java 21+ is not available, use the conceptual test instead
