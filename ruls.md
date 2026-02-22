# Anchor ⚓ - Development Rules & Guidelines

> This document defines the coding standards, patterns, and best practices for the Anchor Flutter application. **AI code generators and developers MUST follow these rules.**

---

## 🔄 Feature Development Workflow

### The Process (MANDATORY):

```
1. DISCUSS     → You and Claude discuss the feature requirements
2. FEATURE.md  → Claude creates a Feature Specification document
3. PROMPT      → Claude provides a prompt for code generation
4. GENERATE    → You generate code using the prompt (Cursor/Copilot/etc.)
5. REVIEW      → You share generated code with Claude for review
6. ITERATE     → Fix issues, optimize, finalize
```

### Feature.md Template:
```markdown
# Feature: [Feature Name]

## Overview
Brief description of what this feature does.

## User Stories
- As a user, I want to...
- As a user, I can...

## API Endpoints Used
- `POST /endpoint` - Description
- `GET /endpoint` - Description

## Models Required
- ModelName: field1, field2, field3

## Screens
1. ScreenName - Description
2. ScreenName - Description

## Widgets (Reusable)
- WidgetName - Where it's used, props

## State Management
- ControllerName - What state it manages

## Dependencies
- Existing features/widgets this depends on

## Acceptance Criteria
- [ ] Criteria 1
- [ ] Criteria 2
```

---

## 📐 ScreenUtil - MANDATORY FOR ALL SIZING

### ⚠️ CRITICAL: Every dimension MUST use ScreenUtil

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SIZING EXTENSIONS - USE THESE EVERYWHERE
// ═══════════════════════════════════════════════════════════════════════════

// Width (horizontal)
SizedBox(width: 16.w)              // ✅ Responsive width
Container(width: 200.w)            // ✅ Responsive width

// Height (vertical)
SizedBox(height: 16.h)             // ✅ Responsive height
Container(height: 200.h)           // ✅ Responsive height

// Square/Radius (maintains aspect ratio)
Container(width: 48.r, height: 48.r)  // ✅ Square dimensions
BorderRadius.circular(12.r)           // ✅ Border radius
EdgeInsets.all(16.r)                  // ✅ Equal padding

// Font size
Text('Hello', style: TextStyle(fontSize: 16.sp))  // ✅ Responsive font

// ═══════════════════════════════════════════════════════════════════════════
// WRONG - NEVER DO THIS
// ═══════════════════════════════════════════════════════════════════════════

SizedBox(width: 16)                // ❌ Fixed width
Container(height: 200)             // ❌ Fixed height
BorderRadius.circular(12)          // ❌ Fixed radius
TextStyle(fontSize: 16)            // ❌ Fixed font size
EdgeInsets.all(16)                 // ❌ Fixed padding
```

### When to Use Which Extension:

| Extension | Use For | Example |
|-----------|---------|---------|
| `.w` | Horizontal spacing, widths | `SizedBox(width: 16.w)` |
| `.h` | Vertical spacing, heights | `SizedBox(height: 24.h)` |
| `.r` | Square items, radius, icons, equal padding | `Icon(size: 24.r)` |
| `.sp` | Font sizes | `fontSize: 14.sp` |

### Use AppSizes Constants:
```dart
import 'package:pod/core/constants/app_sizes.dart';

// ✅ PREFERRED - Use predefined constants
Padding(padding: AppSizes.paddingAll16)
SizedBox(height: AppSizes.md)  // 16.r
BorderRadius.circular(AppSizes.radiusMedium)  // 12.r
SizedBox(height: AppSizes.buttonHeight)  // 56.h

