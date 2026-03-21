# Feed & Social Addendum — Audio UX, Home Feed Toggle, Poem Detail Improvements

> **Scope**: Audio toggle on home/explore feeds, audio poem card UX, poem detail screen UX improvements
> **Depends on**: Feed & Social Audit v2 (06_feed_social_audit_v2.md) — apply that first
> **Files**: `home_feed_screen.dart`, `explore_screen.dart`, `poem_card.dart`, `poem_detail_screen.dart`, `feed_controller.dart`

---

## Summary

This addendum covers 3 areas that need UX work: adding audio filtering to the home feed, making audio poems visually distinct in feed cards with inline play, and improving the poem detail screen to use all available backend data (coverColor, better audio player, share, social event integration).

---

## Fixes

---

### 1. HIGH — Add audio toggle to home feed

**File**: `features/feed/screens/home_feed_screen.dart`

**Problem**: Home feed has no way to filter to audio-only poems. The explore screen gets an audio toggle (from the v2 audit), but the home feed — which shows poems from people you follow — doesn't. Users who want to listen to poetry from their followed poets can't filter.

**Fix**: Add a row below the app bar with a toggle chip, similar to explore. The home feed audio toggle filters the *existing* home feed to only show poems with audio (client-side filter), or calls the `/feed/audio` endpoint (server-side). Since the backend already has a separate audio feed endpoint, use that:

```dart
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAudioOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (_showAudioOnly) {
        ref.read(audioFeedControllerProvider.notifier).loadMore();
      } else {
        ref.read(homeFeedControllerProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = _showAudioOnly
        ? ref.watch(audioFeedControllerProvider)
        : ref.watch(homeFeedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('ChatBee',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, size: 26.r, color: AppTheme.textDarkColor),
            onPressed: () => context.push('/notifications'),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: Column(
        children: [
          // ── Feed type toggle ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                _FeedToggleChip(
                  label: 'All',
                  isActive: !_showAudioOnly,
                  onTap: () {
                    if (_showAudioOnly) {
                      HapticFeedback.selectionClick();
                      setState(() => _showAudioOnly = false);
                    }
                  },
                ),
                SizedBox(width: 8.w),
                _FeedToggleChip(
                  label: 'Audio',
                  icon: Icons.headphones_rounded,
                  isActive: _showAudioOnly,
                  onTap: () {
                    if (!_showAudioOnly) {
                      HapticFeedback.selectionClick();
                      setState(() => _showAudioOnly = true);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Feed content ──
          Expanded(
            child: feedState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.toString(), style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                    TextButton(
                      onPressed: () {
                        if (_showAudioOnly) {
                          ref.read(audioFeedControllerProvider.notifier).refresh();
                        } else {
                          ref.read(homeFeedControllerProvider.notifier).refresh();
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (poems) {
                if (poems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAudioOnly ? Icons.headphones_rounded : Icons.auto_stories_rounded,
                          size: 64.r, color: AppTheme.textLightColor,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _showAudioOnly ? 'No audio poems yet' : 'No poems yet',
                          style: TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _showAudioOnly
                              ? 'Poems with audio recordings will appear here'
                              : 'Follow poets to see their work here',
                          style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor),
                        ),
                        if (!_showAudioOnly) ...[
                          SizedBox(height: 16.h),
                          TextButton.icon(
                            onPressed: () => context.push('/search'),
                            icon: Icon(Icons.explore_rounded, size: 18.r),
                            label: const Text('Explore poems'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () {
                    if (_showAudioOnly) {
                      return ref.read(audioFeedControllerProvider.notifier).refresh();
                    }
                    return ref.read(homeFeedControllerProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: poems.length,
                    itemBuilder: (_, i) => PoemCard(poem: poems[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable toggle chip for feed type selection.
class _FeedToggleChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FeedToggleChip({
    required this.label,
    this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : AppTheme.featureBackgroundColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14.r, color: isActive ? Colors.white : AppTheme.textMediumColor),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isActive ? Colors.white : AppTheme.textMediumColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add imports: `import 'package:flutter/services.dart';`, `import 'package:chatbee/features/feed/controllers/feed_controller.dart';`, `import 'package:chatbee/features/poems/widgets/poem_card.dart';`.

This replaces the placeholder home feed with the real feed + audio toggle. The `_FeedToggleChip` widget can also be reused in the explore screen.

---

### 2. HIGH — Audio poems need a more prominent indicator and inline play in feed cards

**File**: `poem_card.dart`

**Problem**: Audio poems currently show only a tiny 14px mic icon at the bottom-right of the card footer. Users don't realize they can listen to a poem. There's no way to play the audio without tapping into the detail screen. For a poetry app, audio is a key differentiator and should be visually prominent.

**Fix**: Add an audio bar between the poem content and the footer, with a play button and duration. This is visible only for poems with audio — it doesn't affect text-only poems:

```dart
// In poem_card.dart build(), between the hashtags section and the footer divider:

