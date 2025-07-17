import '../movie.dart';
import '../utils/completed_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../utils/user_profile_storage.dart';
import '../utils/debug_loader.dart';

class MovieLike {
  final String movieId;
  final DateTime likedAt;
  final String sessionType; // "solo", "friend", "group"
  
  MovieLike({
    required this.movieId, 
    required this.likedAt, 
    required this.sessionType
  });
  
  factory MovieLike.fromJson(Map<String, dynamic> json) {
    return MovieLike(
      movieId: json['movieId'],
      likedAt: DateTime.parse(json['likedAt']),
      sessionType: json['sessionType'] ?? 'solo',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'movieId': movieId,
      'likedAt': likedAt.toIso8601String(),
      'sessionType': sessionType,
    };
  }
}

class UserProfile {
  String uid;
  String name;
  String email;
  Set<String> likedMovieIds;                    // ✅ KEEP: Personal likes
  List<CompletedSession> sessionHistory;        // ✅ KEEP: Session-based matches
  final List<String> friendIds;
  final List<String> groupIds;
  List<MovieLike> recentLikes;
  List<String> recentLikedMovieIds;
  DateTime lastActivityDate;
  Set<String> passedMovieIds;
  bool hasSeenMatcher = false;

  // ✅ KEEP: In-memory cache for personal likes only
  Set<Movie> _cachedLikedMovies = <Movie>{};
  Set<String> _cachedLikedMovieIds = <String>{};

  UserProfile({
    required this.uid,
    this.name = '',
    this.email = '',
    this.friendIds = const [],
    this.groupIds = const [],
    required this.likedMovieIds,
    this.hasSeenMatcher = false,
    List<String>? recentLikedMovieIds,
    DateTime? lastActivityDate,
    Set<String>? passedMovieIds,
    List<MovieLike>? recentLikes,
    this.sessionHistory = const [],
    // ✅ IGNORE: Old parameters for backwards compatibility
    Set<String>? preferredGenres,
    Set<String>? preferredVibes,
    Set<String>? blockedGenres, 
    Set<String>? blockedAttributes,
    Set<Movie>? likedMovies,
    Set<Movie>? matchedMovies,
    Map<String, double>? genreScores,
    Map<String, double>? vibeScores,
    })  : recentLikedMovieIds = recentLikedMovieIds ?? [],
        lastActivityDate = lastActivityDate ?? DateTime.now(),
        passedMovieIds = passedMovieIds ?? {},
        recentLikes = recentLikes ?? [];

  // ✅ SIMPLIFIED: Only liked movies getter
  Set<Movie> get likedMovies {
    return Set.from(_cachedLikedMovies);
  }

  // ✅ NEW: Get matched movies from sessions
  Set<Movie> getMatchedMoviesFromSessions() {
    final matchedIds = sessionHistory
        .where((session) => session.type != SessionType.solo)
        .expand((session) => session.matchedMovieIds)
        .toSet();
    
    // Return cached movies that match these IDs
    return _cachedLikedMovies.where((movie) => matchedIds.contains(movie.id)).toSet();
  }

  // ✅ SIMPLIFIED: Only for liked movies
  void addLikedMovie(Movie movie) {
    likedMovieIds.add(movie.id);
    _cachedLikedMovies.add(movie);
    _cachedLikedMovieIds.add(movie.id);
  }

  // ✅ BULK LOADING: Load missing movies into cache
  void loadMoviesIntoCache(List<Movie> movies) {
    for (final movie in movies) {
      // Add to liked cache if ID is in likedMovieIds but not yet cached
      if (likedMovieIds.contains(movie.id) && !_cachedLikedMovieIds.contains(movie.id)) {
        _cachedLikedMovies.add(movie);
        _cachedLikedMovieIds.add(movie.id);
      }
    }
  }

  // ✅ CACHE MANAGEMENT: Get IDs that need loading
  Set<String> getMissingLikedMovieIds() {
    return likedMovieIds.difference(_cachedLikedMovieIds);
  }

