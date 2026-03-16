# Flutter Poetry Editor Screen — Windsurf IDE Prompt

## Overview

Build a **Poetry Creation/Editor Screen** in Flutter. This is a core feature of a poetry app where poets write and stylize their work with rich inline formatting. The editor must feel elegant, minimal, and writer-focused — like a digital parchment, not a word processor.

---

## Screen Structure

### 1. App Bar / Top Bar
- A **back arrow** on the left.
- A **"Save"** button on the right (icon or text).
- An optional **"Preview"** button (eye icon) next to Save that toggles a read-only preview of the poem with all formatting rendered cleanly.
- The app bar should be minimal — no title text, let the poem itself be the focus. Use a subtle divider or no divider at all.

### 2. Title Field
- A single-line `TextField` at the top for the poem's **title**.
- Placeholder text: *"Untitled Poem"* in a light gray italic style.
- Use a **larger, serif or display font** (e.g., `Merriweather`, `Playfair Display`, or `Lora` from Google Fonts) — sized around 24–28sp.
- No visible border — just an underline or completely borderless. The title should feel like it's written directly on the page.
- On focus, show a very subtle underline accent (thin, muted color).

### 3. Poetry Body Editor (Rich Text Area)
This is the **core of the feature**. It is NOT a plain `TextField`. It is a **rich text editor** that supports inline formatting per-word or per-selection.

**Use the `flutter_quill` package** (or build a custom solution with `TextEditingController` + `TextSpan` + selection handling if you prefer full control — but `flutter_quill` is recommended for speed and reliability).

**Requirements:**
- Multi-line text input with **no character limit**.
- Placeholder text: *"Begin writing..."* in light gray italic.
- The font should be a **clean serif or literary font** (e.g., `Lora`, `EB Garamond`, `Source Serif Pro`) at ~16–18sp with comfortable line height (1.6–1.8x).
- The editor must support **selecting any word, phrase, or line** and applying the following formatting independently:

---

## Formatting Features (Inline, Per-Selection)

When the user **selects text** (long-press or double-tap a word, then drag handles), a **floating formatting toolbar** should appear above or below the selection. This toolbar provides:

### Core Formatting Options:
| Feature | Icon | Behavior |
|---|---|---|
| **Bold** | `B` (bold icon) | Toggles bold weight on selected text |
| **Italic** | `I` (italic icon) | Toggles italic style on selected text |
| **Underline** | `U` (underline icon) | Toggles underline decoration on selected text |
| **Strikethrough** | `S` (strikethrough icon) | Toggles line-through decoration on selected text |
| **Text Color** | Paint bucket / color circle icon | Opens a **color picker popup** — user picks a color, and only the selected text gets that color |

### Additional / Suggested Formatting Options:
| Feature | Icon | Behavior |
|---|---|---|
| **Highlight / Background Color** | Highlighter icon | Applies a background color behind the selected text — like a marker highlight. Opens a small palette (yellow, green, pink, blue, purple, orange). Useful for poets to emphasize key phrases for readers. |
| **Font Size Override** | `A↑` / `A↓` or a small size stepper | Allows making specific words larger or smaller than the base font — great for emphasis or whisper effects in poetry. Offer a few presets: Small (14sp), Normal (17sp), Large (22sp), Display (28sp). |
| **Superscript / Subscript** | `X²` / `X₂` icons | Toggles superscript or subscript — useful for footnotes, annotations, or stylistic choices. |
| **Letter Spacing** | `AV` icon with arrows | Allows expanding or compressing letter spacing on selected text — options: Tight, Normal, Wide, Very Wide. This is a poetic tool for visual rhythm. |
| **Opacity / Fade** | Ghost/transparency icon | Reduces the opacity of selected text (e.g., 30%, 50%, 70%, 100%) — a unique poetry feature where fading words can represent memory, whispers, or fading thoughts. |
| **All Caps / Small Caps** | `AA` icon | Toggles uppercase or small-caps transform on selected text. |

