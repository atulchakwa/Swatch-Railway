import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_railways/billing/contract_billing_config_screen.dart';
import 'package:crm_train/view/common_railways/billing/monthly_bill_screen.dart';
import 'package:crm_train/view/common_railways/billing/billing_approval_screen.dart';
import 'package:crm_train/view/common_railways/billing/contractor_billing_dashboard.dart';
import 'package:crm_train/view/common_railways/billing/supervisor_billing_dashboard.dart';
import 'package:crm_train/view/common_railways/billing/billing_report_screen.dart';
import 'package:crm_train/model/billing_models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';

class BillingDashboardScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const BillingDashboardScreen({super.key, this.stationId, this.stationName});

  @override
  State<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends State<BillingDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BillingDashboardSummary summary = BillingDashboardSummary();
  List<BillingReport> recentBills = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() { isLoading = true; error = null; });
    try {
      final results = await Future.wait([
        ApiService.getBillingDashboard(),
        ApiService.getBillingReports(),
      ]);
      if (mounted) {
        setState(() {
          summary = results[0] as BillingDashboardSummary;
          recentBills = results[1] as List<BillingReport>;
          if (!silent) isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() { isLoading = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final role = user?.role ?? '';

    if (role == 'Railway Supervisor') {
      return const SupervisorBillingDashboard();
    }
    if (role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master') {
      return _buildAdminDashboard();
    }
    return ContractorBillingDashboard(stationId: widget.stationId ?? '', stationName: widget.stationName ?? '');
  }

  Widget _buildAdminDashboard() {
    final user = Provider.of<AuthProvider>(context).currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Billing Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if ((widget.stationName ?? '').isNotEmpty)
              Text('Station: ${widget.stationName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractBillingConfigScreen())),
            tooltip: 'Billing Configuration',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Pending', icon: Icon(Icons.hourglass_empty, size: 18)),
            Tab(text: 'Reports', icon: Icon(Icons.report, size: 18)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(error ?? 'Error loading data', style: TextStyle(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                ]))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(user),
                    _buildPendingTab(),
                    _buildReportsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingReportScreen())),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recentBills.take(5).map((bill) => _buildBillCard(bill)),
          const SizedBox(height: 20),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Pending Bills', '${summary.pendingBills}', Colors.orange, Icons.hourglass_empty)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Approved', '${summary.approvedBills}', Colors.green, Icons.check_circle)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Total Contract Value', '₹${_formatAmount(summary.totalContractValue)}', kRailwayBlue, Icons.currency_rupee)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Total Payable', '₹${_formatAmount(summary.totalPayable)}', Colors.teal, Icons.account_balance_wallet)),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(BillingReport bill) {
    final statusColor = bill.status == 'APPROVED' ? Colors.green : (bill.status == 'REJECTED' ? Colors.red : Colors.orange);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonthlyBillScreen(billId: bill.uid))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.uid.length > 12 ? bill.uid.substring(0, 12) : bill.uid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(bill.contractNumber, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text('${bill.entityName} • ${bill.period}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_formatAmount(bill.finalPayable)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kRailwayBlue)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(bill.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    final pending = recentBills.where((b) => b.status == 'PENDING').toList();
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('No pending bills', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Pending Approval', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...pending.map((bill) => _buildPendingApprovalCard(bill)),
      ],
    );
  }

  Widget _buildPendingApprovalCard(BillingReport bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bill.uid.length > 12 ? bill.uid.substring(0, 12) : bill.uid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow('Contract', bill.contractNumber),
            _detailRow('Contractor', bill.entityName),
            _detailRow('Period', bill.period),
            _detailRow('Amount', '₹${_formatAmount(bill.finalPayable)}'),
            _detailRow('Score', '${bill.overallScore}%'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveBill(bill.uid),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectBill(bill.uid),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveBill(String billId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Bill'),
        content: const Text('Are you sure you want to approve this bill? This will generate the invoice.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.approveBill(billId);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill approved successfully'), backgroundColor: Colors.green));
                _loadData(silent: true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectBill(String billId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter rejection reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService.rejectBill(billId, reason: reasonCtrl.text);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill rejected successfully'), backgroundColor: Colors.green));
                _loadData(silent: true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generate Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildReportTile(Icons.description, 'Monthly Billing Report', 'View and export monthly billing summaries'),
          _buildReportTile(Icons.assignment, 'Contract Billing Report', 'Contract-wise detailed billing report'),
          _buildReportTile(Icons.warning_amber, 'Penalty Report', 'Penalty breakdown and analytics'),
          _buildReportTile(Icons.business, 'Division Billing Report', 'Division-wise billing summary'),
          _buildReportTile(Icons.person, 'Contractor Billing Report', 'Contractor-wise billing history'),
          _buildReportTile(Icons.receipt_long, 'Invoice Register', 'All generated invoices register'),
        ],
      ),
    );
  }

  Widget _buildReportTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: kRailwayBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.download, color: kRailwayBlue),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingReportScreen()));
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(Icons.settings, 'Configure\nBilling Rules', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractBillingConfigScreen()))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(Icons.calculate, 'Generate\nMonthly Bill', () => _generateBill()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(Icons.approval, 'Pending\nApprovals', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingApprovalScreen()))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(Icons.assessment, 'Billing\nReports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingReportScreen()))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: kRailwayBlue, size: 28),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _generateBill() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Monthly Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select period for bill generation:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: 'Jun 2026',
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Billing Period'),
              items: ['Jun 2026', 'May 2026', 'Apr 2026'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill generation started for all active contracts'), backgroundColor: Colors.green));
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
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