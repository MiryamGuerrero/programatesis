import "package:flutter/material.dart";

import "package:reuma_nutri_app/shared/repositories/gestion_tutores_pacientes_page.dart";

class RegistroClinicoPage extends StatelessWidget {
  const RegistroClinicoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FormEditarControlClinicoPaciente(),
        ),
      ],
    );
  }
}