// ── Audio indicator (only for poems with audio) ──
if (widget.poem.hasAudio) ...[
  SizedBox(height: 12.h),
  GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      // Navigate to detail screen where full audio player exists
      context.push('/poem/${widget.poem.id}', extra: widget.poem);
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppTheme.featureBackgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Play icon in a circle
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 22.r,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(width: 10.w),
          // Audio info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listen to this poem',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDarkColor,
                  ),
                ),
                if (widget.poem.audioDuration > 0)
                  Text(
                    '${widget.poem.audioDuration ~/ 60}:${(widget.poem.audioDuration % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                  ),
              ],
            ),
          ),
          // Headphone icon
          Icon(Icons.headphones_rounded, size: 18.r, color: AppTheme.textLightColor),
        ],
      ),
    ),
  ),
],
```

This creates a tappable audio bar that navigates to the detail screen where the full player lives. The bar uses the app's dark theme colors, shows the duration, and has a clear play affordance.

**Why not inline audio playback?** Adding a full audio player to each card in a ListView creates lifecycle complexity (multiple AudioPlayer instances, disposal on scroll, pause-other-when-play). The detail screen's audio player already handles this well. The card's audio bar serves as a CTA to open the detail screen.

---

### 3. HIGH — Poem detail screen improvements

**File**: `poem_detail_screen.dart`

**Problem (multiple UX issues):**

A. **Audio player is basic** — play/pause only, no progress bar, no seek. Users can't see how far into the poem they are.

B. **`coverColor` field is never used** — the backend sends a `coverColor` hex string that the author chose. It should be used as a subtle background tint on the detail screen.

C. **No share button** — users can't share a poem.

D. **Comment count uses `widget.poem.commentsCount` (static)** — doesn't update after adding a comment.

E. **Social state doesn't integrate with the socialEventProvider** — liking on detail doesn't propagate back to feed cards.

F. **Timestamps not converted to local time** — same issue as chat (from chat audit).

G. **Hashtags are not tappable** — tapping a hashtag should filter the explore feed to that hashtag.

**Fixes:**

**A. Better audio player with progress bar and seek:**

Replace the simple audio player section with:

```dart
if (poem.hasAudio)
  _AudioPlayerWidget(
    audioUrl: poem.audioUrl,
    duration: poem.audioDuration,
  ),
