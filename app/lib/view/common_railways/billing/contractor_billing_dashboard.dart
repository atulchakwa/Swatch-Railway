import 'package:crm_train/model/billing_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_railways/billing/monthly_bill_screen.dart';
import 'package:crm_train/view/common_railways/billing/billing_report_screen.dart';
import 'package:flutter/material.dart';

class ContractorBillingDashboard extends StatefulWidget {
  final String stationId;
  final String stationName;
  const ContractorBillingDashboard({super.key, this.stationId = '', this.stationName = ''});

  @override
  State<ContractorBillingDashboard> createState() => _ContractorBillingDashboardState();
}

class _ContractorBillingDashboardState extends State<ContractorBillingDashboard> {
  Map<String, dynamic>? data;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; });
    try {
      if (widget.stationId.isNotEmpty) {
        final contracts = await ApiService.getStationContracts(widget.stationId);
        final contractIds = contracts.map((c) => c.uid).toSet();
        final allBills = <BillingReport>[];
        for (final cid in contractIds) {
          try {
            allBills.addAll(await ApiService.getBillingReports(contractId: cid));
          } catch (_) {}
        }
        allBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        double pending = 0, approved = 0, deductions = 0;
        for (final b in allBills) {
          deductions += b.totalDeduction;
          if (b.status == 'PENDING') pending += b.finalPayable;
          if (b.status == 'APPROVED') approved += b.finalPayable;
        }
        final stationData = <String, dynamic>{
          'configs': contracts.length,
          'totalBills': allBills.length,
          'pendingAmount': pending,
          'approvedAmount': approved,
          'totalDeductions': deductions,
          'recentBills': allBills.take(10).map((b) => b.toJson()).toList(),
        };
        if (mounted) setState(() { data = stationData; isLoading = false; });
      } else {
        final result = await ApiService.getContractorBillingData();
        if (mounted) setState(() { data = result; isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationSuffix = widget.stationName.isNotEmpty ? ' - ${widget.stationName}' : '';
    return Scaffold(
      appBar: AppBar(
        title: Text('My Billing$stationSuffix', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh')],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? const Center(child: Text('Could not load billing data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentMonthBill(context),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      const Text('Recent Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...((data!['recentBills'] as List?) ?? []).map((b) => _buildBillHistoryCard(context, b as Map<String, dynamic>)),
                      if ((data!['recentBills'] as List?)?.isEmpty ?? true)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.stationName.isNotEmpty ? 'No bills found for ${widget.stationName}' : 'No bills yet',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text('Downloads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDownloadTile(context, Icons.picture_as_pdf, 'Download Invoice', 'Latest invoice'),
                      _buildDownloadTile(context, Icons.table_chart, 'Download Bill Summary', 'Excel format'),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentMonthBill(BuildContext context) {
    final bills = (data!['recentBills'] as List?) ?? [];
    final latest = bills.isNotEmpty ? bills[0] as Map<String, dynamic> : null;
    final pendingAmount = (data!['pendingAmount'] ?? 0).toDouble();
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: kRailwayBannerGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: kRailwayBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pending Bills Amount', style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 4),
            Text('Current Outstanding', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32)),
        ]),
        const SizedBox(height: 20),
        Text('₹${_formatAmount(pendingAmount)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (latest != null) ...[
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)), child: Text(latest['status'] ?? 'PENDING', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Text('Score: ${latest['overallScore'] ?? 'N/A'}%', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
          ]),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 16), label: const Text('Download Invoice', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.summarize, size: 16), label: const Text('Bill Summary', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)))),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final deductions = (data!['totalDeductions'] ?? 0).toDouble();
    final approved = (data!['approvedAmount'] ?? 0).toDouble();
    final totalBills = (data!['totalBills'] ?? 0);
    return Row(children: [
      Expanded(child: _statCard('Total Deductions', '₹${_formatAmount(deductions)}', Colors.red)),
      const SizedBox(width: 12),
      Expanded(child: _statCard('Approved Amount', '₹${_formatAmount(approved)}', Colors.green)),
      const SizedBox(width: 12),
      Expanded(child: _statCard('Total Bills', '$totalBills', Colors.blue)),
    ]);
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(2, 3))]),
      child: Column(children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 4), Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))]));
  }

  Widget _buildBillHistoryCard(BuildContext context, Map<String, dynamic> bill) {
    final status = bill['status'] ?? 'PENDING';
    final statusColor = status == 'APPROVED' ? Colors.green : Colors.orange;
    return Card(margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.receipt, color: kRailwayBlue, size: 24)),
        title: Text(bill['uid']?.toString().substring(0, 12) ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(bill['period'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${_formatAmount((bill['finalPayable'] ?? 0).toDouble())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kRailwayBlue)),
          const SizedBox(height: 2),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonthlyBillScreen(billId: bill['uid'] ?? ''))),
      ),
    );
  }

  Widget _buildDownloadTile(BuildContext context, IconData icon, String title, String subtitle) {
    return Card(margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: kRailwayBlue)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.download, color: kRailwayBlue),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillingReportScreen())),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}