---

## Floating Formatting Toolbar — Design & Behavior

- **Trigger**: Appears only when text is selected. Disappears when selection is cleared.
- **Position**: Float above the selection if there's room, otherwise below. It should never overlap the selected text.
- **Shape**: A **rounded, pill-shaped or soft-rectangle** container with a subtle shadow and slight blur backdrop.
- **Background**: Semi-transparent dark (e.g., `Colors.grey[900]?.withOpacity(0.92)`) or adapt to theme.
- **Icons**: Use outlined/thin icons in white or light color. When a formatting option is **active** on the current selection, its icon should be **highlighted** (filled icon, accent color background, or underline indicator).
- **Scrollable**: If all options don't fit in one row, make the toolbar **horizontally scrollable** or split into a primary row (Bold, Italic, Underline, Strikethrough, Color) and a secondary row or expandable "more" (`...`) button for advanced options.
- **Animation**: Toolbar should **fade + slide in** when appearing and **fade out** when dismissed. Use a ~200ms ease-in-out curve.

---

## Color Picker (for Text Color & Highlight)

When the user taps the **color** or **highlight** button on the toolbar:

- Show a **small popup/bottom sheet** with:
  - A **curated palette** of 12–16 colors suited for poetry aesthetics — not harsh primaries. Think: muted tones, ink colors, earth tones, pastels. Example palette:
    - Ink Black `#1A1A2E`
    - Deep Crimson `#6B0F1A`
    - Midnight Blue `#1B3A4B`
    - Forest Green `#2D6A4F`
    - Burnt Sienna `#A0522D`
    - Dusty Rose `#C9928E`
    - Amber Gold `#D4A843`
    - Plum `#6A0572`
    - Storm Gray `#6C757D`
    - Ocean Teal `#2A9D8F`
    - Soft Lavender `#9B8EC1`
    - Warm White `#F5F0EB`
  - A **"Custom Color"** option that opens a full HSL/wheel color picker (use `flutter_colorpicker` package or build a simple one).
  - A **"Reset / Remove Color"** option to clear the color back to default.
- The popup should have a small **arrow/notch** pointing toward the toolbar button that triggered it.

---

## Additional Screen Features

### Line Numbers (Optional Toggle)
- A toggle in a settings menu or long-press gesture to show **faint line numbers** in the left margin.
- Line numbers should be in a very light gray, small font, and not interfere with the writing experience.
- Useful for poets who reference lines during editing.

### Word & Character Count
- A **subtle, non-intrusive** counter at the bottom of the screen or in the app bar.
- Show: `Words: 42 | Lines: 7 | Characters: 281`
- Use a very small font (11–12sp), muted gray color.
- This should not distract from writing.

### Stanza Separator
- When the user presses **Enter twice** (creating a blank line), visually render a **subtle stanza break** — a thin horizontal line or extra spacing — to clearly delineate stanzas.
- In editing mode, the blank line is editable/deletable. In preview mode, it renders as a clean stanza gap.

### Undo / Redo
- Support **undo and redo** for both text changes and formatting changes.
- Add undo/redo icons in the app bar or as a swipe gesture (two-finger swipe left = undo, right = redo).
- Maintain a history stack of at least 30 actions.

### Auto-Save
- Implement a **debounced auto-save** — save the poem state to local storage (Hive, SharedPreferences, or SQLite) every 3 seconds after the last edit.
- Show a tiny, subtle "Saved" indicator (small checkmark or text) that appears briefly after each auto-save and fades out.

### Dark Mode / Theme Switching
- Support **light and dark themes**.
  - Light: Warm parchment-like background (`#FAF8F5` or `#FFF8F0`), dark ink text.
  - Dark: Deep charcoal background (`#1A1A2E` or `#121212`), soft white/cream text.
