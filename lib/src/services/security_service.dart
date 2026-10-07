import 'package:cloud_firestore/cloud_firestore.dart';

// Phase R: セキュリティ & コンプライアンス
class SecurityService {
  factory SecurityService() => _instance;
  SecurityService._internal();
  static final SecurityService _instance = SecurityService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ 2要素認証の有効化 (認証確認付き)
  Future<void> enableTwoFactorAuth(
    String currentUserId,
    String targetUserId,
  ) async {
    // 認証確認: 現在のユーザーが本人またはadminか
    if (currentUserId != targetUserId) {
      final currentUser =
          await _firestore.collection('users').doc(currentUserId).get();
      final isAdmin = currentUser['role'] == 'admin';

      if (!isAdmin) {
        throw UnauthorizedException(
          'Cannot enable 2FA for other users. Only account owner or admin allowed.',
        );
      }
    }

    await _logSecurityEvent(
      targetUserId,
      'TWO_FACTOR_AUTH_ENABLED',
      {'initiatedBy': currentUserId, 'action': '2FA enabled'},
    );

    await _firestore.collection('users').doc(targetUserId).update({
      '2faEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ GDPR データ削除リクエスト (権限検証付き)
  Future<void> recordDataRequest(
    String requestingUserId,
    String targetUserId,
    String requestType,
  ) async {
    // 権限確認: 本人またはadminのみ
    if (requestingUserId != targetUserId) {
      final requester =
          await _firestore.collection('users').doc(requestingUserId).get();
      final isAdmin = requester['role'] == 'admin';

      if (!isAdmin) {
        throw UnauthorizedException(
            'Only account owner or admin can request data operations');
      }
    }

    await _firestore
        .collection('compliance')
        .doc('data_requests')
        .collection('all')
        .add({
      'userId': targetUserId,
      'requestType': requestType,
      'requestedBy': requestingUserId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await _logSecurityEvent(
      targetUserId,
      'DATA_REQUEST_INITIATED',
      {'type': requestType, 'requestedBy': requestingUserId},
    );
  }

  /// ✅ セキュリティイベントログ (機密情報マスキング付き)
  Future<void> _logSecurityEvent(
    String userId,
    String eventType,
    Map<String, dynamic> details,
  ) async {
    // 機密情報のマスキング
    final sanitizedDetails = sanitizeDetails(details);

    await _firestore.collection('security_audit').add({
      'userId': userId,
      'eventType': eventType,
      'details': sanitizedDetails,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ ユーザーデータ削除 (権限検証・監査ログ付き)
  Future<void> deleteUserData(
    String requestingUserId,
    String targetUserId,
  ) async {
    // 権限確認: 本人またはadminのみ
    if (requestingUserId != targetUserId) {
      final requester =
          await _firestore.collection('users').doc(requestingUserId).get();
      final isAdmin = requester['role'] == 'admin';

      if (!isAdmin) {
        throw UnauthorizedException(
            'Insufficient permissions for data deletion');
      }
    }

    // 削除前の監査ログ
    await _logSecurityEvent(
      targetUserId,
      'DATA_DELETION_INITIATED',
      {
        'reason': 'GDPR data deletion request',
        'initiatedBy': requestingUserId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    try {
      // トランザクション: 関連する全データ削除
      await _firestore.runTransaction((transaction) async {
        // ユーザードキュメント削除
        transaction.delete(_firestore.collection('users').doc(targetUserId));

        // ランキングデータ削除
        transaction.delete(_firestore
            .collection('rankings')
            .doc('global')
            .collection('players')
            .doc(targetUserId));

        // プロフィール削除
        transaction
            .delete(_firestore.collection('user_profiles').doc(targetUserId));

        // アチーブメント削除
        transaction.delete(_firestore
            .collection('achievements')
            .doc('user_achievements')
            .collection(targetUserId)
            .doc('all'));
      });

      // 削除完了ログ
      await _logSecurityEvent(
        targetUserId,
        'DATA_DELETION_COMPLETED',
        {'status': 'success', 'completedAt': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      // 削除失敗ログ
      await _logSecurityEvent(
        targetUserId,
        'DATA_DELETION_FAILED',
        {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// ✅ 機密情報マスキング (public for testing)
  Map<String, dynamic> sanitizeDetails(Map<String, dynamic> details) =>
      details.map((key, value) {
        final lowerKey = key.toLowerCase();

        // 機密キーワードのマスキング
        if (lowerKey.contains('password') ||
            lowerKey.contains('token') ||
            lowerKey.contains('secret') ||
            lowerKey.contains('apikey') ||
            lowerKey.contains('credential')) {
          return MapEntry(key, '[REDACTED]');
        }

        return MapEntry(key, value);
      });
}

/// ✅ 認可エラー例外
class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}
