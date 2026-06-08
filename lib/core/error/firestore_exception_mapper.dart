import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vouch/core/error/app_exception.dart';

/// Maps raw [FirebaseException] to the sealed [AppException]
/// hierarchy so presentation never sees Firebase types.
AppException mapFirestoreException(FirebaseException e) {
  return switch (e.code) {
    'permission-denied' => const PermissionDenied(),
    'not-found' => const NotFound(),
    'unavailable' => const ServiceUnavailable(),
    'resource-exhausted' => const RateLimited(),
    'deadline-exceeded' => const NetworkException(),
    'cancelled' => const NetworkException(),
    'unauthenticated' => const PermissionDenied(
      'You need to sign in to do that.',
    ),
    _ => const FirestoreWriteException(),
  };
}
