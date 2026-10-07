import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/chess_engine_service.dart';
import '../../services/ai_opponent_engine_enhanced.dart';
import '../../widgets/game_analysis_bar.dart';
import 'package:chess/chess.dart' as chess_lib;

/// CPU Game Screen with Integrated Analysis
///
/// Displays chess game with real-time engine analysis, statistics,
/// and performance metrics using AIOpponentEngineEnhanced.
class CPUGameAnalysisScreen extends ConsumerStatefulWidget {
  const CPUGameAnalysisScreen({
    Key? key,
    this.difficulty = AIDifficulty.medium,
  }) : super(key: key);
  final AIDifficulty difficulty;

  @override
  ConsumerState<CPUGameAnalysisScreen> createState() =>
      _CPUGameAnalysisScreenState();
}

class _CPUGameAnalysisScreenState extends ConsumerState<CPUGameAnalysisScreen> {
  late ChessEngineService chess;
  late AIOpponentEngineEnhanced aiEngine;
  late GameAnalysisRecorder recorder;

  bool isThinking = false;
  String? selectedSquare;
  List<String> legalMovesFromSelected = [];
  Map<String, dynamic> lastEngineStats = {};
  int? lastEvaluation;

  @override
  void initState() {
    super.initState();
    chess = ChessEngineService();
    aiEngine = AIOpponentEngineEnhanced(chess, widget.difficulty);
    recorder = GameAnalysisRecorder();
  }

  @override
  void dispose() {
    recorder.saveGameAnalysis();
    super.dispose();
  }

  void _selectSquare(String square) {
    setState(() {
      if (selectedSquare == square) {
        selectedSquare = null;
        legalMovesFromSelected = [];
      } else {
        selectedSquare = square;
        _updateLegalMovesForSquare(square);
      }
    });
  }

  void _updateLegalMovesForSquare(String square) {
    final legalMoves = chess.getLegalMoves();
    final movesFromSquare = legalMoves
        .where((move) => move.fromAlgebraic == square)
        .map((move) => move.toAlgebraic)
        .toList();
    legalMovesFromSelected = movesFromSquare;
  }

  Future<void> _makePlayerMove(String to) async {
    if (selectedSquare == null) return;

    final from = selectedSquare!;
    final success = chess.makeMove(from, to);

    if (success) {
      setState(() {
        selectedSquare = null;
        legalMovesFromSelected = [];
      });

      // Record player move
      recorder.recordPlayerMove(
        from: from,
        to: to,
        stats: aiEngine.getSearchStats(),
      );

      // Wait a moment then AI moves
      await Future.delayed(const Duration(milliseconds: 500));
      await _makeAIMove();
    }
  }

