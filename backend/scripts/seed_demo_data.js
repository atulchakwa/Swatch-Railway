/*
 * Seed demo dashboard data for a station.
 * Usage: node scripts/seed_demo_data.js <stationId>
 *
 * Prerequisites:
 *   cd backend && node scripts/seed_demo_data.js STATION_ID
 */
import { db } from '../src/database/index.js';

const stationId = process.argv[2];
if (!stationId) {
  console.error('Usage: node scripts/seed_demo_data.js <stationId>');
  process.exit(1);
}

const ts = new Date().toISOString();

function today() { return new Date().toISOString().split('T')[0]; }
function daysAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().split('T')[0]; }
function hoursAgo(n) { const d = new Date(); d.setHours(d.getHours() - n); return d.toISOString(); }
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function rand(min, max) { return Math.floor(min + Math.random() * (max - min + 1)); }

async function seed() {
  const batchSize = 500;
  let ops = 0;
  let batch = db.batch();

  async function flush() {
    if (ops === 0) return;
    await batch.commit();
    ops = 0;
    batch = db.batch();
  }

  function add(collection, data) {
    const ref = db.collection(collection).doc();
    batch.set(ref, data);
    ops++;
    if (ops >= batchSize) flush();
  }

  // 1. Stations doc
  add('stations', { stationId, stationName: 'Demo Station', stationCode: 'DEMO', active: true });

  // 2. Daily scorecards (7 days)
  for (let i = 6; i >= 0; i--) {
    add('daily_scorecards', { stationId, date: daysAgo(i), overallStationScore: rand(70, 98), grade: pick(['A','A+','B','B+']), createdAt: ts });
  }

  // 3. Station attendance (30 days, ~10 workers/day)
  for (let i = 29; i >= 0; i--) {
    const d = daysAgo(i);
    for (let w = 0; w < rand(8, 15); w++) {
      add('station_attendance', {
        stationId, date: d, workerId: `worker_${w}_${i}`, workerName: `Worker ${w + 1}`,
        status: Math.random() > 0.12 ? 'present' : 'absent',
        shift: pick(['morning', 'afternoon', 'night']), createdAt: ts,
      });
    }
  }

  // 4. Station feedback
  for (let i = 0; i < 20; i++) {
    add('station_feedback', {
      stationId, rating: rand(1, 5), isNegative: Math.random() < 0.15,
      passengerName: `Passenger ${i + 1}`,
      comment: 'Demo feedback comment', createdAt: hoursAgo(rand(1, 720)),
    });
  }

  // 5. Complaints
  for (let i = 0; i < 10; i++) {
    add('complaints', {
      stationId, title: `Demo Complaint ${i + 1}`, description: 'Demo complaint description',
      status: pick(['OPEN', 'IN_PROGRESS', 'CLOSED']),
      priority: pick(['low', 'medium', 'high']),
      createdAt: hoursAgo(rand(1, 720)),
    });
  }

  // 6. Machines
  const machineTypes = ['scrubber', 'sweeper', 'vacuum', 'washer', 'blower'];
  for (let i = 0; i < 12; i++) {
    add('machines', {
      stationId, machineName: `Machine ${i + 1}`, machineType: pick(machineTypes),
      workingStatus: Math.random() > 0.15 ? 'operational' : 'under_maintenance',
      createdAt: ts,
    });
  }

  // 7. Station daily activities (7 days)
  for (let i = 6; i >= 0; i--) {
    add('station_daily_activities', {
      stationId, date: daysAgo(i), activityName: `Demo Activity ${i + 1}`,
      status: Math.random() > 0.1 ? 'COMPLETED' : 'PENDING',
      assignedTo: 'Demo Worker', createdAt: ts,
    });
  }

  // 8. Execution logs (7 days)
  for (let i = 6; i >= 0; i--) {
    add('execution_logs', {
      stationId, date: daysAgo(i), plannedManpower: rand(15, 25),
      actualManpower: rand(12, 22), createdAt: ts,
    });
  }

  // 9. Activity frequencies
  for (const f of ['daily', 'weekly', 'monthly']) {
    add('activity_frequencies', {
      stationId, activityName: `Demo ${f} Activity`, frequency: f,
      lastCompletedDate: daysAgo(rand(0, 3)), status: 'active', createdAt: ts,
    });
  }

  // 10. Station billing packs
  const m = new Date().getMonth() + 1;
  const y = new Date().getFullYear();
  for (const status of ['DRAFT', 'SUBMITTED', 'APPROVED']) {
    add('station_billing_packs', {
      stationId, contractId: 'contract_demo',
      month: m, year: y, status,
      totalAmount: rand(50000, 250000), createdAt: ts,
    });
  }

  // 11. Platforms
  for (let i = 1; i <= 4; i++) {
    add('platforms', {
      stationId, platformNumber: i.toString(),
      name: `Platform ${i}`, platformName: `Platform ${i}`,
      status: 'active', createdAt: ts,
    });
  }

  // 12. Cleaning tasks (7 days × 6 tasks/day)
  for (let i = 6; i >= 0; i--) {
    const d = daysAgo(i);
    for (let j = 0; j < 6; j++) {
      add('cleaningTasks', {
        stationId, scheduledDate: d, areaName: `Area ${j + 1}`,
        platformId: `platform_${(j % 4) + 1}`,
        status: pick(['pending', 'in_progress', 'completed', 'approved']),
        workerId: `worker_${j}`, workerName: `Worker ${j + 1}`,
        createdAt: ts,
      });
    }
  }

  await flush();

  // 13. Station reports (for listReports to return data)
  for (let i = 0; i < 10; i++) {
    await db.collection('station_reports').add({
      stationId, reportType: pick(['daily_attendance', 'daily_activity', 'daily_scorecard', 'monthly_attendance']),
      month: m, year: y, status: 'completed',
      title: `Demo Report ${i + 1}`,
      createdAt: hoursAgo(rand(1, 720)),
    });
  }

  console.log(`✅ Seeded demo data for station: ${stationId}`);
}

seed().catch(err => { console.error('❌ Seed failed:', err); process.exit(1); });
