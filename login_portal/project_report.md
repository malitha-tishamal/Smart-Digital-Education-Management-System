# Eduwide App — Full Project Report

**Platform**
Flutter (Multi-Platform)

**Backend**
Firebase (Firestore + Auth)

**Version**
1.0.0+1

**Developer**
Malitha Tishamal

**Institution**
HNDIT

**SDK**
Dart >=3.9.0 <4.0.0
Android, iOS, Web, Windows, Linux, macOS

**Date**
July 2026

## 1. Project Overview
Eduwide is a cross-platform mobile/desktop application built with Flutter, designed as a comprehensive Login Portal and Educational Management System for HNDIT 4232. The app streamlines user management, providing role-based access control for Admins, Teachers, and Students. It handles user authentication, profile data management, and role-specific dashboards to facilitate educational resources and account management.

**Key Goals**
* Provide secure user authentication using Firebase Auth.
* Enable role-based access for Administrators, Teachers, and Students.
* Manage user profile data including NIC, Stream, Subjects, and A/L Year.
* Provide an administrative dashboard to manage user accounts and resources.
* Ensure a smooth startup flow with timezone support and robust Firebase initialization.

## 2. Technology Stack & Dependencies
| Category | Package | Version | Purpose |
| :--- | :--- | :--- | :--- |
| UI Framework | `flutter` | SDK | Core UI |
| Database | `cloud_firestore` | ^6.0.0 | NoSQL real-time database |
| Authentication | `firebase_auth` | ^6.0.0 | User login/session |
| Core Firebase | `firebase_core` | ^4.0.0 | Firebase initialization |
| Timezone | `timezone` | ^0.10.1 | Asia/Colombo timezone support |
| Image Picker | `image_picker` | ^1.2.0 | Profile photo upload |
| Date Formatting | `intl` | ^0.20.2 | Date/time display |
| HTTP | `http` | ^1.5.0 | Network requests |
| Icons | `cupertino_icons` | ^1.0.8 | iOS style icons |
| Launcher Icons | `flutter_launcher_icons`| ^0.14.4 | App icon generation |

## 3. App Architecture
```text
eduwide/lib/
├── main.dart                     ← App entry point, timezone setup, Firebase init
├── auth_service.dart             ← Firebase Auth & Firestore user logic
├── core/
│   ├── firebase_options.dart     ← Auto-generated Firebase config
│   ├── app_colors.dart           ← Global color palette
│   └── dashboard_wrapper.dart    ← Role-based routing (Admin/Teacher/Student)
├── auth/
│   ├── firebase_load_check_screen.dart
│   ├── simple_preload_screen.dart
│   ├── start_page.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   └── forgot_password_screen.dart
├── models/
│   └── user_model.dart           ← AppUser data model
└── screens/
    ├── admin/
    │   └── admin_dashboard.dart
    ├── teacher/
    │   └── teacher_dashboard.dart
    ├── student/
    │   └── user_dashboard.dart
    ├── class_detail_screen.dart
    ├── user_accounts_manage.dart
    └── user_resource_view.dart
```

## 4. Firebase Firestore Data Collections
| Collection | Purpose | Key Fields |
| :--- | :--- | :--- |
| `users` | All app accounts | `uid`, `email`, `name`, `nic`, `mobile`, `role`, `stream`, `subjects[]`, `status`, `alYear`, `studentId` |

## 5. Global Design System (AppColors)
Defined in `core/app_colors.dart`. Provides the foundation for the visual aesthetics.
* **Primary Colors**: Integrates a primary palette for buttons, active states, and icons.
* **Backgrounds**: Uses `AppColors.lightBackground` for the default `Scaffold` background, ensuring a clean and modern look.

## 6. Authentication Module (lib/auth/)
### 6.1 App Startup Flow
```text
MyApp (MaterialApp)
  └── AuthWrapper (StreamBuilder on FirebaseAuth.authStateChanges)
        ├── Loading: FirebaseLoadCheckScreen
        ├── Logged In: SimplePreloadScreen → DashboardWrapper
        └── Not Logged In: StartPage (Login/Signup)
```
### 6.2 Login Page (`login_screen.dart`)
Allows users to authenticate using email and password via `FirebaseAuth`. Includes error handling and navigation to "Forgot Password" or "Sign Up" screens.

### 6.3 Sign Up Page (`signup_screen.dart`)
Registration form that captures extensive user details: Name, Email, Password, NIC, Mobile, Role, Stream, Subjects, A/L Year, and Student ID.
Data is saved to Firestore under the `users` collection with a default `status` of `pending`.

### 6.4 Forgot Password Page (`forgot_password_screen.dart`)
Allows users to send a Firebase password-reset link to their email via `AuthService.sendPasswordResetEmail()`.

## 7. Core Module (lib/core/)
### 7.1 Dashboard Wrapper (`dashboard_wrapper.dart`)
The central routing component post-login. Reads the user's document from Firestore to determine their `role` and routes them appropriately:
* `admin` → `AdminDashboard`
* `teacher` → `TeacherDashboard`
* `student` / `user` → `StudentDashboard`

Handles missing user documents gracefully and forces sign-out if the record is missing.

## 8. Screen Modules (lib/screens/)
### 8.1 Admin Module
Provides tools for managing the educational platform. Includes account management screens (`user_accounts_manage.dart`) and administrative dashboards.
### 8.2 Teacher Module
Dedicated dashboard for teachers to manage classes and resources (`class_detail_screen.dart`, `user_resource_view.dart`).
### 8.3 Student Module
Dedicated dashboard for students to view their educational progress and resources.

## 9. Security & Access Control
| Feature | Implementation |
| :--- | :--- |
| Role-based routing | `DashboardWrapper` reads Firestore `role` field to route users dynamically. |
| Account Status | Users are created with a `pending` status which can be managed by admins. |
| Session management | `FirebaseAuth.authStateChanges()` stream handles session persistence across app restarts. |

## 10. Platform Support
| Platform | Status |
| :--- | :--- |
| Android | ✅ Primary target |
| iOS | ✅ Supported |
| Web | ✅ Supported (via firebase_options.dart) |
| Windows | ✅ Supported |
| Linux | ✅ Supported |
| macOS | ✅ Supported |

Report generated: July 2026 | Eduwide App v1.0.0+1 | Developed by Malitha Tishamal | HNDIT 4232
