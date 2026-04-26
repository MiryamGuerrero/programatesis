import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:flutter_localizations/flutter_localizations.dart";

import "core/state/app_providers.dart";
import "features/auth/login_page.dart";
import "features/auth/set_password_page.dart";
import "shared/models/app_role.dart";
import "shared/widgets/role_shell.dart";

class ReumaNutriApp extends ConsumerWidget {
  const ReumaNutriApp({super.key});

  static const Color _tealPrimary = Color(0xFF0D9488);
  static const Color _tealPrimaryDark = Color(0xFF0F766E);
  static const Color _coralAccent = Color(0xFFFB923C);
  static const Color _coralAccentStrong = Color(0xFFF97316);
  static const Color _pearlBackground = Color(0xFFF8FAFC);
  static const Color _snowSurface = Color(0xFFFFFFFF);
  static const Color _slateTitle = Color(0xFF334155);
  static const Color _slateBody = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);
    final authFlowIntent = ref.watch(authFlowIntentProvider);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _tealPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _tealPrimary,
      secondary: _coralAccent,
      tertiary: _coralAccentStrong,
      surface: _snowSurface,
      onSurface: _slateTitle,
      outline: const Color(0xFFD5DEE8),
      error: const Color(0xFF991B1B),
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF991B1B),
    );

    final baseTextTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: _slateBody,
      displayColor: _slateBody,
    );

    final textTheme = baseTextTheme.copyWith(
      headlineLarge: GoogleFonts.nunitoSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: _slateTitle,
      ),
      headlineMedium: GoogleFonts.nunitoSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: _slateTitle,
      ),
      headlineSmall: GoogleFonts.nunitoSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: _slateTitle,
      ),
      titleLarge: GoogleFonts.nunitoSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
        color: _slateTitle,
      ),
      titleMedium: GoogleFonts.nunitoSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _slateTitle,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.45,
        color: _slateBody,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.35,
        color: _slateBody,
      ),
    );

    final rootPage = authSession.when(
      data: (session) {
        if (authFlowIntent == AuthFlowIntent.setPassword) {
          return const SetPasswordPage();
        }
        if (session == null) {
          return const LoginPage();
        }
        final roleAsync = ref.watch(appRoleProvider);
        final optimisticRole = _resolveRoleFromSession(session) ?? AppRole.tutor;
        return roleAsync.maybeWhen(
          data: (role) => RoleShell(role: role),
          orElse: () => RoleShell(role: optimisticRole),
        );
      },
      error: (error, stackTrace) => const LoginPage(),
      loading: () {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final role = _resolveRoleFromSession(session) ?? AppRole.tutor;
          return RoleShell(role: role);
        }
        return const LoginPage();
      },
    );

    return MaterialApp(
      title: "Reuma Nutri",
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'EC'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'EC'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _pearlBackground,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: _slateTitle,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: GoogleFonts.nunitoSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _slateTitle,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: _slateBody),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8E3EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8E3EC), width: 1.2),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: _tealPrimary, width: 1.9),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF991B1B), width: 1.5),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF991B1B), width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _tealPrimaryDark,
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
            foregroundColor: _slateTitle,
            side: const BorderSide(color: Color(0xFFBFD0DE)),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFFD8E3EC)),
          selectedColor: _coralAccent.withValues(alpha: 0.18),
          backgroundColor: _snowSurface,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shadowColor: const Color(0x00000000),
          color: _snowSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xFFF8FAFC)),
          headingTextStyle: TextStyle(fontWeight: FontWeight.w800),
          dataTextStyle: TextStyle(fontWeight: FontWeight.w600),
          dividerThickness: 0.7,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: _tealPrimary,
          titleTextStyle: TextStyle(
            color: _slateTitle,
            fontWeight: FontWeight.w700,
          ),
          subtitleTextStyle: TextStyle(
            color: _slateBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: _snowSurface,
          elevation: 8,
          shadowColor: const Color(0x14000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: _tealPrimary.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          selectedIconTheme: const IconThemeData(color: _tealPrimary),
          unselectedIconTheme:
              const IconThemeData(color: _slateBody),
          selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelTextStyle:
              const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: _tealPrimary.withValues(alpha: 0.18),
        ),
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => rootPage,
      ),
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => rootPage,
      ),
    );
  }
}

AppRole? _resolveRoleFromSession(Session session) {
  final candidates = <dynamic>[
    session.user.appMetadata["role"],
    session.user.appMetadata["rol"],
    session.user.appMetadata["id_rol"],
    session.user.userMetadata?["role"],
    session.user.userMetadata?["rol"],
    session.user.userMetadata?["id_rol"],
  ];

  for (final candidate in candidates) {
    final role = tryParseRole(candidate);
    if (role != null) {
      return role;
    }
  }

  return null;
}
