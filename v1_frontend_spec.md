# ChatBee v1 — Frontend Implementation Spec

*March 22, 2026*

---

## Overview

This spec covers all Flutter frontend changes for v1: editor refactor (inline all settings, add description with @mentions, alignment, word limit), card redesign (new layout matching the approved screenshot), font bundling (PlayfairDisplay), 3-dot menu, remove detail screen, audio seekbar, and notification routing.

---

## Approved card design (from screenshot)

```
┌─────────────────────────────────────────┐
│  [avatar] bobbycneis          85w       │  Author row: avatar + name + time (left)
│           @god                    •••   │               @username below + 3-dot (right)
├─────────────────────────────────────────┤
│  Thanks for the support @writersnetwork │  Description (app font, muted)
│  and special thanks to @god             │  @mentions tappable → profile
├──────────── thin divider ───────────────┤
│                                         │
│     Celestial Heart                     │  Title (PlayfairDisplay-Medium, aligned)
│                                         │
│     Two stars decided to align,         │  Body (PlayfairDisplay-Regular, aligned)
│     and I'm divine when the worlds      │
│     begin to intertwine.                │
│                                         │
│                          — Asif         │  Attribution (only if isOriginal)
│                                         │  Inside poem body area, Playfair, right-aligned
├─────────────────────────────────────────┤
│  ♥ 1    💬 1    ↻ 0          ©    →    │  Social footer + copyright badge + share
└─────────────────────────────────────────┘
```

**Key changes from current card:**
- Author row: avatar + display name + @username (second line) + time. 3-dot menu on right.
- Description with tappable @mentions appears ABOVE poem, separated by divider.
- Title uses PlayfairDisplay-Medium. Body uses PlayfairDisplay-Regular. NOT GoogleFonts.
- No truncation — full poem shown (150 word limit enforced at creation).
- No `_isLong` / "Show more..." / `ShaderMask` / `ConstrainedBox(maxHeight)`.
- No `GestureDetector` on the whole card navigating to detail screen.
- `— Username` attribution inside poem area, right-aligned, only when `isOriginal == true`.
- Audio bar upgraded from static badge to playable seekbar.
- Share icon added (dummy for v1).

---

## Font strategy

**Font**: PlayfairDisplay — bundled as .ttf (NOT `google_fonts` package).

**Files in `assets/fonts/`:**
- `PlayfairDisplay-Regular.ttf` — poem body
- `PlayfairDisplay-Medium.ttf` — poem title

**`pubspec.yaml`:**
```yaml
flutter:
  fonts:
    - family: PlayfairDisplay
      fonts:
        - asset: assets/fonts/PlayfairDisplay-Regular.ttf
        - asset: assets/fonts/PlayfairDisplay-Medium.ttf
          weight: 500
```

**Replace everywhere:**
- `GoogleFonts.playfairDisplay(...)` → `TextStyle(fontFamily: 'PlayfairDisplay', ...)`
- `GoogleFonts.lato(...)` in Quill customStyles → `TextStyle(fontFamily: 'PlayfairDisplay', ...)`

**Applies to:** Card title + body + attribution. Editor title + Quill body.
**Does NOT apply to:** Description, author row, hashtags, social footer, rest of app.

---

## Editor layout (final)

```
┌──────────────────────────────────────────┐
│ ←  [del]   [≡L ≡C ≡R]    ↶  ↷  Publish │  App bar
├──────────────────────────────────────────┤
│              Title field                 │  PlayfairDisplay-Medium, aligned
├──────────────────────────────────────────┤
│           Poem body (Quill)              │  PlayfairDisplay-Regular, aligned
│           Floating toolbar on selection  │  bold/italic/underline/strike/color/size
│                               42 / 150   │  Word counter (red when over)
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ Add a description...                     │  App font, @mention autocomplete, 200 char max
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ ☑ This is my original work               │  Checkbox (defaults unchecked)
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ GENRES                                   │
│ [#love] [#grief] [#nature] ...           │  Tappable chips + custom input
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ VOICE / AUDIO                            │
│ [Record]  [Upload]                       │  Full recording UI (from bottom sheet)
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ COVER COLOR                              │
│ ● ● ● ● ● ●                             │  Color dots (for future poster use)
└──────────────────────────────────────────┘

  "Publish" opens minimal bottom sheet:
  ┌─────────────────────────────────────┐
  │        [Save Draft]  [  Publish  ]  │
  └─────────────────────────────────────┘
```

