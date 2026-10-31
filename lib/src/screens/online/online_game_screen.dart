import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../models/online_game.dart';
import '../../providers/board_theme_provider.dart';
import '../../providers/cosmetic_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../providers/user_preferences_provider.dart';
import '../../widgets/game_board.dart';
import '../../widgets/time_clock.dart';
import '../../widgets/game_info_panel.dart';
import '../../services/sound_service.dart';
import 'online_game_result_screen.dart';

/// Screen for playing online multiplayer chess games
class OnlineGameScreen extends ConsumerStatefulWidget {
  const OnlineGameScreen({
    required this.gameId,
    Key? key,
  }) : super(key: key);
  final String gameId;

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  late String _gameId;

  /// Guards against pushing OnlineGameResultScreen more than once - the
  /// game stream keeps emitting (e.g. opponent's late activity-timestamp
  /// writes) after the game has already ended, and each emission rebuilds
  /// this screen.
  bool _hasShownResult = false;

  /// A move queued via GameBoard's premove support while it was the
  /// opponent's turn, auto-submitted the moment it becomes the local
  /// player's turn (see `_buildGameBoard`'s post-frame callback).
  String? _premoveFrom;
  String? _premoveTo;
  String? _premovePromotion;

  @override
  void initState() {
    super.initState();
    _gameId = widget.gameId;
  }

