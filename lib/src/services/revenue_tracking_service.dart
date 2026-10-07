import 'package:flutter/foundation.dart';

/// Revenue transaction model
class RevenueTransaction {
  RevenueTransaction({
    required this.productId,
    required this.amount,
    required this.currency,
    required this.transactionType,
    String? id,
    DateTime? timestamp,
    this.userId,
    this.metadata,
  })  : id = id ?? 'txn_${DateTime.now().millisecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();
  final String id;
  final String productId;
  final double amount;
  final String currency;
  final String transactionType; // purchase, refund, renewal
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic>? metadata;

  double get netAmount {
    if (transactionType == 'refund') {
      return -amount;
    }
    return amount;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'amount': amount,
        'currency': currency,
        'transactionType': transactionType,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'netAmount': netAmount,
        'metadata': metadata,
      };

  @override
  String toString() => 'RevenueTransaction($productId: $amount $currency)';
}

/// Revenue segment model
class RevenueSegment {
  RevenueSegment({required this.name});
  final String name;
  double totalRevenue = 0;
  int transactionCount = 0;
  final List<RevenueTransaction> transactions = [];

  double get averageRevenue =>
      transactionCount > 0 ? totalRevenue / transactionCount : 0.0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'totalRevenue': totalRevenue,
        'transactionCount': transactionCount,
        'averageRevenue': averageRevenue,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };
}

/// Revenue tracking service
class RevenueTrackingService {
  factory RevenueTrackingService() => _instance;

  RevenueTrackingService._internal() {
    _initializeSegments();
  }
  static final RevenueTrackingService _instance =
      RevenueTrackingService._internal();

  final _transactions = <RevenueTransaction>[];
  final _segments = <String, RevenueSegment>{};
  double _totalRevenue = 0;

  /// Initialize default segments
  void _initializeSegments() {
    _segments['subscription'] = RevenueSegment(name: 'Subscription');
    _segments['premium_features'] = RevenueSegment(name: 'Premium Features');
    _segments['cosmetics'] = RevenueSegment(name: 'Cosmetics');
    _segments['other'] = RevenueSegment(name: 'Other');

    debugPrint(
        '[RevenueTrackingService] Initialized with ${_segments.length} segments');
  }

  /// Record transaction
  void recordTransaction({
    required String productId,
    required double amount,
    required String currency,
    required String transactionType,
    required String segment,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    try {
      final transaction = RevenueTransaction(
        productId: productId,
        amount: amount,
        currency: currency,
        transactionType: transactionType,
        userId: userId,
        metadata: metadata,
      );

      _transactions.add(transaction);
      _totalRevenue += transaction.netAmount;

      // Add to segment
      final seg =
          _segments.putIfAbsent(segment, () => RevenueSegment(name: segment));
      seg.transactions.add(transaction);
      seg.totalRevenue += transaction.netAmount;
      seg.transactionCount++;

      debugPrint(
          '[RevenueTrackingService] Transaction recorded: ${transaction.id}');
    } catch (e) {
      debugPrint('[RevenueTrackingService] Error recording transaction: $e');
    }
  }

  /// Record purchase
  void recordPurchase({
    required String productId,
    required double price,
    required String currency,
    required String segment,
    String? userId,
  }) {
    recordTransaction(
      productId: productId,
      amount: price,
      currency: currency,
      transactionType: 'purchase',
      segment: segment,
      userId: userId,
    );
  }

  /// Record refund
  void recordRefund({
    required String productId,
    required double amount,
    required String currency,
    String? userId,
  }) {
    recordTransaction(
      productId: productId,
      amount: amount,
      currency: currency,
      transactionType: 'refund',
      segment: 'refunds',
      userId: userId,
    );
  }

  /// Record subscription renewal
  void recordRenewal({
    required String subscriptionId,
    required double amount,
    required String currency,
    String? userId,
  }) {
    recordTransaction(
      productId: subscriptionId,
      amount: amount,
      currency: currency,
      transactionType: 'renewal',
      segment: 'subscription',
      userId: userId,
    );
  }

  /// Get total revenue
  double getTotalRevenue() => _totalRevenue;

  /// Get revenue by segment
  double getSegmentRevenue(String segment) =>
      _segments[segment]?.totalRevenue ?? 0.0;

  /// Get all transactions
  List<RevenueTransaction> getAllTransactions() =>
      List.unmodifiable(_transactions);

  /// Get transactions by segment
  List<RevenueTransaction> getTransactionsBySegment(String segment) =>
      _segments[segment]?.transactions ?? [];

  /// Get transaction count
  int getTransactionCount() => _transactions.length;

  /// Get average transaction value
  double getAverageTransactionValue() =>
      _transactions.isNotEmpty ? _totalRevenue / _transactions.length : 0.0;

  /// Get segment data
  Map<String, RevenueSegment> getAllSegments() => Map.unmodifiable(_segments);

  /// Generate revenue report
  String generateReport() {
    final buffer = StringBuffer();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                  REVENUE TRACKING REPORT                        ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Revenue: \$${_totalRevenue.toStringAsFixed(2).padRight(45)}║
║ Total Transactions: ${_transactions.length.toString().padRight(45)}║
║ Average Transaction: \$${getAverageTransactionValue().toStringAsFixed(2).padRight(40)}║
╠══════════════════════════════════════════════════════════════════╣
║ REVENUE BY SEGMENT:
    ''');

    for (final entry in _segments.entries) {
      final seg = entry.value;
      buffer.writeln(
        '║ ${seg.name.padRight(20)}: \$${seg.totalRevenue.toStringAsFixed(2).padRight(20)} (${seg.transactionCount} txns)║',
      );
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ TRANSACTION BREAKDOWN:
    ''');

    final typeCounts = <String, int>{};
    for (final txn in _transactions) {
      typeCounts[txn.transactionType] =
          (typeCounts[txn.transactionType] ?? 0) + 1;
    }

    for (final entry in typeCounts.entries) {
      buffer.writeln(
          '║ ${entry.key.padRight(20)}: ${entry.value.toString().padRight(45)}║');
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');

    return buffer.toString();
  }

  /// Clear all data
  void clear() {
    _transactions.clear();
    _totalRevenue = 0.0;
    for (final segment in _segments.values) {
      segment.transactions.clear();
      segment.totalRevenue = 0.0;
      segment.transactionCount = 0;
    }
  }
}
