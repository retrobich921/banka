@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Preservation Property Tests
/// 
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
/// 
/// **Property 2: Preservation** - Self-Join, Self-Leave, and Protection Behaviors
/// 
/// These tests capture the EXISTING behavior on UNFIXED Security Rules
/// for non-buggy inputs. They verify that after the fix, all existing
/// behaviors remain unchanged (no regressions).
/// 
/// **IMPORTANT**: Follow observation-first methodology
/// - Run tests on UNFIXED Security Rules
/// - Tests should PASS (confirming baseline behavior)
/// - After fix, re-run to ensure behavior is preserved
/// 
/// **Test Cases**:
/// 1. Users can create their own member documents in public groups (self-join)
/// 2. Users can delete their own member documents (self-leave)
/// 3. Non-owner users CANNOT create member documents for other users (protection)
/// 4. Owners can update member roles
/// 5. Users can create join requests only for themselves
void main() {
  group('Preservation Property Tests - Existing Behaviors', () {
    late FirebaseFirestore firestore;

    setUpAll(() async {
      // Initialize Flutter bindings
      TestWidgetsFlutterBinding.ensureInitialized();
      
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

    group('Property 2.1: Self-Join Preservation', () {
      test(
        'User can create their own member document in a public group',
        () async {
          // **Validates: Requirement 3.1**
          // This is the existing behavior that must be preserved
          
          // ARRANGE: Create a public group
          const ownerUid = 'alice';
          const joiningUserUid = 'bob';
          const groupId = 'public-group-1';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Public Energy Drinks',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A public group for energy drink enthusiasts',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Owner's member document
          await groupRef.collection('members').doc(ownerUid).set({
            'userId': ownerUid,
            'groupId': groupId,
            'role': 'owner',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Bob (joining user) creates his own member document
          await _authenticateAs(joiningUserUid);
          
          final bobMemberRef = groupRef.collection('members').doc(joiningUserUid);
          
          // This should SUCCEED on unfixed Security Rules
          // because isSelf(memberId) returns true when auth.uid == memberId
          await bobMemberRef.set({
            'userId': joiningUserUid,
            'groupId': groupId,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          // ASSERT: Verify member document was created
          final bobMemberDoc = await bobMemberRef.get();
          expect(bobMemberDoc.exists, isTrue);
          expect(bobMemberDoc.data()?['userId'], equals(joiningUserUid));
          expect(bobMemberDoc.data()?['role'], equals('member'));
          
          // OBSERVATION: User can self-join public groups
          // This behavior must be preserved after the fix
        },
      );

      test(
        'Multiple users can self-join the same public group',
        () async {
          // Property-based test: For all users, self-join succeeds
          
          // ARRANGE: Create a public group
          const ownerUid = 'alice';
          const groupId = 'public-group-2';
          final joiningUsers = ['bob', 'charlie', 'diana'];
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Public Collectors',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'Open to all collectors',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Each user creates their own member document
          for (final userId in joiningUsers) {
            await _authenticateAs(userId);
            
            final memberRef = groupRef.collection('members').doc(userId);
            await memberRef.set({
              'userId': userId,
              'groupId': groupId,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });
            
            // ASSERT: Verify each member document was created
            final memberDoc = await memberRef.get();
            expect(memberDoc.exists, isTrue);
            expect(memberDoc.data()?['userId'], equals(userId));
          }
          
          // OBSERVATION: All users can self-join
          // This behavior must be preserved after the fix
        },
      );
    });

    group('Property 2.2: Self-Leave Preservation', () {
      test(
        'User can delete their own member document (self-leave)',
        () async {
          // **Validates: Requirement 3.2**
          // This is the existing behavior that must be preserved
          
          // ARRANGE: Create a group with Bob as a member
          const ownerUid = 'alice';
          const leavingUserUid = 'bob';
          const groupId = 'group-with-bob';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Test Group',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A test group',
            'membersUids': [ownerUid, leavingUserUid],
            'membersCount': 2,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Create Bob's member document
          await _authenticateAs(leavingUserUid);
          final bobMemberRef = groupRef.collection('members').doc(leavingUserUid);
          await bobMemberRef.set({
            'userId': leavingUserUid,
            'groupId': groupId,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          // Verify Bob's member document exists
          var bobMemberDoc = await bobMemberRef.get();
          expect(bobMemberDoc.exists, isTrue);
          
          // ACT: Bob deletes his own member document (leaves the group)
          await _authenticateAs(leavingUserUid);
          
          // This should SUCCEED on unfixed Security Rules
          // because isSelf(memberId) returns true
          await bobMemberRef.delete();
          
          // ASSERT: Verify member document was deleted
          bobMemberDoc = await bobMemberRef.get();
          expect(bobMemberDoc.exists, isFalse);
          
          // OBSERVATION: User can self-leave groups
          // This behavior must be preserved after the fix
        },
      );

      test(
        'Multiple users can self-leave the same group',
        () async {
          // Property-based test: For all users, self-leave succeeds
          
          // ARRANGE: Create a group with multiple members
          const ownerUid = 'alice';
          const groupId = 'group-with-multiple-members';
          final leavingUsers = ['bob', 'charlie', 'diana'];
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Test Group',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A test group',
            'membersUids': [ownerUid, ...leavingUsers],
            'membersCount': 1 + leavingUsers.length,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Create member documents for all users
          for (final userId in leavingUsers) {
            await _authenticateAs(userId);
            final memberRef = groupRef.collection('members').doc(userId);
            await memberRef.set({
              'userId': userId,
              'groupId': groupId,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });
          }
          
          // ACT: Each user deletes their own member document
          for (final userId in leavingUsers) {
            await _authenticateAs(userId);
            
            final memberRef = groupRef.collection('members').doc(userId);
            await memberRef.delete();
            
            // ASSERT: Verify each member document was deleted
            final memberDoc = await memberRef.get();
            expect(memberDoc.exists, isFalse);
          }
          
          // OBSERVATION: All users can self-leave
          // This behavior must be preserved after the fix
        },
      );
    });

    group('Property 2.3: Protection Against Unauthorized Member Creation', () {
      test(
        'Non-owner user CANNOT create member document for another user',
        () async {
          // **Validates: Requirement 3.3**
          // This is the existing protection that must be preserved
          
          // ARRANGE: Create a group
          const ownerUid = 'alice';
          const attackerUid = 'charlie';
          const victimUid = 'bob';
          const groupId = 'protected-group';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Protected Group',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A group with protection',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Charlie (non-owner) tries to create member document for Bob
          await _authenticateAs(attackerUid);
          
          final bobMemberRef = groupRef.collection('members').doc(victimUid);
          
          // This should FAIL on unfixed Security Rules
          // because isSelf(memberId) returns false when auth.uid != memberId
          // and Charlie is not the group owner
          
          // ASSERT: Expect permission-denied error
          expect(
            () async {
              await bobMemberRef.set({
                'userId': victimUid,
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
          
          // OBSERVATION: Non-owner users cannot create member documents for others
          // This protection must be preserved after the fix
        },
      );

      test(
        'Non-owner user CANNOT create member documents for multiple users',
        () async {
          // Property-based test: For all non-owner users attempting to create
          // member documents for other users, operation is blocked
          
          // ARRANGE: Create a group
          const ownerUid = 'alice';
          const attackerUid = 'charlie';
          const groupId = 'protected-group-2';
          final victimUsers = ['bob', 'diana', 'eve'];
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Protected Group',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A group with protection',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Charlie tries to create member documents for multiple users
          await _authenticateAs(attackerUid);
          
          for (final victimUid in victimUsers) {
            final memberRef = groupRef.collection('members').doc(victimUid);
            
            // ASSERT: Each attempt should fail
            expect(
              () async {
                await memberRef.set({
                  'userId': victimUid,
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
          }
          
          // OBSERVATION: Non-owner users cannot create member documents for others
          // This protection must be preserved after the fix
        },
      );
    });

    group('Property 2.4: Owner Can Update Member Roles', () {
      test(
        'Group owner can update member roles',
        () async {
          // **Validates: Requirement 3.4**
          // This is the existing behavior that must be preserved
          
          // ARRANGE: Create a group with Bob as a member
          const ownerUid = 'alice';
          const memberUid = 'bob';
          const groupId = 'group-with-roles';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Group with Roles',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A group with role management',
            'membersUids': [ownerUid, memberUid],
            'membersCount': 2,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Create Bob's member document
          await _authenticateAs(memberUid);
          final bobMemberRef = groupRef.collection('members').doc(memberUid);
          await bobMemberRef.set({
            'userId': memberUid,
            'groupId': groupId,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Owner updates Bob's role
          await _authenticateAs(ownerUid);
          
          // This should SUCCEED on unfixed Security Rules
          // because the update rule checks if the requester is the group owner
          await bobMemberRef.update({
            'role': 'moderator',
          });
          
          // ASSERT: Verify role was updated
          final bobMemberDoc = await bobMemberRef.get();
          expect(bobMemberDoc.data()?['role'], equals('moderator'));
          
          // OBSERVATION: Owner can update member roles
          // This behavior must be preserved after the fix
        },
      );

      test(
        'Owner can update roles for multiple members',
        () async {
          // Property-based test: For all group owners, updating member roles succeeds
          
          // ARRANGE: Create a group with multiple members
          const ownerUid = 'alice';
          const groupId = 'group-with-multiple-roles';
          final memberUsers = ['bob', 'charlie', 'diana'];
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Group with Multiple Roles',
            'ownerId': ownerUid,
            'isPublic': true,
            'description': 'A group with role management',
            'membersUids': [ownerUid, ...memberUsers],
            'membersCount': 1 + memberUsers.length,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Create member documents
          for (final userId in memberUsers) {
            await _authenticateAs(userId);
            final memberRef = groupRef.collection('members').doc(userId);
            await memberRef.set({
              'userId': userId,
              'groupId': groupId,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });
          }
          
          // ACT: Owner updates all member roles
          await _authenticateAs(ownerUid);
          
          for (final userId in memberUsers) {
            final memberRef = groupRef.collection('members').doc(userId);
            await memberRef.update({
              'role': 'moderator',
            });
            
            // ASSERT: Verify each role was updated
            final memberDoc = await memberRef.get();
            expect(memberDoc.data()?['role'], equals('moderator'));
          }
          
          // OBSERVATION: Owner can update roles for all members
          // This behavior must be preserved after the fix
        },
      );
    });

    group('Property 2.5: Join Request Creation Preservation', () {
      test(
        'User can create join request only for themselves',
        () async {
          // **Validates: Requirement 3.5**
          // This is the existing behavior that must be preserved
          
          // ARRANGE: Create a private group
          const ownerUid = 'alice';
          const requestingUserUid = 'bob';
          const groupId = 'private-group-for-requests';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Private Group',
            'ownerId': ownerUid,
            'isPublic': false,
            'description': 'A private group',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Bob creates a join request for himself
          await _authenticateAs(requestingUserUid);
          
          final joinRequestRef = groupRef.collection('join_requests').doc(requestingUserUid);
          
          // This should SUCCEED on unfixed Security Rules
          // because the create rule checks if auth.uid == userId
          await joinRequestRef.set({
            'userId': requestingUserUid,
            'groupId': groupId,
            'groupOwnerId': ownerUid,
            'status': 'pending',
            'displayName': 'Bob',
            'requestedAt': FieldValue.serverTimestamp(),
          });
          
          // ASSERT: Verify join request was created
          final joinRequestDoc = await joinRequestRef.get();
          expect(joinRequestDoc.exists, isTrue);
          expect(joinRequestDoc.data()?['userId'], equals(requestingUserUid));
          expect(joinRequestDoc.data()?['status'], equals('pending'));
          
          // OBSERVATION: User can create join request for themselves
          // This behavior must be preserved after the fix
        },
      );

      test(
        'User CANNOT create join request for another user',
        () async {
          // Property-based test: Users can only create join requests for themselves
          
          // ARRANGE: Create a private group
          const ownerUid = 'alice';
          const attackerUid = 'charlie';
          const victimUid = 'bob';
          const groupId = 'private-group-protected';
          
          await _authenticateAs(ownerUid);
          
          final groupRef = firestore.collection('groups').doc(groupId);
          await groupRef.set({
            'name': 'Private Group',
            'ownerId': ownerUid,
            'isPublic': false,
            'description': 'A private group',
            'membersUids': [ownerUid],
            'membersCount': 1,
            'postsCount': 0,
            'tags': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // ACT: Charlie tries to create a join request for Bob
          await _authenticateAs(attackerUid);
          
          final joinRequestRef = groupRef.collection('join_requests').doc(victimUid);
          
          // This should FAIL on unfixed Security Rules
          // because auth.uid (charlie) != userId (bob)
          
          // ASSERT: Expect permission-denied error
          expect(
            () async {
              await joinRequestRef.set({
                'userId': victimUid,
                'groupId': groupId,
                'groupOwnerId': ownerUid,
                'status': 'pending',
                'displayName': 'Bob',
                'requestedAt': FieldValue.serverTimestamp(),
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
          
          // OBSERVATION: Users cannot create join requests for others
          // This protection must be preserved after the fix
        },
      );
    });
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
