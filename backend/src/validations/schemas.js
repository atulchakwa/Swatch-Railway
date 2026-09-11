import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().email('Invalid email format').max(255, 'Email too long'),
  password: z.string().min(6, 'Password must be at least 6 characters').max(128, 'Password too long')
});

export const createUserSchema = z.object({
  email: z.string().email('Invalid email format').max(255, 'Email too long'),
  password: z.string().min(6, 'Password must be at least 6 characters').max(128, 'Password too long'),
  fullName: z.string().min(2, 'Full name must be at least 2 characters').max(100, 'Name too long'),
  mobile: z.string().regex(/^\d{10}$/, 'Mobile must be 10 digits').optional().nullable(),
  role: z.string().min(2, 'Role is required').max(50, 'Role too long'),
  zone: z.string().max(100, 'Zone too long').optional().nullable(),
  division: z.string().max(100, 'Division too long').optional().nullable(),
  depot: z.string().max(100, 'Depot too long').optional().nullable(),
  entityId: z.string().max(100, 'Entity ID too long').optional().nullable()
});

export const bulkCreateUsersSchema = z.object({
  users: z.array(z.object({
    email: z.string().email('Invalid email format').max(255, 'Email too long'),
    password: z.string().min(6, 'Password must be at least 6 characters').max(128, 'Password too long'),
    fullName: z.string().min(2, 'Full name must be at least 2 characters').max(100, 'Name too long'),
    role: z.string().min(2, 'Role is required').max(50, 'Role too long'),
    mobile: z.string().regex(/^\d{10}$/, 'Mobile must be 10 digits').optional().nullable(),
    zone: z.string().max(100, 'Zone too long').optional().nullable(),
    division: z.string().max(100, 'Division too long').optional().nullable(),
    depot: z.string().max(100, 'Depot too long').optional().nullable(),
    entityId: z.string().max(100, 'Entity ID too long').optional().nullable()
  })).min(1, 'At least one user is required').max(100, 'Maximum 100 users per request')
});

