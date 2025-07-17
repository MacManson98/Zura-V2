import '../movie.dart';
import 'user_profile.dart';
import 'friend_group.dart';

enum MatchType {
  friend, // Match with a single friend
  group, // Match with a group
}

class MatchItem {
  final String id;
  final Movie movie;
  final DateTime matchedAt;
  final MatchType matchType;
  final UserProfile? friend; // For friend matches
  final FriendGroup? group; // For group matches
  final List<UserProfile> likedBy; // Users who liked this movie (should include currentUser)
  bool watched;
  DateTime? watchedAt;

  MatchItem({
    required this.id,
    required this.movie,
    required this.matchedAt,
    required this.matchType,
    this.friend,
    this.group,
    required this.likedBy,
    this.watched = false,
    this.watchedAt,
  }) : assert((matchType == MatchType.friend && friend != null) || 
             (matchType == MatchType.group && group != null),
             'Friend match requires friend, group match requires group');

  // For when the movie is marked as watched
  void markAsWatched() {
    watched = true;
    watchedAt = DateTime.now();
  }

  // For when the movie is unmarked as watched
  void markAsUnwatched() {
    watched = false;
    watchedAt = null;
  }

  // Helper to count days since match
  int get daysSinceMatch => DateTime.now().difference(matchedAt).inDays;

  // Helper to count days since watched (if watched)
  int? get daysSinceWatched => watchedAt != null 
      ? DateTime.now().difference(watchedAt!).inDays 
      : null;

  // For sorting by most recent matches
  static int sortByRecent(MatchItem a, MatchItem b) => 
      b.matchedAt.compareTo(a.matchedAt);

  // For sorting by most recent watched
  static int sortByWatched(MatchItem a, MatchItem b) {
    if (a.watchedAt == null && b.watchedAt == null) return 0;
    if (a.watchedAt == null) return 1;
    if (b.watchedAt == null) return -1;
    return b.watchedAt!.compareTo(a.watchedAt!);
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movie': movie.toJson(),
      'matchedAt': matchedAt.toIso8601String(),
      'matchType': matchType.index,
      'friendId': friend?.name, // In a real app, this would be an actual ID
      'groupId': group?.id,
      'likedBy': likedBy.map((user) => user.name).toList(),
      'watched': watched,
      'watchedAt': watchedAt?.toIso8601String(),
    };
  }

  // Create from JSON
  factory MatchItem.fromJson(Map<String, dynamic> json, {
    required UserProfile Function(String) findFriend,
    required FriendGroup Function(String) findGroup,
  }) {
    final matchType = MatchType.values[json['matchType']];
    
    return MatchItem(
      id: json['id'],
      movie: Movie.fromJson(json['movie']),
      matchedAt: DateTime.parse(json['matchedAt']),
      matchType: matchType,
      friend: matchType == MatchType.friend ? findFriend(json['friendId']) : null,
      group: matchType == MatchType.group ? findGroup(json['groupId']) : null,
      likedBy: (json['likedBy'] as List)
          .map((name) => findFriend(name))
          .toList(),
      watched: json['watched'] ?? false,
      watchedAt: json['watchedAt'] != null 
          ? DateTime.parse(json['watchedAt']) 
          : null,
    );
  }
}