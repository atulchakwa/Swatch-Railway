import { db, admin } from '../database/index.js';
import { ValidationError, NotFoundError, ForbiddenError, ConflictError } from '../errors/index.js';
import { BaseRepository } from '../repositories/BaseRepository.js';
import { safeFormat } from '../utils/helpers.js';

class UserService {
  async createUser(creatorData, userData) {
    const { email, password, role, userType, fullName, designation, mobile, zone, division, depot, entityId, trainId, trainIds, worker_type, stationId, platformId, areaId } = userData;
    const normalizedEmail = email ? email.trim().toLowerCase() : null;
    const { uid: creatorId, name, fullName: creatorNameAuth, role: creatorRole } = creatorData;
    const creatorName = creatorNameAuth || name || creatorRole || 'Admin';

    if (!email || !password || !role || !userType) {
      throw new ValidationError("Email, Password, Role, and UserType are required.");
    }

    const emailQuery = await db.collection('users').where('email', '==', normalizedEmail).limit(1).get();
    if (!emailQuery.empty) {
      throw new ValidationError("Email already registered.");
    }

    if (mobile) {
      const mobileQuery = await db.collection('users').where('mobile', '==', mobile).limit(1).get();
      if (!mobileQuery.empty) {
        throw new ValidationError("Mobile Number already registered.");
      }
    }

    const roleUpper = role.toUpperCase();
    if (roleUpper === 'CTS' || roleUpper === 'CONTRACTOR SUPERVISOR') {
      if (!division || !trainId) {
        throw new ValidationError("Division and Train ID are mandatory for Contractor Supervisor.");
      }
      if (trainIds && trainIds.length > 1) {
        throw new ValidationError("Contractor Supervisor can only be mapped to ONE train.");
      }
    }

    if (roleUpper === 'RAILWAY SUPERVISOR') {
      if (!division || (!trainId && (!trainIds || trainIds.length === 0))) {
        throw new ValidationError("Division and at least one Train ID are mandatory for Railway Supervisor.");
      }
    }

    if (roleUpper === 'STATION_MASTER') {
      if (!stationId) {
        throw new ValidationError("stationId is mandatory for Station Master.");
      }
    }

    if (roleUpper === 'PLATFORM_MASTER') {
      if (!areaId) {
        throw new ValidationError("areaId is mandatory for Platform Master.");
      }
      if (!platformId) {
        throw new ValidationError("platformId is mandatory for Platform Master.");
      }
      if (!stationId) {
        throw new ValidationError("stationId is mandatory for Platform Master.");
      }
    }

    const normalizedUserType = userType.toLowerCase();
    const isWorkerRole = roleUpper.includes('WORKER') || roleUpper === 'JANITOR' || roleUpper === 'ATTENDANT';
    if (isWorkerRole) {
      const explicitWorkerType = worker_type || (roleUpper === 'JANITOR' ? 'Janitor' : (roleUpper === 'ATTENDANT' ? 'Attendant' : null));
      if (!explicitWorkerType || !['Janitor', 'Attendant'].includes(explicitWorkerType)) {
        throw new ValidationError("Invalid worker category. Only 'Janitor' and 'Attendant' categories are permitted for workers.");
      }
      userData.worker_type = explicitWorkerType; // ensure it is set correctly
    }

    let entityData = null;
    if (normalizedUserType === 'contractor') {
      if (!entityId) {
        throw new ValidationError("Contractor users must have an 'entityId' (Company ID).");
      }
      const entityDoc = await db.collection('entities').doc(entityId).get();
      if (!entityDoc.exists) {
        throw new NotFoundError("Entity (Company) not found.");
      }
      entityData = entityDoc.data();
      const userRoleLower = role.toLowerCase().replace(/_/g, " ");
      if ((!userRoleLower.includes("super admin") && userRoleLower.includes("admin")) || userRoleLower.includes('supervisor')) {
        if (!zone || !division) {
          throw new ValidationError("Zone and Division are mandatory to check Active Contracts.");
        }
        console.log(`(CreateUser) Checking Active Contract for Entity: ${entityId}`);
        const contractSnapshot = await db.collection('contracts')
          .where('entityId', '==', entityId)
          .get();
          
        const invalidStatuses = ['Expired', 'EXPIRED', 'REJECTED', 'rejected', 'SUSPENDED', 'suspended'];
        const hasValidContract = contractSnapshot.docs.some(doc => {
          const d = doc.data();
          return !invalidStatuses.includes(d.status) && d.zone === zone && d.division === division;
        });

        if (!hasValidContract) {
          throw new ForbiddenError(`Cannot create ${role}. No valid Contract found for this Company in Zone: ${zone}, Division: ${division}. Please ensure a contract exists and is not expired or rejected.`);
        }
      }
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({ email: normalizedEmail, password, displayName: fullName, disabled: false });
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        throw new ValidationError("Email is already in use (Auth).");
      }
      throw error;
    }

