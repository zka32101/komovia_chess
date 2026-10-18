import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a just-generated game GIF to the OS share sheet with X/Twitter in
/// mind (hashtag-friendly caption, no attempt to attach unrelated apps'
/// text). There's no "launch directly into X with this file attached" on
/// either platform without X's own SDK/API credentials - a bare URL scheme
/// (`twitter://post?...`) can prefill text but cannot attach media from a
/// third-party app - so the real mechanism here is the system share sheet,
/// which lists X/Twitter (when installed) as one of the targets the user
/// picks. The button that calls this is labeled for X, but under the hood
/// it's the same general mechanism `Share.shareXFiles` always uses.
class GameShareService {
  Future<void> shareGameGif({
    required Uint8List gifBytes,
    required String caption,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/komovia_chess_game_${DateTime.now().millisecondsSinceEpoch}.gif',
    );
    await file.writeAsBytes(gifBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/gif')],
      text: caption,
    );
  }
}
