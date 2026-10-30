import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/repertoire_line.dart';
import '../services/repertoire_service.dart';

final repertoireServiceProvider =
    Provider<RepertoireService>((ref) => RepertoireService());

/// Every repertoire line belonging to [uid], oldest-added first.
final repertoireLinesProvider =
    FutureProvider.family<List<RepertoireLine>, String>((ref, uid) {
  final service = ref.watch(repertoireServiceProvider);
  return service.getLines(uid);
});

/// Just the lines of [uid]'s that are due for review right now - the set
/// `RepertoireReviewScreen` quizzes.
final dueRepertoireLinesProvider =
    FutureProvider.family<List<RepertoireLine>, String>((ref, uid) {
  final service = ref.watch(repertoireServiceProvider);
  return service.getDueLines(uid);
});
