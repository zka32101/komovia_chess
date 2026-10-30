import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fair_play_service.dart';

final fairPlayServiceProvider =
    Provider<FairPlayService>((ref) => FairPlayService());