  // ✅ SIMPLIFIED: Only for liked movies
  set likedMovies(Set<Movie> value) {
    _cachedLikedMovies = Set.from(value);
    _cachedLikedMovieIds = value.map((movie) => movie.id).toSet();
    likedMovieIds = Set.from(_cachedLikedMovieIds);
  }

  void addCompletedSession(CompletedSession session) {
    sessionHistory.insert(0, session);
    if (sessionHistory.length > 50) {
      sessionHistory = sessionHistory.take(50).toList();
    }
  }

  // Get recent solo sessions
  List<CompletedSession> get recentSoloSessions {
    return sessionHistory
        .where((session) => session.type == SessionType.solo)
        .take(10)
        .toList();
  }

  // Get recent collaborative sessions
  List<CompletedSession> get recentCollaborativeSessions {
    return sessionHistory
        .where((session) => session.type != SessionType.solo)
        .take(10)
        .toList();
  }

  // Get sessions from last 7 days
  List<CompletedSession> get recentSessions {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return sessionHistory
        .where((session) => session.startTime.isAfter(weekAgo))
        .toList();
  }

  // Session statistics
  int get totalSessions => sessionHistory.length;
  
  int get totalMatches => sessionHistory
      .map((session) => session.matchedMovieIds.length)
      .fold(0, (sum, matches) => sum + matches);
  
  int get totalLikedFromSessions => sessionHistory
      .map((session) => session.likedMovieIds.length)
      .fold(0, (sum, likes) => sum + likes);

  Future<List<CompletedSession>> loadCollaborativeSessions(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('swipeSessions')
        .where('hostId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .get();

    return snapshot.docs.map((doc) {
      return CompletedSession.fromFirestore(doc.id, doc.data());
    }).toList();
  }

  factory UserProfile.empty() {
    return UserProfile(
      uid: '',
      name: '',
      email: '',
      friendIds: const [],
      groupIds: const [],
      likedMovieIds: {},
      recentLikedMovieIds: [],
      passedMovieIds: {},
      recentLikes: [],
    );
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    List<String>? friendIds,
    List<String>? groupIds,
    Set<String>? likedMovieIds,
    bool? hasSeenMatcher,
    List<String>? recentLikedMovieIds,
    DateTime? lastActivityDate,
    Set<String>? passedMovieIds,
    List<MovieLike>? recentLikes,
    List<CompletedSession>? sessionHistory,
    // ✅ IGNORE: Old parameters for backwards compatibility
    Set<String>? favouriteMovieIds,
    Set<String>? matchedMovieIds,
    List<Map<String, dynamic>>? matchHistory,
    Set<String>? preferredGenres,
    Set<String>? preferredVibes,
    Set<String>? blockedGenres,
    Set<String>? blockedAttributes,
    Set<Movie>? likedMovies,
    Set<Movie>? matchedMovies,
    Map<String, double>? genreScores,
    Map<String, double>? vibeScores,
  }) {
    final newProfile = UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      friendIds: friendIds ?? this.friendIds,
      groupIds: groupIds ?? this.groupIds,
      likedMovieIds: likedMovieIds ?? this.likedMovieIds,
      hasSeenMatcher: hasSeenMatcher ?? this.hasSeenMatcher,
      recentLikedMovieIds: recentLikedMovieIds ?? this.recentLikedMovieIds,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      passedMovieIds: passedMovieIds ?? this.passedMovieIds,
      recentLikes: recentLikes ?? this.recentLikes,
      sessionHistory: sessionHistory ?? this.sessionHistory,
    );
    
    // ✅ IMPORTANT: Preserve cache when copying
    newProfile._cachedLikedMovies = Set.from(_cachedLikedMovies);
    newProfile._cachedLikedMovieIds = Set.from(_cachedLikedMovieIds);
    
