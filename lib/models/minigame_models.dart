// File: lib/models/minigame_models.dart

enum GameType {
  emojiGuess,
  trivia,
  yearGuess,
  castGuess,
  // Future game types
}

enum GameFrequency {
  daily,
  weekly,
  monthly,
}

enum GameStatus {
  available,
  completed,
  locked,
  expired,
}

class MinigameChallenge {
  final String id;
  final GameType type;
  final GameFrequency frequency;
  final String title;
  final String description;
  final String emoji;
  final DateTime startDate;
  final DateTime endDate;
  final int maxScore;
  final int rewardPoints;
  final List<String> rewards;
  
  MinigameChallenge({
    required this.id,
    required this.type,
    required this.frequency,
    required this.title,
    required this.description,
    required this.emoji,
    required this.startDate,
    required this.endDate,
    required this.maxScore,
    required this.rewardPoints,
    this.rewards = const [],
  });
  
  GameStatus get status {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return GameStatus.locked;
    if (now.isAfter(endDate)) return GameStatus.expired;
    return GameStatus.available; // Will be overridden by user progress
  }
  
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }
  
  String get timeRemainingText {
    final remaining = timeRemaining;
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else {
      return '${remaining.inMinutes}m';
    }
  }
}

class GameProgress {
  final String challengeId;
  final int bestScore;
  final int attempts;
  final DateTime? lastPlayed;
  final DateTime? completedAt;
  final bool isCompleted;
  final int pointsEarned;
  
  GameProgress({
    required this.challengeId,
    this.bestScore = 0,
    this.attempts = 0,
    this.lastPlayed,
    this.completedAt,
    this.isCompleted = false,
    this.pointsEarned = 0,
  });
  
  GameProgress copyWith({
    int? bestScore,
    int? attempts,
    DateTime? lastPlayed,
    DateTime? completedAt,
    bool? isCompleted,
    int? pointsEarned,
  }) {
    return GameProgress(
      challengeId: challengeId,
      bestScore: bestScore ?? this.bestScore,
      attempts: attempts ?? this.attempts,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'challengeId': challengeId,
      'bestScore': bestScore,
      'attempts': attempts,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isCompleted': isCompleted,
      'pointsEarned': pointsEarned,
    };
  }
  
  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      challengeId: json['challengeId'],
      bestScore: json['bestScore'] ?? 0,
      attempts: json['attempts'] ?? 0,
      lastPlayed: json['lastPlayed'] != null 
          ? DateTime.parse(json['lastPlayed']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      isCompleted: json['isCompleted'] ?? false,
      pointsEarned: json['pointsEarned'] ?? 0,
    );
  }
}

class MinigameStats {
  final int totalPoints;
  final int gamesPlayed;
  final int gamesCompleted;
  final int currentStreak;
  final int longestStreak;
  final Map<GameType, int> typeStats;
  final DateTime? lastPlayDate;
  
  MinigameStats({
    this.totalPoints = 0,
    this.gamesPlayed = 0,
    this.gamesCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.typeStats = const {},
    this.lastPlayDate,
  });
  
  MinigameStats copyWith({
    int? totalPoints,
    int? gamesPlayed,
    int? gamesCompleted,
    int? currentStreak,
    int? longestStreak,
    Map<GameType, int>? typeStats,
    DateTime? lastPlayDate,
  }) {
    return MinigameStats(
      totalPoints: totalPoints ?? this.totalPoints,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesCompleted: gamesCompleted ?? this.gamesCompleted,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      typeStats: typeStats ?? this.typeStats,
      lastPlayDate: lastPlayDate ?? this.lastPlayDate,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalPoints': totalPoints,
      'gamesPlayed': gamesPlayed,
      'gamesCompleted': gamesCompleted,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'typeStats': typeStats.map((key, value) => MapEntry(key.name, value)),
      'lastPlayDate': lastPlayDate?.toIso8601String(),
    };
  }
  
  factory MinigameStats.fromJson(Map<String, dynamic> json) {
    final typeStatsJson = json['typeStats'] as Map<String, dynamic>? ?? {};
    final typeStats = <GameType, int>{};
    
    for (final entry in typeStatsJson.entries) {
      final gameType = GameType.values.firstWhere(
        (type) => type.name == entry.key,
        orElse: () => GameType.emojiGuess,
      );
      typeStats[gameType] = entry.value as int;
    }
    
    return MinigameStats(
      totalPoints: json['totalPoints'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      gamesCompleted: json['gamesCompleted'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      typeStats: typeStats,
      lastPlayDate: json['lastPlayDate'] != null 
          ? DateTime.parse(json['lastPlayDate']) 
          : null,
    );
  }
}