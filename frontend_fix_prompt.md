# ChatBee Frontend Fix Prompt — Phase 2 Integration

## Context

The backend Phase 2 is fully deployed with these new endpoints:

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/api/v1/users/:id/follow` | Required | Toggle follow/unfollow |
| GET | `/api/v1/users/:id/profile` | Optional | Public profile with `isFollowedByMe` |
| GET | `/api/v1/users/:id/followers` | Optional | Paginated followers list |
| GET | `/api/v1/users/:id/following` | Optional | Paginated following list |
| GET | `/api/v1/feed` | Required | Home feed (poems from followed users + own) |
| GET | `/api/v1/feed/explore` | Optional | Explore feed (scored by engagement), supports `?hashtag=` filter |
| GET | `/api/v1/search/poems?q=` | Optional | Full-text poem search |
| GET | `/api/v1/search/users?q=` | Optional | User search by name/username |

The frontend code at [/Users/asif/development/Products/chatbee](file:///Users/asif/development/Products/chatbee) already has repos, controllers, models, and screens for ALL of these features — but **they are not wired into the app's navigation**. The app still shows the old placeholder screens.

---

## Problem #1 — HOME tab shows a static placeholder

**Root cause:** [home_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_screen.dart) (the main shell with bottom nav) imports the **wrong** [HomeFeedScreen](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_feed_screen.dart#9-69).

### Current (BROKEN):
```dart
// lib/features/home/screens/home_screen.dart, line 6
import 'package:chatbee/features/home/screens/home_feed_screen.dart';
```
This file ([features/home/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_feed_screen.dart)) is a **static placeholder** — it just shows "Your feed will appear here" with an icon. It doesn't call any API.

### Required Fix:
```dart
import 'package:chatbee/features/feed/screens/home_feed_screen.dart';
```
The **real** [HomeFeedScreen](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_feed_screen.dart#9-69) is at [features/feed/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/home_feed_screen.dart) — it uses [HomeFeedController](file:///Users/asif/development/Products/chatbee/lib/features/feed/controllers/feed_controller.dart#9-49), calls `GET /api/v1/feed`, and displays poems with pagination.

**After fixing this import**, also update the `AppBar` title in [features/feed/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/home_feed_screen.dart) from `'Home'` to `'ChatBee'` and add the notification bell icon to match the current design (see the existing placeholder's AppBar for reference).

---

## Problem #2 — EXPLORE tab shows the old connections-based UserSearchScreen

**Root cause:** [home_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_screen.dart) uses [UserSearchScreen](file:///Users/asif/development/Products/chatbee/lib/features/search/screens/user_search_screen.dart#14-20) (the old connections/friends search) for the EXPLORE tab instead of the new [ExploreScreen](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/explore_screen.dart#28-34).

### Current (BROKEN):
```dart
// lib/features/home/screens/home_screen.dart, lines 8, 34
import 'package:chatbee/features/search/screens/user_search_screen.dart';

// In _screens list:
const UserSearchScreen(),  // <-- This is the old "add friend" screen
```

### Required Fix:
```dart
import 'package:chatbee/features/feed/screens/explore_screen.dart';

// In _screens list:
const ExploreScreen(),  // <-- This is the new Phase 2 explore with poem feed + search
```

The [ExploreScreen](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/explore_screen.dart#28-34) at [features/feed/screens/explore_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/explore_screen.dart) already has:
- Hashtag filter chips
- Explore feed with engagement-scored poems
- Search bar with tabbed results (Poems + People)
- Poem cards + user results with navigation to `/profile/:id`

---

## Problem #3 — Routing for followers/following lists

Verify that routes for `/profile/:id/followers` and `/profile/:id/following` exist in your router config. The [OtherProfileScreen](file:///Users/asif/development/Products/chatbee/lib/features/profile/screens/other_profile_screen.dart#15-23) already has `GestureDetector` taps that navigate to these routes (lines 286-298). If these routes are not defined, create a screen that:
1. Calls `FollowRepo.getFollowers(userId)` or `FollowRepo.getFollowing(userId)`
2. Shows a paginated list of [UserSearchResult](file:///Users/asif/development/Products/chatbee/lib/features/profile/models/user_search_result.dart#1-29) items
3. Each item navigates to `/profile/:id` on tap

The [FollowRepo](file:///Users/asif/development/Products/chatbee/lib/features/profile/repos/follow_repo.dart#10-47) at [features/profile/repos/follow_repo.dart](file:///Users/asif/development/Products/chatbee/lib/features/profile/repos/follow_repo.dart) already has [getFollowers()](file:///Users/asif/development/Products/chatbee/lib/features/profile/repos/follow_repo.dart#27-36) and [getFollowing()](file:///Users/asif/development/Products/chatbee/lib/features/profile/repos/follow_repo.dart#37-46) methods ready.

---

## Problem #4 — Old UserSearchScreen still accessible

The old [UserSearchScreen](file:///Users/asif/development/Products/chatbee/lib/features/search/screens/user_search_screen.dart#14-20) at [features/search/screens/user_search_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/search/screens/user_search_screen.dart) uses the **connections API** (`/users/search-with-status`, `/connections/request`, accept, reject, etc.) — this is the old "add friend" flow. It should remain accessible but should NOT be the EXPLORE tab.

Consider keeping it accessible from a "Find Friends" button somewhere, or from the profile screen. It is NOT the explore screen.

---

## Summary of Changes

Only **one file** needs to be modified to fix the two major issues:

### [lib/features/home/screens/home_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_screen.dart)

1. **Line 6**: Change import from [features/home/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_feed_screen.dart) → [features/feed/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/home_feed_screen.dart)
2. **Line 8**: Change import from [features/search/screens/user_search_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/search/screens/user_search_screen.dart) → [features/feed/screens/explore_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/explore_screen.dart)
3. **Line 34**: Change [UserSearchScreen()](file:///Users/asif/development/Products/chatbee/lib/features/search/screens/user_search_screen.dart#14-20) → [ExploreScreen()](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/explore_screen.dart#28-34)

### [lib/features/feed/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/feed/screens/home_feed_screen.dart)

4. Update the AppBar to show `'ChatBee'` as title (not `'Home'`) and add the notification bell icon to match the current UI design.

### Router Config

5. Add routes for `/profile/:id/followers` and `/profile/:id/following` if they don't exist yet.

### Optional Cleanup

6. Consider deleting or archiving [features/home/screens/home_feed_screen.dart](file:///Users/asif/development/Products/chatbee/lib/features/home/screens/home_feed_screen.dart) (the placeholder) since it's no longer needed.

---

## After These Fixes

- **HOME** tab will show the real feed from `GET /api/v1/feed` with poems from followed users
- **EXPLORE** tab will show engagement-scored poems from `GET /api/v1/feed/explore` with hashtag filters and search
- **Profile** pages already work — follow/unfollow, chat, poems all functional
- **Search** within explore already works for both poems and users
