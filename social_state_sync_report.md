# ChatBee — Like/Repost State Sync Inconsistency Report

**Prepared for:** Anti Gravity Development Team
**Date:** April 5, 2026
**Issue:** Like count, red heart, and repost state not reflecting across screens

---

## Problem Summary

When a user likes a poem from the home feed, the red heart and count don't show as liked on: the own profile poems tab, the other user's profile, the standalone poem screen, explore search results, or inside repost wrappers. The reverse is also true — likes from profile screens don't sync back to feeds.

---

## Architecture Overview (how state flows today)

```
User taps Like on PoemCard (in home feed)
  → PoemCard calls SocialActionController.toggleLike()
    → SocialActionController calls socialRepo.togglePoemLike() [API]
    → SocialActionController emits SocialEvent to socialEventStreamProvider
      → HomeFeedController receives event via stream subscription ✅
      → ExploreFeedController receives event via stream subscription ✅
      → AudioFeedController receives event via stream subscription ✅
      → MyPoemsController has NO subscription ❌
      → OtherProfileController has NO subscription ❌
      → PoemStandaloneScreen has NO subscription ❌
      → ExploreScreen search results (local list) has NO subscription ❌
```

---

## Root Causes Found: 3

### Root Cause 1: `MyPoemsController` never subscribes to social events

**File:** `poem_controller.dart`

`MyPoemsController` manages the poems shown on your own profile's "Poems" and "Drafts" tabs. It has `prependPoem`, `updatePoem`, `removePoem` — but zero social event handling. It never listens to `socialEventStreamProvider`.

So when you like a poem from the home feed, the `PoemModel` objects in `MyPoemsController` still hold `isLikedByMe: false` and `likesCount: 0` from the original fetch. When you navigate to your profile, those stale values display.

**Impact:** Like/repost/comment counts on own profile poems tab are always stale until the user does a full pull-to-refresh.

### Root Cause 2: `PoemGridCard` bypasses `SocialActionController` — calls `socialRepo` directly

**File:** `poem_grid_card.dart`

`PoemCard` (the full-size card in feeds) correctly uses `SocialActionController` for likes/reposts, which emits social events to the bus.

But `PoemGridCard` (the compact card in profile grid views) calls `ref.read(socialRepoProvider).togglePoemLike()` directly, then **manually** calls `updatePoemSocialState` on each feed controller AND emits to the event bus. This creates two problems:

1. **Double-update for feed controllers** — they receive both the direct `updatePoemSocialState` call AND the event bus emission, potentially causing flicker or race conditions.
2. **Still misses MyPoemsController** — even with the manual calls, `MyPoemsController` was never included in the list.

### Root Cause 3: `OtherProfileController` never subscribes to social events

**File:** `other_profile_controller.dart`

`OtherProfileController` holds the poems and reposts displayed on another user's profile. Like `MyPoemsController`, it has no social event subscription. If you like a poem from the feed and then visit that poet's profile, the poem shows as un-liked.

The same issue affects reposts displayed in the profile's "Reposts" tab — the original poem inside the repost wrapper never gets its social state updated.

---

## Additional Sync Gaps (lower severity)

### Gap A: Explore screen search results are a local list

**File:** `explore_screen.dart`

`_poemResults` is a `List<PoemModel>` stored in widget state. When a user searches for poems, gets results, then likes one, the like state is local to that `PoemCard`. If they search again or scroll away and back, the state resets to the server's original response.

**This is acceptable for now** — search results are ephemeral and re-fetched on each search. But it's worth noting.

### Gap B: `PoemStandaloneScreen` shows stale data on deep link open

**File:** `poem_standalone_screen.dart`

When a poem is opened via deep link or notification, it's fetched fresh from the server — so the initial state is correct. But if the user likes it and then navigates away and back, the `poemFutureProvider` may serve cached data. The `_localPoem` override from the previous report helps, but the fundamental issue is that there's no event bus subscription.

**This is partially mitigated** by the `_localPoem` pattern from the previous fix round.

---

## Delivered Fixes — 3 files

