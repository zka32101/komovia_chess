import 'package:flutter/material.dart';
import '../../data/chess_curriculum_data.dart';
import '../../widgets/learn/piece_movement_diagram.dart';

/// Beginner-friendly, step-by-step tutorial covering the basic rules of
/// chess and how each piece moves.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({Key? key}) : super(key: key);

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Page 0 is the "game basics" intro; pages after that are one per piece.
  int get _totalPages => ChessCurriculumData.pieceMovementSteps.length + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('遊び方'),
          elevation: 0,
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              minHeight: 4,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _GameBasicsPage(),
                  for (final step in ChessCurriculumData.pieceMovementSteps)
                    _PieceMovementPage(step: step),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _goToPage(_currentPage - 1),
                          child: const Text('もどる'),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _currentPage < _totalPages - 1
                            ? () => _goToPage(_currentPage + 1)
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          _currentPage < _totalPages - 1 ? 'つぎへ' : '完了',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _GameBasicsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'チェスの基本ルール',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'まずは、ゲーム全体の基本的な流れを確認しましょう。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            for (final basic in ChessCurriculumData.gameBasics)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        basic,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'つぎのページから、それぞれの駒の動かし方を1つずつ見ていきます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      );
}

class _PieceMovementPage extends StatelessWidget {
  const _PieceMovementPage({required this.step});
  final PieceMovementStep step;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              step.pieceName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              step.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: PieceMovementDiagram(
                symbol: step.symbol,
                pieceSquare: step.pieceSquare,
                highlightSquares: step.highlightSquares,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '動き方のポイント',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            for (final detail in step.details)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        detail,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
