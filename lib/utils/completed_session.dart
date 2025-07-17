// File: lib/models/completed_session.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionType { solo, friend, group }

class CompletedSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final SessionType type;
  final List<String> participantNames;
  final List<String> likedMovieIds; // For solo sessions
  final List<String> matchedMovieIds; // For collaborative sessions
  final String? mood; // If mood-based session
  final String? groupName;

  CompletedSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.participantNames,
    required this.likedMovieIds,
    required this.matchedMovieIds,
    this.mood,
    this.groupName,
  });

  // Auto-generate fun titles for collaborative sessions
  String get funTitle {
    if (type == SessionType.solo) {
      return _generateSoloTitle();
    } else {
      return _generateCollaborativeTitle();
    }
  }

  String _generateSoloTitle() {
    final timeOfDay = _getTimeOfDay(startTime);
    final dayName = _getDayName(startTime);
    final movieCount = likedMovieIds.length;
    
    if (movieCount == 0) {
      return "$dayName ${timeOfDay}Browsing";
    }
    
    // 🎯 Generate titles based on actual content
    if (mood != null && mood!.isNotEmpty) {
      // Use the session mood if available
      final moodName = mood!.toLowerCase();
      if (moodName.contains('action')) return "$dayName Action Hunt";
      if (moodName.contains('comedy')) return "$dayName Comedy Night";
      if (moodName.contains('horror')) return "$dayName Horror Session";
      if (moodName.contains('romance')) return "$dayName Romance Quest";
      if (moodName.contains('drama')) return "$dayName Drama Discovery";
      if (moodName.contains('thriller')) return "$dayName Thriller Hunt";
      if (moodName.contains('sci')) return "$dayName Sci-Fi Search";
      if (moodName.contains('fantasy')) return "$dayName Fantasy Adventure";
      if (moodName.contains('chill')) return "$dayName Chill Session";
      if (moodName.contains('intense')) return "$dayName Intense Picks";
    }
    
    // Fallback to count-based titles
    if (movieCount == 1) return "$dayName Perfect Pick";
    if (movieCount == 2) return "$dayName Double Feature";
    if (movieCount <= 4) return "$dayName Movie Hunt";
    if (movieCount <= 8) return "$dayName Discovery Session";
    return "$dayName Epic Find";
  }

  String _generateCollaborativeTitle() {
    final matchCount = matchedMovieIds.length;
    final isGroup = type == SessionType.group;
    
    if (matchCount == 0) {
      return isGroup ? "Group Browse Session" : "Friend Browse Session";
    } else if (matchCount == 1) {
      return isGroup ? "Group Perfect Match" : "Cinema Sync Success";
    } else if (matchCount == 2) {
      return isGroup ? "Group Double Feature" : "Movie Match Duo";
    } else {
      return isGroup ? "Group Movie Magic" : "Match Making Masters";
    }
  }

  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour < 6) return "Late Night ";
    if (hour < 12) return "Morning ";
    if (hour < 17) return "Afternoon ";
    if (hour < 21) return "Evening ";
    return "Night ";
  }

  String _getDayName(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(time.year, time.month, time.day);
    
    final difference = today.difference(sessionDay).inDays;
    
    if (difference == 0) return "Today's";
    if (difference == 1) return "Yesterday's";
    if (difference <= 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return "${days[time.weekday - 1]}'s";
    }
    return "${time.month}/${time.day}";
  }

  String get displayTitle {
    if (type == SessionType.solo) {
      final count = likedMovieIds.length;
      return "$funTitle • $count movie${count == 1 ? '' : 's'}";
    } else {
      final friendNames = participantNames.where((name) => name != "You").join(", ");
      final count = matchedMovieIds.length;
      return "With $friendNames • $count match${count == 1 ? '' : 'es'}";
    }
  }

  Duration get duration => endTime.difference(startTime);

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type.toString().split('.').last,
      'participantNames': participantNames,
      'likedMovieIds': likedMovieIds,
      'matchedMovieIds': matchedMovieIds,
      'mood': mood,
      'groupName': groupName,
    };
  }

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      type: SessionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      participantNames: List<String>.from(json['participantNames']),
      likedMovieIds: List<String>.from(json['likedMovieIds']),
      matchedMovieIds: List<String>.from(json['matchedMovieIds']),
      mood: json['mood'],
      groupName: json['groupName'] as String?,
    );
  }

  factory CompletedSession.fromFirestore(String docId, Map<String, dynamic> data) {
    return CompletedSession(
      id: docId,
      startTime: _parseDateTime(data['startedAt']) ?? DateTime.now(),
      endTime: _parseDateTime(data['completedAt']) ?? DateTime.now(), // Use now if null
            type: _inferSessionType(
        (data['inviteType'] ??
            data['sessionType'] ??
            (data['isGroupSession'] == true ? 'group' : null))
            ?.toString(),
      ),
      participantNames: List<String>.from(data['participantNames'] ?? []),
      likedMovieIds: [], // Optional: You can try reconstructing from `userLikes` if needed
      matchedMovieIds: List<String>.from(data['matches'] ?? []),
      mood: data['selectedMoodName'],
      groupName: data['groupName'] as String?,
    );
  }

  static SessionType _inferSessionType(String? inviteType) {
    switch (inviteType) {
      case 'friend':
        return SessionType.friend;
      case 'group':
        return SessionType.group;
      default:
        return SessionType.solo;
    }
  }

  static DateTime? _parseDateTime(dynamic input) {
    if (input == null) return null;
    if (input is Timestamp) return input.toDate();
    if (input is String) return DateTime.tryParse(input);
    return null;
  }
  
  // ✅ NEW: Get other participants for a completed session
  List<String> getOtherParticipantNames(String currentUserName) {
    return participantNames.where((name) => name != currentUserName).toList();
  }

  // ✅ NEW: Display format for other participants
  String getOtherParticipantsDisplay(String currentUserName, {int maxNames = 2}) {
    final otherNames = getOtherParticipantNames(currentUserName);
    
    if (otherNames.isEmpty) return "Solo Session";
    if (otherNames.length == 1) return otherNames.first;
    
    if (otherNames.length <= maxNames) {
      return otherNames.join(", ");
    } else {
      final displayed = otherNames.take(maxNames).join(", ");
      final remaining = otherNames.length - maxNames;
      return "$displayed and $remaining other${remaining == 1 ? '' : 's'}";
    }
  }

  String getSessionDisplayName(String currentUserName) {
    // For group sessions (3+ people), try to use group name first
    if (participantNames.length > 2) {
      if (groupName != null && groupName!.isNotEmpty) {
        return groupName!;
      }
      // Fallback to participant list for groups without names
      return getOtherParticipantsDisplay(currentUserName);
    }
    
    // For friend sessions (2 people), always use friend's name
    final otherParticipants = getOtherParticipantNames(currentUserName);
    return otherParticipants.isNotEmpty ? otherParticipants.first : "Friend Session";
  }

  /// Check if this is a group session (3+ participants)
  bool get isGroupSession => participantNames.length > 2;

  /// Check if this is a friend session (exactly 2 participants)
  bool get isFriendSession => participantNames.length == 2;

  /// Check if this session has a custom group name
  bool get hasGroupName => groupName != null && groupName!.isNotEmpty;
}