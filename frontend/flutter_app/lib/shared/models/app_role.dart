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
  return tryParseRole(rawRole) ?? AppRole.tutor;
}

AppRole? tryParseRole(dynamic rawRole) {
  if (rawRole == null) {
    return null;
  }

  if (rawRole is int) {
    return _parseRoleById(rawRole);
  }

  final token = rawRole.toString().trim().toLowerCase();
  if (token.isEmpty || token == "authenticated" || token == "anon") {
    return null;
  }

  final roleId = int.tryParse(token);
  if (roleId != null) {
    return _parseRoleById(roleId);
  }

  switch (token) {
    case "admin":
    case "administrador":
      return AppRole.admin;
    case "medico":
    case "medic":
      return AppRole.medico;
    case "nutricionista":
    case "nutricionist":
    case "nutritionist":
      return AppRole.nutricionista;
    case "tutor":
      return AppRole.tutor;
    default:
      return null;
  }
}

AppRole? _parseRoleById(int roleId) {
  switch (roleId) {
    case 1:
      return AppRole.admin;
    case 2:
      return AppRole.medico;
    case 3:
      return AppRole.nutricionista;
    case 4:
      return AppRole.tutor;
    default:
      return null;
  }
}