// ✅ ALSO OK - Direct ScreenUtil usage for custom values
SizedBox(height: 32.h)
Padding(padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h))
```

---

## 🧩 Reusable Widgets - MANDATORY

### Rule: Create a Reusable Widget When:
1. **Used 2+ times** across different screens
2. **Complex UI** with multiple nested widgets
3. **Has its own state** or animation
4. **Feature-specific** but used in multiple screens of that feature

### Widget Organization:

```
lib/
├── shared/                        # App-wide reusable widgets
│   └── widgets/
│       ├── buttons/
│       │   ├── gradient_button.dart
│       │   ├── icon_button_circle.dart
│       │   └── text_link_button.dart
│       ├── inputs/
│       │   ├── app_text_field.dart
│       │   ├── search_bar.dart
│       │   └── tag_input.dart
│       ├── cards/
│       │   ├── base_card.dart
│       │   └── user_list_tile.dart
│       ├── loaders/
│       │   ├── shimmer_box.dart
│       │   ├── skeleton_list.dart
│       │   └── loading_overlay.dart
│       ├── dialogs/
│       │   ├── confirm_dialog.dart
│       │   └── bottom_sheet_base.dart
│       └── misc/
│           ├── empty_state.dart
│           ├── error_state.dart
│           └── avatar_widget.dart
│
├── features/
│   └── anchor/
│       └── widgets/              # Feature-specific widgets
│           ├── anchor_card.dart
│           ├── item_tile.dart
│           └── visibility_badge.dart
```

### Reusable Widget Template:

```dart
// lib/shared/widgets/buttons/gradient_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pod/core/theme/app_colors.dart';
import 'package:pod/core/theme/app_text_styles.dart';
import 'package:pod/core/constants/app_sizes.dart';

/// A gradient button with loading state support.
/// 
/// Usage:
/// ```dart
/// GradientButton(
///   label: 'Submit',
///   onPressed: _handleSubmit,
///   isLoading: state.isLoading,
/// )
/// ```
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;
  final List<Color>? gradientColors;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? [AppColors.gradient1, AppColors.gradient2];
    final isDisabled = onPressed == null || isLoading;

    return Container(
      width: width ?? double.infinity,
      height: height ?? AppSizes.buttonHeight,
      decoration: BoxDecoration(
        gradient: !isDisabled ? LinearGradient(colors: colors) : null,
        color: isDisabled ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 20.r,
                    width: 20.r,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(label, style: AppTextStyles.button),
          ),
        ),
      ),
    );
  }
}
```

### Widget Documentation Requirements:
1. **Doc comment** explaining purpose
2. **Usage example** in doc comment
3. **Named parameters** with defaults where sensible
4. **const constructor** when possible

---

## 📁 Project Structure

```
lib/
├── core/                          # Shared infrastructure
│   ├── config/                    # App configuration (environments, feature flags)
│   ├── constants/                 # App-wide constants (sizes, keys)
│   ├── di/                        # Dependency injection (locator.dart)
│   ├── error/                     # Failure classes (sealed)
│   ├── network/                   # API layer (Dio, interceptors, ApiService)
│   ├── routing/                   # GoRouter setup, routes, navigation extensions
│   ├── theme/                     # Colors, typography, theme data
│   └── utils/                     # Helpers (logger, snackbar, validators, shared_prefs)
│
├── features/                      # Feature modules (vertical slices)
│   ├── auth/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── controllers/
│   │   ├── screens/
│   │   └── widgets/              # Feature-specific widgets
│   │
│   ├── anchor/
│   ├── profile/
│   ├── feed/
│   └── ...
│
├── shared/                        # App-wide reusable widgets
│   └── widgets/
│       ├── buttons/
│       ├── inputs/
│       ├── cards/
│       ├── loaders/
│       └── ...
│
└── main.dart
```

---

## 🏗️ Feature Architecture

Every feature MUST follow this structure:

```
feature_name/
├── models/                        # Data classes (immutable)
├── repositories/                  # API calls via ApiService
├── controllers/                   # AsyncNotifier state management
├── screens/                       # Full-page ConsumerWidget/ConsumerStatefulWidget
└── widgets/                       # Feature-specific reusable widgets
```

### Layer Responsibilities:

| Layer | Responsibility | Can Access |
|-------|---------------|------------|
| **Screen** | UI rendering, user input, navigation, side effects | Controller, Theme, Sizes, Widgets |
| **Controller** | State management, business logic | Repository, SharedPrefs |
| **Repository** | Data fetching, API calls | ApiService only |
| **Model** | Data structure, serialization | Nothing (pure data) |
| **Widget** | Reusable UI component | Theme, Sizes only |

---

## 📦 State Management Rules (Riverpod 2.0)

### 1. Use `@riverpod` Code Generation
```dart
// ✅ CORRECT
@riverpod
class MyController extends _$MyController {
  @override
  FutureOr<MyModel?> build() => null;
}