    const newUid = userRecord.uid;
      const lowerCreatorRole = (creatorRole || '').toLowerCase();
      // Ensure all users go for approval, even if created by a super admin
      const initialStatus = 'PENDING';

      await db.collection('users').doc(newUid).set({
        uid: newUid,
        email: normalizedEmail,
        password,
        role,
        userType: normalizedUserType,
        fullName: fullName || null,
        mobile: mobile || null,
        designation: designation || null,
        zone: zone || null,
        division: division || null,
        depot: depot || null,
        entityId: entityId || null,
        entityDetails: entityData,
        trainId: trainId || null,
        trainIds: trainIds || (trainId ? [trainId] : []),
        worker_type: worker_type || null,
        stationId: stationId || null,
        platformId: platformId || null,
        areaId: areaId || null,
        createdBy: creatorId,
        createdByName: creatorName,
        status: initialStatus,
        createdAt: new Date().toISOString(),
        submitted_at: new Date().toISOString()
      });

      console.log(`(Admin) User Created: ${fullName} by ${creatorName} with status ${initialStatus}`);
    return { message: 'User created successfully.', uid: newUid };
  }

  async updateUser(editorData, uid, updates) {
    const { fullName, designation, mobile, zone, division, depot, role, userType, password, entityId, trainId, trainIds, worker_type, stationId, platformId, areaId } = updates;
    const { uid: editorId, name, fullName: editorAuthName, role: editorRole } = editorData;
    const editorName = editorAuthName || name || editorRole || 'Admin';

    if (!uid) {
      throw new ValidationError("User ID is required.");
    }

    const userDocRef = db.collection('users').doc(uid);
    const doc = await userDocRef.get();
    if (!doc.exists) {
      throw new NotFoundError("User not found.");
    }

    const currentData = doc.data();
    const targetUserName = fullName || currentData.fullName || 'Unknown User';
    const finalRole = role || currentData.role;
    const finalRoleUpper = finalRole ? finalRole.toUpperCase() : '';
    const finalDivision = division || currentData.division;
    const finalTrainId = trainId || currentData.trainId;
    const finalTrainIds = trainIds || currentData.trainIds;

    if (finalRoleUpper === 'CTS' || finalRoleUpper === 'CONTRACTOR SUPERVISOR') {
      if (!finalDivision || !finalTrainId) {
        throw new ValidationError("Division and Train ID are mandatory for Contractor Supervisor.");
      }
      if (Array.isArray(finalTrainId) || (finalTrainIds && finalTrainIds.length > 1)) {
        throw new ValidationError("Contractor Supervisor can only be mapped to ONE train.");
      }
    }

    if (finalRoleUpper === 'RAILWAY SUPERVISOR') {
      if (!finalDivision || (!finalTrainId && (!finalTrainIds || finalTrainIds.length === 0))) {
        throw new ValidationError("Division and at least one Train ID are mandatory for Railway Supervisor.");
      }
    }

    const updateData = {};
    if (fullName !== undefined) updateData.fullName = fullName;
    if (designation !== undefined) updateData.designation = designation;
    if (mobile !== undefined) updateData.mobile = mobile;
    if (zone !== undefined) updateData.zone = zone;
    if (division !== undefined) updateData.division = division;
    if (depot !== undefined) updateData.depot = depot;
    if (role !== undefined) updateData.role = role;
    if (userType !== undefined) updateData.userType = userType.toLowerCase();
    if (trainId !== undefined) updateData.trainId = trainId;
    if (trainIds !== undefined) updateData.trainIds = trainIds;
    if (worker_type !== undefined) {
      if (!['Janitor', 'Attendant'].includes(worker_type)) {
        throw new ValidationError("Invalid worker category. Only 'Janitor' and 'Attendant' categories are permitted for workers.");
      }
      updateData.worker_type = worker_type;
    }
    if (stationId !== undefined) updateData.stationId = stationId;
    if (platformId !== undefined) updateData.platformId = platformId;
    if (areaId !== undefined) updateData.areaId = areaId;
    updateData.status = 'PENDING';
    updateData.updatedAt = new Date().toISOString();
    updateData.updatedBy = editorId;
    updateData.updatedByName = editorName;

    if (password) {
      try {
        await admin.auth().updateUser(uid, { password });
        console.log(`(Admin) Password updated for user: ${uid}`);
      } catch (authError) {
        console.error('Error updating password in Auth:', authError);
        throw new ValidationError("Failed to update password. Password must be strong.");
      }
    }

    if (entityId !== undefined) {
      updateData.entityId = entityId;
      if (entityId) {
        const entityDoc = await db.collection('entities').doc(entityId).get();
        if (!entityDoc.exists) {
          throw new NotFoundError("Entity (Company) not found with this ID.");
        }
        updateData.entityDetails = entityDoc.data();
      } else {
        updateData.entityDetails = null;
      }
    }

    if (Object.keys(updateData).length === 0 && !password) {
      throw new ValidationError("No fields to update provided.");
    }

    await userDocRef.update(updateData);
    console.log(`(Admin) User "${targetUserName}" updated by ${editorName}.`);
    return { message: `User "${targetUserName}" has been updated successfully.`, updates: updateData };
  }

  async approveUser(approverData, uid) {
    const { uid: approverId, name, fullName, role } = approverData;
    const approverName = fullName || name || role || 'Master Admin';

    if (!uid) {
      throw new ValidationError("User ID is required.");
    }

    const userDocRef = db.collection('users').doc(uid);
    const doc = await userDocRef.get();
    if (!doc.exists) {
      throw new NotFoundError("User not found.");
    }

    const userData = doc.data();
    const userName = userData.fullName || "User";

    await userDocRef.update({
      status: 'APPROVED',
      approvedBy: approverId,
      approvedByName: approverName,
      approvedAt: new Date().toISOString(),
      approved_at: null,
      rejectedBy: null,
      rejectedByName: null,
      rejectedAt: null
    });

    console.log(`(Master) User ${userName} (${uid}) APPROVED by ${approverName}.`);
    return { message: `User ${userName} has been approved successfully.`, approvedBy: approverName };
  }

  async getPendingUsers() {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('status', '==', 'PENDING').limit(200).get();

    if (snapshot.empty) {
      return { count: 0, users: [], message: 'No pending users found.' };
    }

    const pendingUsers = [];
    snapshot.forEach(doc => {
      const userData = doc.data();
      delete userData.password;
      userData.createdAt = safeFormat(userData.createdAt);
      userData.submitted_at = safeFormat(userData.submitted_at);
      pendingUsers.push({ ...userData, uid: doc.id });
    });

    console.log(`(Master) Fetched ${pendingUsers.length} pending users.`);
    return { count: pendingUsers.length, users: pendingUsers };
  }

  async rejectUser(rejectorData, uid) {
    const { uid: adminId, name, fullName, role } = rejectorData;
    const adminName = fullName || name || role || 'Master Admin';

    if (!uid) {
      throw new ValidationError("User ID is required.");
    }

    const userDocRef = db.collection('users').doc(uid);
    const doc = await userDocRef.get();
    if (!doc.exists) {
      throw new NotFoundError("User not found.");
    }

    const userData = doc.data();
    const userName = userData.fullName || "User";

    await userDocRef.update({
      status: 'REJECTED',
      rejectedBy: adminId,
      rejectedByName: adminName,
      rejectedAt: new Date().toISOString(),
      updatedBy: adminId,
      updatedByName: adminName,
      updatedAt: new Date().toISOString(),
      approvedBy: null,
      approvedByName: null,
      approvedAt: null,
      approved_at: null,
      suspendedBy: null,
      suspendedByName: null,
      suspendedAt: null,
      suspended_at: null,
      reviewed_at: null
    });

    console.log(`(Master) User ${userName} (${uid}) REJECTED by ${adminName}.`);
    return { message: `User ${userName} has been rejected.`, rejectedBy: adminName };
  }

  async suspendUser(adminData, uid, reason) {
    const { uid: adminId, name, fullName, role } = adminData;
    const adminName = fullName || name || role || 'Admin';

    if (!uid) {
      throw new ValidationError("User ID is required.");
    }

    const userDocRef = db.collection('users').doc(uid);
    const doc = await userDocRef.get();
    if (!doc.exists) {
      throw new NotFoundError("User not found.");
    }

    const userData = doc.data();
    if (userData.status !== 'APPROVED') {
      throw new ValidationError(`Cannot suspend a user with status: ${userData.status}`);
    }

    const suspensionReason = reason || 'No reason provided';

    await userDocRef.update({
      status: 'SUSPENDED',
      suspensionReason,
      suspendedBy: adminId,
      suspendedByName: adminName,
      suspendedAt: new Date().toISOString(),
      updatedBy: adminId,
      updatedByName: adminName,
      updatedAt: new Date().toISOString(),
      approvedBy: null,
      approvedByName: null,
      approvedAt: null,
      approved_at: null,
      rejectedBy: null,
      rejectedByName: null,
      rejectedAt: null,
      suspended_at: null
    });

    console.log(`(Admin) User ${userData.fullName} (${uid}) SUSPENDED by ${adminName}.`);
    return { message: `User ${userData.fullName} has been suspended.`, suspendedBy: adminName };
  }

  async getUsers(requesterData, filters) {
    const { status: filterStatus, division, zone, depot } = filters;
    const { uid: requesterUid, role, zone: userZone, division: userDivision } = requesterData;
    const userRole = (role || "").trim().toUpperCase().replace(/\s+/g, '_');

    const ROLE_HIERARCHY = {
      'SUPER_ADMIN': 100, 'COMPANY_MASTER': 90, 'RAILWAY_MASTER': 80,
      'ADMIN': 70, 'RAILWAY_ADMIN': 60, 'STATION_MASTER': 55,
      'RAILWAY_SUPERVISOR': 50, 'AREA_MASTER': 48, 'CONTRACTOR_ADMIN': 45,
      'CONTRACTOR_SUPERVISOR': 40, 'PLATFORM_MASTER': 35, 'CTS': 30,
      'WORKER': 10, 'RAILWAY_WORKER': 10, 'JANITOR': 10, 'ATTENDANT': 10, 'PASSENGER': 1
    };
    const requesterLevel = ROLE_HIERARCHY[userRole] || 0;

    let query = db.collection('users');

    if (requesterLevel >= 70) {
      if (zone) query = query.where('zone', '==', zone);
      if (division) query = query.where('division', '==', division);
    } else if (requesterLevel >= 60) {
      query = query.where('zone', '==', userZone);
      if (division) query = query.where('division', '==', division);
    } else {
      query = query.where('division', '==', userDivision);
    }

    const snapshot = await query.limit(5000).get();
    let userList = [];
    let stats = { pending: 0, approved: 0, rejected: 0 };

    snapshot.forEach(doc => {
      const d = doc.data();
      const targetRole = (d.role || '').toUpperCase().replace(/\s+/g, '_');
      const targetLevel = ROLE_HIERARCHY[targetRole] || 0;
      
      if (doc.id === requesterUid) return;

      if (targetLevel > requesterLevel) return;

      const s = (d.status || '').toUpperCase();
      if (s === 'PENDING') stats.pending++;
      if (s === 'APPROVED') stats.approved++;
      if (s === 'REJECTED') stats.rejected++;

      if (filterStatus) {
        if (s === filterStatus.toUpperCase()) {
          userList.push({ ...d, uid: doc.id });
        }
      } else {
        userList.push({ ...d, uid: doc.id });
      }
    });

    return { success: true, count: userList.length, stats, users: userList };
  }

  async getRailwayWorkers(requesterData, filters) {
    const { status: filterStatus, division, zone } = filters;
    const { role: requesterRole, zone: requesterZone, division: requesterDivision } = requesterData;
    const userRole = (requesterRole || '').trim().toUpperCase().replace(/\s+/g, '_');

    const ROLE_HIERARCHY = {
      'SUPER_ADMIN': 100, 'COMPANY_MASTER': 90, 'RAILWAY_MASTER': 80,
      'ADMIN': 70, 'RAILWAY_ADMIN': 60, 'STATION_MASTER': 55,
      'RAILWAY_SUPERVISOR': 50, 'AREA_MASTER': 48, 'CONTRACTOR_ADMIN': 45,
      'CONTRACTOR_SUPERVISOR': 40, 'PLATFORM_MASTER': 35, 'CTS': 30,
      'WORKER': 10, 'RAILWAY_WORKER': 10, 'JANITOR': 10, 'ATTENDANT': 10, 'PASSENGER': 1
    };
    const requesterLevel = ROLE_HIERARCHY[userRole] || 0;

    console.log(`[GET /api/admin/railway-workers] userRole: ${userRole}, requesterDivision: ${requesterDivision}`);

    let query = db.collection('users');

    if (requesterLevel >= 70) {
      if (zone) query = query.where('zone', '==', zone);
      if (division) query = query.where('division', '==', division);
    } else if (requesterLevel >= 60 || userRole === 'CONTRACTOR_MASTER') {
      if (requesterZone) query = query.where('zone', '==', requesterZone);
      if (division) query = query.where('division', '==', division);
    } else {
      if (requesterDivision) {
        query = query.where('division', '==', requesterDivision);
      } else if (requesterZone) {
        query = query.where('zone', '==', requesterZone);
      }
    }

    let snapshot = await query.get();
    console.log(`[GET /api/admin/railway-workers] Firestore query returned ${snapshot.size} users`);

    if (snapshot.empty && requesterLevel < 70) {
      if (requesterZone) {
        console.log(`[GET /api/admin/railway-workers] Initial query was empty. Trying zone fallback: ${requesterZone}`);
        let fallbackQuery = db.collection('users').where('zone', '==', requesterZone);
        if (requesterData.userType === 'contractor' && requesterData.entityId) {
          fallbackQuery = fallbackQuery.where('entityId', '==', requesterData.entityId);
        }
        snapshot = await fallbackQuery.get();
        console.log(`[GET /api/admin/railway-workers] Zone fallback query returned ${snapshot.size} users`);
      }
    }

    let workerList = [];
    let stats = { pending: 0, approved: 0, rejected: 0 };
    const validRoles = ['worker', 'railway worker', 'janitor', 'attendant', 'contractor worker', 'obhs staff', 'staff'];

    snapshot.forEach(doc => {
      const d = doc.data();
      const r = (d.role || '').toLowerCase();
      if (!validRoles.includes(r)) return;

      const s = (d.status || '').toUpperCase();
      if (s === 'PENDING') stats.pending++;
      if (s === 'APPROVED') stats.approved++;
      if (s === 'REJECTED') stats.rejected++;

      if (filterStatus) {
        if (s === filterStatus.toUpperCase()) {
          workerList.push({ ...d, uid: doc.id });
        }
      } else {
        workerList.push({ ...d, uid: doc.id });
      }
    });

    return { success: true, count: workerList.length, stats, workers: workerList };
  }

  async getWorkerProfile(uid) {
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new NotFoundError('Worker profile not found.');
    }

    const userData = userDoc.data();

    const allRunsSnapshot = await db.collection('RunInstance')
      .where('status', 'in', ['PLANNED', 'ALLOCATED', 'READY', 'Active', 'ACTIVE', 'active', 'Scheduled', 'scheduled', 'Running', 'running'])
      .limit(200).get();

    let assignedRuns = [];
    allRunsSnapshot.forEach(doc => {
      const runData = doc.data();
      const assignedCoach = runData.coaches.find(c => c.workerId === uid);
      if (assignedCoach) {
        assignedRuns.push({
          runInstanceId: runData.runInstanceId,
          instanceId: runData.instanceId,
          trainNo: runData.trainNo,
          trainName: runData.trainName,
          departureDate: runData.departureDate,
          outboundTrainNo: runData.outboundTrainNo,
          inboundTrainNo: runData.inboundTrainNo,
          status: runData.status,
          myCoach: {
            coachPosition: assignedCoach.coachPosition,
            coachType: assignedCoach.coachType,
            attendanceStatus: assignedCoach.attendanceStatus
          }
        });
      }
    });

    assignedRuns.sort((a, b) => new Date(b.departureDate) - new Date(a.departureDate));

    return {
      success: true,
      profile: {
        fullName: userData.fullName,
        email: userData.email,
        mobile: userData.mobile,
        designation: userData.designation,
        division: userData.division,
        zone: userData.zone,
        status: userData.status,
        uid: userData.uid,
        userType: userData.userType
      },
      assignedRuns
    };
  }

  async getWorkerStatistics(uid) {
    const now = new Date();
    const runsSnapshot = await db.collection('RunInstance')
      .where('status', 'in', ['PLANNED', 'ALLOCATED', 'READY', 'Active', 'ACTIVE', 'active', 'Scheduled', 'scheduled', 'Running', 'running'])
      .limit(200).get();

    let activeRun = null;
    runsSnapshot.forEach(doc => {
      const runData = doc.data();
      const assignedCoach = runData.coaches.find(c => c.workerId === uid);
      if (assignedCoach && !activeRun) {
        activeRun = { ...runData, runInstanceId: runData.runInstanceId || doc.id, coachType: assignedCoach.coachType };
      }
    });

    let dueTasks = 0, overdueTasks = 0, completedTasks = 0, upcomingTasks = 0;

    if (activeRun) {
      const runInstanceId = activeRun.runInstanceId;
      const coachType = activeRun.coachType || 'S2';

      const completedSnapshot = await db.collection('obhs_tasks').where('runInstanceId', '==', runInstanceId).limit(200).get();
      const completedTaskIds = new Set();
      completedSnapshot.forEach(doc => {
        completedTaskIds.add(doc.data().uid);
      });

      const tripStartDate = new Date(activeRun.createdAt || now);
      const toiletFreqs = [
        { freq: 'Hour 1', startRel: 0, duration: 1 },
        { freq: 'Hour 2', startRel: 1, duration: 1 },
        { freq: 'Hour 3', startRel: 2, duration: 1 },
        { freq: 'Hour 5', startRel: 4, duration: 2 },
        { freq: 'Hour 7', startRel: 6, duration: 2 },
        { freq: 'Hour 9', startRel: 8, duration: 2 }
      ];
      const coachCleaningFreqs = [
        { freq: 'Train Start', startRel: 0, duration: 3 },
        { freq: 'Mid Journey', startRel: 6, duration: 4 },
        { freq: 'Train End', startRel: 12, duration: 3 }
      ];
      const linenFreqs = [
        { freq: 'Initial Distribution', startRel: 0, duration: 4 },
        { freq: 'Night Return Check', startRel: 10, duration: 4 }
      ];
      const taskDefs = [];
      for (const coach of [coachType]) {
        for (const f of toiletFreqs) taskDefs.push({ type: 'Toilet Cleaning', coach, ...f });
        for (const f of coachCleaningFreqs) taskDefs.push({ type: 'Coach Cleaning', coach, ...f });
        for (const f of linenFreqs) taskDefs.push({ type: 'Linen Distribution', coach, ...f });
      }

      taskDefs.forEach(task => {
        const startTime = new Date(tripStartDate.getTime() + task.startRel * 60 * 60 * 1000);
        const endTime = new Date(startTime.getTime() + task.duration * 60 * 60 * 1000);
        const suffix = task.freq ? `_${task.freq.replace(/\s+/g, '')}` : '';
        const generatedTaskId = `${runInstanceId}_${task.coach}_${task.type.replace(/\s+/g, '')}${suffix}`;
        if (completedTaskIds.has(generatedTaskId)) {
          completedTasks++;
        } else if (now > endTime) {
          overdueTasks++;
        } else if (now >= startTime) {
          dueTasks++;
        } else {
          upcomingTasks++;
        }
      });
    }

    const today = now.toISOString().split('T')[0];
    let attendancePercentage = 0;
    try {
      const attendanceSnapshot = await db.collection('obhs_attendance').where('workerId', '==', uid).limit(200).get();
      let markedCount = 0;
      attendanceSnapshot.forEach(doc => {
        const d = doc.data();
        const docDate = d.createdAt ? d.createdAt.split('T')[0] : '';
        if (docDate !== today) return;
        if (d.isStartMarked) markedCount++;
        if (d.isMidMarked) markedCount++;
        if (d.isEndMarked) markedCount++;
      });
      attendancePercentage = Math.round((markedCount / 3) * 100);
    } catch (_) {
      // Silently handle attendance error
    }

    let complaintsRaised = 0;
    try {
      const complaintsSnapshot = await db.collection('obhs_complaints').where('submittedBy.uid', '==', uid).limit(200).get();
      complaintsRaised = complaintsSnapshot.size;
    } catch (_) {
      // Silently handle complaints error
    }

    let averageRating = 0;
    try {
      const ratingSnapshot = await db.collection('ratings').where('workerId', '==', uid).limit(200).get();
      let total = 0, count = 0;
      ratingSnapshot.forEach(doc => {
        const r = doc.data().rating || 0;
        total += r;
        count++;
      });
      averageRating = count > 0 ? Math.round((total / count) * 10) / 10 : 0;
    } catch (_) {
      // Silently handle ratings error
    }

    return {
      success: true,
      statistics: {
        dueTasks,
        overdueTasks,
        completedTasks,
        upcomingTasks,
        tasksCompleted: completedTasks,
        attendancePercentage,
        complaintsRaised,
        averageRating
      }
    };
  }

  async getWorkers() {
    const snapshot = await db.collection('users').get();

    const validRoles = ['worker', 'railway worker', 'janitor', 'attendant', 'contractor worker', 'obhs staff', 'staff'];
    const workersList = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const role = (data.role || '').toLowerCase();
      if (!validRoles.includes(role)) return;
      workersList.push({
        uid: data.uid || doc.id,
        fullName: data.fullName || '',
        email: data.email || '',
        mobile: data.mobile || '',
        role: data.role || '',
        designation: data.designation || '',
        status: data.status || 'PENDING',
        userType: data.userType || ''
      });
    });

    return { count: workersList.length, workers: workersList };
  }

  async getRailwaySupervisors(zone, division, role) {
    const userRole = (role || "").toUpperCase().replace(/\s+/g, '_');
    
    const ROLE_HIERARCHY = {
      'SUPER_ADMIN': 100, 'COMPANY_MASTER': 90, 'RAILWAY_MASTER': 80,
      'ADMIN': 70, 'RAILWAY_ADMIN': 60, 'STATION_MASTER': 55,
      'RAILWAY_SUPERVISOR': 50, 'AREA_MASTER': 48, 'CONTRACTOR_ADMIN': 45,
      'CONTRACTOR_SUPERVISOR': 40, 'PLATFORM_MASTER': 35, 'CTS': 30,
      'WORKER': 10, 'RAILWAY_WORKER': 10, 'JANITOR': 10, 'ATTENDANT': 10, 'PASSENGER': 1
    };
    const requesterLevel = ROLE_HIERARCHY[userRole] || 0;
    
    // Master or Admin levels
    const isMaster = requesterLevel >= 60;

    let query = db.collection('users')
      .where('status', '==', 'APPROVED');

    if (isMaster) {
      if (zone) {
        query = query.where('zone', '==', zone);
        console.log(`(GetSupervisors) Master access: Fetching entire Zone ${zone}`);
      } else {
        console.log('(GetSupervisors) Master access: No zone set, fetching all supervisors');
      }
    } else {
      if (!zone) {
        throw new ValidationError("Your user profile is missing Zone.");
      }
      if (!division) {
        throw new ValidationError("Your user profile is missing Division.");
      }
      query = query.where('zone', '==', zone).where('division', '==', division);
      console.log(`(GetSupervisors) Admin/Sup access: Fetching Division ${division}`);
    }

    let snapshot;
    try {
      snapshot = await query.limit(500).get();
    } catch (error) {
      if (error.code === 'FAILED_PRECONDITION') {
        throw new ValidationError(`Query requires an index. Firebase Console check karo. ${error.message}`);
      }
      throw error;
    }

    if (snapshot.empty) {
      return { count: 0, supervisors: [] };
    }

    const supervisorList = [];
    const allowedRoles = ['Railway Supervisor', 'Station Master', 'Railway Admin', 'Area Master', 'Platform Master'];

    snapshot.forEach(doc => {
      const data = doc.data();
      if (allowedRoles.includes(data.role)) {
        supervisorList.push({
          uid: data.uid,
          fullName: data.fullName,
          division: data.division,
          depot: data.depot
        });
      }
    });

    return { count: supervisorList.length, supervisors: supervisorList };
  }

  async getWorkersPerformance(adminUser) {
    if (!adminUser || !adminUser.uid) {
      throw new ForbiddenError("Unauthorized. Session expired.");
    }

    const allowedRoles = ['Admin', 'Railway Supervisor', 'Company Master'];
    if (!allowedRoles.includes(adminUser.role)) {
      throw new ForbiddenError("Access Denied. Admin privilege required.");
    }

    const workersSnapshot = await db.collection('users')
      .where('status', '==', 'APPROVED')
      .where('role', '==', 'Railway Worker')
      .limit(200).get();

    if (workersSnapshot.empty) {
      return { success: true, message: "No active workers found.", data: [] };
    }

    let workerPerformanceMap = {};
    workersSnapshot.docs.forEach(doc => {
      const uData = doc.data();
      if (uData.uid) {
        workerPerformanceMap[uData.uid] = {
          workerId: uData.uid,
          workerName: uData.fullName || "Unknown Worker",
          email: uData.email || "",
          designation: uData.designation || "OBHS Staff",
          passengerFeedbackCount: 0,
          passengerSumRating: 0,
          passengerAvgRating: 0.0,
          officialFeedbackCount: 0,
          officialSumRating: 0,
          officialAvgRating: 0.0,
          combinedOverallRating: 0.0,
          totalFeedbackCount: 0,
          parametersBreakdown: {
            cleanlinessSum: 0,
            toiletHygieneSum: 0,
            linenQualitySum: 0,
            securitySum: 0,
            staffBehaviourSum: 0
          }
        };
      }
    });

    const feedbackSnapshot = await db.collection('obhs_feedbacks').limit(200).get();
    feedbackSnapshot.docs.forEach(doc => {
      const fData = doc.data();
      if (!fData) return;

      let assignedWorkerId = null;
      if (fData.feedbackType === 'OFFICIAL') {
        assignedWorkerId = fData.targetWorker?.uid;
      } else {
        assignedWorkerId = fData.collectedBy?.uid;
      }

      if (assignedWorkerId && workerPerformanceMap[assignedWorkerId]) {
        let workerNode = workerPerformanceMap[assignedWorkerId];
        const overallScore = Number(fData.overallRating || 0);
        workerNode.totalFeedbackCount += 1;
        if (fData.feedbackType === 'OFFICIAL') {
          workerNode.officialFeedbackCount += 1;
          workerNode.officialSumRating += overallScore;
        } else {
          workerNode.passengerFeedbackCount += 1;
          workerNode.passengerSumRating += overallScore;
        }
        if (fData.ratings) {
          workerNode.parametersBreakdown.cleanlinessSum += Number(fData.ratings.cleanliness || 0);
          workerNode.parametersBreakdown.toiletHygieneSum += Number(fData.ratings.toiletHygiene || 0);
          workerNode.parametersBreakdown.linenQualitySum += Number(fData.ratings.linenQuality || 0);
          workerNode.parametersBreakdown.securitySum += Number(fData.ratings.security || 0);
          workerNode.parametersBreakdown.staffBehaviourSum += Number(fData.ratings.staffBehaviour || 0);
        }
      }
    });

    let finalPerformanceList = Object.values(workerPerformanceMap).map(worker => {
      if (worker.passengerFeedbackCount > 0) {
        worker.passengerAvgRating = parseFloat((worker.passengerSumRating / worker.passengerFeedbackCount).toFixed(2));
      }
      if (worker.officialFeedbackCount > 0) {
        worker.officialAvgRating = parseFloat((worker.officialSumRating / worker.officialFeedbackCount).toFixed(2));
      }
      if (worker.totalFeedbackCount > 0) {
        const grandSum = worker.passengerSumRating + worker.officialSumRating;
        worker.combinedOverallRating = parseFloat((grandSum / worker.totalFeedbackCount).toFixed(2));
        worker.parameters = {
          cleanliness: parseFloat((worker.parametersBreakdown.cleanlinessSum / worker.totalFeedbackCount).toFixed(2)),
          toiletHygiene: parseFloat((worker.parametersBreakdown.toiletHygieneSum / worker.totalFeedbackCount).toFixed(2)),
          linenQuality: parseFloat((worker.parametersBreakdown.linenQualitySum / worker.totalFeedbackCount).toFixed(2)),
          security: parseFloat((worker.parametersBreakdown.securitySum / worker.totalFeedbackCount).toFixed(2)),
          staffBehaviour: parseFloat((worker.parametersBreakdown.staffBehaviourSum / worker.totalFeedbackCount).toFixed(2))
        };
      } else {
        worker.parameters = { cleanliness: 0, toiletHygiene: 0, linenQuality: 0, security: 0, staffBehaviour: 0 };
      }
      delete worker.passengerSumRating;
      delete worker.officialSumRating;
      delete worker.parametersBreakdown;
      return worker;
    });

    finalPerformanceList.sort((a, b) => b.combinedOverallRating - a.combinedOverallRating);

    return { success: true, totalWorkersEvaluated: finalPerformanceList.length, data: finalPerformanceList };
  }

  async getUserById(requesterData, uid) {
    if (!uid) {
      throw new ValidationError("User ID (UID) is required.");
    }

    const docRef = db.collection('users').doc(uid);
    const doc = await docRef.get();
    if (!doc.exists) {
      throw new NotFoundError("User not found.");
    }

    const targetUser = doc.data();

    if (requesterData.userType === 'railway') {
      const reqRole = (requesterData.role || '').toLowerCase();
      if (!reqRole.includes('master')) {
        if (targetUser.division !== requesterData.division) {
          throw new ForbiddenError("Access Denied: You cannot view users of another Division.");
        }
      } else {
        if (targetUser.zone !== requesterData.zone) {
          throw new ForbiddenError("Access Denied: You cannot view users of another Zone.");
        }
      }
    } else if (requesterData.userType === 'contractor') {
      if (targetUser.entityId !== requesterData.entityId) {
        throw new ForbiddenError("Access Denied: Different Company.");
      }
    }

    delete targetUser.password;
    return targetUser;
  }

  async getWorkerTasks(workerId, query = {}) {
    const snapshot = await db.collection('obhs_tasks').where('assignedTo', '==', workerId).limit(50).get();
    const tasks = [];
    snapshot.forEach(doc => tasks.push({ id: doc.id, ...doc.data() }));
    return { count: tasks.length, tasks };
  }

  async submitWorkerComplaint(user, body) {
    const { title, description, category, priority } = body;
    if (!title || !description) throw new ValidationError('Title and description are required.');
    const complaintId = `cmp_${Date.now()}`;
    const complaint = {
      complaintId,
      title,
      description,
      category: category || 'General',
      priority: priority || 'MEDIUM',
      status: 'OPEN',
      raisedBy: user.uid,
      raisedByName: user.fullName || 'Unknown',
      division: user.division || null,
      zone: user.zone || null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await db.collection('complaints').doc(complaintId).set(complaint);
    return { success: true, message: 'Complaint submitted successfully', complaintId };
  }
}

export const userService = new UserService();
