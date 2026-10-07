import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an online multiplayer game
class OnlineGame {
  OnlineGame({
    required this.gameId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.whitePlayerId,
    required this.blackPlayerId,
    required this.whitePlayerName,
    required this.blackPlayerName,
    required this.whiteRating,
    required this.blackRating,
    required this.pgn,
    required this.currentFen,
    required this.moves,
    required this.timeControl,
    required this.timeControlMs,
    required this.whiteTimeRemainingMs,
    required this.blackTimeRemainingMs,
    this.startedAt,
    this.endedAt,
    this.lastMoveTimestamp,
    this.whiteLastActivityTimestamp,
    this.blackLastActivityTimestamp,
    this.result,
    this.resultReason,
    this.abandonedBy,
    this.whiteRatingDelta,
    this.blackRatingDelta,
    this.whiteNewRating,
    this.blackNewRating,
    this.drawOfferedBy,
  });

  /// Create from Firestore JSON
  factory OnlineGame.fromJson(Map<String, dynamic> json) => OnlineGame(
        gameId: json['gameId'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        startedAt: json['startedAt'] != null
            ? (json['startedAt'] as Timestamp).toDate()
            : null,
        endedAt: json['endedAt'] != null
            ? (json['endedAt'] as Timestamp).toDate()
            : null,
        whitePlayerId: json['whitePlayerId'] as String,
        blackPlayerId: json['blackPlayerId'] as String,
        whitePlayerName: json['whitePlayerName'] as String,
        blackPlayerName: json['blackPlayerName'] as String,
        whiteRating: json['whiteRating'] as int,
        blackRating: json['blackRating'] as int,
        pgn: json['pgn'] as String? ?? '',
        currentFen: json['currentFen'] as String,
        moves: (json['moves'] as List?)
                ?.map((m) => GameMove.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        timeControl: json['timeControl'] as String,
        timeControlMs: json['timeControlMs'] as int,
        whiteTimeRemainingMs: json['whiteTimeRemainingMs'] as int,
        blackTimeRemainingMs: json['blackTimeRemainingMs'] as int,
        lastMoveTimestamp: json['lastMoveTimestamp'] != null
            ? (json['lastMoveTimestamp'] as Timestamp).toDate()
            : null,
        whiteLastActivityTimestamp: json['whiteLastActivityTimestamp'] != null
            ? (json['whiteLastActivityTimestamp'] as Timestamp).toDate()
            : null,
        blackLastActivityTimestamp: json['blackLastActivityTimestamp'] != null
            ? (json['blackLastActivityTimestamp'] as Timestamp).toDate()
            : null,
        result: json['result'] as String?,
        resultReason: json['resultReason'] as String?,
        abandonedBy: json['abandonedBy'] as String?,
        whiteRatingDelta: json['whiteRatingDelta'] as int?,
        blackRatingDelta: json['blackRatingDelta'] as int?,
        whiteNewRating: json['whiteNewRating'] as int?,
        blackNewRating: json['blackNewRating'] as int?,
        drawOfferedBy: json['drawOfferedBy'] as String?,
      );
  final String gameId;
  final String type; // online_pvp, online_rapid, online_blitz
  final String status; // matchmaking, active, completed, abandoned
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Player information
  final String whitePlayerId;
  final String blackPlayerId;
  final String whitePlayerName;
  final String blackPlayerName;
  final int whiteRating;
  final int blackRating;

  /// Game state
  final String pgn;
  final String currentFen;
  final List<GameMove> moves;

  /// Time control
  final String timeControl; // 10min, 5min, 3min
  final int timeControlMs;
  final int whiteTimeRemainingMs;
  final int blackTimeRemainingMs;
  final DateTime? lastMoveTimestamp;
  final DateTime? whiteLastActivityTimestamp;
  final DateTime? blackLastActivityTimestamp;

  /// Game result
  final String? result; // white_win, black_win, draw
  final String?
      resultReason; // checkmate, resignation, timeout, draw_agreement, abandonment
  final String? abandonedBy;

  /// Rating changes
  final int? whiteRatingDelta;
  final int? blackRatingDelta;
  final int? whiteNewRating;
  final int? blackNewRating;

  /// Player ID of whoever currently has an outstanding draw offer, if any.
  final String? drawOfferedBy;

  /// Convert to Firestore JSON
  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'type': type,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'whitePlayerId': whitePlayerId,
        'blackPlayerId': blackPlayerId,
        'whitePlayerName': whitePlayerName,
        'blackPlayerName': blackPlayerName,
        'whiteRating': whiteRating,
        'blackRating': blackRating,
        'pgn': pgn,
        'currentFen': currentFen,
        'moves': moves.map((m) => m.toJson()).toList(),
        'timeControl': timeControl,
        'timeControlMs': timeControlMs,
        'whiteTimeRemainingMs': whiteTimeRemainingMs,
        'blackTimeRemainingMs': blackTimeRemainingMs,
        'lastMoveTimestamp': lastMoveTimestamp != null
            ? Timestamp.fromDate(lastMoveTimestamp!)
            : null,
        'whiteLastActivityTimestamp': whiteLastActivityTimestamp != null
            ? Timestamp.fromDate(whiteLastActivityTimestamp!)
            : null,
        'blackLastActivityTimestamp': blackLastActivityTimestamp != null
            ? Timestamp.fromDate(blackLastActivityTimestamp!)
            : null,
        'result': result,
        'resultReason': resultReason,
        'abandonedBy': abandonedBy,
        'whiteRatingDelta': whiteRatingDelta,
        'blackRatingDelta': blackRatingDelta,
        'whiteNewRating': whiteNewRating,
        'blackNewRating': blackNewRating,
        'drawOfferedBy': drawOfferedBy,
      };

  /// Create a copy with modifications
  OnlineGame copyWith({
    String? gameId,
    String? type,
    String? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? whitePlayerId,
    String? blackPlayerId,
    String? whitePlayerName,
    String? blackPlayerName,
    int? whiteRating,
    int? blackRating,
    String? pgn,
    String? currentFen,
    List<GameMove>? moves,
    String? timeControl,
    int? timeControlMs,
    int? whiteTimeRemainingMs,
    int? blackTimeRemainingMs,
    DateTime? lastMoveTimestamp,
    DateTime? whiteLastActivityTimestamp,
    DateTime? blackLastActivityTimestamp,
    String? result,
    String? resultReason,
    String? abandonedBy,
    int? whiteRatingDelta,
    int? blackRatingDelta,
    int? whiteNewRating,
    int? blackNewRating,
    String? drawOfferedBy,
    bool clearDrawOffer = false,
  }) =>
      OnlineGame(
        gameId: gameId ?? this.gameId,
        type: type ?? this.type,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        whitePlayerId: whitePlayerId ?? this.whitePlayerId,
        blackPlayerId: blackPlayerId ?? this.blackPlayerId,
        whitePlayerName: whitePlayerName ?? this.whitePlayerName,
        blackPlayerName: blackPlayerName ?? this.blackPlayerName,
        whiteRating: whiteRating ?? this.whiteRating,
        blackRating: blackRating ?? this.blackRating,
        pgn: pgn ?? this.pgn,
        currentFen: currentFen ?? this.currentFen,
        moves: moves ?? this.moves,
        timeControl: timeControl ?? this.timeControl,
        timeControlMs: timeControlMs ?? this.timeControlMs,
        whiteTimeRemainingMs: whiteTimeRemainingMs ?? this.whiteTimeRemainingMs,
        blackTimeRemainingMs: blackTimeRemainingMs ?? this.blackTimeRemainingMs,
        lastMoveTimestamp: lastMoveTimestamp ?? this.lastMoveTimestamp,
        whiteLastActivityTimestamp:
            whiteLastActivityTimestamp ?? this.whiteLastActivityTimestamp,
        blackLastActivityTimestamp:
            blackLastActivityTimestamp ?? this.blackLastActivityTimestamp,
        result: result ?? this.result,
        resultReason: resultReason ?? this.resultReason,
        abandonedBy: abandonedBy ?? this.abandonedBy,
        whiteRatingDelta: whiteRatingDelta ?? this.whiteRatingDelta,
        blackRatingDelta: blackRatingDelta ?? this.blackRatingDelta,
        whiteNewRating: whiteNewRating ?? this.whiteNewRating,
        blackNewRating: blackNewRating ?? this.blackNewRating,
        drawOfferedBy:
            clearDrawOffer ? null : (drawOfferedBy ?? this.drawOfferedBy),
      );

  /// Get whose turn it is
  String get currentTurn => moves.length.isEven ? 'white' : 'black';

  /// Get display name for current player
  String get currentPlayerName =>
      currentTurn == 'white' ? whitePlayerName : blackPlayerName;

  /// Is this game finished?
  bool get isFinished => status == 'completed' || status == 'abandoned';

  /// Is this game active?
  bool get isActive => status == 'active';
}

/// Represents a single move in an online game
class GameMove {
  GameMove({
    required this.moveNumber,
    required this.from,
    required this.to,
    required this.timestamp,
    required this.playerId,
    this.promotion,
  });