---

## Changes by file

### 1. `pubspec.yaml`

Register PlayfairDisplay font family. Check if `google_fonts` can be removed (other screens may still use it).

---

### 2. `poem_model.dart` — add new fields

```dart
@JsonKey(defaultValue: '')
final String description;

@JsonKey(defaultValue: '')
final String textAlign;

@JsonKey(defaultValue: [])
final List<MentionedUser> mentions;
```

Add `MentionedUser` class:

```dart
@JsonSerializable()
class MentionedUser {
  final String id;
  final String username;
  final String displayName;
  final String photoURL;

  const MentionedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.photoURL,
  });

  factory MentionedUser.fromJson(Map<String, dynamic> json) => _$MentionedUserFromJson(json);
  Map<String, dynamic> toJson() => _$MentionedUserToJson(this);
}
```

Update constructor + `copyWith`. Run `dart run build_runner build`.

---

### 3. `poem_repo.dart` — update request

```dart
class CreatePoemRequest {
  // ... existing ...
  final String description;
  final String textAlign;

  const CreatePoemRequest({
    // ... existing ...
    this.description = '',
    this.textAlign = 'left',
  });

  Map<String, dynamic> toJson() => {
    // ... existing ...
    'description': description,
    'textAlign': textAlign,
  };
}
```

---

### 4. `poetry_editor_screen.dart` — major refactor

**Move FROM bottom sheet TO editor:**
- Hashtag state (selectedHashtags, customTags, customTagController)
- isOriginal checkbox
- Audio state (entire recording/upload/preview flow)
- Cover color

**Add NEW state:**
- `TextEditingController _descriptionController`
- `String _textAlign = 'left'`

**Pre-fill on edit:** Load existing poem's description, textAlign, hashtags, isOriginal, audio, coverColor.

**App bar changes:**
- REMOVE: preview mode toggle
- ADD: alignment segmented control (3 icons — left/center/right)
- CHANGE: "Save" → "Publish" (opens minimal bottom sheet)
- KEEP: back, delete (existing poems only), undo, redo

**Body:** `SingleChildScrollView` wrapping: title → divider → Quill editor (scrollable: false, expands: false) → word counter → description field → original content → genres → audio → cover color.

**CRITICAL:** Quill inside SingleChildScrollView requires `scrollable: false` and `expands: false` on QuillEditorConfig.

**Title field:** Apply `_textAlignEnum` (TextAlign from string) and PlayfairDisplay-Medium font.

**Word counter:** Simple `Text('$_wordCount / 150')` right-aligned, red when over 150.

**Publish flow:** Validate (word count, non-empty) → open MinimalPublishSheet → call `_submit('public')` or `_submit('private')`.

**Submit method:** Moved from bottom sheet. Builds `CreatePoemRequest` with all fields including description + textAlign. Calls create/update API, updates feed controllers, pops editor.

---

### 5. `publish_bottom_sheet.dart` — gut to minimal

Replace entire file with `MinimalPublishSheet` — just drag handle + two buttons (Save Draft + Publish). Receives `onPublish`, `onDraft`, `isSubmitting` callbacks.

---

### 6. Create `mention_text_field.dart`

Reusable `@mention` autocomplete widget for the description field.

**Behavior:**
1. On `@` typed, start tracking query.
2. Debounce 300ms, call `GET /users/search?q=<text_after_@>&limit=5`.
3. Show overlay with matching users (avatar + username + displayName).
4. Tap → replace `@partial` with `@username ` (trailing space).
5. Dismiss on: selection, backspace past `@`, space after no match.

**Uses existing endpoint:** `ApiEndpoints.usersSearch` = `/users/search`.

**Overlay positioning:** `LayerLink` + `CompositedTransformFollower`.

---

### 7. `poem_card.dart` — new layout

