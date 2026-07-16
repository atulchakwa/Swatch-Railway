import { ForbiddenError } from '../errors/index.js';
import { ROLE_PERMISSIONS } from '../permissions/roles.js';

export function requirePermission(permission) {
  return (req, res, next) => {
    const role = (req.user?.role || '').toUpperCase();
    const normalizedRole = role.replace(/\s+/g, '_');
    const permissions = ROLE_PERMISSIONS[normalizedRole] || [];

    if (!permissions.includes(permission)) {
      console.log(`[AuthZ] Failed permission ${permission} for role "${role}" (normalized: "${normalizedRole}"). Permissions:`, permissions);
      throw new ForbiddenError(`Insufficient permissions. Required: ${permission}`);
    }
    next();
  };
}

export function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const userRole = (req.user?.role || '').toUpperCase();
    const normalizedUserRole = userRole.replace(/\s+/g, '_');

    const allowed = allowedRoles.map(r => r.toUpperCase().replace(/\s+/g, '_'));

    if (!allowed.includes(normalizedUserRole)) {
      throw new ForbiddenError(`Access denied. Required role: ${allowedRoles.join(' or ')}`);
    }
    next();
  };
}

export function requireAnyRole(...allowedRoles) {
  return (req, res, next) => {
    const userRole = (req.user?.role || '').toUpperCase().replace(/\s+/g, '_');
    const allowed = allowedRoles.map(r => r.toUpperCase().replace(/\s+/g, '_'));

    if (!allowed.includes(userRole)) {
      throw new ForbiddenError(`Access denied. Requires one of: ${allowedRoles.join(', ')}`);
    }
    next();
  };
}

export function requireEntityAccess(req, res, next) {
  const { userType, entityId: userEntityId } = req.user || {};
  const targetEntityId = req.params.uid || req.query.entityId || req.body.entityId;

  if (userType === 'contractor' && targetEntityId && targetEntityId !== userEntityId) {
    throw new ForbiddenError('You can only access your own company data');
  }
  next();
}

export function requireStationAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (role === 'STATION_MASTER' || role === 'AREA_MASTER' || role === 'PLATFORM_MASTER') {
    const stationId = req.user.stationId;
    if (!stationId) {
      throw new ForbiddenError('No station assigned to your account');
    }
    const targetStationId = req.params.stationId || req.body.stationId || req.query.stationId;
    if (targetStationId && targetStationId !== stationId) {
      throw new ForbiddenError('You can only access your assigned station');
    }
  }
  next();
}

export function requirePlatformAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (role === 'PLATFORM_MASTER') {
    const platformId = req.user.platformId;
    if (!platformId) {
      throw new ForbiddenError('No platform assigned to your account');
    }
    const targetPlatformId = req.params.platformId || req.body.platformId || req.query.platformId;
    if (targetPlatformId && targetPlatformId !== platformId) {
      throw new ForbiddenError('You can only access your assigned platform');
    }
  }
  next();
}

export function requireAreaAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (role === 'AREA_MASTER') {
    const areaId = req.user.areaId;
    if (!areaId) {
      throw new ForbiddenError('No area assigned to your account');
    }
    const targetAreaId = req.params.areaId || req.body.areaId || req.query.areaId;
    if (targetAreaId && targetAreaId !== areaId) {
      throw new ForbiddenError('You can only access your assigned area');
    }
  }
  next();
}

export function requireMasterAccess(minRole) {
  return (req, res, next) => {
    const role = (req.user?.role || '').toUpperCase();
    const roleHierarchy = {
      'SUPER_ADMIN': 100,
      'COMPANY_MASTER': 90,
      'RAILWAY_MASTER': 80,
      'ADMIN': 70,
      'RAILWAY_ADMIN': 60,
      'RAILWAY_SUPERVISOR': 50,
      'CONTRACTOR_ADMIN': 45,
      'CONTRACTOR_SUPERVISOR': 40,
      'STATION_MASTER': 55,
      'AREA_MASTER': 48,
      'PLATFORM_MASTER': 35,
      'CTS': 30,
      'WORKER': 10,
      'RAILWAY_WORKER': 10,
      'JANITOR': 10,
      'ATTENDANT': 10,
      'PASSENGER': 1
    };

    const userRoleLevel = roleHierarchy[role] || 0;
    const requiredRoleLevel = roleHierarchy[minRole] || 0;

    if (userRoleLevel < requiredRoleLevel) {
      throw new ForbiddenError(`Access denied. Requires ${minRole} or higher role`);
    }
    next();
  };
}

export function requireZoneMasterAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (!['SUPER_ADMIN', 'ADMIN', 'RAILWAY_MASTER', 'RAILWAY_ADMIN', 'COMPANY_MASTER'].includes(role)) {
    throw new ForbiddenError('Access denied. Requires zone master or higher role');
  }
  next();
}

export function requireAreaMasterAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (!['AREA_MASTER', 'STATION_MASTER', 'PLATFORM_MASTER'].includes(role)) {
    throw new ForbiddenError('Access denied. Requires area master, station master, or platform master role');
  }
  next();
}

export function requirePlatformMasterAccess(req, res, next) {
  const role = (req.user?.role || '').toUpperCase();
  if (!['PLATFORM_MASTER', 'AREA_MASTER', 'STATION_MASTER'].includes(role)) {
    throw new ForbiddenError('Access denied. Requires platform master, area master, or station master role');
  }
  next();
}

export function requireDashboardLevelAccess(level) {
  return (req, res, next) => {
    const role = (req.user?.role || '').toUpperCase().replace(/\s+/g, '_');
    const roleHierarchy = {
      'SUPER_ADMIN': 100, 'COMPANY_MASTER': 90, 'RAILWAY_MASTER': 80,
      'ADMIN': 70, 'RAILWAY_ADMIN': 60, 'STATION_MASTER': 55,
      'RAILWAY_SUPERVISOR': 50, 'AREA_MASTER': 48, 'CONTRACTOR_ADMIN': 45,
      'CONTRACTOR_SUPERVISOR': 40, 'PLATFORM_MASTER': 35, 'CTS': 30,
      'WORKER': 10, 'RAILWAY_WORKER': 10, 'JANITOR': 10, 'ATTENDANT': 10, 'PASSENGER': 1
    };
    
    const userRoleLevel = roleHierarchy[role] || 0;

    switch (level) {
      case 'admin':
        if (userRoleLevel < 60 && role !== 'COMPANY_MASTER') {
          throw new ForbiddenError('Admin dashboard access requires admin privileges');
        }
        break;
      case 'zone':
        if (userRoleLevel < 48) { // Area Master and above
          throw new ForbiddenError('Zone dashboard access requires zone-level privileges');
        }
        break;
      case 'station':
        if (userRoleLevel < 48) { // Area Master and above
          throw new ForbiddenError('Station dashboard access requires station-level privileges');
        }
        break;
      case 'platform':
        if (userRoleLevel < 35) { // Platform Master and above
          throw new ForbiddenError('Platform dashboard access requires platform-level privileges');
        }
        break;
      case 'area':
        if (userRoleLevel < 35) { // Platform Master and above. Workers (10) are restricted.
          throw new ForbiddenError('Area dashboard access requires area-level privileges');
        }
        break;
    }
    next();
  };
}