  /// Create from JSON
  factory GameMove.fromJson(Map<String, dynamic> json) => GameMove(
        moveNumber: json['moveNumber'] as int,
        from: json['from'] as String,
        to: json['to'] as String,
        promotion: json['promotion'] as String?,
        timestamp: (json['timestamp'] as Timestamp).toDate(),
        playerId: json['playerId'] as String,
      );
  final int moveNumber;
  final String from; // e2-e4 format
  final String to;
  final String? promotion;
  final DateTime timestamp;
  final String playerId;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'moveNumber': moveNumber,
        'from': from,
        'to': to,
        'promotion': promotion,
        'timestamp': Timestamp.fromDate(timestamp),
        'playerId': playerId,
      };

  /// Get notation (e.g., "e4", "Nf3")
  String get notation => '$from-$to${promotion != null ? '=$promotion' : ''}';
}

/// Matchmaking queue entry
class MatchmakingQueueEntry {
  // white, black, random

  MatchmakingQueueEntry({
    required this.queueId,
    required this.playerId,
    required this.playerName,
    required this.currentRating,
    required this.ratingRange,
    required this.timeControlType,
    required this.queuedAt,
    required this.timeoutAt,
    required this.priority,
    required this.status,
    required this.color,
    this.matchedGameId,
    this.matchedOpponentId,
  });

