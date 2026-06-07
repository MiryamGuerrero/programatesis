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

class ReumaNutriApp extends ConsumerStatefulWidget {
  const ReumaNutriApp({super.key});

  @override
  ConsumerState<ReumaNutriApp> createState() => _ReumaNutriAppState();
}

class _ReumaNutriAppState extends ConsumerState<ReumaNutriApp> {
  @override
  void initState() {
    super.initState();
    // Listener crítico para navegación inmediata sin recargar
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        ref.invalidate(appRoleProvider);
        ref.invalidate(miPerfilProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    final authFlowIntent = ref.watch(authFlowIntentProvider);
    
    // COLORES CORPORATIVOS
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0171BB),
      primary: const Color(0xFF0171BB),
      secondary: const Color(0xFF70A81C),
      surface: Colors.white,
    );

    final rootPage = authSession.when(
      data: (session) {
        if (authFlowIntent == AuthFlowIntent.setPassword) return const SetPasswordPage();
        if (session == null) return const LoginPage();

        final roleAsync = ref.watch(appRoleProvider);
        return roleAsync.when(
          data: (role) => RoleShell(role: role),
          loading: () => RoleShell(role: _resolveRoleFromSession(session) ?? AppRole.tutor),
          error: (_, __) => RoleShell(role: _resolveRoleFromSession(session) ?? AppRole.tutor),
        );
      },
      error: (_, __) => const LoginPage(),
      loading: () {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return RoleShell(role: _resolveRoleFromSession(session) ?? AppRole.tutor);
        return const LoginPage();
      },
    );

    return MaterialApp(
      title: "NutriReuma",
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        textTheme: GoogleFonts.latoTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
        ),
      ),
      home: rootPage,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'EC')],
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
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
    if (role != null) return role;
  }
  return null;
}