| File | What changed |
|------|-------------|
| `poem_controller.dart` | Added `socialEventStreamProvider` subscription in `build()`. Social events now update like/repost/comment state on all poems in the My Poems list. |
| `poem_grid_card.dart` | Switched from direct `socialRepoProvider` calls to `SocialActionController`. Removed all manual `updatePoemSocialState` calls (the controller handles that via the event bus). Added loading guards to prevent double-tap. Added optimistic comment count via `showModalBottomSheet<bool>`. |
| `other_profile_controller.dart` | Added `socialEventStreamProvider` subscription in `build()`. Social events now update both `poems` and `reposts` lists, including original poems nested inside repost wrappers. |

---

## Fix Details

### Fix 1: `poem_controller.dart` — MyPoemsController subscribes to social events

```dart
@override
FutureOr<List<PoemModel>> build() async {
  ref.watch(userSessionProvider);

  // NEW: Subscribe to social events
  final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
    _updatePoemSocialState(event);
  });
  ref.onDispose(() => sub.cancel());

  final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
  _hasMore = page.hasMore;
  return page.poems;
}
```

The `_updatePoemSocialState` method only triggers a state update if a poem actually matched the event, avoiding unnecessary rebuilds for events about other users' poems.

### Fix 2: `poem_grid_card.dart` — uses SocialActionController

Before (broken):
```dart
// Called socialRepo directly — no event bus emission for MyPoemsController
final result = await ref.read(socialRepoProvider).togglePoemLike(widget.poem.id);
// Then manually called each feed controller — missed MyPoemsController, caused double-updates
ref.read(homeFeedControllerProvider.notifier).updatePoemSocialState(...);
ref.read(exploreFeedControllerProvider.notifier).updatePoemSocialState(...);
```

After (fixed):
```dart
// Single call — SocialActionController handles API + event bus + all listeners
final result = await ref
    .read(socialActionControllerProvider.notifier)
    .toggleLike(widget.poem.id);
```

Also added:
- `_isLikeLoading` / `_isRepostLoading` guards so the social event listener doesn't overwrite optimistic state during in-flight actions
- Optimistic comment count tracking (same as the PoemCard fix from previous report)

### Fix 3: `other_profile_controller.dart` — subscribes to social events

```dart
@override
OtherProfileState build(String userId) {
  // NEW: Subscribe to social events
  final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
    _updatePoemSocialState(event);
  });
  ref.onDispose(() => sub.cancel());

  Future.microtask(() => _loadProfile(userId));
  return const OtherProfileState();
}
```

The `_updatePoemSocialState` method updates both `poems` and `reposts` lists, including the `originalPoem` inside repost wrappers.

---

## State Flow After Fixes

```
User taps Like on any PoemCard or PoemGridCard (anywhere in the app)
  → SocialActionController.toggleLike() [single entry point]
    → API call
    → Emits SocialEvent to bus
      → HomeFeedController ✅ (via stream sub in build)
      → ExploreFeedController ✅ (via stream sub in build)
      → AudioFeedController ✅ (via stream sub in build)
      → MyPoemsController ✅ (NEW - via stream sub in build)
      → OtherProfileController ✅ (NEW - via stream sub in build)
      → PoemGridCard ✅ (NEW - via stream sub in initState)
      → PoemCard ✅ (local optimistic + didUpdateWidget from parent)
```

---

## Integration Checklist

- [ ] Replace `poem_controller.dart` — drop-in, same class name, re-run `build_runner`
- [ ] Replace `poem_grid_card.dart` — drop-in, new import for `social_action_controller.dart` (was `social_repo.dart`)
- [ ] Replace `other_profile_controller.dart` — drop-in, new import for `social_events.dart`, re-run `build_runner`
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs` (poem_controller.g.dart needs regeneration due to new import)

## Testing

- [ ] Like a poem from home feed → go to own profile Poems tab → heart should be red, count should match
- [ ] Like a poem from explore feed → open that poet's profile → same poem should show as liked
- [ ] Like a poem from PoemGridCard (profile grid) → go to home feed → same poem should show as liked
- [ ] Repost from any screen → check all other screens show the repost count updated
- [ ] Comment on a poem → check count updates everywhere
- [ ] Deep link to a poem → like it → go back to feed → should be liked there too
- [ ] Like from standalone screen → go to My Poems → should show liked

---

*End of report.*
