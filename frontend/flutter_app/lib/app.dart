import "dart:ui";
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
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        ref.invalidate(appRoleProvider);
        ref.invalidate(miPerfilProvider);
      } else if (data.event == AuthChangeEvent.signedOut) {
        ref.read(activeRoleOverrideProvider.notifier).state = null;
        ref.read(miPerfilOverrideProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(authSessionProvider);
    final authFlowIntent = ref.watch(authFlowIntentProvider);
    final authError = ref.watch(authErrorProvider);

    // COLORES CORPORATIVOS
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0171BB),
      primary: const Color(0xFF0171BB),
      secondary: const Color(0xFF70A81C),
      surface: Colors.white,
    );

    final rootPage = authSession.when(
      data: (session) {
        if (authFlowIntent == AuthFlowIntent.setPassword) {
          return const SetPasswordPage();
        }
        if (session == null || authError != null) {
          return const LoginPage();
        }

        final isSwitchingRole = ref.watch(roleSwitchLoadingProvider);
        final targetRole = ref.watch(targetRoleProvider);
        final roleAsync = ref.watch(appRoleProvider);
        final currentRole = roleAsync.valueOrNull;

        // Mantener la pantalla de carga activa mientras se procese el cambio
        // o mientras el rol actual no coincida con el rol objetivo solicitado
        if (isSwitchingRole || (targetRole != null && currentRole != targetRole)) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0171BB),
              ),
            ),
          );
        }

        if (currentRole != null) {
          return RoleShell(key: ValueKey(currentRole.id), role: currentRole);
        }
        return roleAsync.when(
          data: (role) => RoleShell(key: ValueKey(role.id), role: role),
          loading: () => const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0171BB),
              ),
            ),
          ),
          error: (_, __) => const LoginPage(),
        );
      },
      error: (_, __) => const LoginPage(),
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0171BB),
          ),
        ),
      ),
    );

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: "NutriReuma",
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        // Optimizamos el renderizado de texto para evitar bloqueos
        textTheme: GoogleFonts.latoTextTheme().copyWith(
          bodyMedium: GoogleFonts.lato(fontWeight: FontWeight.w500),
        ),
        fontFamily: GoogleFonts.lato().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155)),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: const WidgetStatePropertyAll(true),
          trackVisibility: const WidgetStatePropertyAll(false),
          thickness: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.dragged)) {
              return 10.0;
            }
            return 7.0;
          }),
          radius: const Radius.circular(8.0),
          interactive: true,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged)) {
              return const Color(0xFF004C87); // Azul intenso al arrastrar
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF0171BB); // Azul corporativo al pasar el cursor
            }
            return const Color(0xFF475569); // Pizarra oscuro con alto contraste sobre el fondo
          }),
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
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    return Scrollbar(
      controller: details.controller,
      interactive: true,
      thumbVisibility: true,
      trackVisibility: false,
      child: child,
    );
  }
}
