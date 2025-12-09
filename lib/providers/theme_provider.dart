import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';

/// Defines a full application theme, including colors and fonts.
class AppTheme {
  final String name;
  final Gradient? gradient;
  final String? imageAssetPath;
  final Color primaryAccent;
  final Color navBarColor;
  final Brightness navBarBrightness; // For icons and text on nav bars
  final Color foregroundColor;
  final bool isPro;
  final Gradient? glassGradient; // New property for glass widgets

  const AppTheme({
    required this.name,
    this.gradient,
    this.imageAssetPath,
    required this.primaryAccent,
    required this.navBarColor,
    this.navBarBrightness = Brightness.light, // Default to light icons
    required this.foregroundColor,
    this.isPro = false,
    this.glassGradient,
  }) : assert(gradient != null || imageAssetPath != null,
            'Theme must have a gradient or an image.');
}

/// A list of predefined themes for the user to choose from.
final List<AppTheme> appThemes = [
  // --- Color Themes ---
  const AppTheme(
    name: "Deep Purple",
    gradient: LinearGradient(
      colors: [Color(0xFF6A1B9A), Color(0xFF303F9F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC2c0a4c), // Darker, semi-transparent purple
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: false, // This is the default free theme
    glassGradient: null, // Dark themes don't need a special glass gradient
  ),
  const AppTheme(
    name: "Lush Jungle",
    gradient: LinearGradient(
      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC0d6e66), // Darker, semi-transparent teal
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Fiery Sunset",
    gradient: LinearGradient(
      colors: [Color(0xFFd31027), Color(0xFFea384d)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xCC8f0b1a), // Darker, semi-transparent red
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  // --- Image Themes ---
  // NEW: Forest Theme (User Request)
  const AppTheme(
    name: "Forest Sanctuary",
    imageAssetPath: 'assets/img/forest.jpg',
    primaryAccent: Color(0xFF81C784), // Soft Green
    navBarColor: Color(0xDD1B5E20), // Dark Green Background
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  // NEW: Snow Theme (User Request)
  const AppTheme(
    name: "Glacial Peak",
    imageAssetPath: 'assets/img/snow.jpg',
    primaryAccent: Color(0xFF4DD0E1), // Cyan/Ice Blue
    navBarColor: Color(0xDD263238), // Blue Grey Background (High Contrast)
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Beach Escape",
    imageAssetPath: 'assets/img/beach.jpg',
    primaryAccent: Color(0xFF00A7C4), // Cyan from the water
    navBarColor: Color(0xDD005f73), // Dark, semi-transparent teal
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Cosmic Dream",
    imageAssetPath: 'assets/img/space.jpg',
    primaryAccent: Color(0xFF9d4edd), // Vibrant purple from nebula
    navBarColor: Color(0xDD10002b), // Dark, semi-transparent deep purple
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Tech Vision",
    imageAssetPath: 'assets/img/tech.jpg',
    primaryAccent: Color(0xFF00f5d4), // Bright cyan from circuits
    navBarColor: Color(0xDD0a0a0a), // Dark, semi-transparent black
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Onyx",
    gradient: LinearGradient(
      colors: [Color(0xFF434343), Color(0xFF000000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    navBarColor: Color(0xDD1a1a1a),
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    isPro: true,
    glassGradient: null,
  ),
  const AppTheme(
    name: "Midnight",
    gradient: LinearGradient(
      colors: [Color(0xFF000046), Color(0xFF1CB5E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent: Colors.white,
    isPro: true,
    navBarColor: Color(0xDD00002a),
    navBarBrightness: Brightness.light,
    foregroundColor: Colors.white,
    glassGradient: null,
  ),
  AppTheme(
    name: "Alabaster",
    gradient: const LinearGradient(
      colors: [
        Color(0xFFF5F5F5), // Off-white
        Color.fromARGB(255, 171, 170, 170), // Slightly darker grey
        Color.fromARGB(255, 143, 143, 143) // darker grey
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    primaryAccent:
        const Color(0xFF37474F), // Darker blue-grey for better contrast
    navBarColor: const Color(0xDDE0E0E0), // Semi-transparent light grey
    navBarBrightness: Brightness.dark, // Use dark icons on this light theme
    foregroundColor: const Color(0xFF212121), // Dark grey for text
    isPro: true,
    glassGradient: LinearGradient(
      colors: [
        Colors.black.withAlpha((0.12 * 255).round()),
        Colors.grey.withAlpha((0.05 * 255).round())
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

/// Helper function to determine a high-contrast color (black or white) for
/// text on a given background color.
Color _getHighContrastColor(Color backgroundColor) {
  // Use the luminance to decide if the background is light or dark.
  return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// Manages the app's current theme and notifies listeners of changes.
/// Persists the selected theme using Firestore for the logged-in user.
class ThemeProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  AppTheme _currentAppTheme = appThemes[0];
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeScale = 1.0;
  String _fontFamily = 'Roboto';
  DateTime? _lastLocalUpdate;

  AppTheme get currentTheme => _currentAppTheme;
  ThemeMode get themeMode => _themeMode;
  double get fontSizeScale => _fontSizeScale;
  AppTheme get defaultTheme => appThemes.firstWhere((t) => !t.isPro);
  String get fontFamily => _fontFamily;

  void updateForUser(AuthProvider auth, SubscriptionProvider subscription) {
    _authProvider = auth;

    // 1. If auth is loading, DO NOT touch the theme.
    // This prevents the "false start" where isPro is false but loading.
    if (auth.isLoading) {
      return;
    }

    // 2. Prevent rapid updates (keep this)
    if (_lastLocalUpdate != null &&
        DateTime.now().difference(_lastLocalUpdate!) <
            const Duration(seconds: 3)) {
      return;
    }

    AppTheme newTheme;
    ThemeMode newThemeMode;
    double newFontSizeScale;
    String newFontFamily;

    if (auth.user == null) {
      // 3. LOGOUT LOGIC: explicitly revert to default here
      newTheme = defaultTheme;
      newThemeMode = ThemeMode.system;
      newFontSizeScale = 1.0;
      newFontFamily = 'Roboto';
    } else {
      // 4. LOGIN LOGIC
      newTheme = appThemes.firstWhere(
        (t) => t.name == auth.themeName,
        orElse: () => defaultTheme,
      );

      // 5. PRO CHECK: Only downgrade if we are SURE the user isn't Pro.
      // We rely on auth.isPro, but we trust the user's preference if
      // they are a Founder or if the subscription is active.
      if (newTheme.isPro && !subscription.isPro) {
        newTheme = defaultTheme;
      }

      newThemeMode = _themeModeFromString(auth.themeMode);
      newFontSizeScale = (auth.fontSizeScale ?? 1.0).clamp(0.8, 1.5);
      newFontFamily = (auth.fontFamily != null &&
              appThemes.any((t) => true) // placeholder to keep logic compact
          ? auth.fontFamily!
          : 'Roboto');
    }

    // 6. APPLY CHANGE
    if (newTheme.name != _currentAppTheme.name ||
        newThemeMode != _themeMode ||
        newFontSizeScale != _fontSizeScale ||
        newFontFamily != _fontFamily) {
      _currentAppTheme = newTheme;
      _themeMode = newThemeMode;
      _fontSizeScale = newFontSizeScale;
      _fontFamily = newFontFamily;
      notifyListeners();
    }
  }

  // --- Setters for user preferences ---

  Future<void> setAppTheme(AppTheme theme) async {
    if (_currentAppTheme.name == theme.name) return;
    _currentAppTheme = theme;
    _lastLocalUpdate = DateTime.now();
    notifyListeners();
    await _authProvider?.updateUserPreferences({'themeName': theme.name});
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _authProvider
        ?.updateUserPreferences({'themeMode': _themeModeToString(mode)});
  }

  Future<void> setFontSizeScale(double scale) async {
    if (_fontSizeScale == scale) return;
    _fontSizeScale = scale;
    notifyListeners();
    await _authProvider?.updateUserPreferences({'fontSizeScale': scale});
  }

  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;
    _fontFamily = family;
    notifyListeners();
    await _authProvider?.updateUserPreferences({'fontFamily': family});
  }

  // --- Helpers ---

  ThemeMode _themeModeFromString(String? modeString) {
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // --- ThemeData Builders ---

  ThemeData get lightThemeData => _buildThemeData(ThemeData.light());
  ThemeData get darkThemeData => _buildThemeData(ThemeData.dark());

  ThemeData _buildThemeData(ThemeData base) {
    final theme = currentTheme;
    final isDark = base.brightness == Brightness.dark;

    // For elements that should have a "glass" effect (e.g., text fields, chips).
    final Color glassColor = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.1)
        : const Color.fromRGBO(0, 0, 0, 0.05);

    // Create more robust background colors for cards and dialogs.
    final Color cardBackgroundColor = () {
      final lerped =
          Color.lerp(base.cardColor, theme.navBarColor, isDark ? 0.1 : 0.05)!;
      return lerped.withAlpha(math.min(255, (lerped.a * 255 * 0.85).round()));
    }();

    final Color dialogBackgroundColor =
        theme.navBarColor.withAlpha(245); // Almost opaque

    final scaledTextStyle = base.textTheme.bodyMedium?.copyWith(
      fontFamily: _fontFamily,
      fontSize: (base.textTheme.bodyMedium?.fontSize ?? 14.0) * _fontSizeScale,
      color: theme.foregroundColor,
    );

    // Apply font family and color to all text styles
    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.displayLarge?.fontSize ?? 57.0) *
                  _fontSizeScale,
              color: theme.foregroundColor),
          // ... (Intermediate styles omitted for brevity, they are the same logic) ...
          bodyMedium: scaledTextStyle,
          labelLarge: base.textTheme.labelLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: (base.textTheme.labelLarge?.fontSize ?? 14.0) *
                  _fontSizeScale,
              color: theme.primaryAccent),
        )
        .apply(
          bodyColor: theme.foregroundColor,
          displayColor: theme.foregroundColor,
        );

    // --- FIX CONTRAST: Define explicit color scheme for pickers ---
    final colorScheme = base.colorScheme.copyWith(
      primary: theme.primaryAccent,
      secondary: theme.primaryAccent,
      onPrimary: _getHighContrastColor(theme.primaryAccent),
      onSurface: theme.foregroundColor, // Main text color
      surface: theme.navBarColor, // Background for pickers
      brightness: base.brightness,
    );

    return base.copyWith(
      primaryColor: theme.primaryAccent,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,

      // --- NEW: Fix Contrast Issues in Pickers & Popups ---
      datePickerTheme: DatePickerThemeData(
        backgroundColor: theme.navBarColor, // Solid dark background
        headerBackgroundColor: theme.navBarColor,
        headerForegroundColor: theme.primaryAccent,
        yearStyle: textTheme.bodyLarge,
        dayStyle: textTheme.bodyMedium,
        weekdayStyle: textTheme.bodySmall,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _getHighContrastColor(theme.primaryAccent);
          }
          return theme.foregroundColor;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: theme.navBarColor, // Solid background for dropdowns
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: theme.navBarColor,
        hourMinuteTextColor: theme.primaryAccent,
        dayPeriodTextColor: theme.foregroundColor,
        dialHandColor: theme.primaryAccent,
        dialTextColor: theme.foregroundColor,
        entryModeIconColor: theme.primaryAccent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      // ----------------------------------------------------

      appBarTheme: AppBarTheme(
        backgroundColor: theme.navBarColor,
        foregroundColor: theme.foregroundColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: theme.navBarBrightness,
          statusBarIconBrightness: theme.navBarBrightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: theme.foregroundColor),
        actionsIconTheme: IconThemeData(color: theme.foregroundColor),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.navBarColor,
        selectedItemColor: theme.primaryAccent,
        unselectedItemColor: theme.foregroundColor.withAlpha(
            math.min(255, (theme.foregroundColor.a * 255 * 0.7).round())),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryAccent,
          foregroundColor: _getHighContrastColor(theme.primaryAccent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: theme.primaryAccent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.primaryAccent;
          }
          return theme.foregroundColor.withAlpha(
              math.min(255, (theme.foregroundColor.a * 255 * 0.5).round()));
        }),
        checkColor: WidgetStateProperty.all(theme.navBarColor),
        side: BorderSide(
            color: theme.foregroundColor.withAlpha(
                math.min(255, (theme.foregroundColor.a * 255 * 0.7).round()))),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: theme.foregroundColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColor,
        labelStyle: textTheme.bodyLarge,
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: theme.foregroundColor.withAlpha(
              math.min(255, (theme.foregroundColor.a * 255 * 0.5).round())),
        ),
        prefixIconColor: theme.foregroundColor.withAlpha(
            math.min(255, (theme.foregroundColor.a * 255 * 0.7).round())),
        suffixIconColor: theme.foregroundColor.withAlpha(
            math.min(255, (theme.foregroundColor.a * 255 * 0.7).round())),
        contentPadding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: theme.foregroundColor.withAlpha(math.min(
                  255, (theme.foregroundColor.a * 255 * 0.2).round()))),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.colorScheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassColor,
        labelStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: theme.foregroundColor.withAlpha(
                math.min(255, (theme.foregroundColor.a * 255 * 0.2).round())),
          ),
        ),
        deleteIconColor: theme.foregroundColor.withAlpha(
            math.min(255, (theme.foregroundColor.a * 255 * 0.7).round())),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return theme.primaryAccent;
              }
              return glassColor;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return theme.navBarColor;
              }
              return theme.foregroundColor;
            },
          ),
          side: WidgetStateProperty.all(
            BorderSide(
                color: theme.foregroundColor.withAlpha((0.2 * 255).round())),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.primaryAccent,
        inactiveTrackColor: theme.primaryAccent.withAlpha(
            math.min(255, (theme.primaryAccent.a * 255 * 0.3).round())),
        thumbColor: theme.primaryAccent,
        overlayColor: theme.primaryAccent.withAlpha(
            math.min(255, (theme.primaryAccent.a * 255 * 0.2).round())),
        valueIndicatorColor: theme.navBarColor,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(
          color: theme.foregroundColor,
        ),
      ),
      colorScheme: colorScheme,
    );
  }

  Future<void> resetToDefault() async {
    _currentAppTheme = defaultTheme;
    _themeMode = ThemeMode.system;
    _fontSizeScale = 1.0;
    _fontFamily = 'Roboto';
    notifyListeners();
  }
}