// ❌ WRONG - Don't use manual StateNotifier
class MyController extends StateNotifier<AsyncValue<MyModel?>> { }
```

### 2. Controller Pattern
```dart
@riverpod
class AnchorListController extends _$AnchorListController {
  @override
  FutureOr<List<AnchorModel>> build() async {
    return ref.read(anchorRepositoryProvider).getMyAnchors();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => 
      ref.read(anchorRepositoryProvider).getMyAnchors()
    );
  }
}
```

### 3. Repository Pattern
```dart
class AnchorRepository {
  final ApiService _api;
  
  AnchorRepository(this._api);

  Future<List<AnchorModel>> getMyAnchors() async {
    return _api.get(
      AppConfig.anchors,
      fromJsonT: (json) => (json as List)
          .map((e) => AnchorModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@riverpod
AnchorRepository anchorRepository(AnchorRepositoryRef ref) {
  return AnchorRepository(ref.read(apiServiceProvider.notifier));
}
```

---

## 🎨 UI Rules

### 1. Screen Structure
```dart
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});

  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(myControllerProvider.notifier).submit(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Side effects FIRST
    ref.listen(myControllerProvider, (prev, next) {
      next.when(
        data: (data) {
          if (data != null) {
            AppSnackBar.success(context, 'Success!');
            context.goToHome();
          }
        },
        error: (e, _) => AppSnackBar.error(context, e.toString()),
        loading: () {},
      );
    });

    // 2. Watch state
    final state = ref.watch(myControllerProvider);
    final isLoading = state.isLoading;

    // 3. Build UI with ScreenUtil
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16.r),  // ✅ ScreenUtil
        child: Column(
          children: [
            SizedBox(height: 24.h),     // ✅ ScreenUtil
            // ...
          ],
        ),
      ),
    );
  }
}
```

### 2. Navigation - Always in UI Layer
```dart
// ✅ CORRECT - Navigation in screen via ref.listen
ref.listen(loginControllerProvider, (prev, next) {
  if (next.valueOrNull != null) {
    context.goToHome();
  }
});

// ❌ WRONG - Navigation in controller
```

### 3. Snackbars - Always in UI Layer
```dart
// ✅ CORRECT
ref.listen(controller, (prev, next) {
  next.whenOrNull(
    error: (e, _) => AppSnackBar.error(context, e.toString()),
  );
});

// ❌ WRONG - Snackbar in controller/repository
```

---

## 🎯 Using Core Utilities

### AppSnackBar
```dart
import 'package:pod/core/utils/snackbar.dart';

AppSnackBar.success(context, 'Saved successfully!');
AppSnackBar.error(context, 'Something went wrong');
AppSnackBar.warning(context, 'Check your input');
```

### Navigation Extensions
```dart
import 'package:pod/core/routing/navigation_extensions.dart';

context.goToHome();
context.goToLogin();
context.goToAnchorDetail('123');
context.goBack();
```

### Theme & Sizes
```dart
import 'package:pod/core/theme/app_colors.dart';
import 'package:pod/core/theme/app_text_styles.dart';
import 'package:pod/core/constants/app_sizes.dart';

