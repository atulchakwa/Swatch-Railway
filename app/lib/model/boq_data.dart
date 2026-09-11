class BoqItem {
  final int srNo;
  final String mainArea;
  final String subArea;
  final double basicAreaSqFt;
  final double tenderedAreaPerDay;
  final String frequencyType;
  final int boqTimesPerPeriod;
  final int totalDays;
  final String frequencyDescription;

  const BoqItem({
    required this.srNo,
    required this.mainArea,
    required this.subArea,
    required this.basicAreaSqFt,
    required this.tenderedAreaPerDay,
    required this.frequencyType,
    required this.boqTimesPerPeriod,
    required this.totalDays,
    required this.frequencyDescription,
  });
}

const List<BoqItem> boqData = [
  // ── 1. All Platforms ──
  BoqItem(srNo: 1, mainArea: 'All Platforms', subArea: 'PF-01', basicAreaSqFt: 64883, tenderedAreaPerDay: 389298, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 1, mainArea: 'All Platforms', subArea: 'PF-02 & PF-03', basicAreaSqFt: 67089, tenderedAreaPerDay: 201267, frequencyType: 'daily', boqTimesPerPeriod: 3, totalDays: 1461, frequencyDescription: 'Two times in day shift and One time in Night shift and as and when required.'),
  BoqItem(srNo: 1, mainArea: 'All Platforms', subArea: 'PF-04 & PF-05', basicAreaSqFt: 78769, tenderedAreaPerDay: 472614, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 1, mainArea: 'All Platforms', subArea: 'PF-06', basicAreaSqFt: 78656, tenderedAreaPerDay: 471936, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 1, mainArea: 'All Platforms', subArea: 'PF-07 & PF-08', basicAreaSqFt: 69402, tenderedAreaPerDay: 138804, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required.'),

  // ── 1b. Cover shed ──
  BoqItem(srNo: 1, mainArea: 'Cover shed', subArea: 'PF-01', basicAreaSqFt: 65450, tenderedAreaPerDay: 4300.62, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required'),
  BoqItem(srNo: 1, mainArea: 'Cover shed', subArea: 'PF-02 & PF-03', basicAreaSqFt: 38500, tenderedAreaPerDay: 2529.77, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required'),
  BoqItem(srNo: 1, mainArea: 'Cover shed', subArea: 'PF-04 & PF-05', basicAreaSqFt: 65450, tenderedAreaPerDay: 4300.62, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required'),
  BoqItem(srNo: 1, mainArea: 'Cover shed', subArea: 'PF-06', basicAreaSqFt: 50600, tenderedAreaPerDay: 3324.85, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required'),
  BoqItem(srNo: 1, mainArea: 'Cover shed', subArea: 'PF-07 & PF-08', basicAreaSqFt: 15400, tenderedAreaPerDay: 1011.91, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required'),

  // ── 2. All inner Roof & concourse area (West side) ──
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'AC/SL/LW Room', basicAreaSqFt: 2075, tenderedAreaPerDay: 68.17, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'VIP', basicAreaSqFt: 576, tenderedAreaPerDay: 18.92, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'RRI Tower', basicAreaSqFt: 4952, tenderedAreaPerDay: 162.69, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'PLS & CHI', basicAreaSqFt: 2240, tenderedAreaPerDay: 73.59, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'Concourse Dome', basicAreaSqFt: 5025, tenderedAreaPerDay: 165.09, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'Concourse Ceiling', basicAreaSqFt: 6696, tenderedAreaPerDay: 219.99, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'Gallery All', basicAreaSqFt: 7904, tenderedAreaPerDay: 259.68, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'SSE C & W', basicAreaSqFt: 680, tenderedAreaPerDay: 22.34, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'Train Light Office', basicAreaSqFt: 120, tenderedAreaPerDay: 3.94, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'RPF', basicAreaSqFt: 4174, tenderedAreaPerDay: 137.13, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'GRP', basicAreaSqFt: 2273, tenderedAreaPerDay: 74.68, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (West side)', subArea: 'All offices (38)', basicAreaSqFt: 18546, tenderedAreaPerDay: 609.31, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),

  // ── 2b. East side building ──
  BoqItem(srNo: 2, mainArea: 'All inner Roof & concourse area (East side)', subArea: 'Station Building', basicAreaSqFt: 13466, tenderedAreaPerDay: 442.41, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),

  // ── 3. All in and out wall of station building ──
  BoqItem(srNo: 3, mainArea: 'All in and out wall of station building', subArea: 'West building', basicAreaSqFt: 248659.44, tenderedAreaPerDay: 8169.51, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),
  BoqItem(srNo: 3, mainArea: 'All in and out wall of station building', subArea: 'East building', basicAreaSqFt: 15966, tenderedAreaPerDay: 524.55, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a month and as and when required.'),

  // ── 4. Carpet area of Station building (W) ──
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'All Waiting rooms-3', basicAreaSqFt: 1800, tenderedAreaPerDay: 10800, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Retiring Rooms & Dormitory', basicAreaSqFt: 1200, tenderedAreaPerDay: 2400, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Subordinate Rest House', basicAreaSqFt: 600, tenderedAreaPerDay: 1200, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'ORH', basicAreaSqFt: 400, tenderedAreaPerDay: 400, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Concourse Hall', basicAreaSqFt: 11721, tenderedAreaPerDay: 70326, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Porch', basicAreaSqFt: 1125, tenderedAreaPerDay: 2250, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'VIP Room', basicAreaSqFt: 576, tenderedAreaPerDay: 2304, frequencyType: 'daily', boqTimesPerPeriod: 4, totalDays: 1461, frequencyDescription: 'Four times in a day i.e. once in each six-hour interval, and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'No of Stairs', basicAreaSqFt: 760, tenderedAreaPerDay: 1520, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'ORH-2', basicAreaSqFt: 840, tenderedAreaPerDay: 840, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'PLS & CHI', basicAreaSqFt: 2240, tenderedAreaPerDay: 2240, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Gallery All', basicAreaSqFt: 7904, tenderedAreaPerDay: 15808, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'SSE C & W', basicAreaSqFt: 680, tenderedAreaPerDay: 680, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'RPF', basicAreaSqFt: 4174, tenderedAreaPerDay: 4174, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'GRP', basicAreaSqFt: 2273, tenderedAreaPerDay: 2273, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'RRI Tower', basicAreaSqFt: 4952, tenderedAreaPerDay: 4952, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (W)', subArea: 'Electrical office and Store', basicAreaSqFt: 550, tenderedAreaPerDay: 550, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),

  // ── 4b. Carpet area (E) ──
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Waiting Room-01', basicAreaSqFt: 565, tenderedAreaPerDay: 3390, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Retiring Rooms-04', basicAreaSqFt: 855.8, tenderedAreaPerDay: 1711.60, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'ORH-02', basicAreaSqFt: 1186, tenderedAreaPerDay: 1186, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Concourse Ground Floor', basicAreaSqFt: 2612.96, tenderedAreaPerDay: 15677.76, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Concourse 01st Floor', basicAreaSqFt: 1202.79, tenderedAreaPerDay: 7216.74, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day i.e. once in each four-hour interval, and as and when required.'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Porch-01', basicAreaSqFt: 1366.4, tenderedAreaPerDay: 2732.80, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'Stairs', basicAreaSqFt: 384.14, tenderedAreaPerDay: 768.28, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required'),
  BoqItem(srNo: 4, mainArea: 'Carpet area of Station building (E)', subArea: 'VIP Room-01', basicAreaSqFt: 400, tenderedAreaPerDay: 1600, frequencyType: 'daily', boqTimesPerPeriod: 4, totalDays: 1461, frequencyDescription: 'Four times in a day i.e. once in each six-hour interval, and as and when required.'),

  // ── 5. FOB's ──
  BoqItem(srNo: 5, mainArea: "FOB's with steps and railing", subArea: 'Cover shed inner', basicAreaSqFt: 28117, tenderedAreaPerDay: 1847.52, frequencyType: 'monthly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a month and as and when required.'),
  BoqItem(srNo: 5, mainArea: "FOB's with steps and railing", subArea: 'FoB Floor', basicAreaSqFt: 28117, tenderedAreaPerDay: 56234, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day shift and as and when required.'),

  // ── 6. Lift ──
  BoqItem(srNo: 6, mainArea: 'Lift (05) Platform wise', subArea: 'All Lifts', basicAreaSqFt: 1080, tenderedAreaPerDay: 5400, frequencyType: 'daily', boqTimesPerPeriod: 5, totalDays: 1461, frequencyDescription: 'Four times in day shift and One time in Night shift and as and when required.'),

  // ── 7. Escalator ──
  BoqItem(srNo: 7, mainArea: 'Escalator Platform wise', subArea: 'All Escalators', basicAreaSqFt: 560, tenderedAreaPerDay: 1680, frequencyType: 'daily', boqTimesPerPeriod: 3, totalDays: 1461, frequencyDescription: 'Two times in day shift and One time in Night shift and as and when required.'),

  // ── 8. Signages ──
  BoqItem(srNo: 8, mainArea: 'All Signages', subArea: 'Signages', basicAreaSqFt: 2300, tenderedAreaPerDay: 2300, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),

  // ── 9. Tracks ──
  BoqItem(srNo: 9, mainArea: 'Tracks of all platform', subArea: 'Track 1,2,3,4,5,6,7,8,11 & 12', basicAreaSqFt: 208152, tenderedAreaPerDay: 416304, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),

  // ── 10. Area between platforms ──
  BoqItem(srNo: 10, mainArea: 'Total area between each platform', subArea: 'PF-01 & PF-02', basicAreaSqFt: 5415, tenderedAreaPerDay: 10830, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required'),
  BoqItem(srNo: 10, mainArea: 'Total area between each platform', subArea: 'PF-03 & PF-04', basicAreaSqFt: 5415, tenderedAreaPerDay: 10830, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required'),
  BoqItem(srNo: 10, mainArea: 'Total area between each platform', subArea: 'PF-05 & PF-06', basicAreaSqFt: 5415, tenderedAreaPerDay: 10830, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required'),

  // ── 11. All offices West ──
  BoqItem(srNo: 11, mainArea: 'All offices of West Building', subArea: 'Offices 38', basicAreaSqFt: 18546, tenderedAreaPerDay: 18546, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 11, mainArea: 'All offices of West Building', subArea: 'Toilet Unit 23', basicAreaSqFt: 1150, tenderedAreaPerDay: 2300, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),
  BoqItem(srNo: 11, mainArea: 'All offices of West Building', subArea: 'Bathroom 08', basicAreaSqFt: 128, tenderedAreaPerDay: 256, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day or and as and when required'),

  // ── 11b. All offices East ──
  BoqItem(srNo: 11, mainArea: 'All offices of East Building', subArea: 'Bathroom 08', basicAreaSqFt: 760, tenderedAreaPerDay: 760, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 11, mainArea: 'All offices of East Building', subArea: 'Toilet Unit 14', basicAreaSqFt: 415.8, tenderedAreaPerDay: 831.60, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),

  // ── 12. Total circulating area ──
  BoqItem(srNo: 12, mainArea: 'Total circulating area West side', subArea: 'Circulating', basicAreaSqFt: 224312.28, tenderedAreaPerDay: 448624.56, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day or and as and when required'),
  BoqItem(srNo: 12, mainArea: 'Total circulating area West side', subArea: 'Approach Road', basicAreaSqFt: 122538.16, tenderedAreaPerDay: 122538.16, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day or and as and when required'),
  BoqItem(srNo: 12, mainArea: 'Total circulating area East side', subArea: 'Approach Road', basicAreaSqFt: 11270, tenderedAreaPerDay: 11270, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day or and as and when required'),

  // ── 13. Outer Surface ──
  BoqItem(srNo: 13, mainArea: 'Outer Surface area of Entire Station building', subArea: 'Façade Cleaning', basicAreaSqFt: 9742, tenderedAreaPerDay: 320.07, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day or and as and when required'),

  // ── 14. Any other area ──
  BoqItem(srNo: 14, mainArea: 'Any other area (Interior of station building)', subArea: 'West: Doors-38', basicAreaSqFt: 1862, tenderedAreaPerDay: 1862, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 14, mainArea: 'Any other area (Interior of station building)', subArea: 'West: Windows-76', basicAreaSqFt: 1805, tenderedAreaPerDay: 1805, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 14, mainArea: 'Any other area (Interior of station building)', subArea: 'East: Doors-33', basicAreaSqFt: 1617, tenderedAreaPerDay: 1617, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),
  BoqItem(srNo: 14, mainArea: 'Any other area (Interior of station building)', subArea: 'East: Windows-40', basicAreaSqFt: 1900, tenderedAreaPerDay: 1900, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),

  // ── 15. Staircase ──
  BoqItem(srNo: 15, mainArea: 'Staircase', subArea: 'West building', basicAreaSqFt: 6184, tenderedAreaPerDay: 12368, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required.'),
  BoqItem(srNo: 15, mainArea: 'Staircase', subArea: 'East building', basicAreaSqFt: 408, tenderedAreaPerDay: 816, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required.'),

  // ── 16. Benches ──
  BoqItem(srNo: 16, mainArea: 'Benches', subArea: 'Benches-199', basicAreaSqFt: 1990, tenderedAreaPerDay: 3980, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in day shift and as and when required.'),

  // ── 18. Toilet Blocks ──
  BoqItem(srNo: 18, mainArea: 'Toilet Blocks and Bathrooms platforms', subArea: 'Toilet & Bathroom - 66', basicAreaSqFt: 792, tenderedAreaPerDay: 19008, frequencyType: 'daily', boqTimesPerPeriod: 18, totalDays: 1461, frequencyDescription: 'Six time deep cleaning in a day i.e. once in every 4 hours and as and when required & Every One hour mopping i.e. 18 times mopping in a day'),

  // ── 19. Wall of Toilet Blocks ──
  BoqItem(srNo: 19, mainArea: 'Wall of Toilet Blocks and Bathrooms platforms', subArea: 'Toilet Walls', basicAreaSqFt: 11530, tenderedAreaPerDay: 69180, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day and as and when required'),

  // ── 20. Drinking water booths ──
  BoqItem(srNo: 20, mainArea: 'Drinking water booths', subArea: 'W-Fountain & HUT-29 & Cooler-08', basicAreaSqFt: 444, tenderedAreaPerDay: 10656, frequencyType: 'daily', boqTimesPerPeriod: 18, totalDays: 1461, frequencyDescription: 'Six time deep cleaning in a day i.e. once in every 4 hours and as and when required & Every One hour mopping i.e. 18 times mopping in a day'),

  // ── 21. Wall of Drinking water ──
  BoqItem(srNo: 21, mainArea: 'Wall of Drinking water hut & fountain', subArea: 'Water Hut Walls', basicAreaSqFt: 78350, tenderedAreaPerDay: 470100, frequencyType: 'daily', boqTimesPerPeriod: 6, totalDays: 1461, frequencyDescription: 'Six times in a day and as and when required'),

  // ── 22. General area ──
  BoqItem(srNo: 22, mainArea: 'General area (windows, grills, glasses)', subArea: 'Windows 93 including grill & glass', basicAreaSqFt: 1248, tenderedAreaPerDay: 1248, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),

  // ── 23. Garden ──
  BoqItem(srNo: 23, mainArea: 'Garden & vacant space', subArea: 'Garden', basicAreaSqFt: 12587.32, tenderedAreaPerDay: 12587.32, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),

  // ── 24-31. Goods area ──
  BoqItem(srNo: 24, mainArea: 'Goods PF area', subArea: 'Goods Platform', basicAreaSqFt: 242188, tenderedAreaPerDay: 69196.58, frequencyType: 'weekly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a week and as and when required.'),
  BoqItem(srNo: 25, mainArea: 'Goods Line-01', subArea: 'Line 01', basicAreaSqFt: 7696.20, tenderedAreaPerDay: 2198.92, frequencyType: 'weekly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a week and as and when required.'),
  BoqItem(srNo: 26, mainArea: 'Goods Line-02', subArea: 'Line 02', basicAreaSqFt: 7696.20, tenderedAreaPerDay: 2198.92, frequencyType: 'weekly', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Twice in a week and as and when required.'),
  BoqItem(srNo: 27, mainArea: 'Goods Office building', subArea: 'CGS Office, FOIS, Store, Traders, Labour', basicAreaSqFt: 3818.40, tenderedAreaPerDay: 7636.80, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),
  BoqItem(srNo: 28, mainArea: 'Goods office gallery', subArea: 'Gallery', basicAreaSqFt: 1683.45, tenderedAreaPerDay: 3366.90, frequencyType: 'daily', boqTimesPerPeriod: 2, totalDays: 1461, frequencyDescription: 'Two times in a day and as and when required.'),
  BoqItem(srNo: 29, mainArea: 'Goods building front road area', subArea: 'Front Road', basicAreaSqFt: 3106.75, tenderedAreaPerDay: 3106.75, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 30, mainArea: 'Approach Road from Goods office to over bridge', subArea: 'Approach Road', basicAreaSqFt: 25820, tenderedAreaPerDay: 25820, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required.'),
  BoqItem(srNo: 31, mainArea: 'Goods building side open area', subArea: 'Open Area', basicAreaSqFt: 66.76, tenderedAreaPerDay: 66.76, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1461, frequencyDescription: 'Once in a day and as and when required'),

  // ── 32. Pest Control ──
  BoqItem(srNo: 32, mainArea: 'Pest & Rodent Control treatment', subArea: 'Pest Control', basicAreaSqFt: 1340609.08, tenderedAreaPerDay: 1340609.08, frequencyType: 'monthly', boqTimesPerPeriod: 1, totalDays: 48, frequencyDescription: '1 Treatment in Every Month or as and when required, Total 48 Treatment during 04(Four) years or as and when required'),

  // ── 33. Feedback System ──
  BoqItem(srNo: 33, mainArea: 'Computerised Passenger Feedback & Contract Management System', subArea: 'Feedback System', basicAreaSqFt: 0, tenderedAreaPerDay: 0, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 1, frequencyDescription: 'For 04 years'),

  // ── 34. Dustbins ──
  BoqItem(srNo: 34, mainArea: 'Dustbins', subArea: 'Blue-75, Green-75, Red-75, Black-75', basicAreaSqFt: 0, tenderedAreaPerDay: 0, frequencyType: 'daily', boqTimesPerPeriod: 1, totalDays: 300, frequencyDescription: '300 dustbins'),
];
