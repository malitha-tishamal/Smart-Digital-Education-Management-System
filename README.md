# 📱 Mobile Application

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Cloudinary](https://img.shields.io/badge/Cloudinary-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-Academic-blue?style=for-the-badge)

</div>

---

## 📖 Overview

This mobile application is developed using **Flutter**. The system serves as a secure and scalable authentication and profile management portal. It implements a **Role-Based Access Control (RBAC)** model to differentiate between **Admin** and **User** accounts.

Additionally, it integrates with **Cloudinary CDN** for remote media storage, ensuring efficient handling of profile images without overloading the primary database.

---

## 🎯 Key Objectives

- 🔐 Implement secure sign-up, sign-in, and password recovery using **Firebase Authentication**
- 👤 Enable detailed user profile management linked with **Firestore** and **Firebase Auth UID**
- 🧭 Implement role-based UI navigation (**Admin** vs **User** dashboards)
- ☁️ Integrate **Cloudinary API** for direct image upload using HTTP multipart requests
- 📧 Enforce email verification checks before allowing profile-related actions
- 🌍 Apply timezone localization (**Asia/Colombo, Sri Lanka**) for consistent timestamp handling

---

## ⚙️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter (Dart) |
| **Authentication** | Firebase Authentication |
| **Database** | Cloud Firestore |
| **Media Storage** | Cloudinary CDN |
| **HTTP Client** | HTTP Package |
| **Time Handling** | Timezone Package |
| **Image Picker** | Image Picker |

---

## 🚀 Features

- ✅ Secure Authentication System
- ✅ Role-Based Access Control (RBAC)
- ✅ Profile Management System
- ✅ Cloud Image Upload
- ✅ Email Verification Enforcement
- ✅ Real-time Firestore Data Sync
- ✅ Localized Time Handling (Sri Lanka)

---

## 🧠 System Overview

The application connects **Flutter frontend** with **Firebase backend** services for authentication and data storage.

User profile images are uploaded directly to **Cloudinary** using HTTP multipart requests, and only the returned secure URL is stored in Firestore.

User navigation is dynamically controlled based on the role assigned in Firestore (`admin` or `user`).
