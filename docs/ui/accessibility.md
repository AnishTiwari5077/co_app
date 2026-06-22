# SahakariMS — UI: Accessibility

## Overview

SahakariMS is committed to accessibility for all users, including those with visual impairments, motor difficulties, and varying tech literacy. We follow **WCAG 2.1 Level AA** standards and Flutter accessibility best practices.

---

## Accessibility Principles

1. **Perceivable** — All information must be available to all senses
2. **Operable** — All functionality usable via keyboard or assistive tech
3. **Understandable** — Content and operations must be comprehensible
4. **Robust** — Works with current and future assistive technologies

---

## Color & Contrast

All text meets WCAG 2.1 contrast requirements:

| Element | Color Pair | Ratio | Requirement |
|---------|-----------|-------|-------------|
| Body text | `#1A1A2E` on `#FFFFFF` | 18.9:1 | ✅ AA (≥4.5:1) |
| Secondary text | `#6B7280` on `#FFFFFF` | 5.3:1 | ✅ AA |
| Button text | `#FFFFFF` on `#1A3A6B` | 12.1:1 | ✅ AAA |
| Credit amount | `#2E7D32` on `#FFFFFF` | 6.1:1 | ✅ AA |
| Debit amount | `#C62828` on `#FFFFFF` | 7.2:1 | ✅ AA |
| Error text | `#C62828` on `#F5F7FA` | 5.8:1 | ✅ AA |

**Never rely on color alone** — Errors also show an icon and text. Credits/debits also show `+`/`-` prefix.

---

## Semantics in Flutter

```dart
// Always provide semantic labels for interactive elements
Semantics(
  label: 'Approve loan application LN-2081-089 for Ram Shrestha',
  button: true,
  child: ElevatedButton(
    onPressed: _approveLoan,
    child: const Text('Approve'),
  ),
)

// Amount display with readable semantics
Semantics(
  label: 'Total balance: 45,238 Nepali rupees',
  child: AmountDisplay(amount: 45238.0),
)

// Status badge
Semantics(
  label: 'Loan status: Active',
  child: StatusBadge(status: 'Active'),
)

// Icon-only buttons MUST have labels
IconButton(
  icon: const Icon(Icons.download),
  tooltip: 'Download statement',  // tooltip = semantic label
  onPressed: _downloadStatement,
)
```

---

## Touch Targets

All interactive elements meet the 48×48dp minimum:

```dart
// Custom touch target enforcement
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
```

---

## Form Accessibility

```dart
// Every input has a visible label (not just placeholder)
TextFormField(
  decoration: InputDecoration(
    labelText: 'Phone Number *',           // Always visible label
    hintText: '98XXXXXXXX',               // Example format in hint
    helperText: 'Nepal mobile number format',
    errorText: _phoneError,               // Visible error message
    prefixIcon: const Icon(Icons.phone),
  ),
  keyboardType: TextInputType.phone,
  textInputAction: TextInputAction.next,   // Logical form flow
  onChanged: _validatePhone,
)

// Error messages are descriptive, not just "Invalid"
String? _validatePhone(String? value) {
  if (value == null || value.isEmpty)
    return 'Phone number is required';
  if (!RegExp(r'^9[6-9]\d{8}$').hasMatch(value))
    return 'Enter a valid 10-digit Nepal mobile number (e.g., 9841234567)';
  return null;
}
```

---

## Screen Reader Support

```dart
// Loading states are announced
AsyncValue.loading() → Semantics(
  label: 'Loading member data, please wait',
  liveRegion: true,  // Announces to screen reader
  child: CircularProgressIndicator(),
)

// Alerts are live regions (announced immediately)
Semantics(
  liveRegion: true,
  child: Text('Transaction successful! Receipt: RCP-KTM-2081-04567'),
)

// Focus management after navigation
// Move focus to page title after route change
WidgetsBinding.instance.addPostFrameCallback((_) {
  FocusScope.of(context).requestFocus(_pageTitleFocusNode);
});
```

---

## Keyboard Navigation (Windows Desktop)

The admin app runs on Windows and must support full keyboard navigation:

| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Move between focusable elements |
| `Enter` / `Space` | Activate button or select item |
| `Arrow keys` | Navigate lists, tables, dropdowns |
| `Escape` | Close dialog or modal |
| `Ctrl+S` | Save current form |
| `Ctrl+P` | Print receipt |
| `Ctrl+N` | New transaction/member |
| `Alt+D` | Go to dashboard |

```dart
// Keyboard shortcut handling
@override
Widget build(BuildContext context) {
  return Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
          const SaveIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP):
          const PrintIntent(),
    },
    child: Actions(
      actions: {
        SaveIntent: CallbackAction<SaveIntent>(
          onInvoke: (_) => _saveForm(),
        ),
        PrintIntent: CallbackAction<PrintIntent>(
          onInvoke: (_) => _printReceipt(),
        ),
      },
      child: Focus(
        autofocus: true,
        child: _buildContent(),
      ),
    ),
  );
}
```

---

## Text Scaling

```dart
// Respect user's text size preference
// Never use hardcoded text sizes in widgets — always use theme
Text(
  'NPR 45,238.00',
  style: Theme.of(context).textTheme.headlineMedium,  // ✅ Scales with user prefs
)

// Test at 200% text scale to ensure no overflow
// In debug mode: MediaQuery.textScaleFactorOf(context)
```

---

## Accessibility Testing Checklist

- [ ] All images have alt text (semantic labels)
- [ ] All icon buttons have tooltips
- [ ] All form inputs have visible labels
- [ ] Error messages are descriptive
- [ ] Color is not the sole indicator of status
- [ ] All touch targets ≥ 48×48dp
- [ ] Screen reader test (TalkBack on Android, Narrator on Windows)
- [ ] Keyboard-only navigation test (Windows)
- [ ] 200% text scale — no overflow
- [ ] Contrast ratio ≥ 4.5:1 for all text
- [ ] Focus order is logical
- [ ] Loading states announced to screen readers
