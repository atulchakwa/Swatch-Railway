class AnnexureWeightageDefault {
  final int itemNo;
  final String name;
  final double weightage;
  final List<String> keywords;

  const AnnexureWeightageDefault({
    required this.itemNo,
    required this.name,
    required this.weightage,
    this.keywords = const [],
  });
}

/// Annexure-AB default weightages for station cleaning (tender-defined).
/// Items sum to 100%. Railway department can increase/decrease per station via
/// the Area Weightage screen; every save is versioned + audited.
const List<AnnexureWeightageDefault> annexureWeightageDefaults = [
  AnnexureWeightageDefault(itemNo: 1, name: 'Cleaning / washing / scrubbing of floor area incl. platforms, FOBs, subways, ramps & staircases', weightage: 45, keywords: ['platform', 'fob', 'subway', 'ramp', 'staircase', 'stair', 'walkway']),
  AnnexureWeightageDefault(itemNo: 2, name: 'Cleaning of tracks, track peripheral area & adjacent circulating area', weightage: 20, keywords: ['track']),
  AnnexureWeightageDefault(itemNo: 3, name: 'Cleaning of toilets, urinals, bathrooms & washing areas', weightage: 8, keywords: ['toilet', 'urinal', 'bathroom', 'washroom', 'latrine']),
  AnnexureWeightageDefault(itemNo: 4, name: 'Cleaning of walls, pillars, columns, roofs & ceilings of station building', weightage: 4, keywords: ['wall', 'pillar', 'column', 'roof', 'cover shed', 'facade']),
  AnnexureWeightageDefault(itemNo: 5, name: 'Cleaning of doors, windows & glass panes', weightage: 1.5, keywords: ['door', 'window', 'glass panes', 'glass']),
  AnnexureWeightageDefault(itemNo: 6, name: 'Cleaning of rolling shutters', weightage: 3.5, keywords: ['rollin', 'shutter']),
  AnnexureWeightageDefault(itemNo: 7, name: 'Cleaning of hand rails, railings, grilles & ladders', weightage: 0.5, keywords: ['hand rail', 'handrail', 'railing', 'grille', 'ladder']),
  AnnexureWeightageDefault(itemNo: 8, name: 'Cleaning / desilting of drains & gutters', weightage: 1.75, keywords: ['drain', 'gutter', 'desiltin']),
  AnnexureWeightageDefault(itemNo: 9, name: 'Cleaning of roofs / cobwebs & special cleanliness of high-level areas', weightage: 1, keywords: ['cobweb', 'roof cleaning', 'high level cleaning']),
  AnnexureWeightageDefault(itemNo: 10, name: 'Cleaning of glass roofs / skylights', weightage: 3, keywords: ['glass roof', 'skylight']),
  AnnexureWeightageDefault(itemNo: 11, name: 'Cleaning of public areas — waiting halls, booking offices & concourse', weightage: 2, keywords: ['waiting', 'booking', 'concourse', 'cloak room', 'refreshment']),
  AnnexureWeightageDefault(itemNo: 12, name: 'Cleaning of water coolers & drinking water points', weightage: 0.75, keywords: ['water cooler', 'water point', 'drinking water', 'water dispenser', 'cooler']),
  AnnexureWeightageDefault(itemNo: 13, name: 'Cleaning of fire-fighting equipment', weightage: 0.2, keywords: ['fire']),
  AnnexureWeightageDefault(itemNo: 14, name: 'Cleaning of escalators', weightage: 1, keywords: ['escalator']),
  AnnexureWeightageDefault(itemNo: 15, name: 'Cleaning of lifts', weightage: 1, keywords: ['lift']),
  AnnexureWeightageDefault(itemNo: 16, name: 'Cleaning of computers, monitors & office electronic equipment', weightage: 0.3, keywords: ['computer', 'monitor']),
  AnnexureWeightageDefault(itemNo: 17, name: 'Cleaning of furniture & fixtures', weightage: 0.3, keywords: ['furniture', 'fixture', 'furnishing', 'cabinet']),
  AnnexureWeightageDefault(itemNo: 18, name: 'Cleaning of UPS rooms & electrical fittings', weightage: 0.3, keywords: ['ups', 'electrical', 'switch panel', 'fittings']),
  AnnexureWeightageDefault(itemNo: 19, name: 'Cleaning of control rooms', weightage: 0.3, keywords: ['control room']),
  AnnexureWeightageDefault(itemNo: 20, name: 'Cleaning of air-conditioning units', weightage: 0.2, keywords: ['air conditioning', 'aircondition', 'ac unit', 'split ac', 'a/c']),
  AnnexureWeightageDefault(itemNo: 21, name: 'Cleaning of AFC, TVM, DFMD & other passenger amenities', weightage: 0.6, keywords: ['afc', 'tvm', 'dfmd', 'passenger amenit']),
  AnnexureWeightageDefault(itemNo: 22, name: 'Cleaning / sweeping of circulating area', weightage: 4, keywords: ['circulating']),
  AnnexureWeightageDefault(itemNo: 23, name: 'Disposal of garbage', weightage: 0.1, keywords: ['garbage', 'waste', 'dustbin', 'refuse', 'disposal']),
  AnnexureWeightageDefault(itemNo: 24, name: 'Sweeping of AC plants, high-level platforms & special areas', weightage: 0.2, keywords: ['ac plant', 'high level', 'high-rise', 'elevated']),
  AnnexureWeightageDefault(itemNo: 25, name: 'Pest control / rodent control', weightage: 0.5, keywords: ['pest', 'rodent', 'insect', 'fumigation']),
];

/// Auto-suggest the Annexure-AB item for a station area.
/// Matches keywords against `mainArea + areaName`; prefers the earliest
/// occurrence, then the longest keyword, then the lowest item number.
int? resolveAnnexureItemNo({String mainArea = '', String areaName = ''}) {
  final hay = '${mainArea ?? ''} ${areaName ?? ''}'.toLowerCase();
  if (hay.trim().isEmpty) return null;
  int? bestItem;
  var bestIdx = 0x7fffffff;
  var bestLen = 0;
  for (final item in annexureWeightageDefaults) {
    for (final k in item.keywords) {
      final idx = hay.indexOf(k);
      if (idx < 0) continue;
      if (idx < bestIdx || (idx == bestIdx && k.length > bestLen)) {
        bestItem = item.itemNo;
        bestIdx = idx;
        bestLen = k.length;
      }
    }
  }
  return bestItem;
}