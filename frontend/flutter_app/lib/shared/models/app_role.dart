enum AppRole {
  admin,
  medico,
  nutricionista,
  tutor,
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.admin:
        return "Admin";
      case AppRole.medico:
        return "Medico";
      case AppRole.nutricionista:
        return "Nutricionista";
      case AppRole.tutor:
        return "Tutor";
    }
  }
}

AppRole parseRole(String? rawRole) {
  switch ((rawRole ?? "").toLowerCase()) {
    case "admin":
      return AppRole.admin;
    case "medico":
      return AppRole.medico;
    case "nutricionista":
      return AppRole.nutricionista;
    default:
      return AppRole.tutor;
  }
}
