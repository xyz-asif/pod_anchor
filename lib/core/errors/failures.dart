/// Base failure class.
/// Every error in the app is represented as a Failure with a message.
class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

/// When API call fails (500, 401, timeout, etc.)
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// When local storage read/write fails
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// When there's no internet
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// Thrown when user cancels Google Sign-In. Not a real error.
class SignInCancelledException implements Exception {
  const SignInCancelledException();
  @override
  String toString() => 'Sign-in was cancelled';
}
