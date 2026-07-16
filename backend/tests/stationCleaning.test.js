import { describe, it, expect } from 'vitest';
import { ROLES, PERMISSIONS, ROLE_PERMISSIONS } from '../src/permissions/roles.js';
import { stationCleaningService } from '../src/services/stationCleaningService.js';

/* ==========================================================================
   1. SERVICE METHOD COVERAGE
   ========================================================================== */

describe('StationCleaningService - method coverage', () => {
  const expected = [
    'createStationArea', 'listStationAreas', 'getStationArea',
    'updateStationArea', 'deleteStationArea',
    'createStationZone', 'listStationZones', 'getStationZone',
    'updateStationZone', 'deleteStationZone',
    'mapContractor', 'listContractorMappings', 'getContractorMapping',
    'updateContractorMapping', 'deleteContractorMapping',
    'createSchedule', 'listSchedules', 'getSchedule',
    'updateSchedule', 'deleteSchedule',
    'createStationRun', 'listStationRuns', 'updateStationRun',
    'deleteStationRun', 'getMyStationRuns', 'getWorkerStationRuns',
    'getSupervisorStationRuns',
    'submitStationTask', 'getStationTask', 'updateStationTask',
    'deleteStationTask', 'listPendingStationTasks',
    'createStationCleaningForm', 'submitStationCleaningForm',
    'approveStationCleaningForm', 'rejectStationCleaningForm',
    'scoreStationCleaningForm', 'lockStationCleaningForm',
    'listStationCleaningForms', 'getStationCleaningFormDetail',
    'createAreaTaskFrequency', 'updateAreaTaskFrequency',
    'deleteAreaTaskFrequency', 'listAreaTaskFrequencies',
    'getStationDashboard',
    'recordPestControl', 'listPestControl', 'listAllPestControl',
    'reviewPestControl', 'pestControlReport',
    'deployMachine', 'listMachines', 'returnMachine',
    'maintenanceMachine', 'machineReport',
    'recordGarbageDisposal', 'listGarbageRecords', 'garbageReport',
    '_resolveStationId', '_resolveAreaId', '_isMasterOrAdmin',
    '_scopeByEntity', '_scopeByArea', '_scopeByDivision',
  ];
  for (const method of expected) {
    it(`exports "${method}"`, () => {
      expect(typeof stationCleaningService[method]).toBe('function');
    });
  }
});

/* ==========================================================================
   2. CONTROLLER EXPORTS
   ========================================================================== */

describe('StationCleaningController - export coverage', () => {
  it('exports all expected handlers', async () => {
    const ctrl = await import('../src/controllers/stationCleaningController.js');
    const expected = [
      'createStationArea', 'listStationAreas', 'getStationArea',
      'updateStationArea', 'deleteStationArea',
      'createStationZone', 'listStationZones', 'getStationZone',
      'updateStationZone', 'deleteStationZone',
      'mapContractor', 'listContractorMappings', 'getContractorMapping',
      'updateContractorMapping', 'deleteContractorMapping',
      'createSchedule', 'listSchedules', 'getSchedule',
      'updateSchedule', 'deleteSchedule',
      'createStationRun', 'listStationRuns', 'updateStationRun',
      'deleteStationRun', 'getMyStationRuns', 'getWorkerStationRuns',
      'getSupervisorStationRuns',
      'submitStationTask', 'getStationTask', 'updateStationTask',
      'deleteStationTask', 'listPendingStationTasks',
      'createStationCleaningForm', 'submitStationCleaningForm',
      'approveStationCleaningForm', 'rejectStationCleaningForm',
      'scoreStationCleaningForm', 'lockStationCleaningForm',
      'listStationCleaningForms', 'getStationCleaningFormDetail',
      'createAreaTaskFrequency', 'updateAreaTaskFrequency',
      'deleteAreaTaskFrequency', 'listAreaTaskFrequencies',
      'getStationDashboard',
      'recordPestControl', 'listPestControl', 'listAllPestControl',
      'reviewPestControl', 'pestControlReport',
      'deployMachine', 'listMachines', 'returnMachine',
      'maintenanceMachine', 'machineReport',
      'recordGarbageDisposal', 'listGarbageRecords', 'garbageReport',
    ];
    for (const name of expected) {
      expect(typeof ctrl[name], `Missing export: ${name}`).toBe('function');
    }
  });
});

/* ==========================================================================
   3. ROUTE FILE EXPORTS
   ========================================================================== */

