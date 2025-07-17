// File: lib/services/group_service.dart
// Service for the enhanced FriendGroup (single class approach)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_group.dart';
import '../models/user_profile.dart';
import '../utils/user_profile_storage.dart';
import '../utils/debug_loader.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _groupsCollection => _firestore.collection('groups');

  // ============================================================================
  // CREATE
  // ============================================================================

  Future<FriendGroup> createGroup({
    required String name,
    required String description,
    required List<UserProfile> members,
    String imageUrl = '',
    bool isPrivate = false,
    bool notificationsEnabled = true,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create a group');
    }

    DebugLogger.log("🔵 Creating group '$name' for user: ${currentUser.uid}");

    // Create the group
    final group = FriendGroup.create(
      name: name,
      createdBy: currentUser.displayName ?? 'Unknown',
      creatorId: currentUser.uid,
      members: members,
      description: description,
      imageUrl: imageUrl,
      isPrivate: isPrivate,
      notificationsEnabled: notificationsEnabled,
    );

    DebugLogger.log("🔵 Group created with memberIds: ${group.memberIds}");

    try {
      // Save to Firestore
      final docRef = await _groupsCollection.add(group.toFirestore());
      DebugLogger.log("🔵 Group saved to Firestore with ID: ${docRef.id}");
      
      // Return group with Firestore ID
      final savedGroup = group.copyWith(id: docRef.id);

      // Update members' profiles
      await _addGroupToMembers(savedGroup.id, savedGroup.memberIds);
      DebugLogger.log("🔵 Added group to members' profiles");

      DebugLogger.log("✅ Group creation completed successfully");
      return savedGroup;
    } catch (e) {
      DebugLogger.log("❌ Error creating group: $e");
      throw Exception('Failed to create group: $e');
    }
  }

  // ============================================================================
  // READ
  // ============================================================================

  Future<FriendGroup?> getGroupById(String groupId) async {
    try {
      final doc = await _groupsCollection.doc(groupId).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data() as Map<String, dynamic>;
      final memberIds = List<String>.from(data['memberIds'] ?? []);
      
      final memberProfiles = await _loadMemberProfiles(memberIds);
      
      return FriendGroup.fromFirestore(doc.id, data, memberProfiles);
    } catch (e) {
      DebugLogger.log('Error getting group: $e');
      return null;
    }
  }

  Future<List<FriendGroup>> getUserGroups(String userId) async {
    try {
      DebugLogger.log("🔍 Loading groups for user: $userId");
      
      final querySnapshot = await _groupsCollection
          .where('memberIds', arrayContains: userId)
          .orderBy('lastActivityDate', descending: true)
          .get();

      DebugLogger.log("🔍 Found ${querySnapshot.docs.length} group documents");
      
      final groups = <FriendGroup>[];
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final memberIds = List<String>.from(data['memberIds'] ?? []);
          
          DebugLogger.log("🔍 Processing group ${doc.id} with ${memberIds.length} members");
          
          final memberProfiles = await _loadMemberProfiles(memberIds);
          
          if (memberProfiles.isNotEmpty) {
            final group = FriendGroup.fromFirestore(doc.id, data, memberProfiles);
            groups.add(group);
            DebugLogger.log("✅ Successfully created group: ${group.name}");
          } else {
            DebugLogger.log("⚠️ Skipping group ${doc.id} - no member profiles loaded");
          }
        } catch (e) {
          DebugLogger.log("❌ Error processing group ${doc.id}: $e");
        }
      }

      DebugLogger.log("✅ Successfully loaded ${groups.length} groups for user");
      return groups;
    } catch (e) {
      DebugLogger.log('❌ Error getting user groups: $e');
      return [];
    }
  }

    Future<List<FriendGroup>> searchPublicGroups(String query) async {
      try {
        DebugLogger.log("Searching public groups for: $query");
        final querySnapshot = await _groupsCollection
            .where('isPrivate', isEqualTo: false)
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();
        DebugLogger.log("Found ${querySnapshot.docs.length} matching groups");
        final groups = <FriendGroup>[];
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final memberIds = List<String>.from(data['memberIds'] ?? []);
            final memberProfiles = await _loadMemberProfiles(memberIds);
            groups.add(FriendGroup.fromFirestore(doc.id, data, memberProfiles));
          } catch (e) {
            DebugLogger.log('Error processing group ${doc.id}: $e');
          }
        }
        return groups;
      } catch (e) {
        DebugLogger.log('Error searching public groups: $e');
        return [];
      }
    }


  // ============================================================================
  // UPDATE
  // ============================================================================

  Future<FriendGroup?> updateGroup(FriendGroup group) async {
    try {
      await _groupsCollection.doc(group.id).update(group.toFirestore());
      return group;
    } catch (e) {
      DebugLogger.log('Error updating group: $e');
      return null;
    }
  }

  Future<FriendGroup?> updateGroupActivity({
    required String groupId,
    int addSessions = 0,
    int addMatches = 0,
    DateTime? sessionDate,
  }) async {
    try {
      final group = await getGroupById(groupId);
      if (group == null) return null;

      final updatedGroup = group.updateActivity(
        addSessions: addSessions,
        addMatches: addMatches,
        sessionDate: sessionDate,
      );

      await updateGroup(updatedGroup);
      return updatedGroup;
    } catch (e) {
      DebugLogger.log('Error updating group activity: $e');
      return null;
    }
  }

  // ============================================================================
  // DELETE
  // ============================================================================

  Future<bool> deleteGroup(String groupId, String userId) async {
    try {
      final group = await getGroupById(groupId);
      if (group == null) return false;

      if (group.creatorId != userId) {
        throw Exception('Only the group creator can delete the group');
      }

      await _removeGroupFromMembers(groupId, group.memberIds);
      await _groupsCollection.doc(groupId).delete();

      return true;
    } catch (e) {
      DebugLogger.log('Error deleting group: $e');
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId, String userId) async {
    try {
      final group = await getGroupById(groupId);
      if (group == null) return false;

      if (group.creatorId == userId) {
        throw Exception('Group creator cannot leave the group. Delete the group instead.');
      }

      final updatedGroup = group.removeMember(userId);
      await updateGroup(updatedGroup);
      await _removeGroupFromMembers(groupId, [userId]);

      return true;
    } catch (e) {
      DebugLogger.log('Error leaving group: $e');
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// ✅ FIXED: Load real user profiles from Firestore
  Future<List<UserProfile>> _loadMemberProfiles(List<String> memberIds) async {
    final profiles = <UserProfile>[];
    
    try {
      // Fetch all member profiles from Firestore users collection
      for (final memberId in memberIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data()!;
            userData['uid'] = memberId; // Ensure uid is set
            
            // Check what name field exists in the document
            if (userData['name'] == null && userData['displayName'] != null) {
              userData['name'] = userData['displayName'];
            }
            
            profiles.add(UserProfile.fromJson(userData));
            DebugLogger.log("✅ Loaded profile for user: $memberId, name: ${userData['name'] ?? userData['displayName'] ?? 'No name'}");
          } else {
            DebugLogger.log("⚠️ User document not found for: $memberId");
            // Create a minimal profile for missing users
            profiles.add(UserProfile(
              uid: memberId,
              name: 'Unknown User',
              likedMovieIds: {},  // ✅ KEEP: Only liked movies
              // ❌ REMOVED: matchedMovieIds and matchHistory
            ));
          }
        } catch (e) {
          DebugLogger.log("❌ Error loading user profile for $memberId: $e");
          // Create a minimal profile for failed loads
          profiles.add(UserProfile(
            uid: memberId,
            name: 'Unknown User',
            likedMovieIds: {},  // ✅ KEEP: Only liked movies
            // ❌ REMOVED: matchedMovieIds and matchHistory
          ));
        }
      }
      
      DebugLogger.log("✅ Loaded ${profiles.length} member profiles out of ${memberIds.length} member IDs");
      return profiles;
    } catch (e) {
      DebugLogger.log("❌ Error loading member profiles: $e");
      return [];
    }
  }

  Future<void> _addGroupToMembers(String groupId, List<String> memberIds) async {
    for (final memberId in memberIds) {
      try {
        // Update Firestore user document
        await _firestore.collection('users').doc(memberId).update({
          'groupIds': FieldValue.arrayUnion([groupId]),
        });
        
        // Update local storage if this is the current user
        final userProfile = await UserProfileStorage.loadProfile();
        if (userProfile.uid == memberId) {
          final updatedProfile = userProfile.addToGroup(groupId);
          await UserProfileStorage.saveProfile(updatedProfile);
        }
        
        DebugLogger.log("✅ Added group $groupId to user $memberId");
      } catch (e) {
        DebugLogger.log('❌ Error adding group to member $memberId: $e');
      }
    }
  }

  Future<void> _removeGroupFromMembers(String groupId, List<String> memberIds) async {
    for (final memberId in memberIds) {
      try {
        // Update Firestore user document
        await _firestore.collection('users').doc(memberId).update({
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
        
        // Update local storage if this is the current user
        final userProfile = await UserProfileStorage.loadProfile();
        if (userProfile.uid == memberId) {
          final updatedProfile = userProfile.removeFromGroup(groupId);
          await UserProfileStorage.saveProfile(updatedProfile);
        }
        
        DebugLogger.log("✅ Removed group $groupId from user $memberId");
      } catch (e) {
        DebugLogger.log('❌ Error removing group from member $memberId: $e');
      }
    }
  }

  /// Sync user's groups from Firebase (call on login/app start)
  Future<void> syncUserGroupsFromFirebase(String userId) async {
    try {
      // Query Firebase for groups where user is a member
      final querySnapshot = await _groupsCollection
          .where('memberIds', arrayContains: userId)
          .get();

      // Extract group IDs
      final groupIds = querySnapshot.docs.map((doc) => doc.id).toList();
      
      // Update local user profile with synced group IDs
      final userProfile = await UserProfileStorage.loadProfile();
      final updatedProfile = userProfile.copyWith(groupIds: groupIds);
      await UserProfileStorage.saveProfile(updatedProfile);
      DebugLogger.log('✅ Synced ${groupIds.length} groups from Firebase');
    } catch (e) {
      DebugLogger.log('Error syncing groups: $e');
    }
  }

  Future<bool> removeMemberFromGroup({
    required String groupId,
    required String memberIdToRemove,
  }) async {
    try {
      DebugLogger.log("🔄 Removing member $memberIdToRemove from group $groupId");
      
      final group = await getGroupById(groupId);
      if (group == null) {
        throw Exception('Group not found');
      }

      // Check if the member exists in the group
      if (!group.memberIds.contains(memberIdToRemove)) {
        throw Exception('User is not a member of this group');
      }

      // Don't allow removing the creator
      if (group.creatorId == memberIdToRemove) {
        throw Exception('Cannot remove the group creator');
      }

      // Update the group by removing the member
      final updatedMemberIds = group.memberIds.where((id) => id != memberIdToRemove).toList();
      
      // Update Firestore
      await _groupsCollection.doc(groupId).update({
        'memberIds': updatedMemberIds,
        'memberCount': updatedMemberIds.length,
        'lastActivityDate': FieldValue.serverTimestamp(),
      });

      // Remove group from the member's profile
      await _removeGroupFromMembers(groupId, [memberIdToRemove]);

      DebugLogger.log("✅ Successfully removed member $memberIdToRemove from group $groupId");
      return true;
    } catch (e) {
      DebugLogger.log('❌ Error removing member from group: $e');
      throw Exception('Failed to remove member: $e');
    }
  }
}

// Usage: Call this once when user logs in or app starts
void initializeApp() async {
  final groupService = GroupService();
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser != null) {
    // This one call rebuilds the user's group list from Firebase
    await groupService.syncUserGroupsFromFirebase(currentUser.uid);
  }
}