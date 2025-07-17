// File: lib/models/session_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SessionStatus {
  created,     // Host created, waiting for friend
  active,      // Both users joined, swiping together
  completed,   // Session finished
  cancelled,   // Session cancelled by someone
}

enum InvitationType {
  friend,      // Direct friend invite
  code,        // Share code method
  group,
}

class MoodChangeRequest {
  final String fromUserId;
  final String fromUserName;
  final String requestedMoodId;
  final String requestedMoodName;
  final DateTime requestedAt;
  final Map<String, bool> responses; // userId -> accepted/declined

  MoodChangeRequest({
    required this.fromUserId,
    required this.fromUserName,
    required this.requestedMoodId,
    required this.requestedMoodName,
    required this.requestedAt,
    required this.responses,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'requestedMoodId': requestedMoodId,
      'requestedMoodName': requestedMoodName,
      'requestedAt': requestedAt.toIso8601String(),
      'responses': responses,
    };
  }

  factory MoodChangeRequest.fromJson(Map<String, dynamic> json) {
    return MoodChangeRequest(
      fromUserId: json['fromUserId'] ?? '',
      fromUserName: json['fromUserName'] ?? '',
      requestedMoodId: json['requestedMoodId'] ?? '',
      requestedMoodName: json['requestedMoodName'] ?? '',
      requestedAt: DateTime.parse(json['requestedAt']),
      responses: Map<String, bool>.from(json['responses'] ?? {}),
    );
  }
}

class SwipeSession {
  final String sessionId;
  final String hostId;
  final String hostName;
  final String? groupId;
  final List<String> participantIds;
  final List<String> participantNames;
  final SessionStatus status;
  final List<String> matches;
  final String? sessionCode;
  final List<String> moviePool;
  final bool hasMoodSelected;
  final String selectedMoodId;
  final String selectedMoodName;
  final String? selectedMoodEmoji;
  final InvitationType inviteType;
  final Map<String, List<String>> userLikes;
  final Map<String, List<String>> userPasses;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  
  // Fields for cancellation support
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime? moodChangedAt;
  final MoodChangeRequest? pendingMoodChangeRequest;
  
  // Additional fields that were referenced in your copyWith method
  final Map<String, dynamic> sessionSettings;
  final List<String> selectedMoodIds;
  final int currentMovieIndex;
  final String? groupName;

  SwipeSession({
    required this.sessionId,
    required this.hostId,
    required this.hostName,
    required this.participantIds,
    required this.participantNames,
    required this.status,
    required this.matches,
    this.sessionCode,
    required this.moviePool,
    required this.hasMoodSelected,
    required this.selectedMoodId,
    required this.selectedMoodName,
    this.selectedMoodEmoji,
    required this.inviteType,
    required this.userLikes,
    required this.userPasses,
    required this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledBy,
    this.cancelledAt,
    this.moodChangedAt,
    this.pendingMoodChangeRequest,
    required this.sessionSettings,
    required this.selectedMoodIds,
    required this.currentMovieIndex,
    this.groupName,
    this.groupId,
  });

