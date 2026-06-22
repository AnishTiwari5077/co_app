# SahakariMS — UI/UX Guidelines

## Design Philosophy

SahakariMS follows **Material Design 3** with Nepal-specific adaptations. The interface prioritises:

1. **Clarity** — Financial data must be instantly readable
2. **Trust** — Professional appearance instills confidence
3. **Efficiency** — Cashiers process many transactions per hour
4. **Accessibility** — Works for users with varying tech literacy
5. **Bilingual** — Seamless Nepali/English switching

---

## Color Palette

### Primary Colors

```dart
// lib/core/theme/app_colors.dart

class AppColors {
  // Primary — Deep cooperative blue
  static const Color primary         = Color(0xFF1A3A6B);  // Dark navy
  static const Color primaryLight    = Color(0xFF2D5F9E);  // Medium blue
  static const Color primaryDark     = Color(0xFF0F2240);  // Deep navy
  static const Color onPrimary       = Color(0xFFFFFFFF);

  // Secondary — Trust green
  static const Color secondary       = Color(0xFF2E7D32);  // Forest green
  static const Color secondaryLight  = Color(0xFF4CAF50);  // Medium green
  static const Color onSecondary     = Color(0xFFFFFFFF);

  // Accent — Warm gold (Nepal flag inspired)
  static const Color accent          = Color(0xFFC8960C);  // Deep gold
  static const Color accentLight     = Color(0xFFFFD54F);  // Light gold

  // Semantic colors
  static const Color success         = Color(0xFF2E7D32);
  static const Color warning         = Color(0xFFF57C00);
  static const Color error           = Color(0xFFC62828);
  static const Color info            = Color(0xFF1565C0);

  // Background
  static const Color background      = Color(0xFFF5F7FA);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceVariant  = Color(0xFFEEF2F7);

  // Text
  static const Color textPrimary     = Color(0xFF1A1A2E);
  static const Color textSecondary   = Color(0xFF6B7280);
  static const Color textDisabled    = Color(0xFFB5BEC9);

  // Financial specific
  static const Color creditAmount    = Color(0xFF2E7D32);  // Green for deposits
  static const Color debitAmount     = Color(0xFFC62828);  // Red for withdrawals
  static const Color pendingStatus   = Color(0xFFF57C00);
  static const Color activeStatus    = Color(0xFF2E7D32);
  static const Color closedStatus    = Color(0xFF9E9E9E);
  static const Color npaStatus       = Color(0xFFC62828);
}
```

### Dark Mode Palette

```dart
class AppColorsDark {
  static const Color primary         = Color(0xFF5C95D6);
  static const Color primaryLight    = Color(0xFF7EB3E8);
  static const Color background      = Color(0xFF1A1A2E);
  static const Color surface         = Color(0xFF242444);
  static const Color surfaceVariant  = Color(0xFF2D2D50);
  static const Color textPrimary     = Color(0xFFE8EAF6);
  static const Color textSecondary   = Color(0xFFB0BEC5);
}
```

---

## Typography

```dart
// pubspec.yaml dependencies
// google_fonts: ^6.1.0

class AppTextStyles {
  // Display — Dashboard totals, large amounts
  static final TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 57, fontWeight: FontWeight.w700,
    letterSpacing: -0.25, color: AppColors.textPrimary,
  );

  // Headlines — Page titles, section headers
  static final TextStyle headlineLarge = GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static final TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static final TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  // Title — Card titles, list headers
  static final TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static final TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static final TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );

  // Body — Content text
  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );

  // Labels — Badges, chips, buttons
  static final TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1,
  );
  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5,
  );

  // Amount display — NPR amounts (monospace for alignment)
  static final TextStyle amountLarge = GoogleFonts.robotoMono(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static final TextStyle amountMedium = GoogleFonts.robotoMono(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static final TextStyle amountSmall = GoogleFonts.robotoMono(
    fontSize: 14, fontWeight: FontWeight.w500,
  );

  // Nepali text — Devanagari script
  static final TextStyle nepaliBody = GoogleFonts.notoSansDevanagari(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
}
```

---

## Spacing and Dimensions