**Remove:**
- `GestureDetector` on whole card (no detail screen navigation)
- `_isLong`, `ShaderMask`, `ConstrainedBox(maxHeight: 280.h)`
- `GoogleFonts.lato(...)` / `GoogleFonts.playfairDisplay(...)` calls

**Author row:** Avatar + name + @username (two lines) + time (left). 3-dot `PopupMenuButton` (right).

**3-dot menu:**
- Own posts: Edit, Delete, Check Plagiarism (dummy)
- Others: Report (dummy), Check Plagiarism (dummy)

**Description:** Parse `@[a-zA-Z0-9_-]+` with regex, build `RichText` with `TapGestureRecognizer` on mentions → navigate to profile using `poem.mentions` list to resolve username → user ID.

**Poem body:** Full text, no truncation. PlayfairDisplay-Regular. Apply textAlign. `scrollable: false`.

**Attribution:** `— DisplayName` right-aligned inside poem area, PlayfairDisplay italic, only if `isOriginal`.

**Audio:** Upgrade from static "Has audio recording" badge to playable seekbar. Idle: play + duration. Playing: pause + Slider + position/duration. Stop on scroll off-screen via `VisibilityDetector`.

**Share icon:** Dummy, shows "Coming soon" toast.

---

### 8. `app_router.dart` — update poem route

```dart
GoRoute(
  path: '/poem/:id',
  builder: (context, state) {
    final poemId = state.pathParameters['id']!;
    final poem = state.extra as PoemModel?;
    return PoemStandaloneScreen(poemId: poemId, poem: poem);
  },
),
```

---

### 9. Create `poem_standalone_screen.dart`

Minimal scaffold: AppBar with back button + single PoemCard. If `poem` passed via `extra`, show immediately. Otherwise fetch by ID from API.

---

### 10. `notification_navigator.dart` — add poem case

```dart
case 'poem':
  context.push('/poem/$resourceId');
  break;
```

---

### 11. Delete files

- `poem_detail_screen.dart`
- `poem_detail_fetch_wrapper.dart`
- `word_counter.dart` (replaced by inline text)

---

## Files summary

### Modified
| File | Changes |
|------|---------|
| `pubspec.yaml` | Register PlayfairDisplay fonts |
| `poem_model.dart` + `.g.dart` | Add description, textAlign, mentions + MentionedUser |
| `poem_repo.dart` | Add description, textAlign to CreatePoemRequest |
| `poetry_editor_screen.dart` | Major refactor: inline settings, alignment, description, word limit, font |
| `publish_bottom_sheet.dart` | Gut to Publish + Draft buttons only |
| `poem_card.dart` | New layout, 3-dot menu, description, attribution, font, seekbar, share |
| `app_router.dart` | Update `/poem/:id` to standalone scaffold |
| `notification_navigator.dart` | Add `poem` case |

### Created
| File | Purpose |
|------|---------|
| `mention_text_field.dart` | @mention autocomplete TextField |
| `poem_standalone_screen.dart` | Minimal scaffold for deep links / notifications |

### Deleted
| File | Reason |
|------|--------|
| `poem_detail_screen.dart` | Card is the full experience |
| `poem_detail_fetch_wrapper.dart` | No longer needed |
| `word_counter.dart` | Replaced by inline counter |

---

## Implementation order

**Phase 1 — Font + model (quick, non-breaking)**
1. Bundle .ttf files + register in pubspec.yaml
2. Add fields to PoemModel + run build_runner
3. Add fields to CreatePoemRequest
4. Replace GoogleFonts with bundled font in editor + card

**Phase 2 — Editor refactor**
1. Move hashtag/audio/cover/original state from bottom sheet to editor
2. Build scrollable editor with all sections inline
3. Add alignment control to app bar
4. Add word counter below editor
5. Add plain description TextField
6. Gut bottom sheet to just buttons
7. Wire _submit method

**Phase 3 — Mentions + card**
1. Build MentionTextField with @mention autocomplete
2. Replace plain description with MentionTextField
3. Update card layout: author row, description, attribution, font
4. Add 3-dot menu
5. Remove detail screen, update router + notification navigator
6. Create standalone screen

**Phase 4 — Polish**
1. Audio seekbar on card
2. Share icon (dummy)
3. Test all feed endpoints return new fields