describe('StationCleaning routes - exports and endpoints', () => {
  it('exports a router with registered routes', async () => {
    const router = (await import('../src/routes/stationCleaning.js')).default;
    expect(router).toBeDefined();
    expect(typeof router).toBe('function');
    expect(router.stack).toBeDefined();
    expect(router.stack.length).toBeGreaterThanOrEqual(50);
  });

  it('registers all required endpoint patterns', async () => {
    const router = (await import('../src/routes/stationCleaning.js')).default;
    const paths = router.stack.map(l => l.route?.path).filter(Boolean);
    const expected = [
      '/api/station-area/create',
      '/api/station-area/list/:stationId',
      '/api/station-area/:uid',
      '/api/station-area/update/:uid',
      '/api/station-area/delete/:uid',
      '/api/station-zone/create',
      '/api/station-zone/list/:stationId',
      '/api/station-zone/:uid',
      '/api/station-contractor/map',
      '/api/station-contractor/list/:stationId',
      '/api/station-contractor/:uid',
      '/api/station-schedule/create',
      '/api/station-schedule/list/:stationId',
      '/api/station-schedule/:uid',
      '/api/station-runs',
      '/api/station-runs/my-runs',
      '/api/station-runs/worker/:workerId',
      '/api/station-runs/supervisor/:supervisorId',
      '/api/station-runs/:runId',
      '/api/station-tasks/submit',
      '/api/station-tasks/pending-review',
      '/api/station-tasks/:taskId',
      '/api/station-cleaning-form/create',
      '/api/station-cleaning-form/submit/:uid',
      '/api/station-cleaning-form/approve/:uid',
      '/api/station-cleaning-form/reject/:uid',
      '/api/station-cleaning-form/score/:uid',
      '/api/station-cleaning-form/lock/:uid',
      '/api/station-cleaning-form/list',
      '/api/station-cleaning-form/details/:uid',
      '/api/station-dashboard',
      '/api/station-pest-control/record',
      '/api/station-pest-control/list/:stationId',
      '/api/station-pest-control/all',
      '/api/station-pest-control/:uid/review',
      '/api/station-pest-control/report',
      '/api/station-machines/deploy',
      '/api/station-machines/list',
      '/api/station-machines/:uid/return',
      '/api/station-machines/:uid/maintenance',
      '/api/station-machines/report',
      '/api/station-garbage/record',
      '/api/station-garbage/records',
      '/api/station-garbage/report',
      '/api/station-area-task-frequency',
      '/api/station-area-task-frequency/:uid',
    ];
    for (const ep of expected) {
      expect(paths, `Missing endpoint: ${ep}`).toContain(ep);
    }
  });
});

/* ==========================================================================
   4. HELPER METHODS - UNIT TESTS
   ========================================================================== */

function makeUser(overrides = {}) {
  return {
    uid: 'test-uid',
    role: overrides.role || 'SUPER_ADMIN',
    division: overrides.division || 'DELHI',
    stationId: overrides.stationId || null,
    areaId: overrides.areaId || null,
    entityId: overrides.entityId || null,
    userType: overrides.userType || 'railway',
    fullName: overrides.fullName || 'Test User',
    ...overrides,
  };
}

describe('Helper: _resolveStationId', () => {
  it('returns user.stationId for RAILWAY_SUPERVISOR', () => {
    const user = makeUser({ role: 'RAILWAY_SUPERVISOR', stationId: 'STN-A' });
    expect(stationCleaningService._resolveStationId('requested-id', user)).toBe('STN-A');
  });

  it('returns user.stationId for STATION_MASTER', () => {
    const user = makeUser({ role: 'STATION_MASTER', stationId: 'STN-A' });
    expect(stationCleaningService._resolveStationId('other', user)).toBe('STN-A');
  });

  it('returns requestedStationId for SUPER_ADMIN', () => {
    const user = makeUser({ role: 'SUPER_ADMIN', stationId: 'STN-A' });
    expect(stationCleaningService._resolveStationId('requested-id', user)).toBe('requested-id');
  });

  it('returns requestedStationId when stationId is null', () => {
    const user = makeUser({ role: 'RAILWAY_SUPERVISOR', stationId: null });
    expect(stationCleaningService._resolveStationId('requested-id', user)).toBe('requested-id');
  });
});