```dart
class AppDimensions {
  // Spacing scale (4px base)
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  // Border radius
  static const double radiusSm  = 4.0;
  static const double radiusMd  = 8.0;
  static const double radiusLg  = 12.0;
  static const double radiusXl  = 16.0;
  static const double radiusRound = 100.0;

  // Card elevation
  static const double elevationSm  = 1.0;
  static const double elevationMd  = 4.0;
  static const double elevationLg  = 8.0;

  // Icon sizes
  static const double iconSm  = 16.0;
  static const double iconMd  = 24.0;
  static const double iconLg  = 32.0;
  static const double iconXl  = 48.0;

  // Button height
  static const double buttonHeight = 48.0;
  static const double buttonHeightSm = 36.0;

  // Input field height
  static const double inputHeight = 56.0;

  // App bar height
  static const double appBarHeight = 64.0;

  // Bottom nav height
  static const double bottomNavHeight = 72.0;
}
```

---

## Component Library

### AppButton

```dart
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.variant = ButtonVariant.filled,
    this.size = ButtonSize.medium,
  });

  // Usage examples:
  // AppButton(label: 'Approve Loan', onPressed: _approve, icon: Icons.check)
  // AppButton(label: 'Reject', onPressed: _reject, isDestructive: true, variant: ButtonVariant.outlined)
  // AppButton(label: 'Processing...', onPressed: null, isLoading: true)
}
```

### AmountDisplay

```dart
// Always format NPR amounts consistently
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    required this.amount,
    this.isCredit,  // null = neutral, true = green, false = red
    this.size = AmountSize.medium,
    this.showCurrency = true,
  });

  // Usage: AmountDisplay(amount: 50000, isCredit: true)
  // Renders: NPR 50,000.00 in green
}
```

### StatusBadge

```dart
// Consistent status badges across the app
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status});

  // Maps status strings to colors automatically:
  // 'Active'   → Green
  // 'Pending'  → Orange
  // 'Inactive' → Grey
  // 'NPA'      → Red
  // 'Closed'   → Grey
}
```

---

## Screen Layouts

### Admin Desktop (Windows)

```
┌────────────────────────────────────────────────────────┐
│  Sidebar Nav    │           Content Area               │
│  (240px fixed)  │                                      │
│                 │  ┌─────────────────────────────────┐ │
│  🏦 Dashboard   │  │  Page Header + Breadcrumb       │ │
│  👥 Members     │  ├─────────────────────────────────┤ │
│  💰 Savings     │  │                                 │ │
│  🏦 Loans       │  │  Page Content                   │ │
│  📊 Accounting  │  │                                 │ │
│  🏧 Cash        │  │                                 │ │
│  📋 Reports     │  │                                 │ │
│  ⚙️  Settings   │  └─────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

### Mobile Banking App

```
┌─────────────────┐
│  Top App Bar    │  ← Balance summary, notifications bell
├─────────────────┤
│                 │
│  Content Area   │  ← Scrollable content
│                 │
│                 │
│                 │
├─────────────────┤
│  Bottom Nav Bar │  ← Home | Accounts | Loans | More
└─────────────────┘

Bottom Nav items:
  🏠 Home (Dashboard)
  💳 Accounts (Savings/FD)
  🏦 Loans
  ☰  More (Payments, Profile, Settings)
```

---

## Accessibility Standards

- Minimum touch target: **48×48dp**
- Color contrast ratio: **≥ 4.5:1** for normal text, **≥ 3:1** for large text
- All inputs have semantic labels
- Error messages are descriptive, not just "invalid"
- Amounts displayed with sufficient size (minimum 14px)
- Screen reader support via `Semantics` widget
- Keyboard navigation for Windows desktop version

---

## Localization

```dart
// lib/core/utils/locale_provider.dart

// Supported locales
const supportedLocales = [
  Locale('en', 'US'),  // English (default)
  Locale('ne', 'NP'),  // Nepali
];

// Amount formatting
String formatNPR(double amount, {bool showSymbol = true}) {
  final formatted = NumberFormat('#,##,##0.00', 'en_IN').format(amount);
  return showSymbol ? 'NPR $formatted' : formatted;
}

// Nepali month names
const nepaliMonths = [
  'बैशाख', 'जेठ', 'असार', 'श्रावण', 'भाद्र', 'आश्विन',
  'कार्तिक', 'मंसिर', 'पुष', 'माघ', 'फाल्गुन', 'चैत्र'
];
```

---

## Form Design Standards

- One column layout on mobile, two columns on tablet/desktop
- Input labels are always visible (not placeholder-only)
- Validation on blur, not on every keystroke
- Real-time formatting for phone numbers (98XXXXXXXX)
- Auto-format amounts with thousand separators
- Citizenship number format hint: `XX-XX-XX-XXXXX`
- Required fields marked with `*`
- Save/Submit button always at the bottom, full-width on mobile
- Unsaved changes alert when navigating away
