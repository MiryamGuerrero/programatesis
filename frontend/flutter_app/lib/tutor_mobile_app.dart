import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "core/state/app_providers.dart";
import "core/theme/app_theme.dart";
import "features/auth/login_page.dart";
import "features/auth/set_password_page.dart";
import "shared/widgets/tutor_mobile_shell.dart";

class TutorMobileApp extends ConsumerWidget {
  const TutorMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);
    final authFlowIntent = ref.watch(authFlowIntentProvider);

    return MaterialApp(
      title: "NutriReuma",
      debugShowCheckedModeBanner: false,
      theme: AppTema.light,
      home: authSession.when(
        data: (session) {
          if (authFlowIntent == AuthFlowIntent.setPassword) {
            return const SetPasswordPage();
          }

          if (session == null) {
            return const LoginPage();
          }

          final roleRaw =
              (session.user.appMetadata["role"] ?? "").toString().toLowerCase();
          if (roleRaw != "tutor") {
            return const _TutorOnlyScreen();
          }

          return const TutorMobileShell();
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

class _TutorOnlyScreen extends StatefulWidget {
  const _TutorOnlyScreen();

  @override
  State<_TutorOnlyScreen> createState() => _TutorOnlyScreenState();
}

class _TutorOnlyScreenState extends State<_TutorOnlyScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                "Esta aplicación es solo para los Tutores",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Inicia sesion con una cuenta tutor o usa la app web para otros roles.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.arrow_back_rounded),
                  label: const Text(
                    "Regresar al login",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
