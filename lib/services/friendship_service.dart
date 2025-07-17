import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../utils/debug_loader.dart';
import 'dart:async';

class FriendshipService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a friend request
  static Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String fromUserName,
    required String toUserName,
  }) async {
    try {
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      DebugLogger.log("🔍 DEBUG - Auth user UID: ${currentAuthUser?.uid}");
      DebugLogger.log("🔍 DEBUG - fromUserId parameter: $fromUserId");
      DebugLogger.log("🔍 DEBUG - Are they equal? ${currentAuthUser?.uid == fromUserId}");
      DebugLogger.log("🔍 DEBUG - Is user authenticated? ${currentAuthUser != null}");
      
      // Check if a friend request already exists (should be rare now)
      final requestId = '${fromUserId}_$toUserId';
      final existingRequest = await _firestore.collection('friend_requests').doc(requestId).get();
      
      if (existingRequest.exists) {
        final status = existingRequest.data()!['status'];
        DebugLogger.log("⚠️ Friend request already exists with status: $status");
        
        if (status == 'pending') {
          throw Exception('Friend request already sent and is pending');
        }
        // If it exists but isn't pending, delete it and create a new one
        await _firestore.collection('friend_requests').doc(requestId).delete();
        DebugLogger.log("🗑️ Cleaned up old friend request");
      }
      
      // Create new friend request document
      await _firestore.collection('friend_requests').doc(requestId).set({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromUserName': fromUserName,
        'toUserName': toUserName,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      DebugLogger.log("✅ Friend request sent from $fromUserName to $toUserName");
    } catch (e) {
      DebugLogger.log("❌ Error sending friend request: $e");
      throw e;
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingFriendRequestsList(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      DebugLogger.log("❌ Error getting pending friend requests: $e");
      return [];
    }
  }

  static Future<void> acceptFriendRequestById({
    required String requestDocumentId,
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      DebugLogger.log("🤝 Starting to accept friend request with document ID: $requestDocumentId");
      DebugLogger.log("👥 From: $fromUserId -> To: $toUserId");
      
      final batch = _firestore.batch();

      // DELETE the friend request document using the ACTUAL document ID
      final requestRef = _firestore.collection('friend_requests').doc(requestDocumentId);
      DebugLogger.log("🗑️ Adding delete operation for actual document: $requestDocumentId");
      batch.delete(requestRef);

      // Add to both users' friends arrays
      final fromUserRef = _firestore.collection('users').doc(fromUserId);
      DebugLogger.log("👥 Adding $toUserId to $fromUserId's friends");
      batch.update(fromUserRef, {
        'friendIds': FieldValue.arrayUnion([toUserId]),
      });

      final toUserRef = _firestore.collection('users').doc(toUserId);
      DebugLogger.log("👥 Adding $fromUserId to $toUserId's friends");
      batch.update(toUserRef, {
        'friendIds': FieldValue.arrayUnion([fromUserId]),
      });

      // Commit the batch
      DebugLogger.log("💾 Committing batch operation...");
      await batch.commit();
      DebugLogger.log("✅ Batch committed successfully!");

      // Verify the document was deleted
      final deletedDoc = await requestRef.get();
      DebugLogger.log("🔍 Verification - Document exists after delete: ${deletedDoc.exists}");

      DebugLogger.log("✅ Friend request accepted. Users are now friends!");
    } catch (e) {
      DebugLogger.log("❌ Error accepting friend request by ID: $e");
      DebugLogger.log("❌ Document ID: $requestDocumentId");
      DebugLogger.log("❌ Error type: ${e.runtimeType}");
      throw e;
    }
  }

  static Future<void> declineFriendRequestById(String requestDocumentId) async {
    try {
      DebugLogger.log("🚫 Declining friend request with document ID: $requestDocumentId");
      
      // DELETE the friend request document using the ACTUAL document ID
      await _firestore.collection('friend_requests').doc(requestDocumentId).delete();

      DebugLogger.log("✅ Friend request declined and removed");
    } catch (e) {
      DebugLogger.log("❌ Error declining friend request by ID: $e");
      throw e;
    }
  }

  static Stream<List<Map<String, dynamic>>> getPendingFriendRequests(String userId) {
    DebugLogger.log("🔄 Setting up friend requests stream for user: $userId");
    
    return _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          DebugLogger.log("📥 Friend requests stream update: ${snapshot.docs.length} pending requests");
          
          final requests = snapshot.docs.map((doc) {
            final data = doc.data();
            DebugLogger.log("📋 Friend request: ${doc.id} from ${data['fromUserName']} to ${data['toUserName']}");
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          
          DebugLogger.log("✅ Returning ${requests.length} friend requests to UI");
          return requests;
        });
  }

  // Get user's friends list
  static Future<List<UserProfile>> getFriends(String userId) async {
    try {
      DebugLogger.log("🔍 Getting friends for user: $userId");
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        DebugLogger.log("❌ User document doesn't exist");
        return [];
      }

      final userData = userDoc.data()!;
      final List<String> friendIds = List<String>.from(userData['friendIds'] ?? []);
      DebugLogger.log("🔍 Found friendIds: $friendIds");

      if (friendIds.isEmpty) {
        DebugLogger.log("ℹ️ No friend IDs found");
        return [];
      }

      final List<UserProfile> friends = [];
      
      for (String friendId in friendIds) {
        DebugLogger.log("🔍 Loading friend: $friendId");
        final friendDoc = await _firestore.collection('users').doc(friendId).get();
        if (friendDoc.exists) {
          final friendData = friendDoc.data()!;
          DebugLogger.log("🔍 Friend data: ${friendData['name']} (${friendData['uid']})");
          friends.add(UserProfile.fromJson(friendData));
        } else {
          DebugLogger.log("❌ Friend document not found: $friendId");
        }
      }

      DebugLogger.log("✅ Loaded ${friends.length} friends");
      return friends;
    } catch (e) {
      DebugLogger.log("❌ Error getting friends: $e");
      return [];
    }
  }

  // Remove a friend
  static Future<void> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Remove from both users' friends arrays
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'friendIds': FieldValue.arrayRemove([friendId]),
      });

      final friendRef = _firestore.collection('users').doc(friendId);
      batch.update(friendRef, {
        'friendIds': FieldValue.arrayRemove([userId]),
      });

      await batch.commit();

      DebugLogger.log("✅ Friend removed successfully");
    } catch (e) {
      DebugLogger.log("❌ Error removing friend: $e");
      throw e;
    }
  }

  static Future<List<UserProfile>> searchUsersByName(String searchTerm, String currentUserId) async {
    try {
      DebugLogger.log('🔍 Searching for: $searchTerm');
      
      // Simple Firestore query using the original approach but with better error handling
      final querySnapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: searchTerm + '\uf8ff')
          .get();

      DebugLogger.log('📥 Found ${querySnapshot.docs.length} documents');

      final List<UserProfile> users = [];
      
      for (var doc in querySnapshot.docs) {
        if (doc.id != currentUserId) {
          final user = UserProfile.fromJson(doc.data());
          users.add(user);
          DebugLogger.log('✅ Added user: ${user.name}');
        }
      }

      DebugLogger.log('🎯 Returning ${users.length} users');
      return users;
      
    } catch (e) {
      DebugLogger.log("❌ Search error: $e");
      return [];
    }
  }

  // IMPORTANT: You'll also need to add this method to update user documents
  // to include a lowercase name field for efficient searching:

  static Future<void> updateAllUsersForSearch() async {
    final users = await _firestore.collection('users').get();
    final batch = _firestore.batch();
    
    for (var doc in users.docs) {
      final data = doc.data();
      if (data['name'] != null) {
        batch.update(doc.reference, {
          'nameLowercase': (data['name'] as String).toLowerCase(),
        });
      }
    }
    
    await batch.commit();
    DebugLogger.log('✅ Updated all users for optimized search');
  }

  // Check if two users are friends
  static Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId1).get();
      
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final List<String> friendIds = List<String>.from(userData['friendIds'] ?? []);

      return friendIds.contains(userId2);
    } catch (e) {
      DebugLogger.log("❌ Error checking friendship: $e");
      return false;
    }
  }

  // Check if friend request exists
  static Future<String?> getFriendRequestStatus(String fromUserId, String toUserId) async {
    try {
      final requestDoc = await _firestore.collection('friend_requests').doc('${fromUserId}_$toUserId').get();
      
      if (requestDoc.exists) {
        return requestDoc.data()!['status'];
      }
      
      return null;
    } catch (e) {
      DebugLogger.log("❌ Error checking friend request: $e");
      return null;
    }
  }
  static Stream<List<UserProfile>> watchFriends(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists) return <UserProfile>[];

      final userData = userDoc.data()!;
      final List<String> friendIds = List<String>.from(userData['friendIds'] ?? []);

      if (friendIds.isEmpty) return <UserProfile>[];

      // Load all friend profiles
      final List<UserProfile> friends = [];
      for (String friendId in friendIds) {
        try {
          final friendDoc = await _firestore.collection('users').doc(friendId).get();
          if (friendDoc.exists) {
            friends.add(UserProfile.fromJson(friendDoc.data()!));
          }
        } catch (e) {
          DebugLogger.log("❌ Error loading friend $friendId: $e");
        }
      }

      return friends;
    });
  }
}