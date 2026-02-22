/// Used in controller states to track the current status.
///
/// Usage in state:
///   class AuthState {
///     final Status status;
///     ...
///   }
///
/// Usage in view:
///   if (state.status == Status.loading) showLoader();
enum Status { initial, loading, success, error }
