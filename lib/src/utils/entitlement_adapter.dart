import 'package:komovia_core/komovia_core.dart';
import '../providers/premium_provider.dart';

/// Converts this app's local [UserSubscription] (`tier`/`isActive`/
/// `expiryDate`, read from `users/{uid}`'s `subscriptionTier`/
/// `subscriptionExpiry`/`isLifetime` fields - see `PaywallService`) into
/// komovia_core's game-agnostic [Entitlement] shape.
///
/// This app has only ever sold monthly tiers ('pro'/'premium' - see
/// `PaywallService._productIdsByTier`); a lifetime grant is recorded via
/// the separate `isLifetime` flag rather than its own plan, so a
/// lifetime-active subscription (no expiry) maps to
/// [SubscriptionPlan.lifetime] here regardless of which tier it was
/// granted under. There's no `subscriptionStartDate` field in this app's
/// Firestore schema, so [Entitlement.startedAt] is always null - not
/// guessed from elsewhere.
///
/// Per [Entitlement]'s own doc comment, each app's purchase service maps
/// its existing fields onto this shape rather than renaming them -
/// nothing about this app's Firestore schema changes.
extension UserSubscriptionEntitlement on UserSubscription {
  Entitlement toEntitlement() {
    final isLifetimeActive = isActive && expiryDate == null;
    return Entitlement(
      isActive: isActive,
      plan: isActive
          ? (isLifetimeActive ? SubscriptionPlan.lifetime : SubscriptionPlan.monthly)
          : null,
      expiresAt: expiryDate,
    );
  }
}
