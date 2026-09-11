import { describe, it, expect } from 'vitest';
import fs from 'fs';

/* ==========================================================================
   1. FRD SERVICE METHOD COVERAGE
   ========================================================================== */

describe('Dashboard Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { dashboardService } = await import('../src/services/dashboardService.js');
    const expected = ['getDashboardStats', 'getRailwayDashboardStats', 'getStationDashboard',
      'getUserStats', 'getTrainStats', 'getSupervisorStats', 'getActiveTrains',
      'getActiveWorkers', 'getAllFormsStats'];
    for (const m of expected) {
      expect(typeof dashboardService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Station Attendance Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { stationAttendanceService } = await import('../src/services/stationAttendanceService.js');
    const expected = ['markAttendance', 'markBulkAttendance', 'getShiftAttendance',
      'getPlannedVsActual', 'getMonthlySummary', 'flagAbsences', 'updateAttendance',
      'getWorkerHistory', 'applyLeave', 'approveLeave', 'listLeaves', 'calculateOvertime',
      'exportAttendance'];
    for (const m of expected) {
      expect(typeof stationAttendanceService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Execution Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { executionService } = await import('../src/services/executionService.js');
    const expected = ['createPlan', 'getPlans', 'getPlanById', 'updatePlan', 'submitPlan',
      'approvePlan', 'rejectPlan', 'deletePlan', 'createDailyLog', 'submitDailyLog',
      'approveDailyLog', 'rejectDailyLog', 'getDailyLogs', 'getDailyLogById',
      'updateDailyLog', 'deleteDailyLog'];
    for (const m of expected) {
      expect(typeof executionService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Daily Activity Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { dailyActivityService } = await import('../src/services/dailyActivityService.js');
    const expected = ['createRecord', 'autoGenerateFromSchedule', 'startActivity',
      'completeActivity', 'updateStatus', 'listActivities', 'getById',
      'getMissedActivities', 'getPendingActivities', 'getWorkerActivities',
      'getShiftSummary', 'bulkVerify', 'deleteRecord'];
    for (const m of expected) {
      expect(typeof dailyActivityService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Evidence Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { evidenceService } = await import('../src/services/evidenceService.js');
    const expected = ['getEvidenceTypes', 'uploadEvidence', 'uploadMultipleEvidence',
      'uploadEvidenceBase64', 'getEvidenceById', 'updateEvidence', 'deleteEvidence',
      'searchEvidence', 'archiveEvidence', 'restoreEvidence', 'performArchivalCheck',
      'getStorageAnalytics', 'getPerTrainStorage', 'getPerContractorStorage',
      'getDailyUploadCount', 'performBackup', 'getBackupLogs', 'verifyFace'];
    for (const m of expected) {
      expect(typeof evidenceService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Inspection Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { inspectionService } = await import('../src/services/inspectionService.js');
    const expected = ['createInspection', 'getInspections', 'getInspectionById',
      'updateInspection', 'deleteInspection', 'startInspection', 'submitRatings',
      'approveInspection', 'rejectInspection', 'resubmitInspection', 'getScoreSummary',
      'addDeficiency', 'closeDeficiency', 'verifyDeficiencyClosure',
      'createTemplate', 'listTemplates', 'getTemplateById', 'updateTemplate', 'deleteTemplate'];
    for (const m of expected) {
      expect(typeof inspectionService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Station Feedback Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { stationFeedbackService } = await import('../src/services/stationFeedbackService.js');
    const expected = ['sendOtp', 'verifyOtp', 'submitFeedback', 'moderateFeedback',
      'listFeedback', 'getFeedbackSummary', 'getStationQr'];
    for (const m of expected) {
      expect(typeof stationFeedbackService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Complaint Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { complaintService } = await import('../src/services/complaintService.js');
    const expected = ['createComplaint', 'getComplaints', 'getComplaintById',
      'assignComplaint', 'startProgress', 'resolveComplaint', 'verifyComplaint',
      'closeComplaint', 'reopenComplaint', 'rejectComplaint', 'escalateComplaint',
      'checkSlaBreaches', 'deleteComplaint'];
    for (const m of expected) {
      expect(typeof complaintService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Station Billing Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { stationBillingService } = await import('../src/services/stationBillingService.js');
    const expected = ['generateBillingSupportPack', 'getPackById', 'listPacks',
      'updateCompliance', 'submitPack', 'approvePack', 'rejectPack', 'recordPayment',
      'updatePack', 'deletePack', 'returnToDraft'];
    for (const m of expected) {
      expect(typeof stationBillingService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Machine Service (tracking) - method coverage', () => {
  it('exports expected tracking + CRUD methods', async () => {
    const { machineService } = await import('../src/services/machineService.js');
    const expected = ['createMachine', 'getMachines', 'getMachineById', 'updateMachine',
      'deleteMachine', 'deployMachine', 'returnMachine', 'listDeployments',
      'logDowntime', 'resolveDowntime', 'getDowntimeReport', 'scheduleMaintenance',
      'completeMaintenance', 'listMaintenance'];
    for (const m of expected) {
      expect(typeof machineService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Garbage Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { garbageService } = await import('../src/services/garbageService.js');
    const expected = ['createWasteType', 'listWasteTypes', 'recordCollection',
      'listCollections', 'getCollectionById', 'updateCollection', 'verifyCollection',
      'approveCollection', 'markDisposed', 'rejectCollection', 'getGarbageReport'];
    for (const m of expected) {
      expect(typeof garbageService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Pest Control Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { pestControlService } = await import('../src/services/pestControlService.js');
    const expected = ['createChemical', 'listChemicals', 'stockChemical',
      'createTreatmentPlan', 'listTreatmentPlans', 'getTreatmentPlanById',
      'updateTreatmentPlan', 'reviewTreatmentPlan', 'markTreated',
      'deleteTreatmentPlan', 'getPestReport'];
    for (const m of expected) {
      expect(typeof pestControlService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Scorecard Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { scorecardService } = await import('../src/services/scorecardService.js');
    const expected = ['createDailyScorecard', 'submitScorecard', 'approveScorecard',
      'rejectScorecard', 'autoGenerateFromInspections', 'getDailyScorecards',
      'getMonthlyScorecard', 'getScorecardById', 'updateScorecard', 'deleteScorecard'];
    for (const m of expected) {
      expect(typeof scorecardService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Supervisor Daily Log Service - method coverage', () => {
  it('exports expected methods', async () => {
    const { supervisorDailyLogService } = await import('../src/services/supervisorDailyLogService.js');
    const expected = ['createLog', 'submitLog', 'acknowledgeLog', 'acceptLog',
      'rejectLog', 'returnLog', 'updateLog', 'getLogById', 'listLogs', 'getShiftHandover'];
    for (const m of expected) {
      expect(typeof supervisorDailyLogService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

describe('Station Report Service - method coverage', () => {
  it('exports all report + schedule methods', async () => {
    const { stationReportService } = await import('../src/services/stationReportService.js');
    const expected = ['generateStationCleaningReport', 'getReportById', 'listReports',
      'getStationScoreTrend', 'getStationComparison',
      'generateDailyAttendanceReport', 'generateDailyActivityReport',
      'generateDailyScorecardReport', 'generateDailyComplaintReport',
      'generateDailyFeedbackReport', 'generateDailyInspectionReport',
      'generateDailySupervisorLog', 'generateMissedActivityReport',
      'generateArchiveRetrievalReport',
      'generateMonthlyAttendanceSummary', 'generateMonthlyCleaningSummary',
      'generateMonthlyScorecardReport', 'generateMonthlyComplaintSummary',
      'generateMonthlyFeedbackSummary', 'generateMonthlyBillingReport',
      'generateMonthlyPenaltyReport',
      'generateUserActivityAudit', 'generateImageArchiveReport',
      'generateRejectedFormsReport', 'generateInspectionHistoryReport',
      'generateDataModificationReport',
      'scheduleReport', 'listSchedules', 'deleteSchedule', 'executeScheduledReports',
      'getDailyReportTypes', 'getMonthlyReportTypes', 'getAuditReportTypes'];
    for (const m of expected) {
      expect(typeof stationReportService[m], `Missing: ${m}`).toBe('function');
    }
  });
});

/* ==========================================================================
   2. FRD CONTROLLER EXPORT COVERAGE
   ========================================================================== */

describe('Dashboard Controller - export handlers', () => {
  const expected = ['stats', 'railwayDashboardStats', 'stationDashboard', 'userStats',
    'trainStats', 'supervisorStats', 'activeTrains', 'activeWorkers', 'allFormsStats'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/dashboardController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Station Attendance Controller - export handlers', () => {
  const expected = ['markAttendance', 'markBulkAttendance', 'getShiftAttendance',
    'getPlannedVsActual', 'getMonthlySummary', 'flagAbsences', 'updateAttendance',
    'getWorkerHistory', 'applyLeave', 'approveLeave', 'listLeaves', 'calculateOvertime',
    'exportAttendance'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/stationAttendanceController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Execution Controller - export handlers', () => {
  const expected = ['createPlan', 'listPlans', 'getPlanById', 'updatePlan', 'submitPlan',
    'approvePlan', 'rejectPlan', 'deletePlan', 'createLog', 'listLogs', 'getLogById',
    'updateLog', 'deleteLog', 'submitLog', 'approveLog', 'rejectLog'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/executionController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Daily Activity Controller - export handlers', () => {
  const expected = ['createRecord', 'listActivities', 'getById', 'updateStatus',
    'getMissedActivities', 'getPendingActivities', 'getShiftSummary', 'bulkVerify',
    'deleteRecord', 'autoGenerate', 'startActivity', 'completeActivity', 'getWorkerActivities'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/dailyActivityController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Evidence Controller - export handlers', () => {
  const expected = ['getEvidenceTypes', 'uploadEvidence', 'uploadMultipleEvidence',
    'uploadEvidenceBase64', 'getEvidenceById', 'updateEvidence', 'deleteEvidence',
    'searchEvidence', 'archiveEvidence', 'restoreEvidence', 'performArchivalCheck',
    'verifyFace', 'getStorageAnalytics', 'getPerTrainStorage', 'getPerContractorStorage',
    'getDailyUploadCount', 'performBackup', 'getBackupLogs'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/evidenceController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Inspection Controller - export handlers', () => {
  const expected = ['create', 'list', 'getById', 'update', 'remove', 'start',
    'submitRatings', 'approve', 'reject', 'resubmit', 'scoreSummary',
    'addDeficiency', 'closeDeficiency', 'verifyDeficiency',
    'createTemplate', 'listTemplates', 'getTemplateById', 'updateTemplate', 'deleteTemplate'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/inspectionController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Station Feedback Controller - export handlers', () => {
  const expected = ['sendOtp', 'verifyOtp', 'submit', 'list', 'summary', 'qrCode', 'moderate'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/stationFeedbackController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Complaint Controller - export handlers', () => {
  const expected = ['create', 'list', 'getById', 'assign', 'startProgress', 'resolve',
    'verify', 'close', 'reopen', 'reject', 'escalate', 'checkSla', 'remove'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/complaintController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Machine Controller (tracking) - export handlers', () => {
  const expected = ['create', 'list', 'getById', 'update', 'remove', 'deploy',
    'returnMachine', 'listDeployments', 'logDowntime', 'resolveDowntime',
    'downtimeReport', 'scheduleMaintenance', 'completeMaintenance', 'listMaintenance'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/machineController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Garbage Controller - export handlers', () => {
  const expected = ['createWasteType', 'listWasteTypes', 'record', 'list', 'getById',
    'update', 'verify', 'approve', 'markDisposed', 'rejectCollection', 'report'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/garbageController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Pest Control Controller - export handlers', () => {
  const expected = ['createChemical', 'listChemicals', 'stockChemical', 'createPlan',
    'listPlans', 'getPlanById', 'updatePlan', 'reviewPlan', 'markTreated',
    'deletePlan', 'report'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/pestControlController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Scorecard Controller - export handlers', () => {
  const expected = ['createDaily', 'submit', 'approve', 'reject', 'autoGenerate',
    'list', 'monthly', 'getById', 'update', 'remove'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/scorecardController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Supervisor Daily Log Controller - export handlers', () => {
  const expected = ['createLog', 'updateLog', 'submitLog', 'acknowledgeLog', 'acceptLog',
    'rejectLog', 'returnLog', 'getLogById', 'listLogs', 'getShiftHandover'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/supervisorDailyLogController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

describe('Station Report Controller - export handlers', () => {
  const expected = ['generateReport', 'getReportById', 'listReports', 'getScoreTrend',
    'getStationComparison', 'generateDailyAttendanceReport', 'generateDailyActivityReport',
    'generateDailyScorecardReport', 'generateDailyComplaintReport',
    'generateDailyFeedbackReport', 'generateDailyInspectionReport',
    'generateDailySupervisorLogReport', 'generateMissedActivityReport',
    'generateArchiveRetrievalReport',
    'generateMonthlyAttendanceSummary', 'generateMonthlyCleaningSummary',
    'generateMonthlyScorecardSummary', 'generateMonthlyComplaintSummary',
    'generateMonthlyFeedbackSummary', 'generateMonthlyBillingReport',
    'generateMonthlyPenaltyReport',
    'generateUserActivityAudit', 'generateImageArchiveReport',
    'generateRejectedFormsReport', 'generateInspectionHistoryReport',
    'generateDataModificationReport',
    'scheduleReport', 'listSchedules', 'deleteSchedule', 'executeScheduledReports',
    'getDailyReportTypes', 'getMonthlyReportTypes', 'getAuditReportTypes',
    'dispatchEndOfDayReports', 'dispatchEndOfMonthReports', 'dispatchDailyReport',
    'dispatchMonthlyReport', 'dispatchMissedActivityAlert',
    'dispatchRejectedFormNotification', 'dispatchComplaintEscalation'];
  for (const m of expected) {
    it(`exports ${m}`, async () => {
      const mod = await import('../src/controllers/stationReportController.js');
      expect(typeof mod[m]).toBe('function');
    });
  }
});

/* ==========================================================================
   3. FRD ROUTE FILES EXPORT CORRECTLY
   ========================================================================== */

describe('FRD route files export correctly', () => {
  const routes = [
    ['dashboard', '../src/routes/dashboard.js'],
    ['stationAttendance', '../src/routes/stationAttendance.js'],
    ['execution', '../src/routes/execution.js'],
    ['dailyActivities', '../src/routes/dailyActivities.js'],
    ['evidence', '../src/routes/evidence.js'],
    ['inspection', '../src/routes/inspection.js'],
    ['stationFeedback', '../src/routes/stationFeedback.js'],
    ['complaint', '../src/routes/complaint.js'],
    ['machine', '../src/routes/machine.js'],
    ['stationBilling', '../src/routes/stationBilling.js'],
    ['supervisorDailyLog', '../src/routes/supervisorDailyLog.js'],
    ['stationArchive', '../src/routes/stationArchive.js'],
    ['stationReport', '../src/routes/stationReport.js'],
    ['garbage', '../src/routes/garbage.js'],
    ['pestControl', '../src/routes/pestControl.js'],
    ['scorecard', '../src/routes/scorecard.js'],
  ];
  for (const [name, path] of routes) {
    it(`${name} route exports a router`, async () => {
      const mod = await import(path);
      const router = mod.default;
      expect(router).toBeDefined();
      expect(typeof router).toBe('function');
      expect(router.stack).toBeDefined();
      expect(Array.isArray(router.stack)).toBe(true);
      expect(router.stack.length).toBeGreaterThan(0);
    });
  }
});

/* ==========================================================================
   4. FIELD-SPECIFIC COVERAGE FOR KEY SERVICES
   ========================================================================== */

describe('Station Attendance - markAttendance field coverage', () => {
  it('accepts required fields', async () => {
    const { stationAttendanceService } = await import('../src/services/stationAttendanceService.js');
    const fnStr = stationAttendanceService.markAttendance.toString();
    const fields = ['stationId', 'workerId', 'date', 'shift', 'captureMode', 'latitude', 'longitude'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Station Attendance - applyLeave field coverage', () => {
  it('includes leave-specific fields', async () => {
    const { stationAttendanceService } = await import('../src/services/stationAttendanceService.js');
    const fnStr = stationAttendanceService.applyLeave.toString();
    const fields = ['workerId', 'leaveType', 'startDate', 'endDate', 'reason', 'stationId'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Execution Plan - createPlan field coverage', () => {
  it('accepts required plan fields', async () => {
    const { executionService } = await import('../src/services/executionService.js');
    const fnStr = executionService.createPlan.toString();
    const fields = ['stationId', 'contractId', 'month', 'year', 'manpowerPlan', 'shiftPlan'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Daily Activity - createRecord field coverage', () => {
  it('includes scheduling fields', async () => {
    const { dailyActivityService } = await import('../src/services/dailyActivityService.js');
    const fnStr = dailyActivityService.createRecord.toString();
    const fields = ['stationId', 'areaId', 'activityId', 'date', 'shift', 'assignedWorkers'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Evidence - uploadEvidence field coverage', () => {
  it('includes evidence metadata fields', async () => {
    const { evidenceService } = await import('../src/services/evidenceService.js');
    const fnStr = evidenceService.uploadEvidence.toString();
    const fields = ['trainNumber', 'coach', 'taskId', 'taskType', 'evidenceType', 'gpsLat', 'gpsLng'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Complaint - createComplaint field coverage', () => {
  it('includes complaint-specific fields', async () => {
    const { complaintService } = await import('../src/services/complaintService.js');
    const fnStr = complaintService.createComplaint.toString();
    const fields = ['stationId', 'category', 'severity', 'description', 'area', 'evidence'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Garbage - recordCollection field coverage', () => {
  it('includes waste collection tracking fields', async () => {
    const { garbageService } = await import('../src/services/garbageService.js');
    const fnStr = garbageService.recordCollection.toString();
    const fields = ['stationId', 'wasteType', 'quantityKg', 'segregationStatus', 'disposalAgency', 'vehicleNo'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Pest Control - createTreatmentPlan field coverage', () => {
  it('includes pest treatment fields', async () => {
    const { pestControlService } = await import('../src/services/pestControlService.js');
    const fnStr = pestControlService.createTreatmentPlan.toString();
    const fields = ['stationId', 'area', 'pestType', 'treatmentMethod', 'chemicalIds', 'scheduledDate'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Scorecard - createDailyScorecard field coverage', () => {
  it('includes scorecard-specific fields', async () => {
    const { scorecardService } = await import('../src/services/scorecardService.js');
    const fnStr = scorecardService.createDailyScorecard.toString();
    const fields = ['stationId', 'date', 'areaWiseScores', 'overallStationScore', 'inspectorName'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Supervisor Daily Log - createLog field coverage', () => {
  it('includes log-specific fields', async () => {
    const { supervisorDailyLogService } = await import('../src/services/supervisorDailyLogService.js');
    const fnStr = supervisorDailyLogService.createLog.toString();
    const fields = ['stationId', 'date', 'shift', 'activities', 'workerAttendance', 'materialUsage', 'issues', 'photos'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Station Billing - generateBillingSupportPack field coverage', () => {
  it('includes billing-specific fields', async () => {
    const { stationBillingService } = await import('../src/services/stationBillingService.js');
    const fnStr = stationBillingService.generateBillingSupportPack.toString();
    const fields = ['contractId', 'stationId', 'month', 'year'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Machine Tracking - deployMachine field coverage', () => {
  it('includes deployment-specific fields', async () => {
    const { machineService } = await import('../src/services/machineService.js');
    const fnStr = machineService.deployMachine.toString();
    const fields = ['machineId', 'stationId', 'areaId', 'deployedDate', 'shift'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Machine Tracking - logDowntime field coverage', () => {
  it('includes downtime-specific fields', async () => {
    const { machineService } = await import('../src/services/machineService.js');
    const fnStr = machineService.logDowntime.toString();
    const fields = ['machineId', 'startTime', 'endTime', 'reason', 'downtimeType'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Inspection - createInspection field coverage', () => {
  it('includes inspection-specific fields', async () => {
    const { inspectionService } = await import('../src/services/inspectionService.js');
    const fnStr = inspectionService.createInspection.toString();
    const fields = ['stationId', 'inspectionType', 'scheduledDate', 'templateId', 'inspectorId', 'remarks'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

describe('Inspection - createTemplate field coverage', () => {
  it('includes template-specific fields', async () => {
    const { inspectionService } = await import('../src/services/inspectionService.js');
    const fnStr = inspectionService.createTemplate.toString();
    const fields = ['templateName', 'checklistItems', 'inspectionTypes'];
    for (const f of fields) {
      expect(fnStr, `Missing: ${f}`).toContain(f);
    }
  });
});

/* ==========================================================================
   5. APP.JS - ALL ROUTES MOUNTED
   ========================================================================== */

describe('app.js - all routes mounted', () => {
  it('mounts all 53 route modules', async () => {
    const source = fs.readFileSync('./src/app.js', 'utf8');
    const expected = [
      'authRoutes', 'passengerRoutes', 'usersRoutes', 'entitiesRoutes',
      'contractsRoutes', 'trainsRoutes', 'runInstancesRoutes', 'coachFormsRoutes',
      'premisesFormsRoutes', 'ctsFormsRoutes', 'stationRoutes', 'obhsRoutes',
      'mediaRoutes', 'reportsRoutes', 'dashboardRoutes', 'tasksRoutes',
      'v2Routes', 'billingRoutes', 'cleaningFormRoutes', 'miscRoutes',
      'stationCleaningRoutes', 'notificationsRoutes', 'divisionsRoutes',
      'auditRoutes', 'evidenceRoutes', 'platformRoutes', 'areaRoutes',
      'analyticsRoutes', 'complaintRoutes', 'deploymentRoutes',
      'executionRoutes', 'inspectionRoutes', 'scorecardRoutes', 'shiftRoutes',
      'activityRoutes', 'frequencyRoutes', 'materialRoutes', 'machineRoutes',
      'stationFeedbackRoutes', 'stationAttendanceRoutes', 'dailyActivitiesRoutes',
      'stationBillingRoutes', 'supervisorDailyLogRoutes', 'stationArchiveRoutes',
      'stationReportRoutes', 'garbageRoutes', 'pestControlRoutes',
    ];
    for (const route of expected) {
      expect(source, `Missing mount: ${route}`).toContain(route);
    }
  });
});