  /// Create from Firestore JSON
  factory MatchmakingQueueEntry.fromJson(Map<String, dynamic> json) =>
      MatchmakingQueueEntry(
        queueId: json['queueId'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        currentRating: json['currentRating'] as int,
        ratingRange:
            RatingRange.fromJson(json['ratingRange'] as Map<String, dynamic>),
        timeControlType: json['timeControlType'] as String,
        queuedAt: (json['queuedAt'] as Timestamp).toDate(),
        timeoutAt: (json['timeoutAt'] as Timestamp).toDate(),
        priority: json['priority'] as int,
        status: json['status'] as String,
        matchedGameId: json['matchedGameId'] as String?,
        matchedOpponentId: json['matchedOpponentId'] as String?,
        color: json['color'] as String? ?? 'random',
      );
  final String queueId;
  final String playerId;
  final String playerName;
  final int currentRating;
  final RatingRange ratingRange;
  final String timeControlType; // 10min, 5min, 3min
  final DateTime queuedAt;
  final DateTime timeoutAt;
  final int priority;
  final String status; // waiting, matched, expired
  final String? matchedGameId;
  final String? matchedOpponentId;
  final String color;

  /// Convert to Firestore JSON
  Map<String, dynamic> toJson() => {
        'queueId': queueId,
        'playerId': playerId,
        'playerName': playerName,
        'currentRating': currentRating,
        'ratingRange': ratingRange.toJson(),
        'timeControlType': timeControlType,
        'queuedAt': Timestamp.fromDate(queuedAt),
        'timeoutAt': Timestamp.fromDate(timeoutAt),
        'priority': priority,
        'status': status,
        'matchedGameId': matchedGameId,
        'matchedOpponentId': matchedOpponentId,
        'color': color,
      };

  /// Wait time in seconds
  int get waitTimeSeconds => DateTime.now().difference(queuedAt).inSeconds;

  /// Is expired?
  bool get isExpired => DateTime.now().isAfter(timeoutAt);
}

/// Rating range for matchmaking
class RatingRange {
  RatingRange({required this.min, required this.max});

  /// Create from JSON
  factory RatingRange.fromJson(Map<String, dynamic> json) => RatingRange(
        min: json['min'] as int,
        max: json['max'] as int,
      );
  final int min;
  final int max;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  /// Check if rating is in range
  bool contains(int rating) => rating >= min && rating <= max;

  /// Check if this range overlaps with another
  bool overlaps(RatingRange other) => !(max < other.min || min > other.max);
}

/// User presence information
class UserPresence {
  UserPresence({
    required this.playerId,
    required this.isOnline,
    required this.lastSeenAt,
    required this.currentActivity,
    required this.connectionStatus,
    required this.deviceInfo,
    this.currentGameId,
  });

  /// Create from Firestore JSON
  factory UserPresence.fromJson(Map<String, dynamic> json) => UserPresence(
        playerId: json['playerId'] as String,
        isOnline: json['isOnline'] as bool,
        lastSeenAt: (json['lastSeenAt'] as Timestamp).toDate(),
        currentActivity: json['currentActivity'] as String,
        currentGameId: json['currentGameId'] as String?,
        connectionStatus: json['connectionStatus'] as String,
        deviceInfo:
            DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
      );
  final String playerId;
  final bool isOnline;
  final DateTime lastSeenAt;
  final String currentActivity; // idle, matchmaking, in_game, studying
  final String? currentGameId;
  final String connectionStatus; // connected, disconnected
  final DeviceInfo deviceInfo;

  /// Convert to Firestore JSON
  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'isOnline': isOnline,
        'lastSeenAt': Timestamp.fromDate(lastSeenAt),
        'currentActivity': currentActivity,
        'currentGameId': currentGameId,
        'connectionStatus': connectionStatus,
        'deviceInfo': deviceInfo.toJson(),
      };

  /// Copy with modifications
  UserPresence copyWith({
    bool? isOnline,
    DateTime? lastSeenAt,
    String? currentActivity,
    String? currentGameId,
    String? connectionStatus,
    DeviceInfo? deviceInfo,
  }) =>
      UserPresence(
        playerId: playerId,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        currentActivity: currentActivity ?? this.currentActivity,
        currentGameId: currentGameId ?? this.currentGameId,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        deviceInfo: deviceInfo ?? this.deviceInfo,
      );
}

/// Device information for presence tracking
class DeviceInfo {
  DeviceInfo({
    required this.type,
    required this.lastActivity,
  });

  /// Create from JSON
  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        type: json['type'] as String,
        lastActivity: (json['lastActivity'] as Timestamp).toDate(),
      );
  final String type; // web, ios, android
  final DateTime lastActivity;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'type': type,
        'lastActivity': Timestamp.fromDate(lastActivity),
      };
}