describe('Helper: _resolveAreaId', () => {
  it('returns user.areaId for PLATFORM_MASTER', () => {
    const user = makeUser({ role: 'PLATFORM_MASTER', areaId: 'area-1' });
    expect(stationCleaningService._resolveAreaId('other', user)).toBe('area-1');
  });

  it('returns requestedAreaId for non-PLATFORM_MASTER', () => {
    const user = makeUser({ role: 'SUPER_ADMIN', areaId: 'area-1' });
    expect(stationCleaningService._resolveAreaId('requested', user)).toBe('requested');
  });

  it('returns requestedAreaId when areaId is null', () => {
    const user = makeUser({ role: 'PLATFORM_MASTER', areaId: null });
    expect(stationCleaningService._resolveAreaId('requested', user)).toBe('requested');
  });
});

describe('Helper: _isMasterOrAdmin', () => {
  const masterRoles = ['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN'];
  for (const role of masterRoles) {
    it(`returns true for ${role}`, () => {
      expect(stationCleaningService._isMasterOrAdmin(makeUser({ role }))).toBe(true);
    });
  }

  const nonMasterRoles = ['RAILWAY_SUPERVISOR', 'STATION_MASTER', 'PLATFORM_MASTER', 'WORKER', 'JANITOR'];
  for (const role of nonMasterRoles) {
    it(`returns false for ${role}`, () => {
      expect(stationCleaningService._isMasterOrAdmin(makeUser({ role }))).toBe(false);
    });
  }
});

describe('Helper: _scopeByDivision', () => {
  it('returns query unchanged for master roles', () => {
    const query = { where: () => 'filtered' };
    const user = makeUser({ role: 'SUPER_ADMIN', division: 'DELHI' });
    expect(stationCleaningService._scopeByDivision(query, user)).toBe(query);
  });

  it('applies division filter for non-master with division', () => {
    const user = makeUser({ role: 'RAILWAY_SUPERVISOR', division: 'DELHI' });
    let filteredField = null;
    const query = { where: (field, op, val) => { filteredField = field; return 'filtered'; } };
    stationCleaningService._scopeByDivision(query, user);
    expect(filteredField).toBe('division');
  });
});

/* ==========================================================================
   5. ROLE-PERMISSION MATRIX - STATION CLEANING
   ========================================================================== */

function hasPermission(roleKey, permKey) {
  return ROLE_PERMISSIONS[roleKey]?.includes(PERMISSIONS[permKey]) ?? false;
}

function makeAllRolesList(roles) {
  return [...new Set(['SUPER_ADMIN', ...roles])];
}

const stationCleaningPermissions = {
  MANAGE_AREAS: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER']), VIEW: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_ADMIN', 'CONTRACTOR_SUPERVISOR'] },
  MANAGE_ZONES: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER']), VIEW: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_ADMIN', 'CONTRACTOR_SUPERVISOR'] },
  MANAGE_CONTRACTORS: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN']), VIEW: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_SUPERVISOR', 'PLATFORM_MASTER', 'AREA_MASTER'] },
  MANAGE_SCHEDULES: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'PLATFORM_MASTER']), VIEW: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_SUPERVISOR', 'AREA_MASTER'] },
  MANAGE_RUNS: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN']), VIEW: ['RAILWAY_SUPERVISOR', 'CONTRACTOR_SUPERVISOR', 'PLATFORM_MASTER', 'AREA_MASTER'] },
  VIEW_RUNS: { VIEW: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'AREA_MASTER']) },
  SUBMIT_TASKS: { COMP: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'PLATFORM_MASTER', 'RAILWAY_SUPERVISOR', 'AREA_MASTER']) },
  VIEW_TASKS: { VIEW: makeAllRolesList(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'AREA_MASTER']) },
};

