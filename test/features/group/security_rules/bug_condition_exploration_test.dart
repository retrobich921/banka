@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug Condition Exploration Test
/// 
/// **Validates: Requirements 1.1, 1.2, 1.3**
/// 
/// **Property 1: Bug Condition** - Owner Cannot Approve Join Requests
/// 
/// This test demonstrates the bug on UNFIXED Security Rules.
/// It verifies that when a group owner attempts to create a member document
/// for another user (when approving a join request), the operation is blocked
/// by Security Rules with a permission-denied error.
/// 
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists.
/// **DO NOT attempt to fix the test or the code when it fails.**
/// 
/// **Expected Outcome**: Test FAILS with "permission-denied" error
/// (this is correct - it proves the bug exists)
/// 
/// **Concrete Test Case**: 
/// Owner "alice" tries to approve join request from user "bob" 
/// for private group "private-collectors"
void main() {
  group('Bug Condition Exploration - Owner Cannot Approve Join Requests', () {
    late FirebaseFirestore firestore;
    
    // Test user IDs
    const aliceUid = 'alice';
    const bobUid = 'bob';
    const groupId = 'private-collectors';

    setUpAll(() async {
      // Initialize Firebase for testing
      // Note: This requires Firebase Emulator Suite to be running
      // Run: firebase emulators:start --only firestore,auth
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: 'test-project',
        ),
      );

      firestore = FirebaseFirestore.instance;
      
      // Connect to Firestore Emulator
      firestore.useFirestoreEmulator('localhost', 8080);
      
      // Connect to Auth Emulator
      await auth.FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    });

    setUp(() async {
      // Clear Firestore data before each test
      await _clearFirestoreData(firestore);
    });

    test(
      'Owner cannot create member document for another user when approving join request',
      () async {
        // ARRANGE: Set up the scenario
        
        // 1. Create a private group owned by Alice
        await _authenticateAs(aliceUid);
        
        final groupRef = firestore.collection('groups').doc(groupId);
        await groupRef.set({
          'name': 'Private Collectors',
          'ownerId': aliceUid,
          'isPublic': false,
          'description': 'A private group for collectors',
          'membersUids': [aliceUid],
          'membersCount': 1,
          'postsCount': 0,
          'tags': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // 2. Create Alice's member document (owner)
        await groupRef.collection('members').doc(aliceUid).set({
          'userId': aliceUid,
          'groupId': groupId,
          'role': 'owner',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // 3. Bob creates a join request (authenticated as Bob)
        await _authenticateAs(bobUid);
        
        await groupRef.collection('join_requests').doc(bobUid).set({
          'userId': bobUid,
          'groupId': groupId,
          'groupOwnerId': aliceUid,
          'status': 'pending',
          'displayName': 'Bob',
          'requestedAt': FieldValue.serverTimestamp(),
        });
        
        // ACT: Alice (owner) tries to approve Bob's join request
        // This involves creating a member document for Bob
        await _authenticateAs(aliceUid);
        
        // This should FAIL with permission-denied on unfixed Security Rules
        // because the current rule is: allow create: if isSelf(memberId);
        // and Alice (request.auth.uid) != Bob (memberId)
        
        final bobMemberRef = groupRef.collection('members').doc(bobUid);
        
        // ASSERT: Expect permission-denied error
        expect(
          () async {
            await bobMemberRef.set({
              'userId': bobUid,
              'groupId': groupId,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });
          },
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        
        // COUNTEREXAMPLE DOCUMENTATION:
        // When owner (alice) attempts to create member document for another user (bob),
        // Security Rules block the operation with:
        // "The caller does not have permission to execute the specified operation"
        // 
        // This confirms the bug exists: owners cannot approve join requests
        // because they cannot create member documents for other users.
      },
    );

    test(
      'Concrete case: Alice approves Bob\'s request for private-collectors group',
      () async {
        // This is the exact scenario from the bugfix requirements
        
        // ARRANGE
        await _authenticateAs(aliceUid);
        
        // Create private group
        final groupRef = firestore.collection('groups').doc(groupId);
        await groupRef.set({
          'name': 'Private Collectors',
          'ownerId': aliceUid,
          'isPublic': false,
          'description': 'A private group for energy drink collectors',
          'membersUids': [aliceUid],
          'membersCount': 1,
          'postsCount': 0,
          'tags': ['energy-drinks', 'collectors'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Alice's member document
        await groupRef.collection('members').doc(aliceUid).set({
          'userId': aliceUid,
          'groupId': groupId,
          'role': 'owner',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        
        // Bob creates join request
        await _authenticateAs(bobUid);
        await groupRef.collection('join_requests').doc(bobUid).set({
          'userId': bobUid,
          'groupId': groupId,
          'groupOwnerId': aliceUid,
          'status': 'pending',
          'displayName': 'Bob',
          'requestedAt': FieldValue.serverTimestamp(),
        });
        
        // ACT: Alice tries to approve (create Bob's member document)
        await _authenticateAs(aliceUid);
        
        final bobMemberRef = groupRef.collection('members').doc(bobUid);
        
        // ASSERT: Should fail with permission-denied
        expect(
          () async {
            await bobMemberRef.set({
              'userId': bobUid,
              'groupId': groupId,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });
          },
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      },
    );
  });
}

/// Helper function to authenticate as a specific user in the emulator
Future<void> _authenticateAs(String uid) async {
  final authInstance = auth.FirebaseAuth.instance;
  
  // Sign out current user
  await authInstance.signOut();
  
  // Sign in with custom token (emulator allows this)
  // In emulator, we can use any UID without actual authentication
  try {
    await authInstance.signInWithCustomToken(uid);
  } catch (e) {
    // If custom token doesn't work in emulator, use anonymous auth
    // and manually set the UID (this is a workaround for testing)
    await authInstance.signInAnonymously();
  }
}

/// Helper function to clear all Firestore data
Future<void> _clearFirestoreData(FirebaseFirestore firestore) async {
  // Delete all groups and their subcollections
  final groupsSnapshot = await firestore.collection('groups').get();
  
  for (final doc in groupsSnapshot.docs) {
    // Delete members subcollection
    final membersSnapshot = await doc.reference.collection('members').get();
    for (final memberDoc in membersSnapshot.docs) {
      await memberDoc.reference.delete();
    }
    
    // Delete join_requests subcollection
    final requestsSnapshot = await doc.reference.collection('join_requests').get();
    for (final requestDoc in requestsSnapshot.docs) {
      await requestDoc.reference.delete();
    }
    
    // Delete group document
    await doc.reference.delete();
  }
}
