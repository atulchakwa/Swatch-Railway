import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import swaggerUi from 'swagger-ui-express';

import authRoutes from './routes/auth.js';
import passengerRoutes from './routes/passenger.js';
import passengerServiceRequestRoutes from './routes/passengerServiceRequest.js';
import usersRoutes from './routes/users.js';
import entitiesRoutes from './routes/entities.js';
import contractsRoutes from './routes/contracts.js';
import trainsRoutes from './routes/trains.js';
import runInstancesRoutes from './routes/runInstances.js';
import coachFormsRoutes from './routes/coachForms.js';
import premisesFormsRoutes from './routes/premisesForms.js';
import ctsFormsRoutes from './routes/ctsForms.js';
import stationRoutes from './routes/station.js';
import obhsRoutes from './routes/obhs.js';
import mediaRoutes from './routes/media.js';
import reportsRoutes from './routes/reports.js';
import dashboardRoutes from './routes/dashboard.js';
import tasksRoutes from './routes/tasks.js';
import v2Routes from './routes/v2.js';
import billingRoutes from './routes/billing.js';
import cleaningFormRoutes from './routes/cleaningForm.js';
import miscRoutes from './routes/misc.js';
import stationCleaningRoutes from './routes/stationCleaning.js';
import notificationsRoutes from './routes/notifications.js';
import divisionsRoutes from './routes/divisions.js';
import auditRoutes from './routes/audit.js';
import evidenceRoutes from './routes/evidence.js';
import platformRoutes from './routes/platform.js';
import areaRoutes from './routes/area.js';
import areaAssignmentRoutes from './routes/areaAssignments.js';
import tasksV2Routes from './routes/tasksV2.js';
import analyticsRoutes from './routes/analytics.js';
import complaintRoutes from './routes/complaint.js';
import deploymentRoutes from './routes/deployment.js';
import executionRoutes from './routes/execution.js';
import inspectionRoutes from './routes/inspection.js';
import scorecardRoutes from './routes/scorecard.js';
import shiftRoutes from './routes/shift.js';
import activityRoutes from './routes/activity.js';
import frequencyRoutes from './routes/frequency.js';
import materialRoutes from './routes/material.js';
import machineRoutes from './routes/machine.js';
import stationFeedbackRoutes from './routes/stationFeedback.js';
import stationAttendanceRoutes from './routes/stationAttendance.js';
import dailyActivitiesRoutes from './routes/dailyActivities.js';
import stationBillingRoutes from './routes/stationBilling.js';
import supervisorDailyLogRoutes from './routes/supervisorDailyLog.js';
import stationArchiveRoutes from './routes/stationArchive.js';
import stationReportRoutes from './routes/stationReport.js';
import garbageRoutes from './routes/garbage.js';
import pestControlRoutes from './routes/pestControl.js';
import zoneRoutes from './routes/zone.js';
import taskTypeRoutes from './routes/taskType.js';
import geofenceRoutes from './routes/geofence.js';
import idleAlertRoutes from './routes/idleAlert.js';
import { notFoundHandler, errorHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';
import { metricsMiddleware, metricsHandler } from './middleware/metrics.js';
import { swaggerSpec } from './config/swagger.js';

const app = express();

// ─── CORS MUST come before helmet ───────────────────────────────────────────
// cors() middleware - allow ALL origins for Flutter web + APK
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  credentials: false,
}));

// Handle all OPTIONS preflight requests immediately
app.options('*', (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-Requested-With,Accept');
  res.status(204).end();
});

// Safety net: explicitly set ACAO on every response
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-Requested-With,Accept');
  next();
});

// Helmet AFTER cors - disable crossOriginResourcePolicy so CORS headers pass through
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(compression());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(requestLogger);
app.use(metricsMiddleware);

// API Documentation
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Metrics endpoint
app.get('/metrics', metricsHandler);

app.get('/', (req, res) => res.send('Swachh Railways API is running.'));

