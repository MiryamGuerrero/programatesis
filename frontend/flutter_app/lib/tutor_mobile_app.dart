import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "core/state/app_providers.dart";
import "features/auth/login_page.dart";
import "shared/models/app_role.dart";
import "shared/widgets/role_shell.dart";

class TutorMobileApp extends ConsumerWidget {
  const TutorMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);

    return MaterialApp(
      title: "Reuma Nutri Tutor",
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

          final roleRaw = (session.user.appMetadata["role"] ?? "").toString().toLowerCase();
          if (roleRaw != "tutor") {
            return const _TutorOnlyScreen();
          }

          return const RoleShell(role: AppRole.tutor);
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

class _TutorOnlyScreen extends StatelessWidget {
  const _TutorOnlyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Esta app movil es solo para el rol Tutor.",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Inicia sesion con una cuenta tutor o usa la app web para otros roles.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