  @override
  Widget build(BuildContext context) {
    final gameStream = ref.watch(gameStreamProvider(_gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Game'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGameMenu(context),
          ),
        ],
      ),
      body: gameStream.when(
        data: (game) => _buildGameBoard(context, game),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => _buildErrorState(err),
      ),
    );
  }

  /// Build main game board layout
  Widget _buildGameBoard(BuildContext context, OnlineGame game) {
    final isBoardActive = game.status == 'active';
    final isPlayerTurn = _isCurrentPlayerTurn(game);
    final isWhitePlayer = game.whitePlayerId == _getCurrentPlayerId();

    if (!isBoardActive && !_hasShownResult) {
      _hasShownResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                OnlineGameResultScreen(gameId: _gameId, game: game),
          ),
        );
      });
    }

    // A queued premove is submitted the moment it becomes the local
    // player's turn - scheduled as a post-frame callback (not inline)
    // since this method runs from build() and _submitMove eventually
    // calls setState. If the premove turns out illegal in the real
    // resulting position, _submitMove's own "Invalid move" snackbar
    // fires and the slot is simply cleared below rather than retried.
    if (isBoardActive && isPlayerTurn && _premoveFrom != null) {
      final from = _premoveFrom!;
      final to = _premoveTo!;
      final promotion = _premovePromotion;
      _premoveFrom = null;
      _premoveTo = null;
      _premovePromotion = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _submitMove(game, from, to, promotion: promotion);
      });
    }

    return Column(
      children: [
        // Top player info (opponent) with animated time clock
        PlayerTimeClock(
          playerName:
              isWhitePlayer ? game.blackPlayerName : game.whitePlayerName,
          rating: isWhitePlayer ? game.blackRating : game.whiteRating,
          timeMs: isWhitePlayer
              ? game.blackTimeRemainingMs
              : game.whiteTimeRemainingMs,
          isCurrentPlayer: false,
          onTimeExpired: () => _handleOpponentTimeout(game),
        ),

        const Divider(height: 1),

        // Chess Board with GameBoard widget
        Expanded(
          child: _buildChessBoardWidget(context, game, isPlayerTurn),
        ),

        const Divider(height: 1),

        // Bottom player info (self) with animated time clock
        PlayerTimeClock(
          playerName:
              isWhitePlayer ? game.whitePlayerName : game.blackPlayerName,
          rating: isWhitePlayer ? game.whiteRating : game.blackRating,
          timeMs: isWhitePlayer
              ? game.whiteTimeRemainingMs
              : game.blackTimeRemainingMs,
          isCurrentPlayer: true,
          backgroundColor: Colors.blue[50],
          onTimeExpired: () => _handlePlayerTimeout(game),
        ),

        _buildDrawOfferBanner(game),
        _buildTakebackRequestBanner(game),
        _buildAbandonmentForfeitBanner(game),
        _buildPremoveBanner(),

        // Move/Action buttons - once the game ends, OnlineGameResultScreen
        // (pushed above) shows the result/rematch/share actions instead.
        if (isBoardActive) _buildGameActions(context, game),
      ],
    );
  }

  /// Opponent-inactive forfeit claim, shown only to the waiting player
  /// once the opponent has gone silent past the threshold.
  Widget _buildAbandonmentForfeitBanner(OnlineGame game) {
    final uid = _getCurrentPlayerId();
    if (uid.isEmpty || !game.canClaimAbandonmentForfeit(uid)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your opponent has not moved in a while and appears to be '
            'inactive.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _showClaimForfeitConfirmation(context),
            child: const Text('Claim win by forfeit'),
          ),
        ],
      ),
    );
  }

  /// Shown while a premove is queued (selected during the opponent's
  /// turn via GameBoard's premoveColor/onPremove), so the player has
  /// some visible confirmation + a way to cancel it before it auto-fires.
  Widget _buildPremoveBanner() {
    if (_premoveFrom == null || _premoveTo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Premove queued: $_premoveFrom → $_premoveTo'
              '${_premovePromotion != null ? ' (=${_premovePromotion!.toUpperCase()})' : ''}',
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _premoveFrom = null;
                _premoveTo = null;
                _premovePromotion = null;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build chess board widget from game state
  Widget _buildChessBoardWidget(
    BuildContext context,
    OnlineGame game,
    bool isPlayerTurn,
  ) {
    try {
      final gameState = chess_lib.Chess.fromFEN(game.currentFen);
      final showCoordinates =
          ref.watch(userPreferencesProvider).value?.showCoordinates ?? true;

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: GameBoard(
            gameState: gameState,
            theme: ref.watch(selectedBoardThemeProvider),
            pieceSkin: ref.watch(selectedPieceSkinProvider),
            showCoordinates: showCoordinates,
            flipped: game.whitePlayerId != _getCurrentPlayerId(),
            blindfold: ref.watch(blindfoldModeProvider),
            // Online games don't support undo, so the real move history
            // (needed only to enable/disable the undo button) isn't wired
            // through - GameMove doesn't carry enough data to reconstruct
            // real chess_lib.Move objects (piece, color, flags, capture).
            moveHistory: const [],
            onMove: isPlayerTurn && game.status == 'active'
                ? (from, to, {promotion}) =>
                    _submitMove(game, from, to, promotion: promotion)
                : null,
            onResign: game.status == 'active' ? () => _resign(game) : null,
            showMaterial: true,
            isPlayerTurn: isPlayerTurn && game.status == 'active',
            premoveColor: !isPlayerTurn && game.status == 'active'
                ? (game.whitePlayerId == _getCurrentPlayerId()
                    ? chess_lib.Color.WHITE
                    : chess_lib.Color.BLACK)
                : null,
            onPremove: (from, to, {promotion}) {
              setState(() {
                _premoveFrom = from;
                _premoveTo = to;
                _premovePromotion = promotion;
              });
            },
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading board: $e'),
          ],
        ),
      );
    }
  }

  /// Build player information widget (name, rating, time)
  Widget _buildPlayerInfo({
    required String name,
    required int rating,
    required int timeMs,
    required bool isCurrentPlayer,
  }) {
    final minutes = timeMs ~/ 60000;
    final seconds = (timeMs % 60000) ~/ 1000;
    final timeColor = timeMs < 60000 ? Colors.red : Colors.black;

    return Container(
      color: isCurrentPlayer ? Colors.blue[50] : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rating: $rating',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: timeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: timeColor,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build game action buttons
  Widget _buildGameActions(BuildContext context, OnlineGame game) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Resign button
            OutlinedButton.icon(
              onPressed: () => _showResignConfirmation(context, game),
              icon: const Icon(Icons.flag),
              label: const Text('Resign'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),

            // Offer Draw button
            OutlinedButton.icon(
              onPressed: () => _offerDraw(game),
              icon: const Icon(Icons.handshake),
              label: const Text('Offer Draw'),
            ),

            // Claim Draw button
            OutlinedButton.icon(
              onPressed: () => _claimDraw(game),
              icon: const Icon(Icons.check),
              label: const Text('Claim Draw'),
            ),

            // Request Takeback button - only once it's the opponent's
            // turn (i.e. the local player just moved) and no takeback
            // request is already outstanding (OnlineGame.canRequestTakeback).
            if (game.canRequestTakeback(_getCurrentPlayerId()))
              OutlinedButton.icon(
                onPressed: () => _requestTakeback(game),
                icon: const Icon(Icons.undo),
                label: const Text('Request Takeback'),
              ),
          ],
        ),
      );

  /// Build a banner offering Accept/Decline when the opponent has an
  /// outstanding draw offer pending for the local player to respond to.
  Widget _buildDrawOfferBanner(OnlineGame game) {
    if (game.status != 'active') return const SizedBox.shrink();

    final hasIncomingOffer =
        ref.watch(drawOfferStreamProvider(_gameId)).value ?? false;
    if (!hasIncomingOffer) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Opponent offered a draw',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _acceptDraw,
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: _declineDraw,
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  /// Build a banner offering Accept/Decline when the opponent has
  /// requested a takeback (undoing the move they just made) -
  /// OnlineGame.canRespondToTakeback restricts this to the player who
  /// did NOT request it.
  Widget _buildTakebackRequestBanner(OnlineGame game) {
    if (!game.canRespondToTakeback(_getCurrentPlayerId())) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.undo, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Opponent requested a takeback',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _acceptTakeback,
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: _declineTakeback,
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  /// Request to undo the move just made
  Future<void> _requestTakeback(OnlineGame game) async {
    try {
      await ref
          .read(onlineGameServiceProvider)
          .requestTakeback(_gameId, _getCurrentPlayerId());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Takeback request sent to opponent'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting takeback: $e')),
        );
      }
    }
  }

  /// Accept the opponent's outstanding takeback request
  Future<void> _acceptTakeback() async {
    try {
      await ref
          .read(onlineGameServiceProvider)
          .acceptTakeback(_gameId, _getCurrentPlayerId());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting takeback: $e')),
        );
      }
    }
  }

  /// Decline the opponent's outstanding takeback request
  Future<void> _declineTakeback() async {
    try {
      await ref.read(onlineGameServiceProvider).declineTakeback(_gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takeback request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining takeback: $e')),
        );
      }
    }
  }

  /// Build error state
  Widget _buildErrorState(Object error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading game: $error'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );

  /// Show game menu options
  void _showGameMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Game Info'),
              onTap: () {
                Navigator.pop(context);
                _showGameInfo(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Move History'),
              onTap: () {
                Navigator.pop(context);
                _showMoveHistory(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abandon Game'),
              onTap: () {
                Navigator.pop(context);
                _showAbandonConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show resign confirmation dialog
  void _showResignConfirmation(BuildContext context, OnlineGame game) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game?'),
        content: const Text(
          'Are you sure you want to resign? This will lose the game.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _resign(game);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  /// Show abandon confirmation dialog
  void _showAbandonConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Game?'),
        content: const Text(
          'Abandoning will result in a loss. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _abandon();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }

  /// Show game info dialog with detailed game metadata
  void _showGameInfo(BuildContext context) {
    final game = ref.read(onlineGameProvider(_gameId)).value;
    if (game == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              child: GameInfoPanel(
                gameId: game.gameId,
                gameType: game.type,
                status: game.status,
                timeControl: game.timeControl,
                totalMoves: game.moves.length,
                elapsedSeconds: game.createdAt != null
                    ? DateTime.now().difference(game.createdAt).inSeconds
                    : 0,
                whitePlayerName: game.whitePlayerName,
                blackPlayerName: game.blackPlayerName,
                currentTurn: game.whitePlayerId == _getCurrentPlayerId()
                    ? (game.moves.length % 2 == 0 ? 'White' : 'Black')
                    : (game.moves.length % 2 == 0 ? 'Black' : 'White'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show move history
  void _showMoveHistory(BuildContext context) {
    final moves = ref.read(gameMoveProvider(_gameId)).value ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: moves.length,
            itemBuilder: (context, index) {
              final move = moves[index];
              return ListTile(
                title: Text('${index + 1}. ${move.from}${move.to}'),
                subtitle: Text(
                  'By ${move.playerId}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build info row for dialogs
  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value),
          ],
        ),
      );

  /// Resign from game
  Future<void> _resign(OnlineGame game) async {
    final notifier = ref.read(onlineGameNotifierProvider.notifier);
    try {
      await notifier.resign(_gameId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Offer draw
  Future<void> _offerDraw(OnlineGame game) async {
    try {
      // Play notification sound
      final soundService = ref.read(soundServiceProvider);
      await soundService.play(SoundEffect.notification);

      await ref
          .read(onlineGameServiceProvider)
          .offerDraw(_gameId, _getCurrentPlayerId());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draw offer sent to opponent'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error offering draw: $e')),
        );
      }
    }
  }

  /// Accept the opponent's outstanding draw offer
  Future<void> _acceptDraw() async {
    try {
      await ref.read(onlineGameServiceProvider).acceptDraw(_gameId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting draw: $e')),
        );
      }
    }
  }

  /// Decline the opponent's outstanding draw offer
  Future<void> _declineDraw() async {
    try {
      await ref.read(onlineGameServiceProvider).declineDraw(_gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draw offer declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining draw: $e')),
        );
      }
    }
  }

  /// Claim draw under the threefold-repetition or 50-move rule
  Future<void> _claimDraw(OnlineGame game) async {
    try {
      await ref.read(onlineGameServiceProvider).claimDraw(game.gameId);

      final soundService = ref.read(soundServiceProvider);
      await soundService.play(SoundEffect.success);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draw claimed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final soundService = ref.read(soundServiceProvider);
        await soundService.play(SoundEffect.error);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming draw: $e')),
        );
      }
    }
  }

  /// Abandon game
  Future<void> _abandon() async {
    final notifier = ref.read(onlineGameNotifierProvider.notifier);
    try {
      await notifier.abandon(_gameId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Show confirmation before claiming a win by forfeit
  void _showClaimForfeitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Win by Forfeit'),
        content: const Text(
          'Your opponent has been inactive for a long time. Claim this '
          'game as a win?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _claimAbandonmentForfeit();
            },
            child: const Text('Claim Win'),
          ),
        ],
      ),
    );
  }

  Future<void> _claimAbandonmentForfeit() async {
    try {
      await ref
          .read(onlineGameServiceProvider)
          .claimAbandonmentForfeit(_gameId, _getCurrentPlayerId());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Get current player ID
  String _getCurrentPlayerId() {
    final auth = ref.read(firebaseAuthProvider).value;
    return auth?.uid ?? '';
  }

  /// Check if it's the current player's turn
  bool _isCurrentPlayerTurn(OnlineGame game) {
    try {
      final gameState = chess_lib.Chess.fromFEN(game.currentFen);
      final currentPlayerId = _getCurrentPlayerId();
      final isWhitePlayer = game.whitePlayerId == currentPlayerId;

      // Determine whose turn it is based on chess state
      final isWhiteTurn = gameState.turn == chess_lib.Color.WHITE;

      return isWhitePlayer == isWhiteTurn;
    } catch (e) {
      return false;
    }
  }

  /// Handle player timeout
  Future<void> _handlePlayerTimeout(OnlineGame game) async {
    if (!mounted) return;

    // Play timeout sound
    final soundService = ref.read(soundServiceProvider);
    await soundService.play(SoundEffect.error);

    // Show timeout dialog and resign
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time Expired'),
        content: const Text('Your time has expired. The game has been lost.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resign(game);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Handle opponent timeout
  Future<void> _handleOpponentTimeout(OnlineGame game) async {
    if (!mounted) return;

    // Play victory sound
    final soundService = ref.read(soundServiceProvider);
    await soundService.play(SoundEffect.gameOver);

    // Show victory dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Opponent Timeout'),
        content: const Text('Your opponent ran out of time. You win!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Submit a move to the game
  Future<void> _submitMove(
    OnlineGame game,
    String from,
    String to, {
    String? promotion,
  }) async {
    try {
      // Validate move is legal
      final gameState = chess_lib.Chess.fromFEN(game.currentFen);
      final moveSucceeded = gameState.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });

      if (!moveSucceeded) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid move')),
          );
        }
        return;
      }

      final wasCapture = gameState.history.last.move.captured != null;

      // Record move in backend
      final notifier = ref.read(onlineGameNotifierProvider.notifier);
      final currentPlayerId = _getCurrentPlayerId();

      await notifier.recordMove(
        gameId: _gameId,
        moveNumber: game.moves.length + 1,
        from: from,
        to: to,
        promotion: promotion,
        playerId: currentPlayerId,
        updatedFen: gameState.fen,
        updatedPgn: gameState.pgn(),
      );

      // Play appropriate sound based on move type and game state
      final soundService = ref.read(soundServiceProvider);

      if (wasCapture) {
        // Capture move
        await soundService.play(SoundEffect.capture);
      } else {
        // Regular move
        await soundService.play(SoundEffect.movePiece);
      }

      // Check for check or checkmate
      if (gameState.in_check) {
        // Play check sound if opponent king is in check
        await Future.delayed(const Duration(milliseconds: 200));
        await soundService.play(SoundEffect.check);
      }

      if (gameState.in_checkmate) {
        // Play checkmate sound
        await Future.delayed(const Duration(milliseconds: 200));
        await soundService.play(SoundEffect.checkmate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Move sent'),
              duration: Duration(milliseconds: 800)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting move: $e')),
        );
      }
    }
  }
}
