// lib/core/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Gray scale (light → dark)
  static const Color gray50 = Color(0xFFF9FAFB); // pages bg
  static const Color gray100 = Color(0xFFF3F4F6); // cards bg
  static const Color gray200 = Color(0xFFE5E7EB); // borders, dividers
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280); // secondary text
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151); // body text
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827); // headings

  // Primary accent
  static const Color yellow = Color(0xFFF7C948); // main highlight

  // Semantic accents
  static const Color blue = Color(0xFF3B82F6); // info / progress
  static const Color green = Color(0xFF22C55E); // success / pending

  // Status backgrounds
  static const Color bgInfo = Color(0xFFDBEAFE); // completed card
  static const Color bgSuccess = Color(0xFFDCFCE7); // pending card
  static const Color bgWarning = Color(0xFFFEF3C7); // (if you need a warning)
  static const Color bgCancel = Color(0xFFF3F4F6); // canceled card

  // Optional semantic helpers
  static const Color error = Color(0xFFEF4444);
  static const Color link = blue;


    // Backgrounds
  static const Color scaffoldBg = Color(0xFFF3F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text
  static const Color primary = Color(0xFF1F2937); // dark slate
  static const Color textPrimary = Color(0xFF1F2937); // dark slate
  static const Color textSecondary = Color(0xFF6B7280); // medium grey

  // Progress bars
  static const Color progressBlue = Color(0xFF243B6B);
  static const Color progressYellow = Color(0xFFFBBF24);
  static const Color progressTrack = Color(0xFFE5E7EB);

  // Shadows
  static const Color shadow = Colors.black12;


}
