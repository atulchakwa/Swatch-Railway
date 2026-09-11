import swaggerJsdoc from 'swagger-jsdoc';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Swachh Railways API',
      version: '2.0.0',
      description: 'Enterprise Railway Station Cleaning Management System',
      contact: { name: 'Railway IT Team', email: 'it@railway.gov.in' }
    },
    servers: [
      { url: '/', description: 'API server' }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            error: { type: 'string' },
            code: { type: 'string' },
            details: { type: 'string' }
          }
        },
        Pagination: {
          type: 'object',
          properties: {
            count: { type: 'integer' },
            page: { type: 'integer' },
            totalPages: { type: 'integer' }
          }
        },
        User: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            email: { type: 'string', format: 'email' },
            fullName: { type: 'string' },
            mobile: { type: 'string' },
            role: { type: 'string' },
            zone: { type: 'string' },
            division: { type: 'string' },
            entityId: { type: 'string' },
            status: { type: 'string', enum: ['ACTIVE', 'INACTIVE'] }
          }
        },
        Station: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            stationName: { type: 'string' },
            stationCode: { type: 'string' },
            zone: { type: 'string' },
            division: { type: 'string' },
            status: { type: 'string' }
          }
        },
        Inspection: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            stationId: { type: 'string' },
            stationName: { type: 'string' },
            inspectionType: { type: 'string', enum: ['routine', 'random', 'emergency'] },
            scheduledDate: { type: 'string', format: 'date' },
            status: { type: 'string', enum: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'APPROVED', 'REJECTED'] },
            overallScore: { type: 'integer' },
            grade: { type: 'string' }
          }
        },
        Deployment: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            workerId: { type: 'string' },
            workerName: { type: 'string' },
            stationId: { type: 'string' },
            taskId: { type: 'string' },
            shiftId: { type: 'string' },
            status: { type: 'string', enum: ['active', 'inactive'] },
            startDate: { type: 'string', format: 'date' }
          }
        },
        BillingReport: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            contractId: { type: 'string' },
            contractNumber: { type: 'string' },
            month: { type: 'integer' },
            year: { type: 'integer' },
            period: { type: 'string' },
            contractValue: { type: 'number' },
            compositeScore: { type: 'integer' },
            grade: { type: 'string' },
            totalDeduction: { type: 'number' },
            bonus: { type: 'number' },
            finalPayable: { type: 'number' },
            status: { type: 'string', enum: ['PENDING', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED'] }
          }
        },
        BillingConfig: {
          type: 'object',
          properties: {
            contractId: { type: 'string' },
            deductionRate: { type: 'number' },
            performanceWeight: { type: 'number' },
            attendanceWeight: { type: 'number' },
            taskWeight: { type: 'number' },
            feedbackWeight: { type: 'number' },
            bonusRate: { type: 'number' }
          }
        },
        TaskMaster: {
          type: 'object',
          properties: {
            taskCode: { type: 'string' },
            taskName: { type: 'string' },
            taskCategory: { type: 'string' },
            description: { type: 'string' },
            estimatedMinutes: { type: 'integer' },
            defaultPriority: { type: 'integer' },
            active: { type: 'boolean' }
          }
        },
        Machine: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            machineName: { type: 'string' },
            machineType: { type: 'string' },
            serialNumber: { type: 'string' },
            stationId: { type: 'string' },
            workingStatus: { type: 'string', enum: ['working', 'under_maintenance', 'broken', 'retired'] },
            hourlyRate: { type: 'number' },
            dailyRate: { type: 'number' }
          }
        },
        Material: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            materialName: { type: 'string' },
            unit: { type: 'string' },
            stationId: { type: 'string' },
            balance: { type: 'number' },
            reorderLevel: { type: 'number' },
            verificationStatus: { type: 'string' }
          }
        },
        GarbageLog: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            stationId: { type: 'string' },
            collectionTime: { type: 'string' },
            disposalPoint: { type: 'string' },
            wetWaste: { type: 'number' },
            dryWaste: { type: 'number' },
            verificationStatus: { type: 'string', enum: ['pending', 'verified', 'rejected'] },
            collectionLatitude: { type: 'number' },
            collectionLongitude: { type: 'number' },
            tripCost: { type: 'number' },
            wasteDisposalCost: { type: 'number' }
          }
        },
        Complaint: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            stationId: { type: 'string' },
            category: { type: 'string' },
            severity: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
            description: { type: 'string' },
            status: { type: 'string', enum: ['REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'] }
          }
        },
        Notification: {
          type: 'object',
          properties: {
            uid: { type: 'string' },
            userId: { type: 'string' },
            title: { type: 'string' },
            message: { type: 'string' },
            type: { type: 'string' },
            read: { type: 'boolean' },
            createdAt: { type: 'string', format: 'date-time' }
          }
        },
        AuditLog: {
          type: 'object',
          properties: {
            action: { type: 'string' },
            entityType: { type: 'string' },
            entityId: { type: 'string' },
            actorId: { type: 'string' },
            actorName: { type: 'string' },
            ipAddress: { type: 'string' },
            timestamp: { type: 'string', format: 'date-time' }
          }
        },
        LoginRequest: {
          type: 'object',
          required: ['email', 'password'],
          properties: {
            email: { type: 'string', format: 'email', example: 'admin@gmail.com' },
            password: { type: 'string', format: 'password', example: '123456' }
          }
        },
        LoginResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            token: { type: 'string' },
            user: { '$ref': '#/components/schemas/User' }
          }
        }
      }
    },
    security: [{ bearerAuth: [] }],
    tags: [
      { name: 'Auth', description: 'Authentication endpoints' },
      { name: 'Users', description: 'User management' },
      { name: 'Stations', description: 'Station master' },
      { name: 'Platforms', description: 'Platform master' },
      { name: 'Areas', description: 'Area master' },
      { name: 'Frequency', description: 'Frequency configuration' },
      { name: 'Shifts', description: 'Shift management' },
      { name: 'Deployments', description: 'Workforce deployment' },
      { name: 'Geofences', description: 'Geofence management' },
      { name: 'Inspections', description: 'Inspection & scoring' },
      { name: 'Petty Issues', description: 'Petty issue tracking' },
      { name: 'Search', description: 'Global search' },
      { name: 'Billing', description: 'Billing & invoicing' },
      { name: 'Notifications', description: 'In-app notifications' },
      { name: 'Metrics', description: 'Prometheus metrics' },
      { name: 'Activities', description: 'Activity master' },
      { name: 'Machines', description: 'Machine master' },
      { name: 'Materials', description: 'Material/consumable master' },
      { name: 'Pest Control', description: 'Pest & rodent control logs' },
      { name: 'Garbage', description: 'Garbage disposal logs' },
      { name: 'Complaints', description: 'Complaint management' },
      { name: 'Scorecards', description: 'Daily & monthly cleanliness scorecards' },
      { name: 'Execution', description: 'Execution plans & daily logs' },
      { name: 'Task Masters', description: 'Task type configuration master' },
      { name: 'Archival', description: 'Data archival & retrieval' }
    ]
  },
  apis: ['./src/routes/*.js']
};

export const swaggerSpec = swaggerJsdoc(options);