  Future<void> _makeAIMove() async {
    if (chess.isGameOver()) return;

    setState(() {
      isThinking = true;
    });

    final stopwatch = Stopwatch()..start();

    // Get AI move with analysis
    final move = aiEngine.getBestMove();
    stopwatch.stop();

    if (move != null) {
      final from = move.substring(0, 2);
      final to = move.substring(2, 4);
      final promotion = move.length > 4 ? move.substring(4) : null;

      // Make the move
      chess.makeMove(from, to, promotion: promotion);

      // Collect statistics
      final stats = aiEngine.getSearchStats();
      final tableStats = aiEngine.getTableStats();

      // Record AI move and analysis
      recorder.recordAIMove(
        from: from,
        to: to,
        timeMs: stopwatch.elapsedMilliseconds,
        stats: stats,
        tableStats: tableStats,
      );

      setState(() {
        isThinking = false;
        lastEngineStats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CPU vs Player'),
            Text(
              '${widget.difficulty.displayName} - ${_getMoveCount()} moves',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Evaluation bar
          if (lastEngineStats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: EvaluationBar(
                evaluation: _estimateEvaluation(),
                maxEvaluation: 500,
                showValue: true,
              ),
            ),

          // Game analysis bar
          if (lastEngineStats.isNotEmpty)
            GameAnalysisBar(
              stats: lastEngineStats,
              detailed: false,
              onTapDetails: _showAnalysisDashboard,
            ),

          // Chess board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildChessBoard(),
              ),
            ),
          ),

          // Move history and controls
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status display
                Center(
                  child: Text(
                    _getGameStatus(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),

                // Move history
                SizedBox(
                  height: 60,
                  child: _buildMoveHistory(),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isThinking ? null : _resetGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Game'),
                    ),
                    ElevatedButton.icon(
                      onPressed: lastEngineStats.isNotEmpty
                          ? _showAnalysisDashboard
                          : null,
                      icon: const Icon(Icons.analytics),
                      label: const Text('Analysis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessBoard() {
    final board = chess.getBoard();
    const squareSize = 40.0;

    return Container(
      color: Colors.brown[100],
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          final rank = 7 - (index ~/ 8);
          final file = index % 8;
          final square =
              '${String.fromCharCode(97 + file)}${rank + 1}'; // a1-h8

          final isDark = (rank + file) % 2 == 1;
          final isSelected = selectedSquare == square;
          final isLegalMove = legalMovesFromSelected.contains(square);

          final piece = board[rank][file];

          return GestureDetector(
            onTap: () {
              if (isLegalMove && selectedSquare != null) {
                _makePlayerMove(square);
              } else if (!isThinking) {
                _selectSquare(square);
              }
            },
            child: Container(
              color: isSelected
                  ? Colors.yellow
                  : isLegalMove
                      ? Colors.green[300]
                      : isDark
                          ? Colors.brown[400]
                          : Colors.amber[100],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Piece
                  if (piece != null)
                    Text(
                      _getPieceSymbol(piece),
                      style: const TextStyle(fontSize: 24),
                    ),

                  // Legal move indicator
                  if (isLegalMove)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green[600],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoveHistory() {
    final moves = recorder.moves;
    if (moves.isEmpty) {
      return Center(
        child: Text(
          'No moves yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: moves.length,
      itemBuilder: (context, index) {
        final move = moves[index];
        final isAI = index % 2 == 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Chip(
            label: Text(
              '${index + 1}. ${move.notation}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            backgroundColor: isAI ? Colors.blue[100] : Colors.grey[300],
            avatar: CircleAvatar(
              backgroundColor: isAI ? Colors.blue : Colors.grey,
              child: Text(
                isAI ? 'AI' : 'P',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAnalysisDashboard() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Game Analysis'),
            automaticallyImplyLeading: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Performance metrics
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAnalysisSection(
                    'Performance Metrics',
                    [
                      ('Search Depth', '${lastEngineStats['depth']}'),
                      (
                        'Nodes Evaluated',
                        _formatNumber(
                            lastEngineStats['nodesEvaluated'] as int? ?? 0)
                      ),
                      (
                        'Difficulty',
                        lastEngineStats['difficulty'] as String? ?? 'N/A'
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Cache performance
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAnalysisSection(
                    'Cache Performance',
                    [
                      (
                        'Zobrist Hits',
                        (lastEngineStats['zobristHits'] as int? ?? 0).toString()
                      ),
                      (
                        'Zobrist Misses',
                        (lastEngineStats['zobristMisses'] as int? ?? 0)
                            .toString()
                      ),
                      (
                        'Hit Rate',
                        '${lastEngineStats['zobristHitRate'] as String? ?? '0.0'}%'
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Heuristic stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAnalysisSection(
                    'Heuristic Effectiveness',
                    [
                      (
                        'Killer Cutoffs',
                        '${(lastEngineStats['killerStats'] as Map?)?['totalCutoffs'] ?? 0}'
                      ),
                      (
                        'Countermove Cutoffs',
                        '${(lastEngineStats['countermoveStats'] as Map?)?['totalCutoffs'] ?? 0}'
                      ),
                      ('Adaptive Settings', widget.difficulty.displayName),
                    ],
                  ),
                ),

                // Game summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAnalysisSection(
                    'Game Summary',
                    [
                      ('Total Moves', _getMoveCount().toString()),
                      ('AI Analysis Runs', recorder.aiMoveCount.toString()),
                      ('Total Time', '${recorder.totalTimeMs}ms'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<(String, String)> items) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      item.$2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              )),
        ],
      );

  String _getPieceSymbol(chess_lib.Piece piece) {
    const symbols = {
      'p': '♟',
      'n': '♞',
      'b': '♝',
      'r': '♜',
      'q': '♛',
      'k': '♚',
      'P': '♙',
      'N': '♘',
      'B': '♗',
      'R': '♖',
      'Q': '♕',
      'K': '♔',
    };

    final symbol = piece.color == chess_lib.Color.WHITE
        ? piece.type.name.toUpperCase()
        : piece.type.name.toLowerCase();

    return symbols[symbol] ?? '?';
  }

  int _estimateEvaluation() {
    // Simplified evaluation based on move history
    // In a full implementation, this would come from position evaluation
    return 0;
  }

  String _getMoveCount() => ((recorder.moves.length + 1) ~/ 2).toString();

  String _getGameStatus() {
    if (chess.isGameOver()) {
      if (chess.isCheckmate()) {
        return chess.isWhiteTurn() ? 'Black Wins!' : 'White Wins!';
      } else if (chess.isStalemate()) {
        return 'Draw - Stalemate';
      } else {
        return 'Game Over';
      }
    } else if (chess.isCheck()) {
      return 'Check!';
    } else if (isThinking) {
      return 'AI Thinking...';
    } else if (chess.isWhiteTurn()) {
      return 'Your Move (White)';
    } else {
      return 'AI Move (Black)';
    }
  }

  void _resetGame() {
    setState(() {
      chess = ChessEngineService();
      aiEngine = AIOpponentEngineEnhanced(chess, widget.difficulty);
      recorder = GameAnalysisRecorder();
      selectedSquare = null;
      legalMovesFromSelected = [];
      lastEngineStats = {};
      isThinking = false;
    });
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Records game analysis for performance validation
class GameAnalysisRecorder {
  final List<MoveRecord> moves = [];
  int aiMoveCount = 0;
  int totalTimeMs = 0;

  void recordPlayerMove({
    required String from,
    required String to,
    required Map<String, dynamic> stats,
  }) {
    moves.add(MoveRecord(
      from: from,
      to: to,
      notation: '$from$to',
      isAI: false,
      timeMs: 0,
      stats: stats,
    ));
  }

  void recordAIMove({
    required String from,
    required String to,
    required int timeMs,
    required Map<String, dynamic> stats,
    required Map<String, dynamic> tableStats,
  }) {
    aiMoveCount++;
    totalTimeMs += timeMs;

    moves.add(MoveRecord(
      from: from,
      to: to,
      notation: '$from$to',
      isAI: true,
      timeMs: timeMs,
      stats: stats,
      tableStats: tableStats,
    ));
  }

  void saveGameAnalysis() {
    // In a full implementation, this would save to Firebase or local storage
    // For now, just log the summary
    print('Game Analysis Summary:');
    print('Total moves: ${moves.length}');
    print('AI moves: $aiMoveCount');
    print('Total time: ${totalTimeMs}ms');
    print(
        'Average time per AI move: ${(totalTimeMs / aiMoveCount).toStringAsFixed(0)}ms');
  }
}

/// Individual move record with analysis data
class MoveRecord {
  MoveRecord({
    required this.from,
    required this.to,
    required this.notation,
    required this.isAI,
    required this.timeMs,
    required this.stats,
    this.tableStats,
  });
  final String from;
  final String to;
  final String notation;
  final bool isAI;
  final int timeMs;
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? tableStats;
}
