import 'package:flutter/material.dart';

// ─── Brand Palette ────────────────────────────────────────────────────────────
// Inspired by Nepal cooperative identity: deep blue + forest teal + warm amber

class AppColors {
  AppColors._();

  // ── Primary: Cooperative Blue ────────────────────────────────────────────
  static const primary          = Color(0xFF1B5E9B);
  static const primaryDark      = Color(0xFF0D3C6B);
  static const primaryLight     = Color(0xFF4E9FE0);
  static const primaryContainer = Color(0xFFD6E8FF);
  static const onPrimary        = Colors.white;
  static const onPrimaryContainer = Color(0xFF001D36);

  // ── Secondary: Nepal Teal ────────────────────────────────────────────────
  static const secondary          = Color(0xFF0D7C5C);
  static const secondaryDark      = Color(0xFF005C3E);
  static const secondaryLight     = Color(0xFF45D8A4);
  static const secondaryContainer = Color(0xFFB7F0DC);
  static const onSecondary        = Colors.white;
  static const onSecondaryContainer = Color(0xFF002117);

  // ── Accent: Warm Amber ───────────────────────────────────────────────────
  static const accent     = Color(0xFFE67E22);
  static const accentDark = Color(0xFFC0392B);

  // ── Semantic Status ──────────────────────────────────────────────────────
  static const success     = Color(0xFF2E7D32);
  static const successLight = Color(0xFFC8E6C9);
  static const warning     = Color(0xFFF57C00);
  static const warningLight = Color(0xFFFFE0B2);
  static const error       = Color(0xFFC62828);
  static const errorLight  = Color(0xFFFFCDD2);
  static const info        = Color(0xFF0277BD);
  static const infoLight   = Color(0xFFB3E5FC);

  // ── Light Surface ────────────────────────────────────────────────────────
  static const background    = Color(0xFFF4F6FA);
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F8);
  static const outline       = Color(0xFFDDE3EC);
  static const outlineVariant = Color(0xFFEEF1F6);

  // ── Dark Surface ────────────────────────────────────────────────────────
  static const darkBackground    = Color(0xFF0E1621);
  static const darkSurface       = Color(0xFF162032);
  static const darkSurfaceVariant = Color(0xFF1C2A3D);
  static const darkOutline       = Color(0xFF2A3A50);

  // ── Text ────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0D1B2A);
  static const textSecondary = Color(0xFF5A6A7E);
  static const textDisabled  = Color(0xFFADB5C3);
  static const textInverse   = Color(0xFFFFFFFF);

  // ── Dark Text ────────────────────────────────────────────────────────────
  static const darkTextPrimary   = Color(0xFFE4ECF7);
  static const darkTextSecondary = Color(0xFF8BA4C1);
  static const darkTextDisabled  = Color(0xFF445568);

  // ── Financial ────────────────────────────────────────────────────────────
  static const creditAmount  = Color(0xFF1B7F50);
  static const debitAmount   = Color(0xFFC0392B);
  static const npaRed        = Color(0xFFE53935);
  static const interestGold  = Color(0xFFD4AC0D);

  // ── Member Status ─────────────────────────────────────────────────────────
  static const statusActive    = Color(0xFF2E7D32);
  static const statusPending   = Color(0xFFF57C00);
  static const statusSuspended = Color(0xFFC62828);
  static const statusClosed    = Color(0xFF5A6A7E);
  static const statusRejected  = Color(0xFF880E4F);

  // ── Loan Status ───────────────────────────────────────────────────────────
  static const loanActive   = Color(0xFF1565C0);
  static const loanOverdue  = Color(0xFFE65100);
  static const loanNpa      = Color(0xFFC62828);
  static const loanClosed   = Color(0xFF2E7D32);
  static const loanApproved = Color(0xFF00695C);

  // ── Gradient Presets ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashboardGradient = LinearGradient(
    colors: [Color(0xFF1B5E9B), Color(0xFF0D3C6B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradientBlue = LinearGradient(
    colors: [Color(0xFF1B5E9B), Color(0xFF4E9FE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientTeal = LinearGradient(
    colors: [Color(0xFF0D7C5C), Color(0xFF45D8A4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientAmber = LinearGradient(
    colors: [Color(0xFFE67E22), Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradientPurple = LinearGradient(
    colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
