import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repo.g.dart';

class AuthRepo {
  final ApiClient apiClient;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepo({required this.apiClient, FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = GoogleSignIn.instance;

  /// Initialize Google Sign-In with Web Client ID
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          "681751033005-053s2mh6rm0alivsiiu1qri5025tckop.apps.googleusercontent.com",
    );
  }

  /// Sign in with Google and create/fetch user from backend
  Future<UserModel> signInWithGoogle() async {
    // Ensure initialization
    await initialize();

    // 1️⃣ Show Google Sign-In UI
    print('🔐 Starting Google Sign-In...');
    final googleUser = await _googleSignIn.authenticate();

    // 2️⃣ Get authentication tokens
    final googleAuth = await googleUser.authentication;
    print('✅ Google authentication successful');

    // 3️⃣ Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // 4️⃣ Sign into Firebase
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    print('✅ Firebase sign-in successful');

    // 5️⃣ Get Firebase ID token
    final idToken = await userCredential.user?.getIdToken();

    if (idToken == null) {
      throw Exception("Failed to get Firebase ID token");
    }
    print('✅ Firebase ID token obtained: ${idToken.substring(0, 20)}...');

    // 6️⃣ Attach token to API client
    print('💾 Saving token to API client...');
    await apiClient.setToken(idToken);
    print('✅ Token set on API client');

    // 7️⃣ Fetch user profile (backend auto-creates if new)
    print('👤 Fetching user profile...');
    final response = await apiClient.get(ApiEndpoints.usersMe);
    final user = UserModel.fromJson(response.data);

    log("Signed in as: ${user.displayName ?? user.email}", name: "AUTH");
    print('✅ User signed in successfully');

    return user;
  }

  /// Get Firebase ID token
  Future<String?> getIdToken() async {
    return _firebaseAuth.currentUser?.getIdToken();
  }

  /// Refresh token for API client
  Future<void> refreshToken() async {
    final token = await getIdToken();
    if (token != null) {
      await apiClient.setToken(token);
    }
  }

  /// Fetch current user profile from backend
  Future<UserModel> getMyProfile() async {
    final response = await apiClient.get(ApiEndpoints.usersMe);
    return UserModel.fromJson(response.data);
  }

  /// Sign out
  Future<void> signOut() async {
    await apiClient.clearToken();
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();

    log("Signed out", name: "AUTH");
  }

  /// Check if signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Current Firebase user
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Google authentication events
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  /// Silent login attempt
  Future<void> attemptSilentSignIn() async {
    await _googleSignIn.attemptLightweightAuthentication();
  }
}

@riverpod
AuthRepo authRepo(AuthRepoRef ref) {
  return AuthRepo(apiClient: ref.read(apiClientProvider));
}