    return newProfile;
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'friendIds': friendIds,
      'groupIds': groupIds,
      'likedMovieIds': likedMovieIds.toList(),           // ✅ KEEP
      'hasSeenMatcher': hasSeenMatcher,
      'recentLikedMovieIds': recentLikedMovieIds,
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'passedMovieIds': passedMovieIds.toList(),
      'recentLikes': recentLikes.map((like) => like.toJson()).toList(),
      'sessionHistory': sessionHistory.map((session) => session.toJson()).toList(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendIds: List<String>.from(json['friendIds'] ?? []),
      groupIds: List<String>.from(json['groupIds'] ?? []),
      likedMovieIds: Set<String>.from(json['likedMovieIds'] ?? []),
      hasSeenMatcher: json['hasSeenMatcher'] ?? false,
      recentLikedMovieIds: List<String>.from(json['recentLikedMovieIds'] ?? []),
      lastActivityDate: json['lastActivityDate'] != null 
          ? DateTime.parse(json['lastActivityDate'])
          : DateTime.now(),
      passedMovieIds: Set<String>.from(json['passedMovieIds'] ?? []),
      recentLikes: (json['recentLikes'] as List<dynamic>?)
        ?.map((item) => MovieLike.fromJson(item as Map<String, dynamic>))
        .toList() ?? [],
      sessionHistory: (json['sessionHistory'] as List<dynamic>?)
          ?.map((sessionJson) => CompletedSession.fromJson(sessionJson))
          .toList() ?? [],
    );
  }

  // Helper methods
  bool isMemberOfGroup(String groupId) => groupIds.contains(groupId);
  int get groupCount => groupIds.length;
  bool get hasGroups => groupIds.isNotEmpty;

  // Add/remove group methods
  UserProfile addToGroup(String groupId) {
    if (groupIds.contains(groupId)) return this;
    return copyWith(groupIds: [...groupIds, groupId]);
  }

  UserProfile removeFromGroup(String groupId) {
    final newGroupIds = groupIds.where((id) => id != groupId).toList();
    return copyWith(groupIds: newGroupIds);
  }
  
  bool isFriendsWith(String userId) => friendIds.contains(userId);
  int get friendCount => friendIds.length;
  bool get hasFriends => friendIds.isNotEmpty;

  void removeDuplicateSessions() {
    final seen = <String>{};
    final uniqueSessions = <CompletedSession>[];
    
    for (final session in sessionHistory) {
      if (!seen.contains(session.id)) {
        seen.add(session.id);
        uniqueSessions.add(session);
      }
    }
    
    if (uniqueSessions.length != sessionHistory.length) {
      DebugLogger.log("🧹 Cleaned up ${sessionHistory.length - uniqueSessions.length} duplicate sessions");
      sessionHistory = uniqueSessions;
    }
  }

  // Get all sessions for display (combines local solo + firestore collaborative)
  Future<List<CompletedSession>> getAllSessionsForDisplay() async {
    final soloSessions = sessionHistory
        .where((session) => session.type == SessionType.solo)
        .toList();
    
    try {
      final uid = this.uid;
      final userService = UserService();
      final collaborativeSessions = await userService.loadCollaborativeSessionsForDisplay(uid);
      
      // Combine and sort by date
      final allSessions = [...soloSessions, ...collaborativeSessions];
      allSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return allSessions;
    } catch (e) {
      DebugLogger.log("Error loading collaborative sessions: $e");
      return soloSessions; // Fallback to solo sessions only
    }
  }

  // Delete session from appropriate storage
  Future<void> deleteSession(CompletedSession session) async {
    if (session.type == SessionType.solo) {
      // Remove from local storage
      sessionHistory.removeWhere((s) => s.id == session.id);
      await UserProfileStorage.saveProfile(this);
    } else {
      // Remove from Firestore
      try {
        await FirebaseFirestore.instance
            .collection('swipeSessions')
            .doc(session.id)
            .delete();
      } catch (e) {
        DebugLogger.log("Error deleting collaborative session: $e");
      }
    }
  }

  // ✅ COMPATIBILITY: Temporary getters for existing code
  // These provide backwards compatibility while you migrate your UI code
  Set<String> get preferredGenres => <String>{};
  Set<String> get preferredVibes => <String>{};
  Set<String> get blockedGenres => <String>{};
  Set<String> get blockedAttributes => <String>{};
  Map<String, double> get genreScores => <String, double>{};
  Map<String, double> get vibeScores => <String, double>{};
}