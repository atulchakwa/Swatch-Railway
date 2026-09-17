import 'package:crm_train/model/cleaning_form_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/view/common_railways/cleaning_forms/cleaning_form_screen.dart';
import 'package:crm_train/view/common_railways/cleaning_forms/cleaning_form_detail_screen.dart';

class CleaningFormDashboardScreen extends StatefulWidget {
  const CleaningFormDashboardScreen({super.key});

  @override
  State<CleaningFormDashboardScreen> createState() => _CleaningFormDashboardScreenState();
}

class _CleaningFormDashboardScreenState extends State<CleaningFormDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CleaningDashboardSummary summary = CleaningDashboardSummary();
  List<CleaningForm> forms = [];
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

  Future<void> _loadData() async {
    setState(() { isLoading = true; error = null; });
    try {
      final results = await Future.wait([
        ApiService.getCleaningFormDashboard(),
        ApiService.getCleaningForms(),
      ]);
      if (mounted) {
        setState(() {
          summary = results[0] as CleaningDashboardSummary;
          forms = results[1] as List<CleaningForm>;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final role = user?.role ?? '';
    final isSupervisor = role == 'Railway Supervisor';
    final isAdmin = role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master' || role == 'Contractor Admin' || role == 'Contractor Master';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSupervisor ? 'Pending Reviews' : isAdmin ? 'Cleaning Forms' : 'My Forms',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Pending', icon: Icon(Icons.hourglass_empty, size: 18)),
            Tab(text: 'All Forms', icon: Icon(Icons.list, size: 18)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('Error loading data', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                ]))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(user),
                    _buildPendingTab(),
                    _buildAllFormsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab(user) {
    final role = user?.role ?? '';
    final isSupervisor = role == 'Railway Supervisor';
    final isAdmin = role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master' || role == 'Contractor Admin' || role == 'Contractor Master';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(isSupervisor),
          if (isSupervisor) ...[
            const SizedBox(height: 16),
            _buildPendingReviewBanner(),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Forms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (!isAdmin)
                TextButton.icon(
                  onPressed: () => _navigateToForm(isCoach: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Form'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...forms.take(5).map((form) => _buildFormCard(form)),
          const SizedBox(height: 20),
          _buildQuickActions(isAdmin),
          if (isAdmin) ...[
            const SizedBox(height: 20),
            _buildAdminStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isSupervisor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Draft', '${summary.draftForms}', Colors.grey, Icons.edit_note)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Submitted', '${summary.submittedForms}', Colors.blue, Icons.send)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Approved', '${summary.approvedForms}', kSuccessGreen, Icons.check_circle)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Rejected', '${summary.rejectedForms}', kErrorRed, Icons.cancel)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Scored', '${summary.scoredForms}', Colors.purple, Icons.score)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Locked', '${summary.lockedForms}', Colors.grey.shade800, Icons.lock)),
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

  Widget _buildPendingReviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kWarningOrange, kErrorRed],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kWarningOrange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.rate_review, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pending Reviews', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${summary.pendingReview}',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                if (summary.scoringPending > 0) ...[
                  const SizedBox(height: 2),
                  Text('${summary.scoringPending} pending scoring', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(CleaningForm form) {
    final statusColor = _statusColor(form.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CleaningFormDetailScreen(formUid: form.uid ?? ''))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: form.formType == FormType.coach ? kRailwayBlue.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  form.formType == FormType.coach ? Icons.train : Icons.business,
                  color: form.formType == FormType.coach ? kRailwayBlue : Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(form.formId.length > 12 ? form.formId.substring(0, 12) : form.formId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(form.formTypeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text('${form.entityName} • ${form.cleaningDate}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (form.score != null)
                    Text('${form.score!.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kRailwayBlue)),
                  if (form.score != null) const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      form.statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(CleaningFormStatus status) {
    switch (status) {
      case CleaningFormStatus.draft: return Colors.grey;
      case CleaningFormStatus.submitted: return Colors.blue;
      case CleaningFormStatus.approved: return kSuccessGreen;
      case CleaningFormStatus.rejected: return kErrorRed;
      case CleaningFormStatus.scored: return Colors.purple;
      case CleaningFormStatus.locked: return Colors.grey.shade800;
      case CleaningFormStatus.scoringInProgress: return kWarningOrange;
      case CleaningFormStatus.contractorApproved: return Colors.teal;
      case CleaningFormStatus.autoApproved: return Colors.indigo;
    }
  }

  Widget _buildQuickActions(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(Icons.train, 'New Coach\nForm', () => _navigateToForm(isCoach: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(Icons.business, 'New Premise\nForm', () => _navigateToForm(isCoach: false)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(Icons.visibility, 'View All\nForms', () => _tabController.animateTo(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(Icons.assessment, 'Dashboard\nSummary', () => _tabController.animateTo(0)),
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

  Widget _buildAdminStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Division Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Avg Score', '${summary.averageScore.toStringAsFixed(1)}%', kSuccessGreen, Icons.trending_up)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Pending Review', '${summary.pendingReview}', kWarningOrange, Icons.hourglass_empty)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Manpower', '${summary.totalManpower.toInt()}', Colors.blue, Icons.people)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Machines', '${summary.totalMachine.toInt()}', Colors.teal, Icons.precision_manufacturing)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final pendingForms = forms.where((f) => f.status == CleaningFormStatus.submitted || f.status == CleaningFormStatus.scoringInProgress).toList();
    if (pendingForms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('No pending forms', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${pendingForms.length} Pending ${pendingForms.length == 1 ? 'Form' : 'Forms'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...pendingForms.map((form) => _buildPendingFormCard(form)),
      ],
    );
  }

  Widget _buildPendingFormCard(CleaningForm form) {
    final statusColor = _statusColor(form.status);
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
                Text(form.formId.length > 12 ? form.formId.substring(0, 12) : form.formId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(form.statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow('Type', form.formTypeLabel),
            _detailRow('Contractor', form.entityName),
            _detailRow('Contract', form.contractNumber),
            _detailRow('Date', form.cleaningDate),
            _detailRow('Shift', form.cleaningShift),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CleaningFormDetailScreen(formUid: form.uid ?? ''))),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllFormsTab() {
    if (forms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No forms yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${forms.length} Forms', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                _buildFilterChip('Coach', FormType.coach),
                const SizedBox(width: 8),
                _buildFilterChip('Premise', FormType.premise),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...forms.map((form) => _buildFormCard(form)),
      ],
    );
  }

  Widget _buildFilterChip(String label, FormType type) {
    return GestureDetector(
      onTap: () => _filterByType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kRailwayBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kRailwayBlue)),
      ),
    );
  }

  void _filterByType(FormType type) {
    setState(() {
      forms = forms.where((f) => f.formType == type).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Showing ${type == FormType.coach ? 'Coach' : 'Premise'} forms'), backgroundColor: kRailwayBlue),
    );
  }

  void _navigateToForm({required bool isCoach}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CleaningFormScreen(formType: isCoach ? FormType.coach : FormType.premise),
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
}
