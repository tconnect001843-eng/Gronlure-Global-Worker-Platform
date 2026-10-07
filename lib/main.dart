import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api_client.dart';
import 'src/platform_app.dart';

void main() {
  runApp(GronlureApp(api: PlatformApi()));
}

class GronlureApp extends StatefulWidget {
  const GronlureApp({required this.api, super.key});

  final PlatformApi api;

  @override
  State<GronlureApp> createState() => _GronlureAppState();
}

class _GronlureAppState extends State<GronlureApp> {
  static const _themePreferenceKey = 'gronlure_dark_theme';
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isDark = preferences.getBool(_themePreferenceKey) ?? false);
  }

  Future<void> _toggleTheme() async {
    final nextTheme = !_isDark;
    setState(() => _isDark = nextTheme);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_themePreferenceKey, nextTheme);
  }

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF155C45);
    const darkGreen = Color(0xFF84DDB0);
    final lightScheme = ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      surface: const Color(0xFFFFFFFF),
      brightness: Brightness.light,
    );
    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkGreen,
      onPrimary: Color(0xFF08291A),
      secondary: Color(0xFFABDDBE),
      onSecondary: Color(0xFF10251A),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: Color(0xFF151D18),
      onSurface: Color(0xFFE7F0E9),
      onSurfaceVariant: Color(0xFFBECBC1),
      outline: Color(0xFF84938A),
      outlineVariant: Color(0xFF48564D),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE7F0E9),
      onInverseSurface: Color(0xFF202820),
      inversePrimary: Color(0xFF155C45),
      surfaceTint: darkGreen,
      surfaceDim: Color(0xFF101713),
      surfaceBright: Color(0xFF313B34),
      surfaceContainerLowest: Color(0xFF101713),
      surfaceContainerLow: Color(0xFF1B241E),
      surfaceContainer: Color(0xFF202A23),
      surfaceContainerHigh: Color(0xFF29342D),
      surfaceContainerHighest: Color(0xFF344139),
    );

    ThemeData buildTheme(ColorScheme scheme, {required bool dark}) {
      final border = scheme.outlineVariant;
      return ThemeData(
        useMaterial3: true,
        brightness: scheme.brightness,
        colorScheme: scheme,
        scaffoldBackgroundColor: dark
            ? const Color(0xFF101713)
            : const Color(0xFFF5F7F5),
        appBarTheme: AppBarTheme(
          backgroundColor: dark
              ? const Color(0xFF151D18)
              : const Color(0xFFF5F7F5),
          foregroundColor: scheme.onSurface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? const Color(0xFF202A23) : const Color(0xFFF7F9F8),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          prefixIconColor: scheme.onSurfaceVariant,
          suffixIconColor: scheme.onSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.error, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        cardTheme: CardThemeData(
          color: dark ? const Color(0xFF1B241E) : Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: dark
              ? const Color(0xFF202A23)
              : const Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: TextStyle(color: scheme.onSurface),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: dark
              ? const Color(0xFF151D18)
              : const Color(0xFFFFFFFF),
          indicatorColor: dark
              ? const Color(0xFF294233)
              : const Color(0xFFEAF5EF),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: dark
              ? const Color(0xFF29342D)
              : const Color(0xFFEAF5EF),
          side: BorderSide(color: border),
          labelStyle: TextStyle(color: scheme.onSurface),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: dark
              ? const Color(0xFF344139)
              : const Color(0xFF26352C),
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
      );
    }

    return MaterialApp(
      title: 'Gronlure Global Worker Platform',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lightScheme, dark: false),
      darkTheme: buildTheme(darkScheme, dark: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: PlatformShell(
        api: widget.api,
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
