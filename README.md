# Flutter Starter Template

MVVM architecture with Riverpod state management.

## Architecture

```
View → watches Provider → Controller (Notifier) → calls Repo → Repo calls API → state updates → View rebuilds
```

## Folder Structure

```
lib/
├── core/          → Stuff every feature uses (API, routes, errors, utils)
├── shared/        → Reusable widgets, models, enums
├── config/        → Theme, text styles
├── features/      → Each feature is self-contained
│   └── feature_name/
│       ├── models/
│       ├── repos/
│       ├── controllers/
│       ├── views/
│       └── widgets/
├── app.dart       → Root widget
└── main.dart      → Entry point
```

## How to Add a New Feature

1. Create the feature folder:
```bash
mkdir -p lib/features/YOUR_FEATURE/{models,repos,controllers,views,widgets}
```

2. Create files in this order:
   - `models/` → Your data model with `fromJson`/`toJson`
   - `repos/` → API calls using `ApiClient`, with `@riverpod` provider
   - `controllers/` → `AsyncNotifier` with `@riverpod` annotation
   - `views/` → Screens using `ConsumerStatefulWidget`
   - `widgets/` → Feature-specific widgets

3. Add route in `core/routes/app_router.dart`:
```dart
GoRoute(
  path: '/your-feature',
  builder: (context, state) => const YourView(),
),
```

## Setup

```bash
flutter pub get
dart run build_runner build    # Generate .g.dart files
```

## Conventions

- **Repos** throw `Failure` on errors — Controllers catch them.
- **Controllers** use `AsyncValue` for loading/error/data states.
- **Views** use `ConsumerStatefulWidget` with `ref.watch()` in build, `ref.read()` in callbacks.
- One Controller per feature. Split only if the feature grows complex.
- Shared widgets go in `shared/widgets/`. Feature-specific widgets stay in the feature.

## Packages

| Package | Purpose |
|---------|---------|
| flutter_riverpod | State management |
| riverpod_annotation | Codegen annotations for providers |
| riverpod_generator | Provider code generation |
| dio | HTTP client |
| go_router | Routing |
| shared_preferences | Local storage |
| json_serializable | JSON parsing code generation |
| flutter_screenutil | Responsive sizing |

dart run build_runner build --delete-conflicting-outputs