```

Create a separate stateful widget for the audio player:

```dart
class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int duration; // seconds

  const _AudioPlayerWidget({required this.audioUrl, required this.duration});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
      // Use backend duration as fallback
      if (widget.duration > 0 && _duration == Duration.zero) {
        _duration = Duration(seconds: widget.duration);
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.featureBackgroundColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _isPlaying ? _player.pause() : _player.play();
                },
                child: Container(
                  width: 48.r,
                  height: 48.r,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28.r,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Progress and duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seekable progress bar
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.h,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 14.r),
                        activeTrackColor: AppTheme.primaryColor,
                        inactiveTrackColor: AppTheme.borderColor,
                        thumbColor: AppTheme.primaryColor,
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          final newPos = Duration(
                            milliseconds: (v * _duration.inMilliseconds).round(),
                          );
                          _player.seek(newPos);
                        },
                      ),
                    ),
                    // Duration labels
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position),
                              style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor)),
                          Text(_formatDuration(_duration),
                              style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

**B. Use coverColor as background tint:**

In the poem detail screen's `Scaffold`, use the coverColor:

```dart
@override
Widget build(BuildContext context) {
    final poem = widget.poem;
    
    // Parse cover color for background tint
    Color? coverTint;
    if (poem.coverColor.isNotEmpty) {
      try {
        final hex = poem.coverColor.replaceFirst('#', '');
        coverTint = Color(int.parse(hex, radix: 16) + 0xFF000000);
      } catch (_) {}
    }

    return Scaffold(
      // ... appBar unchanged ...
      body: Container(
        // Subtle gradient using cover color
        decoration: coverTint != null
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    coverTint.withValues(alpha: 0.08),
                    AppTheme.backgroundColor,
                  ],
                ),
              )
            : null,
        child: SingleChildScrollView(
          // ... existing content unchanged ...
        ),
      ),
    );
}
```

**C. Add share button to app bar:**

```dart
appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios),
    onPressed: () => context.pop(),
  ),
  actions: [
    // Share button
    IconButton(
      icon: const Icon(Icons.share_outlined),
      onPressed: () {
        HapticFeedback.lightImpact();
        // Share poem text
        // import 'package:share_plus/share_plus.dart';
        // Share.share('${poem.title}\n\n${poem.plainText}\n\n— ${poem.author.displayName}');
        // For now, copy to clipboard:
        Clipboard.setData(ClipboardData(
          text: '${poem.title}\n\n${poem.plainText}\n\n— ${poem.author.displayName}',
        ));
        AppSnackbar.show(context, message: 'Poem copied to clipboard', type: SnackbarType.success);
      },
    ),
    if (ref.watch(authControllerProvider).valueOrNull?.id == poem.author.id)
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/editor', extra: poem),
      ),
  ],
),
```

**D. Track comment count locally + E. Integrate with socialEventProvider:**

Add to `_PoemDetailScreenState`:

```dart
late int _commentCount;
StreamSubscription? _socialSub;

@override
void initState() {
    super.initState();
    _commentCount = widget.poem.commentsCount;
    // ... existing initState code ...

    // Listen for social events (from other screens)
    _socialSub = ref.read(socialEventStreamProvider).stream.listen((event) {
      if (event.poemId == widget.poem.id && mounted) {
        setState(() {
          if (event.isLiked != null) _isLiked = event.isLiked!;
          if (event.likesCount != null) _likeCount = event.likesCount!;
          if (event.isReposted != null) _isReposted = event.isReposted!;
          if (event.repostsCount != null) _repostCount = event.repostsCount!;
          if (event.commentsCount != null) _commentCount = event.commentsCount!;
        });
      }
    });
}

@override
void dispose() {
    _socialSub?.cancel();
    _quillController.dispose();
    _audioPlayer.dispose();
    super.dispose();
}
```

Replace `${widget.poem.commentsCount}` with `$_commentCount` in the build method.

Also add social event broadcasting in `_toggleLike` and `_toggleRepost` (same pattern as poem_card from v2 audit fix #5).

**F. Timestamps:** Apply `formatMessageTime` from chat audit (or use `timeago`). The detail screen already uses `timeago` — verified correct.

**G. Tappable hashtags:**

```dart
// Replace the hashtag Wrap:
if (poem.hashtags.isNotEmpty)
  Wrap(
    spacing: 8.w,
    runSpacing: 4.h,
    children: poem.hashtags.map((tag) => GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Navigate to explore with this hashtag pre-filtered
        context.push('/search');
        // After navigation, filter by hashtag:
        // This requires the explore screen to accept a hashtag parameter
        // For now, use a provider:
        ref.read(exploreFeedControllerProvider.notifier).filterByHashtag(tag);
      },
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 13.sp,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    )).toList(),
  ),
```

---

## Verification Checklist

- [ ] Home feed shows "All" and "Audio" toggle chips
- [ ] Toggle "Audio" on home feed → only audio poems appear
- [ ] Toggle back to "All" → full feed returns
- [ ] Audio poem in feed card shows prominent "Listen to this poem" bar with play icon and duration
- [ ] Tap audio bar on card → navigates to detail screen
- [ ] Detail screen audio player has seekable progress bar with position/duration
- [ ] Detail screen uses coverColor as subtle background gradient
- [ ] Detail screen has share button in app bar
- [ ] Tap share → poem text copied to clipboard
- [ ] Like on detail → go back → feed card shows the like (via socialEventProvider)
- [ ] Add comment on detail → comment count updates on the detail screen
- [ ] Tap hashtag on detail → navigates to explore filtered by that hashtag
- [ ] Audio empty state (home feed) shows headphone icon with "Poems with audio recordings will appear here"
