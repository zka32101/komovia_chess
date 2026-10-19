import 'package:chess/chess.dart' as chess_lib;
import '../services/ai_opponent_engine.dart';

/// State of a CPU game
class CpuGameState {
  CpuGameState({
    required this.gameState,
    required this.difficulty,
    required this.startTime,
    this.moves = const [],
    this.isGameOver = false,
    this.result,
    this.endReason,
    this.endTime,
    this.isAIThinking = false,
    this.playerIsWhite = true,
    this.startingFen,
  });
  final chess_lib.Chess gameState;
  final AIDifficulty difficulty;
  final List<chess_lib.Move> moves;
  final bool isGameOver;
  final String? result; // 'white_win', 'black_win', 'draw'
  final String? endReason; // 'checkmate', 'resignation', 'stalemate'
  final DateTime startTime;
  final DateTime? endTime;
  final bool isAIThinking;
  final bool playerIsWhite;

  /// The FEN the game actually began from, when it wasn't the standard
  /// starting position (e.g. a midgame/endgame practice position) - null
  /// for an ordinary from-scratch game. Kept so [CpuGameNotifier.reset]
  /// can restart from the same practice position instead of always
  /// jumping back to move 1 of a brand new game.
  final String? startingFen;

  /// Get the current turn (true = white, false = black)
  bool get isWhiteTurn => gameState.turn == chess_lib.Color.WHITE;

  /// Check if it's the player's turn
  bool get isPlayerTurn {
    if (playerIsWhite) {
      return isWhiteTurn;
    } else {
      return !isWhiteTurn;
    }
  }

  /// Get game duration
  Duration get gameDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Create a copy with updated fields
  CpuGameState copyWith({
    chess_lib.Chess? gameState,
    AIDifficulty? difficulty,
    List<chess_lib.Move>? moves,
    bool? isGameOver,
    String? result,
    String? endReason,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAIThinking,
    bool? playerIsWhite,
    String? startingFen,
  }) =>
      CpuGameState(
        gameState: gameState ?? this.gameState,
        difficulty: difficulty ?? this.difficulty,
        moves: moves ?? this.moves,
        isGameOver: isGameOver ?? this.isGameOver,
        result: result ?? this.result,
        endReason: endReason ?? this.endReason,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        isAIThinking: isAIThinking ?? this.isAIThinking,
        playerIsWhite: playerIsWhite ?? this.playerIsWhite,
        startingFen: startingFen ?? this.startingFen,
      );
}
