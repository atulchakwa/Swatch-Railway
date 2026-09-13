class EstimateItem {
  final String uid;
  final String contractId;
  final String stationName;
  final String category;
  final int itemNo;
  final String description;
  final String area;
  final double quantity;
  final String unit;
  final Map<String, dynamic> frequency;
  final double rate;
  final double quantityPerDay;
  final double costPerDay;
  final double estimatedCost;
  final String startDate;
  final String endDate;
  final String nsRef;
  final bool isAdditional;
  final String approvalStatus;
  final String status;

  const EstimateItem({
    this.uid = '',
    this.contractId = '',
    this.stationName = '',
    this.category = 'cleaning',
    this.itemNo = 0,
    this.description = '',
    this.area = '',
    this.quantity = 0,
    this.unit = 'sq.ft.',
    this.frequency = const {},
    this.rate = 0,
    this.quantityPerDay = 0,
    this.costPerDay = 0,
    this.estimatedCost = 0,
    this.startDate = '',
    this.endDate = '',
    this.nsRef = '',
    this.isAdditional = false,
    this.approvalStatus = '',
    this.status = 'active',
  });

  factory EstimateItem.fromJson(Map<String, dynamic> json) => EstimateItem(
        uid: (json['id'] ?? json['uid'] ?? '').toString(),
        contractId: (json['contractId'] ?? '').toString(),
        stationName: (json['stationName'] ?? '').toString(),
        category: (json['category'] ?? 'cleaning').toString(),
        itemNo: (json['itemNo'] ?? 0) as int,
        description: (json['description'] ?? '').toString(),
        area: (json['area'] ?? '').toString(),
        quantity: (json['quantity'] ?? 0).toDouble(),
        unit: (json['unit'] ?? 'sq.ft.').toString(),
        frequency: json['frequency'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['frequency'] as Map<String, dynamic>)
            : const {},
        rate: (json['rate'] ?? 0).toDouble(),
        quantityPerDay: (json['quantityPerDay'] ?? 0).toDouble(),
        costPerDay: (json['costPerDay'] ?? 0).toDouble(),
        estimatedCost: (json['estimatedCost'] ?? 0).toDouble(),
        startDate: (json['startDate'] ?? '').toString(),
        endDate: (json['endDate'] ?? '').toString(),
        nsRef: (json['nsRef'] ?? '').toString(),
        isAdditional: json['isAdditional'] == true,
        approvalStatus: (json['approvalStatus'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
      );
}

class EstimateSummary {
  final int count;
  final List<EstimateItem> items;
  final double totalEstimatedCost;
  final Map<String, double> stationTotals;
  final Map<String, double> categoryTotals;

  const EstimateSummary({
    this.count = 0,
    this.items = const [],
    this.totalEstimatedCost = 0,
    this.stationTotals = const {},
    this.categoryTotals = const {},
  });

  factory EstimateSummary.fromJson(Map<String, dynamic> json) => EstimateSummary(
        count: (json['count'] ?? 0) as int,
        items: ((json['items'] ?? []) as List)
            .map((e) => EstimateItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totalEstimatedCost: (json['totalEstimatedCost'] ?? 0).toDouble(),
        stationTotals: _toDoubleMap(json['stationTotals']),
        categoryTotals: _toDoubleMap(json['categoryTotals']),
      );

  static Map<String, double> _toDoubleMap(dynamic v) {
    final m = <String, double>{};
    if (v is Map) {
      v.forEach((k, val) => m[k.toString()] = (val ?? 0).toDouble());
    }
    return m;
  }
}

class VariationRevision {
  final String uid;
  final int revisionNo;
  final String effectiveDate;
  final String description;
  final double originalContractValue;
  final double executedOriginalValue;
  final double reductionValue;
  final double additionalWorkValue;
  final double excessExecutionValue;
  final double recoveryDeductions;
  final double revisedScopeValue;
  final double netVariation;
  final double amendedContractValue;
  final String status;

  const VariationRevision({
    this.uid = '',
    this.revisionNo = 0,
    this.effectiveDate = '',
    this.description = '',
    this.originalContractValue = 0,
    this.executedOriginalValue = 0,
    this.reductionValue = 0,
    this.additionalWorkValue = 0,
    this.excessExecutionValue = 0,
    this.recoveryDeductions = 0,
    this.revisedScopeValue = 0,
    this.netVariation = 0,
    this.amendedContractValue = 0,
    this.status = '',
  });

  factory VariationRevision.fromJson(Map<String, dynamic> json) => VariationRevision(
        uid: (json['id'] ?? json['uid'] ?? '').toString(),
        revisionNo: (json['revisionNo'] ?? 0) as int,
        effectiveDate: (json['effectiveDate'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        originalContractValue: (json['originalContractValue'] ?? 0).toDouble(),
        executedOriginalValue: (json['executedOriginalValue'] ?? 0).toDouble(),
        reductionValue: (json['reductionValue'] ?? json['savings'] ?? 0).toDouble(),
        additionalWorkValue: (json['additionalWorkValue'] ?? 0).toDouble(),
        excessExecutionValue: (json['excessExecutionValue'] ?? 0).toDouble(),
        recoveryDeductions: (json['recoveryDeductions'] ?? 0).toDouble(),
        revisedScopeValue: (json['revisedScopeValue'] ?? 0).toDouble(),
        netVariation: (json['netVariation'] ?? 0).toDouble(),
        amendedContractValue: (json['amendedContractValue'] ?? 0).toDouble(),
        status: (json['status'] ?? '').toString(),
      );
}

class VariationSet {
  final int count;
  final List<VariationRevision> revisions;
  final VariationRevision? latest;

  const VariationSet({this.count = 0, this.revisions = const [], this.latest});

  factory VariationSet.fromJson(Map<String, dynamic> json) => VariationSet(
        count: (json['count'] ?? 0) as int,
        revisions: ((json['revisions'] ?? []) as List)
            .map((e) => VariationRevision.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        latest: json['latest'] == null
            ? null
            : VariationRevision.fromJson(Map<String, dynamic>.from(json['latest'] as Map)),
      );
}

class SwoItem {
  final String description;
  final double quantity;
  final double rate;
  final double amount;

  const SwoItem({this.description = '', this.quantity = 0, this.rate = 0, this.amount = 0});

  factory SwoItem.fromJson(Map<String, dynamic> json) => SwoItem(
        description: (json['description'] ?? '').toString(),
        quantity: (json['quantity'] ?? 0).toDouble(),
        rate: (json['rate'] ?? 0).toDouble(),
        amount: (json['amount'] ?? 0).toDouble(),
      );
}

class Swo {
  final String uid;
  final String swoNumber;
  final String description;
  final String startDate;
  final String endDate;
  final int contractDays;
  final List<SwoItem> items;
  final double totalValue;
  final String status;

  const Swo({
    this.uid = '',
    this.swoNumber = '',
    this.description = '',
    this.startDate = '',
    this.endDate = '',
    this.contractDays = 0,
    this.items = const [],
    this.totalValue = 0,
    this.status = '',
  });

  factory Swo.fromJson(Map<String, dynamic> json) => Swo(
        uid: (json['id'] ?? json['uid'] ?? '').toString(),
        swoNumber: (json['swoNumber'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        startDate: (json['startDate'] ?? '').toString(),
        endDate: (json['endDate'] ?? '').toString(),
        contractDays: (json['contractDays'] ?? 0) as int,
        items: ((json['items'] ?? []) as List)
            .map((e) => SwoItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totalValue: (json['totalValue'] ?? 0).toDouble(),
        status: (json['status'] ?? '').toString(),
      );
}

class SwoSet {
  final int count;
  final double totalSwoValue;
  final List<Swo> swos;

  const SwoSet({this.count = 0, this.totalSwoValue = 0, this.swos = const []});

  factory SwoSet.fromJson(Map<String, dynamic> json) => SwoSet(
        count: (json['count'] ?? 0) as int,
        totalSwoValue: (json['totalSwoValue'] ?? 0).toDouble(),
        swos: ((json['swos'] ?? []) as List)
            .map((e) => Swo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class AmendedValue {
  final String contractNumber;
  final double contractValue;
  final Map<String, dynamic>? latestRevision;
  final double totalSwoValue;
  final double amendedContractValue;
  final double estimateValue;
  final Map<String, dynamic>? trace;

  const AmendedValue({
    this.contractNumber = '',
    this.contractValue = 0,
    this.latestRevision,
    this.totalSwoValue = 0,
    this.amendedContractValue = 0,
    this.estimateValue = 0,
    this.trace,
  });

  factory AmendedValue.fromJson(Map<String, dynamic> json) => AmendedValue(
        contractNumber: (json['contractNumber'] ?? '').toString(),
        contractValue: (json['contractValue'] ?? 0).toDouble(),
        latestRevision: json['latestRevision'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['latestRevision'] as Map<String, dynamic>)
            : null,
        totalSwoValue: (json['totalSwoValue'] ?? 0).toDouble(),
        amendedContractValue: (json['amendedContractValue'] ?? 0).toDouble(),
        estimateValue: (json['estimateValue'] ?? 0).toDouble(),
        trace: json['trace'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['trace'] as Map<String, dynamic>)
            : null,
      );
}

class PeriodContribution {
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double total;
  final List<Map<String, dynamic>> rows;

  const PeriodContribution({this.periodStart, this.periodEnd, this.total = 0, this.rows = const []});

  factory PeriodContribution.fromJson(Map<String, dynamic> json) => PeriodContribution(
        periodStart: json['periodStart'] == null ? null : DateTime.tryParse(json['periodStart'].toString()),
        periodEnd: json['periodEnd'] == null ? null : DateTime.tryParse(json['periodEnd'].toString()),
        total: (json['total'] ?? 0).toDouble(),
        rows: ((json['rows'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}