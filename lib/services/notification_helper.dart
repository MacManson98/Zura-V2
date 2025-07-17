// File: lib/services/notification_helper.dart
// Simple helper for non-session notifications only

import 'package:flutter/material.dart';
import '../utils/debug_loader.dart';
import '../utils/themed_notifications.dart'; // ✅ NEW: Use themed notifications
import 'session_service.dart';
import 'friendship_service.dart';
import 'group_invitation_service.dart';

class NotificationHelper {
  // Handle friend request actions
  static Future<void> handleFriendRequestAction({
    required Map<String, dynamic> requestData,
    required String action,
    required BuildContext context,
    required VoidCallback onFriendsUpdated,
  }) async {
    try {
      if (action == 'accept') {
        await FriendshipService.acceptFriendRequestById(
          requestDocumentId: requestData['id'],
          fromUserId: requestData['fromUserId'],
          toUserId: requestData['toUserId'],
        );
        
        onFriendsUpdated(); // Refresh friends list
        ThemedNotifications.showSuccess(context, '${requestData['fromUserName']} is now your friend!', icon: "👥");
      } else {
        await FriendshipService.declineFriendRequestById(requestData['id']);
        ThemedNotifications.showDecline(context, 'Declined friend request from ${requestData['fromUserName']}');
      }
    } catch (e) {
      DebugLogger.log("❌ Error handling friend request: $e");
      ThemedNotifications.showError(context, 'Failed to process friend request');
    }
  }

  // Handle group invitation actions
  static Future<void> handleGroupInviteAction({
    required Map<String, dynamic> inviteData,
    required String action,
    required BuildContext context,
  }) async {
    try {
      if (action == 'accept') {
        await GroupInvitationService().acceptGroupInvitation(inviteData['id']);
        ThemedNotifications.showSuccess(context, 'Joined ${inviteData['groupName']}!', icon: "🎭");
      } else {
        await GroupInvitationService().declineGroupInvitation(inviteData['id']);
        ThemedNotifications.showDecline(context, 'Declined group invitation');
      }
    } catch (e) {
      DebugLogger.log("❌ Error handling group invite: $e");
      ThemedNotifications.showError(context, 'Failed to process group invitation');
    }
  }

  // Clear all notifications with single call
  static Future<void> clearAllNotifications(String userId, BuildContext context) async {
    try {
      // Get all pending notifications
      final sessionInvitations = await SessionService.getPendingInvitations();
      final friendRequests = await FriendshipService.getPendingFriendRequestsList(userId);

      // Decline all session invitations
      for (final invitation in sessionInvitations) {
        await SessionService.declineInvitation(invitation['id'], invitation['sessionId']);
      }

      // Decline all friend requests
      for (final request in friendRequests) {
        await FriendshipService.declineFriendRequestById(request['id']);
      }

      // Decline all group invitations
      await GroupInvitationService().declineAllGroupInvitations(userId);

      ThemedNotifications.showSuccess(context, 'All notifications cleared successfully', icon: "🧹");
      DebugLogger.log("✅ All notifications cleared successfully");
    } catch (e) {
      DebugLogger.log("❌ Error clearing all notifications: $e");
      ThemedNotifications.showError(context, 'Failed to clear notifications');
    }
  }

  // Handle background notifications (friend session declines, etc.)
  static void handleBackgroundNotifications(
    List<Map<String, dynamic>> notifications,
    String userId,
    BuildContext context,
    Function(int) navigateToTab,
  ) {
    Future.microtask(() async {
      for (final notification in notifications) {
        if (notification['read'] == true) continue;
        
        if (notification['type'] == 'friend_session_declined' && 
            notification['action'] == 'cancel_session') {
          try {
            await SessionService.handleFriendSessionDeclined(
              sessionId: notification['sessionId'],
              declinedByUserId: notification['fromUserId'],
            );
            
            await SessionService.markNotificationAsRead(userId, notification['id']);
            
            if (context.mounted) {
              ThemedNotifications.showInfo(context, 'Your friend declined the session. Session cancelled.', icon: "🚫");
              // ✅ FIXED: Keep host on matcher screen instead of sending to friends screen
              navigateToTab(1); // Stay on matcher screen (index 1)
            }
          } catch (e) {
            DebugLogger.log("❌ Error handling friend session decline: $e");
          }
        }
      }
    });
  }

  static Future<bool?> showClearAllDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.clear_all, color: const Color(0xFFE5A00D), size: 24),
            SizedBox(width: 12),
            Text('Clear All Notifications', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'This will decline all invitations and clear all notifications. This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
            ),
            child: Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}