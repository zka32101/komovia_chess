import 'package:cloud_firestore/cloud_firestore.dart';

// Phase S: 国際化 & 多言語対応
class InternationalizationService {
  factory InternationalizationService() => _instance;
  InternationalizationService._internal();
  static final InternationalizationService _instance =
      InternationalizationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, String>> _translationCache = {};

  Future<Map<String, String>> getTranslations(String languageCode) async {
    if (_translationCache.containsKey(languageCode)) {
      return _translationCache[languageCode]!;
    }

    final doc =
        await _firestore.collection('translations').doc(languageCode).get();
    final translations = Map<String, String>.from(doc.data() ?? {});
    _translationCache[languageCode] = translations;
    return translations;
  }

  Future<List<String>> getSupportedLanguages() async {
    final snapshot = await _firestore.collection('languages').get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  Future<void> setCurrencyPreference(String userId, String currencyCode) async {
    await _firestore.collection('users').doc(userId).update({
      'currencyPreference': currencyCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> convertCurrency(
      double amount, String fromCurrency, String toCurrency) async {
    final doc = await _firestore
        .collection('exchange_rates')
        .doc('${fromCurrency}_$toCurrency')
        .get();
    final rate = doc['rate'] ?? 1.0;
    return (amount * rate).toStringAsFixed(2);
  }
}
