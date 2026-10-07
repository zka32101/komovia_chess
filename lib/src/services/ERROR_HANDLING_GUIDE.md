# Error Handling & Logging Guide

## Overview
All services must use `ErrorHandlerService` for consistent error logging, user-friendly messages, and crash reporting.

## Basic Usage

### In Service Methods

**Before (Old Pattern):**
```dart
} catch (e) {
  throw Exception('Error analyzing game: $e');
}
```

**After (New Pattern):**
```dart
} catch (e, stackTrace) {
  final userMessage = errorHandlerService.handleServiceError(
    'analyzeGame',
    error: e,
    stackTrace: stackTrace,
    userId: userId,
    metadata: {'gameId': gameId},
  );
  throw Exception(userMessage);
}
```

## Error Severity Levels

- **info**: Informational messages (user actions, successful operations)
- **warning**: Potentially problematic situations (validation failures, retries)
- **error**: Recoverable errors (network timeouts, validation failures)
- **critical**: System failures requiring immediate attention (security issues, data corruption)

## Common Patterns

### Input Validation
```dart
final error = errorHandlerService.validateInput(
  userId,
  fieldName: 'userId',
  minLength: 1,
);
if (error != null) {
  return; // Handle error in UI
}
```

### Firebase Operations
```dart
try {
  await _firestore.collection('users').doc(userId).set(data);
} catch (e, stackTrace) {
  final message = errorHandlerService.handleServiceError(
    'createUserProfile',
    error: e,
    stackTrace: stackTrace,
    userId: userId,
  );
  // Return error to UI through provider
  state = AsyncValue.error(message, stackTrace);
}
```

### Logging Events
```dart
errorHandlerService.logError(ErrorContext(
  message: 'Game analysis completed',
  severity: ErrorSeverity.info,
  userId: userId,
  context: 'analyzeGame',
  metadata: {
    'moveCount': moves.length,
    'accuracy': accuracy,
  },
));
```

## Firestore Security Rules

All Firestore operations are now protected by strict security rules:

- **User Data**: Only readable/writable by the owning user
- **Public Content**: Read-only for authenticated users
- **Admin Operations**: Write-only through backend Cloud Functions
- **Nested Collections**: Follow parent document ownership rules

### Rules Deployment

```bash
# Deploy to Firebase
firebase deploy --only firestore:rules

# Validate rules
firebase firestore:describe-index --pretty
```

## Integration Checklist

For each service that catches exceptions:

- [ ] Import `error_handler_service.dart`
- [ ] Wrap try-catch blocks with `errorHandlerService.handleServiceError()`
- [ ] Add `userId` to error context where applicable
- [ ] Add relevant `metadata` (gameId, lessonId, etc.)
- [ ] Return user-friendly error message (don't expose raw exceptions)
- [ ] Test error handling paths

## Example: Complete Service Method

```dart
@override
Future<GameAnalysis> analyzeGame(String userId, String gameId) async {
  try {
    // Validate inputs
    final userError = errorHandlerService.validateInput(userId, fieldName: 'userId');
    if (userError != null) throw Exception(userError);

    // Fetch and process
    final gameDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('games')
        .doc(gameId)
        .get();

    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    // ... analysis logic ...

    // Log success
    errorHandlerService.logError(ErrorContext(
      message: 'Game analysis completed successfully',
      severity: ErrorSeverity.info,
      userId: userId,
      context: 'analyzeGame',
      metadata: {'gameId': gameId, 'movesAnalyzed': moveCount},
    ));

    return analysis;
  } catch (e, stackTrace) {
    final userMessage = errorHandlerService.handleServiceError(
      'analyzeGame',
      error: e,
      stackTrace: stackTrace,
      userId: userId,
      metadata: {'gameId': gameId},
    );
    throw Exception(userMessage);
  }
}
```

## Next Steps

1. **Immediate**: Deploy Firestore security rules to Firebase
2. **This Week**: Update all service methods to use error handler
3. **This Week**: Add input validation to all service method entries
4. **Next Week**: Integrate Firebase Crashlytics for critical error reporting
5. **Next Week**: Set up error analytics dashboard

## Critical Fixes Made

✅ Firebase Security Rules - Implemented comprehensive rules  
✅ Exception Handling - Created centralized error handler  
✅ Input Validation - Built validation utilities  
✅ Error Logging - Structured logging with context  
✅ User Messaging - User-friendly error messages  

