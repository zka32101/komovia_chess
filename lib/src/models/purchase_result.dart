import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_result.freezed.dart';
part 'purchase_result.g.dart';

/// Result of a purchase operation
@freezed
class PurchaseResult with _$PurchaseResult {
  /// Successful purchase
  const factory PurchaseResult.success({
    required String transactionId,
    required String productId,
    required DateTime timestamp,
    String? subscriptionTier,
  }) = PurchaseSuccess;

  /// Purchase failed with error
  const factory PurchaseResult.error({
    required String code,
    required String message,
    required bool isNetworkError,
    String? details,
  }) = PurchaseError;

  /// User cancelled the purchase
  const factory PurchaseResult.cancelled() = PurchaseCancelled;

  factory PurchaseResult.fromJson(Map<String, dynamic> json) =>
      _$PurchaseResultFromJson(json);
}

/// Purchase error details
@freezed
class PurchaseErrorDetail with _$PurchaseErrorDetail {
  const factory PurchaseErrorDetail({
    required String code,
    required String message,
    required bool isNetworkError,
    bool? isRetryable,
  }) = _PurchaseErrorDetail;

  factory PurchaseErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$PurchaseErrorDetailFromJson(json);
}
