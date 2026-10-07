import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

/// Subscription tier enum
enum SubscriptionTier {
  free('Free', 'free'),
  premium('Premium', 'premium'),
  elite('Elite', 'elite');

  final String displayName;
  final String identifier;
  const SubscriptionTier(this.displayName, this.identifier);
}

/// Subscription status
enum SubscriptionStatus {
  active('Active'),
  expired('Expired'),
  cancelled('Cancelled'),
  pending('Pending');

  final String displayName;
  const SubscriptionStatus(this.displayName);
}

/// Premium features
enum PremiumFeature {
  unlimitedPuzzles('Unlimited Puzzles'),
  customBoard('Custom Board Themes'),
  gameAnalysis('Advanced Game Analysis'),
  noAds('Ad-Free Experience'),
  offlinePlay('Offline Play'),
  cloudSync('Cloud Sync'),
  openingBooks('Opening Books'),
  endgameTablebases('Endgame Tablebases');

  final String displayName;
  const PremiumFeature(this.displayName);
}

/// User subscription model
@freezed
class UserSubscription with _$UserSubscription {
  const factory UserSubscription({
    required String userId,
    required SubscriptionTier currentTier,
    required SubscriptionStatus status,
    required DateTime? expiresAt,
    required bool autoRenewing,
    required bool sandbox,
    required DateTime createdAt,
    required DateTime? updatedAt,
  }) = _UserSubscription;
  const UserSubscription._();

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      _$UserSubscriptionFromJson(json);

  /// Check if subscription is active
  bool get isActive => status == SubscriptionStatus.active;

  /// Check if subscription is expired
  bool get isExpired =>
      status == SubscriptionStatus.expired ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  /// Days remaining until expiration
  int? get daysRemaining {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  /// Check if trial
  bool get isTrial => status == SubscriptionStatus.pending;
}

/// Subscription offering
@freezed
class SubscriptionOffering with _$SubscriptionOffering {
  const factory SubscriptionOffering({
    required SubscriptionTier tier,
    required String packageId,
    required double price,
    required String currency,
    required String displayPrice,
    required String period, // "1mo", "1y", etc.
    required List<PremiumFeature> features,
    required bool isMostPopular,
  }) = _SubscriptionOffering;

  factory SubscriptionOffering.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionOfferingFromJson(json);
}

/// RevenueCat entitlement
@freezed
class Entitlement with _$Entitlement {
  const factory Entitlement({
    required String identifier,
    required bool isActive,
    required bool isSandbox,
    required DateTime? purchaseDate,
    required DateTime? expirationDate,
  }) = _Entitlement;

  factory Entitlement.fromJson(Map<String, dynamic> json) =>
      _$EntitlementFromJson(json);
}

/// Paywall data with offerings
@freezed
class PaywallData with _$PaywallData {
  const factory PaywallData({
    required List<SubscriptionOffering> offerings,
    required String? introductoryOffer,
    required bool freeTrialAvailable,
    required String? featuredOffering,
  }) = _PaywallData;

  factory PaywallData.fromJson(Map<String, dynamic> json) =>
      _$PaywallDataFromJson(json);
}

/// Purchase record
@freezed
class PurchaseRecord with _$PurchaseRecord {
  const factory PurchaseRecord({
    required String transactionId,
    required String productId,
    required double amount,
    required String currency,
    required DateTime purchaseDate,
    required SubscriptionTier tier,
  }) = _PurchaseRecord;

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) =>
      _$PurchaseRecordFromJson(json);
}
