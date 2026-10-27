import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/active_cpu_game.dart';
import '../services/active_cpu_game_service.dart';

/// 中断・再開機能。komovia_go/komovia_shogiの
/// `activeAiGameProvider`/`activeShogiGameProvider`と同じ役割 —
/// CPUGameSelectionScreenが「続きから」カードを出すかどうかの判定に使う。
/// 対局そのものの永続化・復元は`CpuGameNotifier`（`cpu_game_provider.dart`）
/// が直接行う（この画面にはすでにFirestoreへ直接アクセスする
/// `_recordResult`のような慣例があるため、それに合わせた）。
final activeCpuGameServiceProvider = Provider<ActiveCpuGameService>(
  (ref) => ActiveCpuGameService(),
);

final activeCpuGameProvider = FutureProvider.autoDispose<ActiveCpuGame?>((
  ref,
) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return await ref.read(activeCpuGameServiceProvider).getActive(uid);
  } catch (_) {
    return null;
  }
});
