import 'package:flutter/material.dart';
import '../../utils/pgn_importer.dart';
import '../online/game_review_screen.dart';

/// Lets the user paste an external PGN transcript and review it with the
/// same move-by-move/Stockfish-evaluation UI as a game played in this app
/// (`GameReviewScreen`). Paste-based rather than a native file picker,
/// since this app has no file-selection dependency at all yet and a
/// pasted PGN is just as usable for review.
class PgnImportScreen extends StatefulWidget {
  const PgnImportScreen({Key? key}) : super(key: key);

  @override
  State<PgnImportScreen> createState() => _PgnImportScreenState();
}

class _PgnImportScreenState extends State<PgnImportScreen> {
  final _controller = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleImport() {
    setState(() => _errorMessage = null);
    try {
      final game = parsePgnToOnlineGame(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              GameReviewScreen(gameId: game.gameId, game: game),
        ),
      );
    } on PgnParseException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'PGNを解析できませんでした。形式を確認してください。');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PGNをインポート'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '他のアプリやサイトからエクスポートしたPGN形式の棋譜を貼り付けると、'
                'このアプリの対局分析画面で振り返ることができます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText:
                        '[Event "?"]\n[White "Player 1"]\n[Black "Player 2"]\n'
                        '[Result "1-0"]\n\n1. e4 e5 2. Nf3 ...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleImport,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('インポートして分析'),
                ),
              ),
            ],
          ),
        ),
      );
}