  factory SwipeSession.create({
    required String hostId,
    required String hostName,
    required InvitationType inviteType,
    String? sessionCode,
    String? selectedMoodId,
    String? selectedMoodName,
    String? selectedMoodEmoji,
    String? groupName,
    
  }) {
    return SwipeSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      hostId: hostId,
      hostName: hostName,
      participantIds: [hostId],
      participantNames: [hostName],
      status: SessionStatus.created,
      sessionCode: sessionCode,
      createdAt: DateTime.now(),
      sessionSettings: {},
      selectedMoodIds: selectedMoodId != null ? [selectedMoodId] : [],
      moviePool: [],
      userLikes: {hostId: []},
      userPasses: {hostId: []},
      matches: [],
      inviteType: inviteType,
      currentMovieIndex: 0,
      // Mood fields
      hasMoodSelected: selectedMoodId != null && selectedMoodName != null,
      selectedMoodId: selectedMoodId ?? '',
      selectedMoodName: selectedMoodName ?? '',
      selectedMoodEmoji: selectedMoodEmoji,
      groupName: groupName,
    );
  }

  SwipeSession copyWith({
    String? sessionId,
    String? hostId,
    String? hostName,
    List<String>? participantIds,
    List<String>? participantNames,
    SessionStatus? status,
    String? sessionCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? sessionSettings,
    List<String>? selectedMoodIds,
    List<String>? moviePool,
    Map<String, List<String>>? userLikes,
    Map<String, List<String>>? userPasses,
    List<String>? matches,
    int? currentMovieIndex,
    InvitationType? inviteType,
    bool? hasMoodSelected,
    String? selectedMoodId,
    String? selectedMoodName,
    String? selectedMoodEmoji,
    String? cancelledBy,
    DateTime? cancelledAt,
    DateTime? moodChangedAt,
    DateTime? updatedAt,
    MoodChangeRequest? pendingMoodChangeRequest, // 🆕 ADDED
    String? groupName,
  }) {
    return SwipeSession(
      sessionId: sessionId ?? this.sessionId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      status: status ?? this.status,
      sessionCode: sessionCode ?? this.sessionCode,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      sessionSettings: sessionSettings ?? this.sessionSettings,
      selectedMoodIds: selectedMoodIds ?? this.selectedMoodIds,
      moviePool: moviePool ?? this.moviePool,
      userLikes: userLikes ?? this.userLikes,
      userPasses: userPasses ?? this.userPasses,
      matches: matches ?? this.matches,
      currentMovieIndex: currentMovieIndex ?? this.currentMovieIndex,
      inviteType: inviteType ?? this.inviteType,
      hasMoodSelected: hasMoodSelected ?? this.hasMoodSelected,
      selectedMoodId: selectedMoodId ?? this.selectedMoodId,
      selectedMoodName: selectedMoodName ?? this.selectedMoodName,
      selectedMoodEmoji: selectedMoodEmoji ?? this.selectedMoodEmoji,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      moodChangedAt: moodChangedAt ?? this.moodChangedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingMoodChangeRequest: pendingMoodChangeRequest ?? this.pendingMoodChangeRequest,
      groupName: groupName ?? this.groupName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'hostId': hostId,
      'hostName': hostName,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'status': status.name,
      'matches': matches,
      'sessionCode': sessionCode,
      'moviePool': moviePool,
      'hasMoodSelected': hasMoodSelected,
      'selectedMoodId': selectedMoodId,
      'selectedMoodName': selectedMoodName,
      'selectedMoodEmoji': selectedMoodEmoji,
      'inviteType': inviteType.name,
      'userLikes': userLikes,
      'userPasses': userPasses,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'moodChangedAt': moodChangedAt?.toIso8601String(),
      'pendingMoodChangeRequest': pendingMoodChangeRequest?.toJson(), // 🆕 ADDED
      // Additional fields
      'sessionSettings': sessionSettings,
      'selectedMoodIds': selectedMoodIds,
      'currentMovieIndex': currentMovieIndex,
      'groupName': groupName,
    };
  }

  factory SwipeSession.fromJson(Map<String, dynamic> json) {
    return SwipeSession(
      sessionId: json['sessionId'] ?? '',
      hostId: json['hostId'] ?? '',
      hostName: json['hostName'] ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantNames: List<String>.from(json['participantNames'] ?? []),
      status: _parseStatus(json['status']),
      matches: List<String>.from(json['matches'] ?? []),
      sessionCode: json['sessionCode'],
      moviePool: List<String>.from(json['moviePool'] ?? []),
      hasMoodSelected: json['hasMoodSelected'] ?? false,
      selectedMoodId: json['selectedMoodId'] ?? '',
      selectedMoodName: json['selectedMoodName'] ?? '',
      selectedMoodEmoji: json['selectedMoodEmoji'],
      inviteType: _parseInviteType(json['inviteType']),
      userLikes: Map<String, List<String>>.from(
        (json['userLikes'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      userPasses: Map<String, List<String>>.from(
        (json['userPasses'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value ?? [])),
        ),
      ),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']),
      startedAt: _parseDateTime(json['startedAt']),
      completedAt: _parseDateTime(json['completedAt']),
      cancelledBy: json['cancelledBy'],
      cancelledAt: _parseDateTime(json['cancelledAt']),
      moodChangedAt: _parseDateTime(json['moodChangedAt']),
      pendingMoodChangeRequest: json['pendingMoodChangeRequest'] != null  // 🆕 ADDED
          ? MoodChangeRequest.fromJson(json['pendingMoodChangeRequest'])
          : null,
      // Additional fields
      sessionSettings: Map<String, dynamic>.from(json['sessionSettings'] ?? {}),
      selectedMoodIds: List<String>.from(json['selectedMoodIds'] ?? []),
      currentMovieIndex: json['currentMovieIndex'] ?? 0,
      groupName: json['groupName'] as String?,
    );
  }

  // Helper methods for parsing
  static SessionStatus _parseStatus(String? status) {
    switch (status) {
      case 'created':
        return SessionStatus.created;
      case 'active':
        return SessionStatus.active;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      default:
        return SessionStatus.created;
    }
  }

  static InvitationType _parseInviteType(String? type) {
    switch (type) {
      case 'code':
        return InvitationType.code;
      case 'friend':
        return InvitationType.friend;
      case 'group':
        return InvitationType.group;
      default:
        return InvitationType.code;
    }
  }

  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    
    if (dateTime is Timestamp) {
      return dateTime.toDate();
    } else if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  // Helper methods
  bool get isHost => FirebaseAuth.instance.currentUser?.uid == hostId;
  bool get isActive => status == SessionStatus.active;
  bool get isWaitingForParticipants => status == SessionStatus.created;
  bool get isCancelled => status == SessionStatus.cancelled;
  bool get isCompleted => status == SessionStatus.completed;
  bool get hasPendingMoodRequest => pendingMoodChangeRequest != null;
  
  bool hasUserLiked(String userId, String movieId) {
    return userLikes[userId]?.contains(movieId) ?? false;
  }
  
  bool hasUserPassed(String userId, String movieId) {
    return userPasses[userId]?.contains(movieId) ?? false;
  }
  
  bool isMovieMatch(String movieId) {
    return matches.contains(movieId);
  }
  
  int getUserSwipeCount(String userId) {
    final likes = userLikes[userId]?.length ?? 0;
    final passes = userPasses[userId]?.length ?? 0;
    return likes + passes;
  }
  
  double getSessionProgress() {
    if (moviePool.isEmpty) return 0.0;
    return currentMovieIndex / moviePool.length;
  }

  // ✅ NEW: Clean method to get other participants from current user's perspective
  List<String> getOtherParticipantNames(String currentUserId) {
    // Find current user's index in participantIds
    final currentUserIndex = participantIds.indexOf(currentUserId);
    
    // If user not found, return empty list (safer than returning all names)
    if (currentUserIndex == -1) return [];
    
    // Return all participant names except the current user's name
    final otherNames = <String>[];
    for (int i = 0; i < participantNames.length; i++) {
      if (i != currentUserIndex) {
        otherNames.add(participantNames[i]);
      }
    }
    
    return otherNames;
  }

  // ✅ NEW: Convenience method to get other participant names as a formatted string
  String getOtherParticipantsDisplay(String currentUserId, {int maxNames = 2}) {
    final otherNames = getOtherParticipantNames(currentUserId);
    
    if (otherNames.isEmpty) return "Solo Session";
    if (otherNames.length == 1) return otherNames.first;
    
    // Show up to maxNames, then "and X others" if more
    if (otherNames.length <= maxNames) {
      return otherNames.join(", ");
    } else {
      final displayed = otherNames.take(maxNames).join(", ");
      final remaining = otherNames.length - maxNames;
      return "$displayed and $remaining other${remaining == 1 ? '' : 's'}";
    }
  }
}