export const createStationSchema = z.object({
  stationCode: z.string().min(1, 'Station code is required').max(50, 'Station code too long'),
  stationName: z.string().min(1, 'Station name is required').max(200, 'Station name too long'),
  division: z.string().min(1, 'Division is required').max(100, 'Division too long'),
  zone: z.string().min(1, 'Zone is required').max(100, 'Zone too long'),
  address: z.string().max(500, 'Address too long').optional().nullable(),
  category: z.string().max(50, 'Category too long').optional().nullable(),
  stationType: z.string().max(50, 'Station type too long').optional().nullable(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  active: z.boolean().optional()
});

export const createContractSchema = z.object({
  contractNumber: z.string().min(1, 'Contract number is required').max(100, 'Contract number too long'),
  contractName: z.string().min(1, 'Contract name is required').max(200, 'Contract name too long'),
  entityId: z.string().min(1, 'Entity ID is required').max(100, 'Entity ID too long'),
  stationIds: z.array(z.string().min(1)).min(1, 'At least one station is required'),
  startDate: z.string().min(1, 'Start date is required').max(20, 'Invalid date format'),
  endDate: z.string().min(1, 'End date is required').max(20, 'Invalid date format'),
  contractValue: z.number().min(0, 'Contract value must be non-negative').optional(),
  workCategories: z.array(z.string()).optional(),
  billingCycle: z.enum(['monthly', 'quarterly', 'half_yearly', 'yearly']).optional(),
  scoringApplicability: z.boolean().optional(),
  assignedRailwayOfficials: z.array(z.object({
    uid: z.string().optional(),
    name: z.string().optional(),
    designation: z.string().optional(),
    email: z.string().optional()
  })).optional(),
  assignedContractorUsers: z.array(z.object({
    uid: z.string().optional(),
    name: z.string().optional(),
    role: z.string().optional()
  })).optional(),
  status: z.string().max(50).optional()
});

export const createPlatformSchema = z.object({
  stationId: z.string().min(1, 'Station ID is required').max(100),
  platformNumber: z.string().min(1, 'Platform number is required').max(50),
  platformName: z.string().max(200).optional().nullable(),
  surfaceType: z.string().max(100).optional().nullable(),
  length: z.coerce.number().positive().max(1000000).optional().nullable(),
  width: z.coerce.number().positive().max(100000).optional().nullable()
});

export const createAreaSchema = z.object({
  stationId: z.string().min(1, 'Station ID is required').max(100),
  platformId: z.string().max(100).optional().nullable(),
  areaName: z.string().min(1, 'Area name is required').max(200),
  areaType: z.string().max(100).optional().nullable(),
  areaCode: z.string().max(50).optional().nullable(),
  cleaningFrequency: z.enum(['hourly', '2hrs', '4hrs', 'daily']).optional(),
  frequencyTimes: z.union([z.array(z.string().regex(/^\d{2}:\d{2}$/, 'Must be HH:MM')), z.number()]).optional(),
  priority: z.number().min(1).max(5).optional(),
  supervisorId: z.string().max(100).optional().nullable(),
  defaultWorkers: z.array(z.string()).optional(),
  defaultShift: z.enum(['morning', 'afternoon', 'night']).optional(),
  qrCode: z.string().max(500).optional().nullable(),
  areaSqft: z.number().positive().max(1000000).optional().nullable(),
  surfaceType: z.string().max(100).optional().nullable(),
  section: z.string().max(50).optional().nullable(),
  sectionName: z.string().max(200).optional().nullable(),
  mainArea: z.string().max(200).optional().nullable(),
  basicAreaSqFt: z.number().nonnegative().max(10000000).optional().nullable(),
  frequencyType: z.enum(['daily', 'monthly', 'weekly']).optional().nullable(),
  boqTimesPerPeriod: z.number().int().positive().optional().nullable(),
  tenderedAreaPerDay: z.number().nonnegative().optional().nullable()
}).passthrough();

export const createShiftSchema = z.object({
  stationId: z.string().min(1, 'Station ID is required').max(100),
  shiftType: z.string().min(1, 'Shift type is required').max(50),
  startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Start time must be HH:MM format'),
  endTime: z.string().regex(/^\d{2}:\d{2}$/, 'End time must be HH:MM format')
});

export const createGeofenceSchema = z.object({
  stationId: z.string().min(1, 'Station ID is required').max(100),
  name: z.string().min(1, 'Name is required').max(200),
  centerLatitude: z.number().min(-90).max(90, 'Latitude must be between -90 and 90'),
  centerLongitude: z.number().min(-180).max(180, 'Longitude must be between -180 and 180'),
  radiusMeters: z.number().positive('Radius must be positive'),
  type: z.string().optional().nullable(),
  platformId: z.string().optional().nullable()
});

export const markAttendanceSchema = z.object({
  runInstanceId: z.string().min(1, 'Run instance ID is required'),
  attendanceType: z.enum(['start', 'mid', 'end'], 'Attendance type must be start, mid, or end'),
  imageUrl: z.string().url('Image URL must be a valid URL'),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  deviceTimestamp: z.string().min(1, 'Device timestamp is required'),
  mobileNumber: z.string().optional().nullable(),
  deviceId: z.string().optional().nullable(),
  geofenceOverride: z.boolean().optional()
});

export const billingConfigSchema = z.object({
  contractId: z.string().min(1, 'Contract ID is required'),
  deductionRate: z.number().min(0).max(100, 'Deduction rate must be 0-100').optional(),
  performanceWeight: z.number().min(0).max(100, 'Weight must be 0-100').optional(),
  attendanceWeight: z.number().min(0).max(100, 'Weight must be 0-100').optional(),
  taskWeight: z.number().min(0).max(100, 'Weight must be 0-100').optional(),
  feedbackWeight: z.number().min(0).max(100, 'Weight must be 0-100').optional(),
  bonusRate: z.number().min(0).max(100, 'Bonus rate must be 0-100').optional()
});

export const createDeploymentSchema = z.object({
  workerId: z.string().min(1, 'Worker ID is required'),
  stationId: z.string().min(1, 'Station ID is required'),
  taskId: z.string().min(1, 'Task ID is required'),
  shiftId: z.string().min(1, 'Shift ID is required'),
  platformId: z.string().optional().nullable(),
  areaId: z.string().optional().nullable(),
  supervisorId: z.string().optional().nullable(),
  startDate: z.string().optional().nullable(),
  endDate: z.string().optional().nullable()
});

export const createMachineSchema = z.object({
  machineName: z.string().min(1, 'Machine name is required'),
  machineType: z.string().min(1, 'Machine type is required'),
  serialNumber: z.string().min(1, 'Serial number is required'),
  stationId: z.string().min(1, 'Station ID is required'),
  location: z.string().optional().nullable(),
  workingStatus: z.enum(['working', 'under_maintenance', 'broken', 'retired']).optional(),
  maintenanceSchedule: z.string().optional().nullable(),
  hourlyRate: z.number().min(0).optional().nullable(),
  dailyRate: z.number().min(0).optional().nullable(),
  downtimeEntry: z.object({
    downtimeDate: z.string().optional(),
    downtimeReason: z.string().optional(),
    estimatedRepairDate: z.string().optional(),
    actualRepairDate: z.string().optional()
  }).optional().nullable(),
  replacementStatus: z.enum(['none', 'requested', 'approved', 'replaced']).optional(),
  remarks: z.string().max(500).optional().nullable()
});

export const createMaterialSchema = z.object({
  materialName: z.string().min(1, 'Material name is required'),
  materialType: z.string().min(1, 'Material type is required'),
  unit: z.string().min(1, 'Unit is required'),
  stationId: z.string().optional().nullable(),
  openingBalance: z.number().min(0).optional(),
  monthlyRequirement: z.number().min(0).optional(),
  reorderLevel: z.number().min(0).optional(),
  unitPrice: z.number().min(0).optional().nullable(),
  remarks: z.string().max(500).optional().nullable()
});

export const paginationSchema = z.object({
  page: z.string().optional(),
  limit: z.string().optional(),
  cursor: z.string().optional()
});
