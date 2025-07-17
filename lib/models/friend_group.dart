// File: lib/models/friend_group.dart
// Enhanced version of your existing FriendGroup with persistence

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class FriendGroup {
  final String id;
  final String name;
  final String description;
  final List<UserProfile> members;
  final String createdBy;
  final String creatorId; // Add this for persistence
  final String imageUrl;
  
  // NEW: Persistence and statistics fields
  final DateTime createdAt;
  final DateTime lastActivityDate;
  final int totalSessions;
  final int totalMatches;
  final List<String> matchMovieIds;
  final DateTime? lastSessionDate;
  final bool isPrivate;
  final bool notificationsEnabled;

  FriendGroup({
    required this.id,
    required this.name,
    this.description = '',
    required this.members,
    required this.createdBy,
    String? creatorId, // Make optional with smart default
    required this.imageUrl,
    DateTime? createdAt, // Make optional with default
    DateTime? lastActivityDate, // Make optional with default
    this.totalSessions = 0,
    this.totalMatches = 0,
    List<String>? matchMovieIds,
    this.lastSessionDate,
    this.isPrivate = false,
    this.notificationsEnabled = true,
  }) : creatorId = creatorId ?? createdBy, // Use createdBy as fallback
       createdAt = createdAt ?? DateTime.now(),
       lastActivityDate = lastActivityDate ?? DateTime.now(),
       matchMovieIds = matchMovieIds ?? const [];

  // Factory for creating new groups
  factory FriendGroup.create({
    required String name,
    required String createdBy,
    required String creatorId,
    required List<UserProfile> members,
    String description = '',
    String imageUrl = '',
    bool isPrivate = false,
    bool notificationsEnabled = true,
  }) {
    final now = DateTime.now();
    return FriendGroup(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      members: members,
      createdBy: createdBy,
      creatorId: creatorId,
      imageUrl: imageUrl,
      createdAt: now,
      lastActivityDate: now,
      matchMovieIds: const [],
      isPrivate: isPrivate,
      notificationsEnabled: notificationsEnabled,
    );
  }

  // Convert to Firestore format (store member IDs, not full objects)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'creatorId': creatorId,
      'memberIds': members.map((member) => member.uid).toList(),
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'totalSessions': totalSessions,
      'totalMatches': totalMatches,
      'lastSessionDate': lastSessionDate != null
          ? Timestamp.fromDate(lastSessionDate!)
          : null,
      'isPrivate': isPrivate,
      'notificationsEnabled': notificationsEnabled,
      'matchMovieIds': matchMovieIds,
    };
  }

  // Create from Firestore (you'll need to load member UserProfiles separately)
  factory FriendGroup.fromFirestore(
    String docId, 
    Map<String, dynamic> data,
    List<UserProfile> memberProfiles, // Pass in the loaded member profiles
  ) {
    return FriendGroup(
      id: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      members: memberProfiles,
      createdBy: data['createdBy'] ?? '',
      creatorId: data['creatorId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivityDate: (data['lastActivityDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalSessions: data['totalSessions'] ?? 0,
      totalMatches: data['totalMatches'] ?? 0,
      matchMovieIds: List<String>.from(data['matchMovieIds'] ?? []),
      lastSessionDate: (data['lastSessionDate'] as Timestamp?)?.toDate(),
      isPrivate: data['isPrivate'] ?? false,
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }

  // Your existing toJson (for local storage/compatibility)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'members': members.map((member) => member.toJson()).toList(),
      'createdBy': createdBy,
      'creatorId': creatorId,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'totalSessions': totalSessions,
      'totalMatches': totalMatches,
      'matchMovieIds': matchMovieIds,
      'lastSessionDate': lastSessionDate?.toIso8601String(),
      'isPrivate': isPrivate,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  // Your existing fromJson
  factory FriendGroup.fromJson(Map<String, dynamic> json) {
    return FriendGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] ?? '',
      members: (json['members'] as List).map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList(),
      createdBy: json['createdBy'] as String,
      creatorId: json['creatorId'] ?? json['createdBy'], // Fallback for old data
      imageUrl: json['imageUrl'] as String,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      lastActivityDate: json['lastActivityDate'] != null ? DateTime.parse(json['lastActivityDate']) : DateTime.now(),
      totalSessions: json['totalSessions'] ?? 0,
      totalMatches: json['totalMatches'] ?? 0,
      matchMovieIds: List<String>.from(json['matchMovieIds'] ?? []),
      lastSessionDate: json['lastSessionDate'] != null ? DateTime.parse(json['lastSessionDate']) : null,
      isPrivate: json['isPrivate'] ?? false,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
    );
  }

  // Helper methods
  bool get hasRecentActivity => DateTime.now().difference(lastActivityDate).inDays < 7;
  bool isCreatedBy(String userId) => creatorId == userId;
  bool hasMember(String userId) => members.any((member) => member.uid == userId);
  int get memberCount => members.length;
  List<String> get memberIds => members.map((member) => member.uid).toList();

  // Update methods
  FriendGroup updateActivity({
    int? addSessions,
    int? addMatches,
    DateTime? sessionDate,
  }) {
    return copyWith(
      totalSessions: totalSessions + (addSessions ?? 0),
      totalMatches: totalMatches + (addMatches ?? 0),
      lastSessionDate: sessionDate ?? lastSessionDate,
      lastActivityDate: DateTime.now(),
    );
  }

  FriendGroup addMember(UserProfile user) {
    if (members.any((member) => member.uid == user.uid)) return this;
    
    return copyWith(
      members: [...members, user],
      lastActivityDate: DateTime.now(),
    );
  }

  FriendGroup removeMember(String userId) {
    // Don't allow removing the creator
    if (userId == creatorId) return this;
    
    final newMembers = members.where((member) => member.uid != userId).toList();
    return copyWith(
      members: newMembers,
      lastActivityDate: DateTime.now(),
    );
  }

  FriendGroup copyWith({
    String? id,
    String? name,
    String? description,
    List<UserProfile>? members,
    String? createdBy,
    String? creatorId,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? lastActivityDate,
    int? totalSessions,
    int? totalMatches,
    List<String>? matchMovieIds,
    DateTime? lastSessionDate,
    bool? isPrivate,
    bool? notificationsEnabled,
  }) {
    return FriendGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      createdBy: createdBy ?? this.createdBy,
      creatorId: creatorId ?? this.creatorId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      totalSessions: totalSessions ?? this.totalSessions,
      totalMatches: totalMatches ?? this.totalMatches,
      matchMovieIds: matchMovieIds ?? this.matchMovieIds,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      isPrivate: isPrivate ?? this.isPrivate,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendGroup &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}