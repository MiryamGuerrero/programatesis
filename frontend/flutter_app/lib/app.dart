import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "core/state/app_providers.dart";
import "features/auth/login_page.dart";
import "shared/widgets/role_shell.dart";

class ReumaNutriApp extends ConsumerWidget {
  const ReumaNutriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);
    final role = ref.watch(appRoleProvider);

    return MaterialApp(
      title: "Reuma Nutri",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0A7E8C),
        textTheme: GoogleFonts.nunitoSansTextTheme(),
        useMaterial3: true,
      ),
      home: authSession.when(
        data: (session) {
          if (session == null) {
            return const LoginPage();
          }
          return RoleShell(role: role);
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
