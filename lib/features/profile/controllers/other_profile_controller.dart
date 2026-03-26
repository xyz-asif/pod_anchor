import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/profile/models/public_profile_model.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/profile/repos/follow_repo.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/chat/models/room_response.dart';

part 'other_profile_controller.g.dart';

/// Immutable state for the Other Profile screen.
class OtherProfileState {
  final PublicProfileModel? profile;
  final List<PoemModel> poems;
  final List<PoemModel> reposts;
  final bool isLoadingProfile;
  final bool isLoadingPoems;
  final bool isLoadingReposts;
  final bool isFollowLoading;
  final bool isChatLoading;
  final String? error;

  const OtherProfileState({
    this.profile,
    this.poems = const [],
    this.reposts = const [],
    this.isLoadingProfile = true,
    this.isLoadingPoems = true,
    this.isLoadingReposts = true,
    this.isFollowLoading = false,
    this.isChatLoading = false,
    this.error,
  });

  OtherProfileState copyWith({
    PublicProfileModel? profile,
    List<PoemModel>? poems,
    List<PoemModel>? reposts,
    bool? isLoadingProfile,
    bool? isLoadingPoems,
    bool? isLoadingReposts,
    bool? isFollowLoading,
    bool? isChatLoading,
    String? error,
    bool clearError = false,
  }) {
    return OtherProfileState(
      profile: profile ?? this.profile,
      poems: poems ?? this.poems,
      reposts: reposts ?? this.reposts,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isLoadingPoems: isLoadingPoems ?? this.isLoadingPoems,
      isLoadingReposts: isLoadingReposts ?? this.isLoadingReposts,
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
      isChatLoading: isChatLoading ?? this.isChatLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for viewing another user's profile.
///
/// Manages profile data, poems, reposts, follow toggle, and chat creation.
/// Replaces all setState calls in OtherProfileScreen.
@riverpod
class OtherProfileController extends _$OtherProfileController {
  @override
  OtherProfileState build(String userId) {
    // Defer loading until after build returns initial state to avoid 
    // "uninitialized provider" error when reading/writing state.
    Future.microtask(() => _loadProfile(userId));
    return const OtherProfileState();
  }

  Future<void> _loadProfile(String userId) async {
    try {
      var profile = await ref.read(followRepoProvider).getPublicProfile(userId);

      // Backend bug workaround: if following but count is 0, bump to 1
      if (profile.isFollowedByMe && profile.followersCount == 0) {
        profile = profile.copyWith(followersCount: 1);
      }

      state = state.copyWith(
        profile: profile,
        isLoadingProfile: false,
        clearError: true,
      );

      // Load poems after profile succeeds
      _loadPoems(userId);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoadingProfile: false,
      );
    }
  }

  Future<void> _loadPoems(String userId) async {
    try {
      final page = await ref.read(poemRepoProvider).getUserPoems(userId);
      state = state.copyWith(poems: page.poems, isLoadingPoems: false);
    } catch (_) {
      state = state.copyWith(isLoadingPoems: false);
    }
  }

  Future<void> loadReposts() async {
    if (!state.isLoadingReposts) return; // Already loaded
    try {
      final page = await ref.read(socialRepoProvider).getUserReposts(state.profile!.id);
      state = state.copyWith(reposts: page.poems, isLoadingReposts: false);
    } catch (_) {
      state = state.copyWith(isLoadingReposts: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoadingProfile: true,
      isLoadingPoems: true,
      isLoadingReposts: true,
      clearError: true,
    );
    await _loadProfile(state.profile?.id ?? '');
  }

  Future<void> toggleFollow() async {
    final profile = state.profile;
    if (profile == null || state.isFollowLoading) return;

    final prevFollowing = profile.isFollowedByMe;
    final prevCount = profile.followersCount;

    // Optimistic
    state = state.copyWith(
      isFollowLoading: true,
      profile: profile.copyWith(
        isFollowedByMe: !prevFollowing,
        followersCount: prevFollowing
            ? (prevCount - 1).clamp(0, 999999)
            : prevCount + 1,
      ),
    );

    try {
      final isNowFollowing = await ref
          .read(followRepoProvider)
          .toggleFollow(profile.id);

      int newCount = prevCount;
      if (isNowFollowing && !prevFollowing) {
        newCount += 1;
      } else if (!isNowFollowing && prevFollowing) {
        newCount -= 1;
      }
      if (newCount < 0) {
        newCount = 0;
      }

      state = state.copyWith(
        isFollowLoading: false,
        profile: state.profile!.copyWith(
          isFollowedByMe: isNowFollowing,
          followersCount: newCount,
        ),
      );

      // Update own following count
      ref.read(authControllerProvider.notifier).updateFollowingCount(
        isNowFollowing && !prevFollowing ? 1 : (!isNowFollowing && prevFollowing ? -1 : 0),
      );
    } catch (_) {
      // Rollback
      state = state.copyWith(
        isFollowLoading: false,
        profile: state.profile!.copyWith(
          isFollowedByMe: prevFollowing,
          followersCount: prevCount,
        ),
      );
      rethrow; // Let UI handle via ref.listen
    }
  }

  /// Opens or creates a DM room. Returns the room so UI can navigate.
  Future<RoomResponse> openChat() async {
    state = state.copyWith(isChatLoading: true);
    try {
      final room = await ref
          .read(chatRepoProvider)
          .getOrCreateDirectRoom(state.profile!.id);
      ref.read(chatListControllerProvider.notifier).upsertRoom(room);
      state = state.copyWith(isChatLoading: false);
      return room;
    } catch (_) {
      state = state.copyWith(isChatLoading: false);
      rethrow;
    }
  }
}