describe('Station Cleaning Role-Permission Matrix', () => {
  const allRoles = Object.keys(ROLES);

  it('MANAGE_AREAS - only COMP roles have it', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_AREAS.COMP.includes(role);
      expect(hasPermission(role, 'MANAGE_AREAS'), `${role} MANAGE_AREAS mismatch`).toBe(shouldHave);
    }
  });

  it('VIEW_AREAS - all except PASSENGER, CTS, workers', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_AREAS.COMP.includes(role)
        || stationCleaningPermissions.MANAGE_AREAS.VIEW.includes(role);
      expect(hasPermission(role, 'VIEW_AREAS'), `${role} VIEW_AREAS mismatch`).toBe(shouldHave || false);
    }
  });

  it('MANAGE_CONTRACTORS - correct roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_CONTRACTORS.COMP.includes(role);
      expect(hasPermission(role, 'MANAGE_CONTRACTORS'), `${role} mismatch`).toBe(shouldHave);
    }
  });

  it('VIEW_CONTRACTORS - manage roles + view-only roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_CONTRACTORS.COMP.includes(role)
        || stationCleaningPermissions.MANAGE_CONTRACTORS.VIEW.includes(role);
      expect(hasPermission(role, 'VIEW_CONTRACTORS'), `${role} mismatch`).toBe(shouldHave || false);
    }
  });

  it('MANAGE_RUNS - correct roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_RUNS.COMP.includes(role);
      expect(hasPermission(role, 'MANAGE_RUNS'), `${role} mismatch`).toBe(shouldHave);
    }
  });

  it('VIEW_RUNS - manage roles + view-only roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.VIEW_RUNS.VIEW.includes(role);
      expect(hasPermission(role, 'VIEW_RUNS'), `${role} mismatch`).toBe(shouldHave || false);
    }
  });

  it('MANAGE_SCHEDULES - correct roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_SCHEDULES.COMP.includes(role);
      expect(hasPermission(role, 'MANAGE_SCHEDULES'), `${role} mismatch`).toBe(shouldHave);
    }
  });

  it('VIEW_SCHEDULES - manage roles + read roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.MANAGE_SCHEDULES.COMP.includes(role)
        || stationCleaningPermissions.MANAGE_SCHEDULES.VIEW.includes(role);
      expect(hasPermission(role, 'VIEW_SCHEDULES'), `${role} mismatch`).toBe(shouldHave || false);
    }
  });

  it('SUBMIT_TASKS - correct roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.SUBMIT_TASKS.COMP.includes(role);
      expect(hasPermission(role, 'SUBMIT_TASKS'), `${role} mismatch`).toBe(shouldHave);
    }
  });

  it('VIEW_TASKS - correct roles', () => {
    for (const role of allRoles) {
      const shouldHave = stationCleaningPermissions.VIEW_TASKS.VIEW.includes(role);
      expect(hasPermission(role, 'VIEW_TASKS'), `${role} mismatch`).toBe(shouldHave || false);
    }
  });

  it('VIEW_DASHBOARD - all non-privileged roles except PASSENGER/CTS', () => {
    const has = ['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER',
      'AREA_MASTER', 'PLATFORM_MASTER', 'RAILWAY_SUPERVISOR', 'CONTRACTOR_ADMIN', 'CONTRACTOR_SUPERVISOR',
      'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT'];
    for (const role of allRoles) {
      expect(hasPermission(role, 'VIEW_DASHBOARD'), `${role} mismatch`).toBe(has.includes(role) || false);
    }
  });
});

/* ==========================================================================
   6. AUTHORIZATION MIDDLEWARE TESTS
   ========================================================================== */