// Colors
Container(color: AppColors.primary)

// Text styles (already have .sp built-in)
Text('Title', style: AppTextStyles.h1)

// Sizes (already have ScreenUtil built-in)
Padding(padding: AppSizes.paddingAll16)
```

### Validators
```dart
import 'package:pod/core/utils/validators.dart';

TextFormField(validator: Validators.email)
TextFormField(validator: Validators.password)
```

---

## 📝 Model Rules

### Required Methods:
```dart
class AnchorModel {
  final String id;
  final String title;
  // ...

  const AnchorModel({required this.id, required this.title});

  // ✅ REQUIRED
  factory AnchorModel.fromJson(Map<String, dynamic> json) { }
  
  // ✅ REQUIRED
  Map<String, dynamic> toJson() => { };
  
  // ✅ REQUIRED
  AnchorModel copyWith({String? id, String? title}) { }
}
```

### Enums with fromString:
```dart
enum AnchorVisibility {
  private,
  unlisted,
  public;

  static AnchorVisibility fromString(String? value) {
    return AnchorVisibility.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => AnchorVisibility.private,
    );
  }
}
```

---

## ⚡ Code Generation

After creating/modifying providers:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📋 Feature Checklist

Before marking a feature complete:

- [ ] Feature.md created and reviewed
- [ ] All dimensions use ScreenUtil (`.w`, `.h`, `.r`, `.sp`)
- [ ] Reusable widgets extracted to `widgets/` folder
- [ ] Models have `fromJson`, `toJson`, `copyWith`
- [ ] Repository uses `ApiService`
- [ ] Controller uses `@riverpod` AsyncNotifier
- [ ] `ref.listen` for side effects
- [ ] `ref.watch` for UI state
- [ ] Loading states handled
- [ ] Error states handled
- [ ] Empty states handled
- [ ] Code generation run

---

## 🚫 Anti-Patterns to Avoid

1. **Fixed dimensions** - Always use ScreenUtil
2. **Duplicate widgets** - Extract to reusable component
3. **Navigation in controllers** - Keep in UI layer
4. **Snackbars in repository** - Keep in UI layer
5. **Direct Dio usage** - Use ApiService
6. **Hardcoded strings** - Use constants
7. **Skip code generation** - Run build_runner
8. **`ref.read` in build()** - Use `ref.watch`
9. **Missing dispose** - Dispose TextEditingControllers
10. **No loading/error states** - Always handle all states

---

## 🎨 Design System Quick Reference

### Colors
```dart
AppColors.primary       // Main brand color
AppColors.gradient1/2/3 // Gradient colors
AppColors.success       // Green
AppColors.error         // Red
AppColors.warning       // Orange
AppColors.textPrimary   // Dark text
AppColors.textSecondary // Grey text
AppColors.background    // Screen background
AppColors.surface       // Card background
AppColors.border        // Border color
```

### Text Styles
```dart
AppTextStyles.h1          // 32.sp bold
AppTextStyles.h2          // 24.sp bold
AppTextStyles.h3          // 20.sp semibold
AppTextStyles.bodyLarge   // 16.sp
AppTextStyles.bodyMedium  // 14.sp
AppTextStyles.bodySmall   // 12.sp
AppTextStyles.button      // 16.sp semibold white
AppTextStyles.caption     // 12.sp grey
```

### Sizes
```dart
AppSizes.xs/sm/md/lg/xl   // 4/8/16/24/32.r
AppSizes.paddingAll16     // EdgeInsets.all(16.r)
AppSizes.paddingAll24     // EdgeInsets.all(24.r)
AppSizes.radiusSmall      // 8.r
AppSizes.radiusMedium     // 12.r
AppSizes.radiusLarge      // 16.r
AppSizes.buttonHeight     // 56.h
AppSizes.iconSmall/Medium/Large  // 20/24/32.r
```

---

*Last updated: January 2026*
*Anchor App v1.0.0*