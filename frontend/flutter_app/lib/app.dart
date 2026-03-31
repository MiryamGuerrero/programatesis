import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "core/state/app_providers.dart";
import "features/auth/login_page.dart";
import "shared/models/app_role.dart";
import "shared/widgets/role_shell.dart";

class ReumaNutriApp extends ConsumerWidget {
  const ReumaNutriApp({super.key});

  static const Color _mintStrong = Color(0xFF4CAF50);
  static const Color _mintSoft = Color(0xFF81C784);
  static const Color _coral = Color(0xFFFF7043);
  static const Color _turquoise = Color(0xFF4DD0E1);
  static const Color _backgroundCream = Color(0xFFFFFDF7);
  static const Color _slateText = Color(0xFF37474F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);
    final roleAsync = ref.watch(appRoleProvider);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _mintStrong,
      brightness: Brightness.light,
    ).copyWith(
      primary: _mintStrong,
      secondary: _turquoise,
      tertiary: _coral,
      error: const Color(0xFFB4452D),
      surface: const Color(0xFFFFFCF6),
      onSurface: _slateText,
      outline: const Color(0xFFB4C5BE),
    );

    return MaterialApp(
      title: "Reuma Nutri",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _backgroundCream,
        textTheme: GoogleFonts.nunitoSansTextTheme().apply(
          bodyColor: _slateText,
          displayColor: _slateText,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _slateText,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.nunitoSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _slateText,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: _slateText.withValues(alpha: 0.74)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _mintSoft.withValues(alpha: 0.36)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _mintSoft.withValues(alpha: 0.44)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: _mintStrong, width: 1.8),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFB4452D), width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFB4452D), width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _mintStrong,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _slateText,
            side: BorderSide(color: _mintSoft.withValues(alpha: 0.6)),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _mintSoft.withValues(alpha: 0.24)),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: _mintSoft.withValues(alpha: 0.24),
          thickness: 1,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: _mintStrong,
          titleTextStyle: const TextStyle(
            color: _slateText,
            fontWeight: FontWeight.w700,
          ),
          subtitleTextStyle: TextStyle(
            color: _slateText.withValues(alpha: 0.76),
            fontWeight: FontWeight.w600,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: _mintSoft.withValues(alpha: 0.3),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          selectedIconTheme: const IconThemeData(color: _mintStrong),
          unselectedIconTheme:
              IconThemeData(color: _slateText.withValues(alpha: 0.72)),
          selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelTextStyle:
              const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: _mintSoft.withValues(alpha: 0.28),
        ),
      ),
      home: authSession.when(
        data: (session) {
          if (session == null) {
            return const LoginPage();
          }

          return roleAsync.when(
            data: (role) => RoleShell(role: role),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const RoleShell(role: AppRole.tutor),
          );
        },
        error: (error, stackTrace) => Scaffold(
          body: Center(child: Text("Error de autenticacion: $error")),
        ),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