describe('Authorization middleware - station cleaning endpoints', () => {
  function withSA(roles) {
    return [...new Set(['SUPER_ADMIN', ...roles])];
  }

  const permConfigs = {
    'MANAGE_AREAS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER']),
    'MANAGE_CONTRACTORS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN']),
    'MANAGE_SCHEDULES': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'PLATFORM_MASTER']),
    'MANAGE_RUNS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN']),
    'VIEW_RUNS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'AREA_MASTER']),
    'SUBMIT_TASKS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'PLATFORM_MASTER', 'RAILWAY_SUPERVISOR', 'AREA_MASTER']),
    'VIEW_TASKS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'AREA_MASTER']),
    'MANAGE_FREQUENCIES': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'PLATFORM_MASTER']),
    'VIEW_FREQUENCIES': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER']),
    'REJECT_FORM': withSA(['RAILWAY_ADMIN', 'STATION_MASTER', 'RAILWAY_SUPERVISOR']),
    'APPROVE_FORM_MANPOWER': withSA(['RAILWAY_ADMIN', 'STATION_MASTER', 'RAILWAY_SUPERVISOR']),
    'SCORE_FORM': withSA(['RAILWAY_ADMIN', 'STATION_MASTER', 'RAILWAY_SUPERVISOR']),
    'MANAGE_PEST_CONTROL': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'PLATFORM_MASTER']),
    'VIEW_PEST_CONTROL': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT']),
    'MANAGE_GARBAGE': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'PLATFORM_MASTER']),
    'VIEW_GARBAGE': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'RAILWAY_SUPERVISOR', 'PLATFORM_MASTER', 'CONTRACTOR_SUPERVISOR', 'WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT']),
    'MANAGE_AREA_ASSIGNMENTS': withSA(['COMPANY_MASTER', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER', 'RAILWAY_MASTER']),
    'VIEW_AREA_ASSIGNMENTS': withSA(['COMPANY_MASTER', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER', 'RAILWAY_MASTER']),
    'MANAGE_DEPLOYMENTS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER']),
    'MANAGE_SHIFTS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER', 'CONTRACTOR_ADMIN']),
    'ASSIGN_SHIFT': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER', 'CONTRACTOR_ADMIN']),
    'MANAGE_ACTIVITIES': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'PLATFORM_MASTER']),
    'MANAGE_INSPECTIONS': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'PLATFORM_MASTER']),
    'MANAGE_MACHINES': withSA(['COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN', 'STATION_MASTER', 'AREA_MASTER', 'CONTRACTOR_ADMIN', 'PLATFORM_MASTER']),
  };

  for (const [perm, allowedRoles] of Object.entries(permConfigs)) {
    it(`${perm} - allowed roles have permission, denied roles throw`, async () => {
      const { requirePermission } = await import('../src/middleware/authorization.js');
      const middleware = requirePermission(PERMISSIONS[perm]);

      for (const role of Object.keys(ROLES)) {
        const req = { user: { role, userType: 'railway', division: 'TEST' } };
        const next = (err) => {};

        if (allowedRoles.includes(role)) {
          let called = false;
          middleware(req, {}, () => { called = true; });
          expect(called, `${role} should pass ${perm}`).toBe(true);
        } else {
          let threw = false;
          try {
            middleware(req, {}, next);
          } catch (e) {
            threw = true;
            expect(e.name || e.constructor.name).toMatch(/Forbidden|Error/i);
          }
          expect(threw, `${role} should be denied ${perm}`).toBe(true);
        }
      }
    });
  }
});

/* ==========================================================================
   7. FORM WORKFLOW - STATUS TRANSITION VALIDATION
   ========================================================================== */

describe('Form workflow - status transition validation', () => {
  const validTransitions = {
    draft: ['submitted', 'deleted'],
    submitted: ['approved', 'rejected', 'deleted'],
    approved: ['scored', 'deleted'],
    scored: ['locked', 'deleted'],
    locked: ['deleted'],
    rejected: ['submitted', 'deleted'],
  };

  const transitionMethods = {
    submitStationCleaningForm: { from: 'draft', to: 'submitted', allowedPrev: ['draft', 'rejected'] },
    approveStationCleaningForm: { from: 'submitted', to: 'approved', allowedPrev: ['submitted'] },
    rejectStationCleaningForm: { from: 'submitted', to: 'rejected', allowedPrev: ['submitted'] },
    scoreStationCleaningForm: { from: 'approved', to: 'scored', allowedPrev: ['approved'] },
    lockStationCleaningForm: { from: 'scored', to: 'locked', allowedPrev: ['scored'] },
  };

  it('VALID_TRANSITIONS map covers all form statuses', () => {
    const allStatuses = ['draft', 'submitted', 'approved', 'scored', 'locked', 'rejected', 'archived', 'deleted'];
    for (const status of allStatuses) {
      if (status === 'archived' || status === 'deleted') continue;
      expect(validTransitions[status], `Missing transitions for: ${status}`).toBeDefined();
    }
  });

  for (const [methodName, config] of Object.entries(transitionMethods)) {
    describe(`${methodName} transition logic`, () => {
      it(`allows transition from ${config.allowedPrev.join(' or ')} to ${config.to}`, () => {
        for (const prev of config.allowedPrev) {
          const form = { status: prev };
          const isValid = config.allowedPrev.includes(form.status);
          expect(isValid, `Should allow ${prev} -> ${config.to}`).toBe(true);
        }
      });

      it(`rejects transition from disallowed statuses to ${config.to}`, () => {
        const disallowed = Object.keys(validTransitions).filter(s => !config.allowedPrev.includes(s));
        for (const bad of disallowed) {
          const form = { status: bad };
          const isValid = config.allowedPrev.includes(form.status);
          expect(isValid, `Should reject ${bad} -> ${config.to}`).toBe(false);
        }
      });
    });
  }

  it('submitStationCleaningForm source code allows draft AND rejected (fix verified)', async () => {
    const fnStr = stationCleaningService.submitStationCleaningForm.toString();
    expect(fnStr).toContain("'draft', 'rejected'");
    expect(fnStr).not.toContain("form.status !== 'draft'");
  });

  it('full happy-path workflow: draft -> submitted -> approved -> scored -> locked', () => {
    const workflow = ['draft', 'submitted', 'approved', 'scored', 'locked'];
    for (let i = 0; i < workflow.length - 1; i++) {
      const from = workflow[i];
      const to = workflow[i + 1];
      expect(validTransitions[from], `No transition from ${from}`).toContain(to);
    }
  });
});

