/*
 * Seed script for the Annexure-AB Work Execution Sheet (50% billing component).
 * Usage: node seed_execution_sheet.mjs <contractId> <stationId>
 * The station + contract must already exist.
 * Populates `execution_sheet_items` with the 25 weighted items as per
 * C 331/2/Mechanized Cleaning/MSH Station/Goods shed - Daily Monitoring /
 * Execution of schedule of work (Work Execution Sheet).
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : JSON.parse(readFileSync('../crm_backend/serviceAccountKey.json', 'utf8'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const contractId = process.argv[2];
const stationId = process.argv[3];
if (!contractId || !stationId) {
  console.error('Usage: node seed_execution_sheet.mjs <contractId> <stationId>');
  process.exit(1);
}

const stationDoc = await db.collection('stations').doc(stationId).get();
if (!stationDoc.exists) {
  console.error(`Station ${stationId} not found`);
  process.exit(1);
}
const stationName = stationDoc.data().stationName || 'Unknown';

// ─── Annexure-AB items (weightages total to 100%) ─────────────────────────────
const ITEMS = [
  {
    itemNo: 1,
    description: 'Scrubbing, wet cleaning of floor, Concourse, Platform, passages, staircase and different types of floor area provided in station building including waiting rooms, all railway/other offices, retiring rooms',
    areaDetails: [
      'PF-1', 'PF-2 & 3', 'PF-04/05', 'PF-06', 'PF-07/08',
      'Concourse Hall', 'All Waiting rooms', 'Retiring Rooms/Dormitory',
      'Subordinate Rest House', 'ORH', 'Staircase - West & East side building',
      "FOB's with its steps and railing (and any additional space that needs attention on FOB)",
      'All Offices', 'Carpet area of Station building west side',
      'Carpet area of Station building East side', 'Goods PF area',
      'Goods Line-01 & 2', 'Goods offices & gallery',
    ],
    shiftMonitoring: 'Spell-wise as per tender (multiple spells in a day)',
    weightage: 45.0,
    requiredFrequencyPerMonth: 120,
    mappedAreas: [
      { mainArea: 'All Platforms', subAreas: [] },
      { mainArea: 'Carpet area of Station building (W)', subAreas: [] },
      { mainArea: 'Carpet area of Station building (E)', subAreas: [] },
      { mainArea: "FOB's with steps and railing", subAreas: ['FoB Floor'] },
      { mainArea: 'Staircase', subAreas: [] },
      { mainArea: 'All offices of West Building', subAreas: ['Offices 38'] },
      { mainArea: 'All offices of East Building', subAreas: [] },
      { mainArea: 'Goods PF area', subAreas: [] },
      { mainArea: 'Goods Line-01', subAreas: [] },
      { mainArea: 'Goods Line-02', subAreas: [] },
      { mainArea: 'Goods Office building', subAreas: [] },
      { mainArea: 'Goods office gallery', subAreas: [] },
    ],
  },
  {
    itemNo: 2,
    description: 'Tracks of all platforms (including up to 50 meters in both UP & DOWN directions from either end of the farthest platform for rag picking). Track No. 1,2,3,4,5,6,7,8,11 & 12. Total area between each platform',
    areaDetails: ['Track No. 1,2,3,4,5,6,7,8,11 & 12', 'PF-01 & PF-02', 'PF-03 & PF-04', 'PF-05 & PF-06'],
    shiftMonitoring: 'Daily rag picking esp. in all spells',
    weightage: 20.0,
    requiredFrequencyPerMonth: 90,
    mappedAreas: [
      { mainArea: 'Tracks of all platform', subAreas: ['Track 1,2,3,4,5,6,7,8,11 & 12'] },
      { mainArea: 'Total area between each platform', subAreas: [] },
    ],
  },
  {
    itemNo: 3,
    description: 'Cleaning of passages & different types of floor area provided in all operation and utility rooms',
    areaDetails: ['Total Toilet/Bathroom - 66', 'Goods offices toilet'],
    shiftMonitoring: 'Multiple spells in a day as applicable',
    weightage: 8.0,
    requiredFrequencyPerMonth: 180,
    mappedAreas: [
      { mainArea: 'Toilet Blocks and Bathrooms platforms', subAreas: ['Toilet & Bathroom - 66'] },
      { mainArea: 'Goods Office building', subAreas: [] },
    ],
  },
  {
    itemNo: 4,
    description: 'Cleaning of Different types of finishing works in wall cladding',
    areaDetails: ['All platforms & station building wall cladding'],
    shiftMonitoring: 'As per deep cleaning / monthly schedule',
    weightage: 4.0,
    requiredFrequencyPerMonth: 12,
    mappedAreas: [
      { mainArea: 'All in and out wall of station building', subAreas: [] },
      { mainArea: 'Wall of Toilet Blocks and Bathrooms platforms', subAreas: ['Toilet Walls'] },
      { mainArea: 'Wall of Drinking water hut & fountain', subAreas: ['Water Hut Walls'] },
    ],
  },
  {
    itemNo: 5,
    description: 'Cleaning of Different types of doors/windows frames and shutters/louvers',
    areaDetails: ['West building Doors 38, Windows-76', 'East building Doors-33, Windows-40'],
    shiftMonitoring: 'Weekly / as and when required',
    weightage: 1.5,
    requiredFrequencyPerMonth: 8,
    mappedAreas: [
      { mainArea: 'Any other area (Interior of station building)', subAreas: ['West: Doors-38', 'West: Windows-76', 'East: Doors-33', 'East: Windows-40'] },
    ],
  },
  {
    itemNo: 6,
    description: 'Cleaning of Glasses fixed to the doors, windows, Ticket counters and General area (windows, including Grills, Glasses etc) elsewhere in the station area',
    areaDetails: ['Windows 93 including grill & glass'],
    shiftMonitoring: 'Alternate day / as and when required',
    weightage: 3.5,
    requiredFrequencyPerMonth: 15,
    mappedAreas: [
      { mainArea: 'General area (windows, grills, glasses)', subAreas: ['Windows 93 including grill & glass'] },
    ],
  },
  {
    itemNo: 7,
    description: 'Cleaning of Rolling shutters',
    areaDetails: ['All rolling shutters in station area'],
    shiftMonitoring: 'Weekly / as and when required',
    weightage: 0.5,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [],
  },
  {
    itemNo: 8,
    description: 'Cleaning of Stainless steel/PVC/MS/wooden hand railing',
    areaDetails: ['All hand railings - platforms, FOB, staircase'],
    shiftMonitoring: 'Spell-wise daily as applicable',
    weightage: 1.75,
    requiredFrequencyPerMonth: 90,
    mappedAreas: [
      { mainArea: "FOB's with steps and railing", subAreas: [] },
      { mainArea: 'Staircase', subAreas: [] },
    ],
  },
  {
    itemNo: 9,
    description: 'Cleaning of suspended ceiling - Inner roof & Cobwebs',
    areaDetails: ['All suspended ceilings in station building'],
    shiftMonitoring: 'Monthly / as and when required',
    weightage: 1.0,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [
      { mainArea: 'All inner Roof & concourse area (West side)', subAreas: [] },
      { mainArea: 'All inner Roof & concourse area (East side)', subAreas: [] },
    ],
  },
  {
    itemNo: 10,
    description: 'Cleaning of Roof Ceiling etc. - Inner roof & Cobwebs',
    areaDetails: ['All roof ceilings in station building'],
    shiftMonitoring: 'Monthly / as and when required',
    weightage: 3.0,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [
      { mainArea: 'All inner Roof & concourse area (West side)', subAreas: [] },
      { mainArea: 'All inner Roof & concourse area (East side)', subAreas: [] },
    ],
  },
  {
    itemNo: 11,
    description: 'Cleaning & sanitation of Toilets & Bath Rooms (Only Staff Toilets)',
    areaDetails: [
      'All offices of West building (staff Toilet/Bathrooms - Toilet Unit-23, Bathroom-08)',
      'All offices of East building (Bathroom-8 & Toilet-14)',
    ],
    shiftMonitoring: 'Spell-wise daily as applicable',
    weightage: 2.0,
    requiredFrequencyPerMonth: 90,
    mappedAreas: [
      { mainArea: 'All offices of West Building', subAreas: ['Toilet Unit 23', 'Bathroom 08'] },
      { mainArea: 'All offices of East Building', subAreas: ['Bathroom 08', 'Toilet Unit 14'] },
    ],
  },
  {
    itemNo: 12,
    description: 'Cleaning and attention of open drains in station area',
    areaDetails: ['All open drains in station area'],
    shiftMonitoring: 'Alternate day / as and when required',
    weightage: 0.75,
    requiredFrequencyPerMonth: 15,
    mappedAreas: [],
  },
  {
    itemNo: 13,
    description: 'External Cleaning of Portable fire extinguishers/smoke detectors/Fire detectors',
    areaDetails: ['All portable fire extinguishers / smoke detectors / fire detectors'],
    shiftMonitoring: 'Monthly / as and when required',
    weightage: 0.2,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [],
  },
  {
    itemNo: 14,
    description: 'Cleaning of escalators',
    areaDetails: ['Escalator'],
    shiftMonitoring: 'Daily as applicable',
    weightage: 1.0,
    requiredFrequencyPerMonth: 30,
    mappedAreas: [
      { mainArea: 'Escalator Platform wise', subAreas: ['All Escalators'] },
    ],
  },
  {
    itemNo: 15,
    description: 'Cleaning of lifts',
    areaDetails: ['Lift-05 platform wise'],
    shiftMonitoring: 'Daily as applicable',
    weightage: 1.0,
    requiredFrequencyPerMonth: 30,
    mappedAreas: [
      { mainArea: 'Lift (05) Platform wise', subAreas: ['All Lifts'] },
    ],
  },
  {
    itemNo: 16,
    description: 'External cleaning of Computers and it\u2019s accessories, Telephone sets and all other Misc. items under due supervision',
    areaDetails: ['All office computers, telephones & misc. items'],
    shiftMonitoring: 'Weekly / as and when required',
    weightage: 0.3,
    requiredFrequencyPerMonth: 8,
    mappedAreas: [],
  },
  {
    itemNo: 17,
    description: 'Cleaning of Furniture, in booking, PRS & TC Offices etc. under due supervision',
    areaDetails: ['Booking, PRS & TC Offices furniture'],
    shiftMonitoring: 'Weekly / as and when required',
    weightage: 0.3,
    requiredFrequencyPerMonth: 8,
    mappedAreas: [],
  },
  {
    itemNo: 18,
    description: 'External cleaning of UPS available in PRS/Booking offices (Signalling & Electrical)',
    areaDetails: ['UPS in PRS / Booking offices'],
    shiftMonitoring: 'Monthly / as and when required',
    weightage: 0.3,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [],
  },
  {
    itemNo: 19,
    description: 'Cleaning of all equipment available in the station control Room, booking offices, and Excess Fare office, other than the items covered elsewhere',
    areaDetails: ['Station Control Room, Booking offices, Excess Fare office equipment'],
    shiftMonitoring: 'Weekly / as and when required',
    weightage: 0.3,
    requiredFrequencyPerMonth: 8,
    mappedAreas: [],
  },
  {
    itemNo: 20,
    description: 'Cleaning of Air conditioners externally in station offices',
    areaDetails: ['All AC units in station offices'],
    shiftMonitoring: 'Monthly / as and when required',
    weightage: 0.2,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [],
  },
  {
    itemNo: 21,
    description: 'External cleaning of automatic fare collection system, Ticket Vending Machine and Security equipment such as Baggage scanners, DFMD etc.',
    areaDetails: ['AFC system, TVM, Baggage scanners, DFMD etc.'],
    shiftMonitoring: 'Alternate day / as and when required',
    weightage: 0.6,
    requiredFrequencyPerMonth: 15,
    mappedAreas: [],
  },
  {
    itemNo: 22,
    description: 'Cleaning of Pavement/circulating area at Ground level near station entry/exit, Subway and Foot over bridge connected to station entry/exit',
    areaDetails: ['Station entry/exit pavement', 'Subway', 'FOB connected to entry/exit'],
    shiftMonitoring: 'Twice a day as applicable',
    weightage: 4.0,
    requiredFrequencyPerMonth: 60,
    mappedAreas: [
      { mainArea: 'Total circulating area West side', subAreas: [] },
      { mainArea: 'Total circulating area East side', subAreas: [] },
      { mainArea: 'Goods building front road area', subAreas: ['Front Road'] },
      { mainArea: 'Approach Road from Goods office to over bridge', subAreas: ['Approach Road'] },
    ],
  },
  {
    itemNo: 23,
    description: 'Supply of Bio-degradable garbage disposal bags and disposal of waste, garbage, dust, dirt, rubbish etc.',
    areaDetails: ['All station bins & waste disposal points'],
    shiftMonitoring: 'Daily as applicable',
    weightage: 0.1,
    requiredFrequencyPerMonth: 90,
    mappedAreas: [],
  },
  {
    itemNo: 24,
    description: 'Disposal of waste, garbage, dust, dirt, rubbish in designated garbage disposal place and cleaning of dust bins as per NGT guidance',
    areaDetails: ['All dust bins & designated garbage disposal place'],
    shiftMonitoring: 'Spell-wise daily as applicable',
    weightage: 0.2,
    requiredFrequencyPerMonth: 120,
    mappedAreas: [
      { mainArea: 'Dustbins', subAreas: ['Blue-75, Green-75, Red-75, Black-75'] },
    ],
  },
  {
    itemNo: 25,
    description: 'Pest, rodent and termite control',
    areaDetails: ['Whole station area'],
    shiftMonitoring: 'Monthly as per schedule',
    weightage: 0.5,
    requiredFrequencyPerMonth: 4,
    mappedAreas: [
      { mainArea: 'Pest & Rodent Control treatment', subAreas: ['Pest Control'] },
    ],
  },
];

const existsSnap = await db.collection('execution_sheet_items')
  .where('stationId', '==', stationId).get();
const updateMode = process.argv.includes('--update');

if (!existsSnap.empty && !updateMode) {
  console.log(`Execution sheet items already exist for station ${stationName} (${stationId}). Skipping. (Use --update to refresh the mapping.)`);
  admin.app().delete();
  process.exit(0);
}

const now = new Date().toISOString();
const batch = db.batch();
let totalWeightage = 0;
const existingByItem = {};
if (updateMode) {
  existsSnap.forEach((doc) => { existingByItem[doc.data().itemNo] = { ref: doc.ref, doc: doc.data() }; });
}
for (const item of ITEMS) {
  const base = {
    description: item.description,
    areaDetails: item.areaDetails,
    shiftMonitoring: item.shiftMonitoring,
    weightage: item.weightage,
    requiredFrequencyPerMonth: item.requiredFrequencyPerMonth,
    mappedAreas: item.mappedAreas || [],
    updatedAt: now,
  };
  if (existingByItem[item.itemNo]) {
    batch.update(existingByItem[item.itemNo].ref, base);
    console.log(`Item ${item.itemNo}: updated (${item.weightage}%)`);
  } else {
    const ref = db.collection('execution_sheet_items').doc();
    batch.set(ref, { uid: ref.id, contractId, stationId, stationName, itemNo: item.itemNo, ...base, status: 'active', createdBy: 'system', createdAt: now });
    console.log(`Item ${item.itemNo}: created (${item.weightage}%)`);
  }
  totalWeightage += item.weightage;
}
await batch.commit();

console.log(`\n${updateMode ? 'Updated' : 'Seeded'} ${ITEMS.length} execution sheet items for ${stationName}.`);
console.log(`Total weightage: ${totalWeightage.toFixed(2)}%`);
admin.app().delete();