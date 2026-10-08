import 'package:komovia_core/testkit.dart';
import 'package:komovia_chess/komovia_chess_engine.dart';

void main() {
  runGameContractTests(
    ChessGame(),
    samplePosition: () => ChessGame().initialPosition(),
  );
}