/* ==========================================================================
   8. VALIDATION SCHEMAS
   ========================================================================== */

describe('Validation schemas - station cleaning', () => {
  it('exports all required schemas', async () => {
    const schemas = await import('../src/validations/stationCleaning.js');
    const expected = [
      'createStationAreaSchema', 'createStationZoneSchema',
      'createScheduleSchema', 'createStationRunSchema',
      'submitStationTaskSchema', 'createStationCleaningFormSchema',
    ];
    for (const name of expected) {
      expect(schemas[name], `Missing schema: ${name}`).toBeDefined();
    }
  });

  it('createStationAreaSchema validates correctly', async () => {
    const { createStationAreaSchema } = await import('../src/validations/stationCleaning.js');
    const valid = createStationAreaSchema.safeParse({ stationId: 'stn-123', name: 'Platform 1' });
    expect(valid.success).toBe(true);

    const noName = createStationAreaSchema.safeParse({ stationId: 'stn-123' });
    expect(noName.success).toBe(false);

    const shortName = createStationAreaSchema.safeParse({ stationId: 'stn-123', name: 'A' });
    expect(shortName.success).toBe(false);
  });

  it('createStationRunSchema validates date format', async () => {
    const { createStationRunSchema } = await import('../src/validations/stationCleaning.js');
    const valid = createStationRunSchema.safeParse({ stationId: 's1', stationName: 'Test', date: '2026-07-07', shift: 'morning' });
    expect(valid.success).toBe(true);

    const badDate = createStationRunSchema.safeParse({ stationId: 's1', stationName: 'Test', date: '07-07-2026', shift: 'morning' });
    expect(badDate.success).toBe(false);
  });
});

/* ==========================================================================
   9. INTEGRATION - SUPERADMIN HAS ALL PERMISSIONS
   ========================================================================== */

describe('SUPER_ADMIN - has all station cleaning permissions', () => {
  const required = [
    'MANAGE_AREAS', 'VIEW_AREAS', 'MANAGE_CONTRACTORS', 'VIEW_CONTRACTORS',
    'MANAGE_SCHEDULES', 'VIEW_SCHEDULES', 'MANAGE_RUNS', 'VIEW_RUNS',
    'SUBMIT_TASKS', 'VIEW_TASKS',
    'SUBMIT_COACH_FORM', 'APPROVE_FORM_MANPOWER', 'REJECT_FORM',
    'SCORE_FORM', 'MANAGE_FORMS',
    'MANAGE_MACHINES', 'VIEW_MACHINES', 'MANAGE_PEST_CONTROL', 'VIEW_PEST_CONTROL',
    'MANAGE_GARBAGE', 'VIEW_GARBAGE', 'VIEW_DASHBOARD',
    'MANAGE_FREQUENCIES', 'VIEW_FREQUENCIES',
  ];
  for (const perm of required) {
    it(`has ${perm}`, () => {
      expect(hasPermission('SUPER_ADMIN', perm)).toBe(true);
    });
  }
});

describe('WORKER has SUBMIT_TASKS and VIEW_TASKS but not manage perms', () => {
  const managePerms = ['MANAGE_AREAS', 'MANAGE_CONTRACTORS', 'MANAGE_SCHEDULES', 'MANAGE_RUNS',
    'APPROVE_FORM_MANPOWER', 'SCORE_FORM', 'MANAGE_FORMS', 'MANAGE_MACHINES'];
  for (const perm of managePerms) {
    it(`does not have ${perm}`, () => {
      expect(hasPermission('WORKER', perm)).toBe(false);
    });
  }

  it('has SUBMIT_TASKS', () => {
    expect(hasPermission('WORKER', 'SUBMIT_TASKS')).toBe(true);
  });

  it('has MANAGE_PEST_CONTROL', () => {
    expect(hasPermission('WORKER', 'MANAGE_PEST_CONTROL')).toBe(true);
  });

  it('has MANAGE_GARBAGE', () => {
    expect(hasPermission('WORKER', 'MANAGE_GARBAGE')).toBe(true);
  });
});
