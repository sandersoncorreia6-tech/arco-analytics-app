enum AppRole { admin, coach, analyst, athlete }

enum AppPermission {
  manageOrganization,
  manageUsers,
  manageRoster,
  manageGames,
  recordScout,
  viewAnalytics,
  viewGamePlan,
  manageVideos,
  exportReports,
}

class AccessPolicy {
  static const Map<AppRole, Set<AppPermission>> permissions = {
    AppRole.admin: {
      AppPermission.manageOrganization,
      AppPermission.manageUsers,
      AppPermission.manageRoster,
      AppPermission.manageGames,
      AppPermission.recordScout,
      AppPermission.viewAnalytics,
      AppPermission.viewGamePlan,
      AppPermission.manageVideos,
      AppPermission.exportReports,
    },
    AppRole.coach: {
      AppPermission.manageRoster,
      AppPermission.manageGames,
      AppPermission.recordScout,
      AppPermission.viewAnalytics,
      AppPermission.viewGamePlan,
      AppPermission.manageVideos,
      AppPermission.exportReports,
    },
    AppRole.analyst: {
      AppPermission.recordScout,
      AppPermission.viewAnalytics,
      AppPermission.viewGamePlan,
      AppPermission.manageVideos,
      AppPermission.exportReports,
    },
    AppRole.athlete: {
      AppPermission.viewAnalytics,
    },
  };

  static bool allows(AppRole role, AppPermission permission) =>
      permissions[role]?.contains(permission) ?? false;

  static String roleLabel(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'Administrador';
      case AppRole.coach:
        return 'Treinador';
      case AppRole.analyst:
        return 'Analista';
      case AppRole.athlete:
        return 'Atleta';
    }
  }
}
