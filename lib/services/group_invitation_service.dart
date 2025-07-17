// File: lib/services/group_invitation_service.dart
// Service for handling group invitations

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../utils/debug_loader.dart';

class GroupInvitationService {
  static final GroupInvitationService _instance = GroupInvitationService._internal();
  factory GroupInvitationService() => _instance;
  GroupInvitationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _invitationsCollection => _firestore.collection('groupInvitations');

  // ============================================================================
  // CREATE INVITATIONS
  // ============================================================================

  /// Send group invitations to multiple users
  Future<List<String>> sendGroupInvitations({
    required String groupId,
    required String groupName,
    required String groupDescription,
    required String groupImageUrl,
    required UserProfile creator,
    required List<UserProfile> invitees,
  }) async {
    try {
      final batch = _firestore.batch();
      final invitationIds = <String>[];

      for (final invitee in invitees) {
        // Skip sending invitation to creator
        if (invitee.uid == creator.uid) continue;

        final invitationData = {
          'groupId': groupId,
          'groupName': groupName,
          'groupDescription': groupDescription,
          'groupImageUrl': groupImageUrl,
          'fromUserId': creator.uid,
          'fromUserName': creator.name,
          'toUserId': invitee.uid,
          'toUserName': invitee.name,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        final docRef = _invitationsCollection.doc();
        batch.set(docRef, invitationData);
        invitationIds.add(docRef.id);

        DebugLogger.log("📧 Sending group invitation to ${invitee.name} for group: $groupName");
      }

      await batch.commit();
      DebugLogger.log("✅ Sent ${invitationIds.length} group invitations");
      return invitationIds;
    } catch (e) {
      DebugLogger.log("❌ Error sending group invitations: $e");
      throw Exception('Failed to send group invitations: $e');
    }
  }

  // ============================================================================
  // READ INVITATIONS
  // ============================================================================

  /// Get pending group invitations for a user
  Stream<List<Map<String, dynamic>>> watchPendingGroupInvitations(String userId) {
    return _invitationsCollection
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  /// Get pending group invitations as a one-time fetch
  Future<List<Map<String, dynamic>>> getPendingGroupInvitations(String userId) async {
    try {
      final snapshot = await _invitationsCollection
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      DebugLogger.log("❌ Error getting pending group invitations: $e");
      return [];
    }
  }

  /// Get invitation by ID
  Future<Map<String, dynamic>?> getInvitationById(String invitationId) async {
    try {
      final doc = await _invitationsCollection.doc(invitationId).get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        ...data,
      };
    } catch (e) {
      DebugLogger.log("❌ Error getting invitation: $e");
      return null;
    }
  }

  // ============================================================================
  // ACCEPT/DECLINE INVITATIONS
  // ============================================================================

  /// Accept a group invitation
  Future<bool> acceptGroupInvitation(String invitationId) async {
    try {
      final invitation = await getInvitationById(invitationId);
      if (invitation == null) {
        throw Exception('Invitation not found');
      }

      if (invitation['status'] != 'pending') {
        throw Exception('Invitation is no longer pending');
      }

      // Update invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add user to the group
      await _addUserToGroup(
        invitation['groupId'],
        invitation['toUserId'],
        invitation['toUserName'],
      );

      DebugLogger.log("✅ Accepted group invitation: ${invitation['groupName']}");
      return true;
    } catch (e) {
      DebugLogger.log("❌ Error accepting group invitation: $e");
      throw Exception('Failed to accept invitation: $e');
    }
  }

  /// Decline a group invitation
  Future<bool> declineGroupInvitation(String invitationId) async {
    try {
      final invitation = await getInvitationById(invitationId);
      if (invitation == null) {
        throw Exception('Invitation not found');
      }

      if (invitation['status'] != 'pending') {
        throw Exception('Invitation is no longer pending');
      }

      // Update invitation status
      await _invitationsCollection.doc(invitationId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      DebugLogger.log("🔸 Declined group invitation: ${invitation['groupName']}");
      return true;
    } catch (e) {
      DebugLogger.log("❌ Error declining group invitation: $e");
      throw Exception('Failed to decline invitation: $e');
    }
  }

  // ============================================================================
  // CLEANUP METHODS
  // ============================================================================

  /// Decline all pending group invitations for a user
  Future<void> declineAllGroupInvitations(String userId) async {
    try {
      final pendingInvitations = await getPendingGroupInvitations(userId);
      
      final batch = _firestore.batch();
      for (final invitation in pendingInvitations) {
        final docRef = _invitationsCollection.doc(invitation['id']);
        batch.update(docRef, {
          'status': 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      DebugLogger.log("✅ Declined ${pendingInvitations.length} group invitations");
    } catch (e) {
      DebugLogger.log("❌ Error declining all group invitations: $e");
      throw Exception('Failed to decline all invitations: $e');
    }
  }

  /// Cancel group invitations (for group creators)
  Future<void> cancelGroupInvitations(String groupId) async {
    try {
      final snapshot = await _invitationsCollection
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      DebugLogger.log("✅ Cancelled ${snapshot.docs.length} group invitations for group: $groupId");
    } catch (e) {
      DebugLogger.log("❌ Error cancelling group invitations: $e");
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Add user to an existing group after accepting invitation
  Future<void> _addUserToGroup(String groupId, String userId, String userName) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final currentMemberIds = List<String>.from(groupData['memberIds'] ?? []);
      
      // Check if user is already a member
      if (currentMemberIds.contains(userId)) {
        DebugLogger.log("⚠️ User $userName is already a member of group $groupId");
        return;
      }

      // Add user to group's member list
      await _firestore.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });

      // Add group to user's profile (you'll need to implement this based on your user system)
      await _addGroupToUserProfile(userId, groupId);

      DebugLogger.log("✅ Added user $userName to group $groupId");
    } catch (e) {
      DebugLogger.log("❌ Error adding user to group: $e");
      throw Exception('Failed to add user to group: $e');
    }
  }

  /// Add group to user's profile
  Future<void> _addGroupToUserProfile(String userId, String groupId) async {
    try {
      // Update user document to include this group
      await _firestore.collection('users').doc(userId).update({
        'groupIds': FieldValue.arrayUnion([groupId]),
      });

      DebugLogger.log("✅ Added group $groupId to user $userId profile");
    } catch (e) {
      DebugLogger.log("❌ Error updating user profile: $e");
      // Don't throw here - user might not have a profile document yet
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get invitation statistics for a group
  Future<Map<String, int>> getGroupInvitationStats(String groupId) async {
    try {
      final snapshot = await _invitationsCollection
          .where('groupId', isEqualTo: groupId)
          .get();

      final stats = {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'declined': 0,
        'cancelled': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String;
        stats['total'] = (stats['total'] ?? 0) + 1;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      DebugLogger.log("❌ Error getting invitation stats: $e");
      return {'total': 0, 'pending': 0, 'accepted': 0, 'declined': 0, 'cancelled': 0};
    }
  }
}