- Add a **theme toggle** (sun/moon icon) in the app bar or settings.
- All formatting colors should remain visible and legible in both themes. Adjust if needed.

### Keyboard Shortcuts (for tablet/desktop)
- `Ctrl+B` = Bold
- `Ctrl+I` = Italic
- `Ctrl+U` = Underline
- `Ctrl+Shift+S` = Strikethrough
- `Ctrl+Z` = Undo
- `Ctrl+Shift+Z` or `Ctrl+Y` = Redo

---

## Data Model

```dart
class Poem {
  String id;             // UUID
  String title;          // Poem title
  String contentJson;    // Rich text stored as Quill Delta JSON
  String plainText;      // Plain text version for search/indexing
  DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;     // Optional tags/categories
}
```

Store the rich text content as **Quill Delta JSON** (if using `flutter_quill`) — this preserves all inline formatting, colors, and styles in a serializable format.

---

## Packages to Use

| Package | Purpose |
|---|---|
| `flutter_quill` | Rich text editor with formatting support |
| `google_fonts` | Literary/serif fonts (Lora, Playfair Display, etc.) |
| `flutter_colorpicker` | Full color picker for custom colors |
| `hive` or `sqflite` | Local storage for auto-save |
| `uuid` | Generate unique poem IDs |
| `provider` or `riverpod` | State management |

---

## UI/UX Design Guidelines

1. **Writer-first experience**: The screen should feel like a blank page, not a software tool. Minimize chrome, maximize writing space.
2. **Typography is king**: Since this is a poetry app, font choices and text rendering quality matter enormously. Use proper line heights, kerning, and font weights.
3. **Formatting should be discoverable but not distracting**: The toolbar only appears on selection — the rest of the time, it's just the poet and their words.
4. **Smooth animations everywhere**: Toolbar appear/disappear, color picker open/close, theme switching — all should be animated with gentle curves (200–300ms).
5. **Tactile feedback**: Add subtle haptic feedback on formatting button taps (use `HapticFeedback.lightImpact()`).
6. **Respect the poem's visual layout**: Poetry is visual. Line breaks, spacing, and indentation must be preserved exactly as the poet types them. Never auto-wrap or auto-correct in ways that break poetic structure.
7. **Padding**: Give generous horizontal padding (24–32px) to the text area so the poem doesn't feel cramped against screen edges. The text should sit in a comfortable column, like a poem on a printed page.

---

## Screen Wireframe (Conceptual)

```
┌─────────────────────────────────┐
│  ←          ☀️  👁  💾         │  ← App Bar (back, theme, preview, save)
├─────────────────────────────────┤
│                                 │
│  Untitled Poem                  │  ← Title field (large serif font)
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │  ← Subtle separator
│                                 │
│  Begin writing...               │  ← Rich text editor body
│                                 │
│                                 │
│                                 │
│   ┌───────────────────────┐     │
│   │ B  I  U  S̶  🎨  A↑ … │     │  ← Floating toolbar (on selection)
│   └───────────────────────┘     │
│                                 │
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│  Words: 0 | Lines: 0           │  ← Word count bar
└─────────────────────────────────┘
```

---

## Implementation Order

1. **Set up the project** with required packages in `pubspec.yaml`.
2. **Build the basic screen layout** — AppBar, title field, body editor placeholder.
3. **Integrate `flutter_quill`** as the body editor with base font styling.
4. **Implement the floating formatting toolbar** with Bold, Italic, Underline, Strikethrough.
5. **Add text color** with the curated palette + custom color picker.
6. **Add highlight/background color** support.
7. **Add advanced options** — font size, opacity, letter spacing, caps.
8. **Implement undo/redo** with history stack.
9. **Add auto-save** with debounced local storage.
10. **Add word/line/character count**.
11. **Implement dark/light theme toggle**.
12. **Add preview mode**.
13. **Polish animations, haptics, and edge cases**.
14. **Test on multiple screen sizes** (phone, tablet, desktop).
