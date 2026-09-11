class StationCleaningPermissions {
  static String normalize(String role) => role.toUpperCase().replaceAll(' ', '_');

  static bool isSuperAdminOrAdmin(String role) {
    return ['SUPER_ADMIN', 'COMPANY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'CONTRACTOR_ADMIN'].contains(normalize(role));
  }

  static bool isSupervisor(String role) {
    return normalize(role) == 'RAILWAY_SUPERVISOR';
  }

  static bool isWorker(String role) {
    return ['WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'CONTRACTOR_SUPERVISOR'].contains(normalize(role));
  }

  static bool canCreateArea(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canEditArea(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canDeleteArea(String role) {
    return isSuperAdminOrAdmin(role);
  }

  static bool canViewAllAreas(String role) {
    return !isWorker(role);
  }

  static bool canAssignWorker(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canBulkAssign(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canGenerateTasks(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canApproveTasks(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canStartTask(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role) || isWorker(role);
  }

  static bool canCompleteTask(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role) || isWorker(role);
  }

  static bool canCreateMachine(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canDeleteMachine(String role) {
    return isSuperAdminOrAdmin(role);
  }

  static bool canAssignMachine(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canCreateMaterial(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canIssueMaterial(String role) {
    return isSuperAdminOrAdmin(role) || isSupervisor(role);
  }

  static bool canApproveReorder(String role) {
    return isSuperAdminOrAdmin(role);
  }

  static bool canViewReports(String role) {
    return !isWorker(role);
  }
}
