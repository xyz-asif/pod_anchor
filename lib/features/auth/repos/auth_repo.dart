import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repo.g.dart';

/// Handles all auth-related operations.
///
/// Flow:
///   1. User taps "Sign in with Google"
///   2. Firebase returns a credential + idToken
///   3. Call `GET /users/me` with the token → backend auto-creates user if new
///   4. Return UserModel
///
/// No try-catch here — ApiClient handles all errors.
class AuthRepo {
  final ApiClient apiClient;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepo({
    required this.apiClient,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Sign in with Google and fetch/create user profile from backend.
  Future<UserModel> signInWithGoogle() async {
    // 1. Trigger Google sign-in flow
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }

    // 2. Get Google auth details
    final googleAuth = await googleUser.authentication;

    // 3. Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // 5. Get Firebase ID token for backend
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to get Firebase ID token');
    }

    // 6. Set token on ApiClient for all future requests
    apiClient.setToken(idToken);

    // 7. Call backend GET /users/me — auto-creates user if new
    final response = await apiClient.get(ApiEndpoints.usersMe);
    final user = UserModel.fromJson(response.data);

    log('Signed in as: ${user.displayName ?? user.email}', name: 'AUTH');
    return user;
  }

  /// Get the current Firebase ID token (refreshed if expired).
  Future<String?> getIdToken() async {
    return _firebaseAuth.currentUser?.getIdToken();
  }

  /// Refresh the API client token (call periodically or on 401).
  Future<void> refreshToken() async {
    final token = await getIdToken();
    if (token != null) {
      apiClient.setToken(token);
    }
  }

  /// Get current user profile from backend.
  Future<UserModel> getMyProfile() async {
    final response = await apiClient.get(ApiEndpoints.usersMe);
    return UserModel.fromJson(response.data);
  }

  /// Sign out from Firebase and Google.
  Future<void> signOut() async {
    apiClient.clearToken();
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    log('Signed out', name: 'AUTH');
  }

  /// Check if a user is currently signed in.
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Current Firebase user (null if not signed in).
  User? get currentFirebaseUser => _firebaseAuth.currentUser;
}

/// Riverpod provider for AuthRepo.
@riverpod
AuthRepo authRepo(AuthRepoRef ref) {
  return AuthRepo(apiClient: ref.read(apiClientProvider));
}
