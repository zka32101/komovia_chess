import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Batches multiple Firestore queries to reduce request count.
/// Combines multiple queries into single batch operations where possible.
class FirestoreBatchQueryService {
  factory FirestoreBatchQueryService() => _instance;

  FirestoreBatchQueryService._internal();
  static final FirestoreBatchQueryService _instance =
      FirestoreBatchQueryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Completer<List<DocumentSnapshot>>> _pendingBatches = {};
  final List<Future<DocumentSnapshot> Function()> _batchQueue = [];
  Timer? _batchTimer;
  static const batchDelayMs = 10;
  static const maxBatchSize = 100;

  /// Batch fetch multiple documents by ID.
  /// Returns results in the same order as requested IDs.
  Future<List<DocumentSnapshot>> batchGetDocuments(
    String collection,
    List<String> docIds,
  ) async {
    if (docIds.isEmpty) return [];
    if (docIds.length == 1) {
      final doc =
          await _firestore.collection(collection).doc(docIds.first).get();
      return [doc];
    }

    // Split into chunks (Firestore "in" operator limited to 10 values)
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < docIds.length; i += chunkSize) {
      chunks.add(
        docIds.sublist(
            i, i + chunkSize > docIds.length ? docIds.length : i + chunkSize),
      );
    }

    final results = <DocumentSnapshot>[];
    for (final chunk in chunks) {
      final query = _firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk);
      final snapshot = await query.get();
      results.addAll(snapshot.docs);
    }

    // Re-order results to match original order
    final docMap = {for (final doc in results) doc.id: doc};
    return docIds
        .map((id) => docMap[id])
        .whereType<DocumentSnapshot>()
        .toList();
  }

  /// Queue a batched query operation.
  Future<List<DocumentSnapshot>> queueBatchedQuery(
    String collection,
    List<String> docIds,
  ) async {
    final batchKey = '$collection:${docIds.join(",")}';

    if (!_pendingBatches.containsKey(batchKey)) {
      _pendingBatches[batchKey] = Completer<List<DocumentSnapshot>>();
      _scheduleBatchExecution();
    }

    return _pendingBatches[batchKey]!.future;
  }

  /// Execute pending batch queries.
  void _scheduleBatchExecution() {
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: batchDelayMs), () async {
      final batchesToProcess = Map.of(_pendingBatches);
      _pendingBatches.clear();

      for (final entry in batchesToProcess.entries) {
        final parts = entry.key.split(':');
        final collection = parts[0];
        final docIds = parts[1].split(',');

        try {
          final results = await batchGetDocuments(collection, docIds);
          entry.value.complete(results);
        } catch (e) {
          entry.value.completeError(e);
        }
      }
    });
  }

  /// Fetch documents with pagination support.
  Future<({List<DocumentSnapshot> docs, DocumentSnapshot? lastDoc})>
      paginatedQuery(
    String collection, {
    required int pageSize,
    DocumentSnapshot? startAfter,
    List<({String field, dynamic value})>? filters,
  }) async {
    Query query = _firestore.collection(collection);

    // Apply filters
    if (filters != null) {
      for (final filter in filters) {
        query = query.where(filter.field, isEqualTo: filter.value);
      }
    }

    // Apply pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(pageSize + 1);
    final snapshot = await query.get();

    bool hasMore = false;
    DocumentSnapshot? lastDoc;

    if (snapshot.docs.length > pageSize) {
      hasMore = true;
      lastDoc = snapshot.docs[pageSize - 1];
      snapshot.docs.removeAt(pageSize);
    } else if (snapshot.docs.isNotEmpty) {
      lastDoc = snapshot.docs.last;
    }

    return (docs: snapshot.docs, lastDoc: lastDoc);
  }

  /// Batch write operations for better performance.
  Future<void> batchWriteDocuments(
    String collection,
    Map<String, Map<String, dynamic>> updates,
  ) async {
    const batchSize = 500; // Firestore batch limit
    final batches = <WriteBatch>[];
    var currentBatch = _firestore.batch();
    var operationCount = 0;

    for (final entry in updates.entries) {
      final docRef = _firestore.collection(collection).doc(entry.key);
      currentBatch.set(docRef, entry.value, SetOptions(merge: true));
      operationCount++;

      if (operationCount >= batchSize) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      batches.add(currentBatch);
    }

    // Commit all batches
    for (final batch in batches) {
      await batch.commit();
    }
  }

  /// Cancel pending batches and cleanup.
  void cancel() {
    _batchTimer?.cancel();
    for (final completer in _pendingBatches.values) {
      if (!completer.isCompleted) {
        completer.completeError('Batch cancelled');
      }
    }
    _pendingBatches.clear();
  }
}
