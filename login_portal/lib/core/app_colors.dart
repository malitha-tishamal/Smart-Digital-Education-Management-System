import 'package:flutter/material.dart';

class AppColors {
  // ---------- Primary Blue Palette ----------
  static const Color primaryPurple = Color(0xFF1976D2);      // now blue (keep name for compatibility)
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryAccent = Color(0xFF82B1FF);

  // ---------- Backgrounds ----------
  static const Color lightBackground = Color(0xFFF0F7FF);    // light blue tint
  static const Color drawerBackground = Color(0xFFE3F2FD);   // soft blue

  // ---------- Text ----------
  static const Color darkestText = Color(0xFF1A1A2E);        // near black
  static const Color darkText = darkestText;                 // alias

  // ---------- Buttons ----------
  static const Color buttonGradientStart = Color(0xFF42A5F5);
  static const Color buttonGradientEnd = Color(0xFF0D47A1);

  // ---------- Input ----------
  static const Color inputBorder = Color(0xFF90CAF9);        // soft blue

  // ---------- Cards & Counting (adjusted to blue theme) ----------
  static const Color adminsCountColor = Color(0xFFE53935);    // keep red if needed
  static const Color pharmacistCountColor = Color(0xFFE53935);
  static const Color totalFoundColor = Color(0xFF1976D2);
  static const Color totalWardsColor = Color(0xFF1976D2);
  static const Color stockTypesColor = Color(0xFF1976D2);
  static const Color releasesCountColor = Color(0xFFE53935);
  static const Color returnsCountColor = Color(0xFF1976D2);

  // ---------- Card backgrounds ----------
  static const Color cardBg1 = Colors.white;
  static const Color cardBg2 = Color(0xFFE3F2FD);            // light blue
  static const Color cardBg3 = Color(0xFFBBDEFB);            // lighter blue
}