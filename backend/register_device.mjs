import { db } from './src/database/index.js';

const [,, mac, trainNo, coach, cabinNum, cabinTxId] = process.argv;

if (!mac || !trainNo || !coach || !cabinNum || !cabinTxId) {
  console.log(`
Usage: node register_device.mjs <mac> <trainNo> <coach> <cabinNum> <cabinTransmitterId>

Example:
  node register_device.mjs AA:BB:CC:DD:EE:03 12135 B1 3 cabin_xxxxx

Steps before registering:
  1. Create cabin_transmitters doc in Firestore (get its doc ID)
  2. Run this script with that doc ID as cabinTransmitterId
`);
  process.exit(1);
}

const doc = {
  mac,
  trainNumber: trainNo,
  coachNumber: coach,
  cabinNumber: parseInt(cabinNum),
  cabinTransmitterId: cabinTxId,
  isActive: true,
  createdAt: new Date().toISOString()
};

await db.collection('devices').doc(mac).set(doc);
console.log('Device registered:', mac);
console.log(JSON.stringify(doc, null, 2));
