# Flutter LMS Mobile App

A **UI-focused Learning Management System (LMS**) mobile application built using Flutter fundamentals. 
This project demonstrates clean architecture, navigation patterns, reusable widgets, and local state management(no backend/API integration yet).

## Overview

This app demonstrates a simple LMS-style mobile UI with:

- A multi-screen starter flow (splash/onboarding/login)
- Named-route navigation and a bottom navigation layout
- Reusable UI components (cards, buttons, app bars)
- Dummy in-memory data models for courses and assignments

## Highlights

- **Splash → Onboarding → Login** starter flow
- **Home** with bottom navigation tabs: Dashboard, Courses, Assignments, Profile
- **Courses** list → course details → lesson screen
- **Assignments** list with simple status badges
- **Profile** view + edit (local state only)
- **Theme + typography**: Inter font applied globally

## App Flow & Navigation

The app uses `MaterialApp` with named routes.

**Initial route:** `/` (Splash)

**Named routes:**

- `/` → Splash
- `/onboarding` → Onboarding
- `/login` → Login
- `/home` → Home (bottom navigation)
- `/courses` → Courses list
- `/course_detail` → Course details (expects a `Course` argument)
- `/lesson` → Lesson (expects a map: `{ course, lessonIndex }`)

Inside Home, the bottom navigation switches between:

- Dashboard (progress cards + “Continue Learning”)
- Courses
- Assignments
- Profile

## Project Structure

Common entry points and modules:

- `lib/main.dart` – app bootstrap
- `lib/app_routes.dart` – route constants + route table
- `lib/theme.dart` – app theme (Inter font, app bar styles, etc.)

UI structure (conventions):

- `lib/screens/` – full pages (Scaffolds + navigation): splash, onboarding, login, home, courses, course detail, lesson, assignments, profile
- `lib/widgets/` – reusable UI components used across pages (cards, app bar, primary button)
- `lib/ui/` – UI primitives/helpers (responsive spacing, layout helpers, theme extensions)

Data (dummy/local):

- `lib/models/course.dart` – `Course` model + `dummyCourses`
- `lib/models/assignment.dart` – `Assignment` model + `dummyAssignments`

Assets:

- `assets/images/` – logos + onboarding images
- `assets/fonts/` – Inter font files

## Tech Stack

- Flutter (Material)
- Dart SDK: `^3.11.0`
- Lint rules: `flutter_lints`

## Getting Started

### Prerequisites

- Flutter SDK installed and on PATH
- A configured device/emulator (Android/iOS) or Chrome (web)

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

Run on a specific platform:

```bash
flutter run -d chrome
```

### Test

```bash
flutter test
```

### Lint / Analyze

```bash
flutter analyze
```

## Notes / Limitations

- UI-only demo (no backend/auth/API persistence)
- Login is simulated (local validation + a short delay)
- Courses/lessons/assignments come from dummy in-memory lists
- Responsive layout uses MediaQuery-based padding/sizing and centered max-width layouts for larger screens (tablets/web)
- Very small screens and extreme landscape sizes may still need additional fine-tuning

## State Management

Simple UI state is handled using `setState`:

- Lesson completion toggle
- Bottom navigation tab switching
- Profile edit mode
- Simulated login loading state

## Screens Included

- Splash
- Onboarding (PageView)
- Login (form validation)
- Home (bottom navigation + dashboard)
- Courses list
- Course detail (lesson list)
- Lesson (placeholder content + mark complete toggle)
- Assignments list
- Profile (edit name/bio locally)

## Future Improvements

- Backend integration (Firebase / REST API)
- Persistent storage for lesson progress
- Authentication with secure login
- Advanced state management (Provider / Bloc)
- Unit & widget test coverage

## License

This project is licensed under the **MIT License**.

See [LICENSE](LICENSE) for details.
