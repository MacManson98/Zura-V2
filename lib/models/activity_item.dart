// File: lib/models/activity_item.dart

import 'user_profile.dart';

// Defines different types of activities that can appear in the activity feed
enum ActivityType {
  movieLiked,
  friendMatch,
  groupCreated,
  movieWatched,
  friendAdded,
}

class ActivityItem {
  final ActivityType type;
  final DateTime timestamp;
  final UserProfile user;
  final String? movieTitle;
  final String? groupName;

  ActivityItem({
    required this.type,
    required this.timestamp,
    required this.user,
    this.movieTitle,
    this.groupName,
  });

  // Helper getter to display time in a user-friendly format
  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  // Helper getter to generate a description for this activity
  String get description {
    switch (type) {
      case ActivityType.movieLiked:
        return '${user.name} liked "$movieTitle"';
      case ActivityType.friendMatch:
        return '${user.name} matched with you on "$movieTitle"';
      case ActivityType.groupCreated:
        return '${user.name} created the group "$groupName"';
      case ActivityType.movieWatched:
        return '${user.name} watched "$movieTitle"';
      case ActivityType.friendAdded:
        return '${user.name} added you as a friend';
    }
  }

  // Optional: Add toJson and fromJson methods for persistence
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
      'user': user.toJson(),
      'movieTitle': movieTitle,
      'groupName': groupName,
    };
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: ActivityType.values[json['type'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      movieTitle: json['movieTitle'] as String?,
      groupName: json['groupName'] as String?,
    );
  }
}