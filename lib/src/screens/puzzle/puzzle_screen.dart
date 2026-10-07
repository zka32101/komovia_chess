import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/puzzle.dart';
import '../../providers/puzzle_provider.dart';
import '../../services/chess_engine_service.dart';
import '../../widgets/game_board.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  int _selectedTab = 0; // 0: Daily, 1: By Rating

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Puzzles'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Tab selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        label: 'Daily Challenge',
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabButton(
                        label: 'By Rating',
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _selectedTab == 0
                    ? _buildDailyChallengeTab()
                    : _buildByRatingTab(),
              ),
            ],
          ),
        ),
      );

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
          ),
        ),
      );

  Widget _buildDailyChallengeTab() {
    final dailyChallenge = ref.watch(dailyChallengeProvider);
    final puzzleStats = ref.watch(userPuzzleStatsProvider);

    return dailyChallenge.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
      data: (challenge) {
        if (challenge == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No daily challenge available'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    // TODO: Refresh or load puzzles by rating
                  },
                  child: const Text('Browse Puzzles'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats card
              puzzleStats.when(
                data: (stats) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            label: 'Solved',
                            value: '${stats['puzzlesSolved'] ?? 0}',
                          ),
                          _buildStatItem(
                            label: 'Streak',
                            value: '${stats['dailyStreak'] ?? 0}',
                          ),
                          _buildStatItem(
                            label: 'Rating',
                            value: '${stats['averageRating'] ?? 1600}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                loading: () => const Skeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // Challenge info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today\'s Theme',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              challenge.theme,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${challenge.puzzleIds.length} puzzles',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete today\'s puzzle set to maintain your daily streak.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Start button
              FilledButton(
                onPressed: () {
                  // Navigate to puzzle solving
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PuzzleSolvingScreen(
                        puzzleIds: challenge.puzzleIds,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Start Today\'s Challenge'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByRatingTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Difficulty Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDifficultyCard(
                  label: 'Beginner',
                  rating: '800-1200',
                  color: Colors.green,
                  minRating: 800,
                  maxRating: 1200,
                ),
                _buildDifficultyCard(
                  label: 'Intermediate',
                  rating: '1200-1600',
                  color: Colors.blue,
                  minRating: 1200,
                  maxRating: 1600,
                ),
                _buildDifficultyCard(
                  label: 'Advanced',
                  rating: '1600-2000',
                  color: Colors.orange,
                  minRating: 1600,
                  maxRating: 2000,
                ),
                _buildDifficultyCard(
                  label: 'Expert',
                  rating: '2000+',
                  color: Colors.red,
                  minRating: 2000,
                  maxRating: 2500,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildDifficultyCard({
    required String label,
    required String rating,
    required Color color,
    required int minRating,
    required int maxRating,
  }) =>
      GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PuzzleListScreen(
                minRating: minRating,
                maxRating: maxRating,
                title: label,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rating,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildStatItem({
    required String label,
    required String value,
  }) =>
      Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
}

enum _PuzzleFeedback { none, correct, wrong, solved }

/// Interactive puzzle solving screen: presents each puzzle's [PuzzleModel.fen]
/// position and requires the solver to play [PuzzleModel.moves] in order.
/// Moves alternate solver/opponent: after each correct solver move, the next
/// move in the list (the opponent's reply) is auto-played, until the list is
/// exhausted.
class PuzzleSolvingScreen extends ConsumerStatefulWidget {
  const PuzzleSolvingScreen({
    required this.puzzleIds,
    Key? key,
  }) : super(key: key);
  final List<String> puzzleIds;

  @override
  ConsumerState<PuzzleSolvingScreen> createState() =>
      _PuzzleSolvingScreenState();
}

class _PuzzleSolvingScreenState extends ConsumerState<PuzzleSolvingScreen> {
  final _chess = ChessEngineService();
  int _puzzleIndex = 0;
  int _moveIndex = 0;
  String? _loadedPuzzleId;
  bool _isPlayerTurn = true;
  _PuzzleFeedback _feedback = _PuzzleFeedback.none;

  String get _currentPuzzleId => widget.puzzleIds[_puzzleIndex];

  void _loadPuzzle(PuzzleModel puzzle) {
    _chess.initGame(fen: puzzle.fen);
    _loadedPuzzleId = puzzle.id;
    _moveIndex = 0;
    _isPlayerTurn = true;
    _feedback = _PuzzleFeedback.none;
  }

  Future<void> _handleMove(String from, String to, {String? promotion}) async {
    final puzzle = await ref.read(puzzleByIdProvider(_currentPuzzleId).future);
    if (puzzle == null || !_isPlayerTurn) return;

    final attempted = '$from$to${promotion ?? ''}'.toLowerCase();
    final expected = puzzle.moves[_moveIndex].toLowerCase();

    if (attempted != expected) {
      setState(() => _feedback = _PuzzleFeedback.wrong);
      _recordAttempt(puzzle.id, solved: false, userMoves: [attempted]);
      return;
    }

    setState(() {
      _chess.makeMove(from, to, promotion: promotion);
      _moveIndex++;
      _feedback = _PuzzleFeedback.correct;
    });

    if (_moveIndex >= puzzle.moves.length) {
      setState(() => _feedback = _PuzzleFeedback.solved);
      _recordAttempt(puzzle.id, solved: true, userMoves: puzzle.moves);
      return;
    }

    // Auto-play the opponent's reply.
    setState(() => _isPlayerTurn = false);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _chess.makeMoveUCI(puzzle.moves[_moveIndex]);
      _moveIndex++;
      _feedback = _PuzzleFeedback.none;
      _isPlayerTurn = _moveIndex < puzzle.moves.length;
    });

    if (_moveIndex >= puzzle.moves.length) {
      setState(() => _feedback = _PuzzleFeedback.solved);
      _recordAttempt(puzzle.id, solved: true, userMoves: puzzle.moves);
    }
  }

  void _recordAttempt(
    String puzzleId, {
    required bool solved,
    required List<String> userMoves,
  }) {
    ref
        .read(puzzleServiceProvider)
        .recordPuzzleAttempt(
          puzzleId: puzzleId,
          solved: solved,
          userMoves: userMoves,
        )
        .catchError((_) {});
  }

  void _nextPuzzle() {
    if (_puzzleIndex + 1 >= widget.puzzleIds.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _puzzleIndex++;
      _loadedPuzzleId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleByIdProvider(_currentPuzzleId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Puzzle ${_puzzleIndex + 1} of ${widget.puzzleIds.length}'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _nextPuzzle,
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: puzzleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (puzzle) {
          if (puzzle == null) {
            return const Center(child: Text('Puzzle not found'));
          }
          if (_loadedPuzzleId != puzzle.id) {
            _loadPuzzle(puzzle);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Chip(label: Text('Rating: ${puzzle.rating}')),
                    for (final theme in puzzle.themes) Chip(label: Text(theme)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFeedbackBanner(),
                const SizedBox(height: 12),
                GameBoard(
                  gameState: _chess.rawChess,
                  onMove: _handleMove,
                  isPlayerTurn: _isPlayerTurn,
                  showMaterial: false,
                ),
                if (_feedback == _PuzzleFeedback.solved)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton(
                      onPressed: _nextPuzzle,
                      child: Text(
                        _puzzleIndex + 1 >= widget.puzzleIds.length
                            ? 'Finish'
                            : 'Next Puzzle',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    switch (_feedback) {
      case _PuzzleFeedback.correct:
        return const _FeedbackBanner(
          text: 'Correct!',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case _PuzzleFeedback.wrong:
        return const _FeedbackBanner(
          text: 'Not quite — try again',
          color: Colors.red,
          icon: Icons.cancel,
        );
      case _PuzzleFeedback.solved:
        return const _FeedbackBanner(
          text: 'Puzzle solved!',
          color: Colors.blue,
          icon: Icons.emoji_events,
        );
      case _PuzzleFeedback.none:
        return const Text(
          'Find the best move for the side to play',
          style: TextStyle(color: Colors.grey),
        );
    }
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.text,
    required this.color,
    required this.icon,
  });
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Lists puzzles within a rating range; tapping one starts solving from that
/// puzzle onward through the rest of the filtered list.
class PuzzleListScreen extends ConsumerWidget {
  const PuzzleListScreen({
    required this.minRating,
    required this.maxRating,
    required this.title,
    Key? key,
  }) : super(key: key);
  final int minRating;
  final int maxRating;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzlesAsync = ref.watch(
      puzzlesByRatingProvider((minRating: minRating, maxRating: maxRating)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: puzzlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (puzzles) {
          if (puzzles.isEmpty) {
            return const Center(child: Text('No puzzles found in this range'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: puzzles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final puzzle = puzzles[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${puzzle.rating}')),
                  title: Text(puzzle.themes.isNotEmpty
                      ? puzzle.themes.join(', ')
                      : 'Puzzle'),
                  subtitle: Text('${puzzle.moves.length} moves to solve'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PuzzleSolvingScreen(
                          puzzleIds:
                              puzzles.skip(index).map((p) => p.id).toList(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Skeleton loader placeholder
class Skeleton extends StatelessWidget {
  const Skeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
      );
}