// Mount all route modules
app.use(authRoutes);                              // /api/auth/*
app.use(usersRoutes);                             // /api/users/*
app.use(entitiesRoutes);                          // /api/contractors/* /api/master/* /api/admin/*
app.use(contractsRoutes);                         // /api/contracts/*
app.use(trainsRoutes);                            // /api/trains/*
app.use(obhsRoutes);                              // /api/obhs/* /api/verifyFace /api/compareFace
app.use(reportsRoutes);                           // /api/reports/*
app.use(stationCleaningRoutes);                   // /api/station-area/* /api/station-zone/* etc.
app.use(notificationsRoutes);                     // /api/notifications/*
app.use(divisionsRoutes);                         // /api/divisions/*
app.use(auditRoutes);                             // /api/audit/*
app.use(evidenceRoutes);                          // /api/evidence/*
app.use(analyticsRoutes);                         // /api/analytics/*
app.use(platformRoutes);                          // /api/platforms/*
app.use(areaRoutes);                              // /api/areas/*
app.use(areaAssignmentRoutes);                    // /api/area-assignments/*
app.use(tasksV2Routes);                           // /api/tasks/* (v2 task management)
app.use(complaintRoutes);                         // /api/complaints/*
app.use(deploymentRoutes);                        // /api/deployments/*
app.use(executionRoutes);                         // /api/execution-plans/*
app.use(inspectionRoutes);                        // /api/inspections/*
app.use(scorecardRoutes);                         // /api/scorecards/*
app.use(shiftRoutes);                             // /api/shifts/*
app.use(activityRoutes);                          // /api/activities/*
app.use(frequencyRoutes);                         // /api/frequencies/*
app.use(materialRoutes);                          // /api/materials/*
app.use(machineRoutes);                           // /api/machines/*
app.use(stationFeedbackRoutes);                   // /api/station-feedback/*
app.use(stationAttendanceRoutes);                 // /api/station-attendance/*
app.use(dailyActivitiesRoutes);                   // /api/station-activities/*
app.use(stationBillingRoutes);                    // /api/station-billing/*
app.use(supervisorDailyLogRoutes);                // /api/supervisor-logs/*
app.use(stationArchiveRoutes);                    // /api/station-archives/*
app.use(stationReportRoutes);                     // /api/station-reports/*
app.use(garbageRoutes);                             // /api/garbage/*
app.use(pestControlRoutes);                         // /api/pest-control/*
app.use(zoneRoutes);                                // /api/zones/*
app.use(taskTypeRoutes);                            // /api/task-types/*
app.use(geofenceRoutes);                            // /api/geofences/* /api/geofence-alerts/*
app.use(idleAlertRoutes);                           // /api/idle-alerts/*

// Relative-path routes mounted with base prefixes
app.use('/api/passenger', passengerRoutes);       // /api/passenger/*
app.use(passengerServiceRequestRoutes);                        // /api/passenger-service-requests/*
app.use('/api/public/passenger', passengerRoutes); // Hack for legacy public endpoint
app.use('/api/run-instances', runInstancesRoutes); // Legacy
app.use('/api/runInstances', runInstancesRoutes);
app.use('/api/coach-forms', coachFormsRoutes);    // /api/coach-forms/*
app.use('/api/premises-forms', premisesFormsRoutes); // /api/premises-forms/*
app.use('/api/cts', ctsFormsRoutes);              // Hack for /api/cts/create-emergency-task
app.use('/api/cts-forms', ctsFormsRoutes);        // /api/cts-forms/*
app.use('/api/stations', stationRoutes);          // /api/stations/*
app.use('/api/media', mediaRoutes);               // /api/media/*
app.use('/api/tasks', tasksRoutes);               // /api/tasks/*
app.use('/api/v2', v2Routes);                     // /api/v2/*
app.use('/api/billing', billingRoutes);           // /api/billing/*
app.use('/api/cleaning-form', cleaningFormRoutes);  // Legacy
app.use('/api/cleaning-forms', cleaningFormRoutes); // /api/cleaning-forms/*
app.use(dashboardRoutes);                         // /api/dashboard/stats /api/railway-dashboard-stats
app.use(miscRoutes);                              // /api/health /api/divisions /api/zones etc.

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
