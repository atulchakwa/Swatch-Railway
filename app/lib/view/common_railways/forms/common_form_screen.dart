import 'package:crm_train/controller/contractor_nav_controller.dart';
import 'package:crm_train/view/common_railways/forms/widgets/common_premises_card.dart';
import 'package:crm_train/view/common_railways/forms/widgets/railway_coach_form_card.dart';
import 'package:crm_train/view/common_railways/forms/widgets/railway_cts_form_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart' hide FormData;

import '../../../model/coach_form_model.dart';
import '../../../model/cts_form_model.dart';

import '../../common_contractor/form_screen/select_from_screen.dart';
import '../../../model/premises_form_model.dart';
import '../../../model/user_entity_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_services.dart';
import '../../../utills/app_colors.dart';
import '../../common_contractor/forms_details/contractor_coach_details.dart';
import '../../common_contractor/forms_details/contractor_cts_details.dart';
import '../../common_contractor/forms_details/contractor_premises_details.dart';
import '../scorecard_forms/common_premises_cleaning_scorecard.dart';
import '../widgets/rolevise_dropdowns.dart';


class CommonFormScreen extends StatefulWidget {
  final String role;
  final String userLevel;
  final String? initialStatus;
  final int initialTabIndex;

  const CommonFormScreen({
    super.key,
    required this.role,
    required this.userLevel,
    this.initialStatus,
    this.initialTabIndex = 0,
  });

  @override
  State<CommonFormScreen> createState() => _CommonFormScreenState();
}

class _CommonFormScreenState extends State<CommonFormScreen> with TickerProviderStateMixin {
  final String userZone = "Central Railway";
  bool isAccepted = false;
  bool isScored = false;
  bool isLocked = false;

  bool _isFiltersExpanded = false;

  List<EntityModel> _approvedEntities = [];
  String _selectedStatus = 'All';
  String? _selectedEntityId;
  String _selectedDateRange = 'All Time';
  String? _selectedFilterDivision;
  String? _selectedFilterDepot;


  List<String> _getBackendStatusCodes(String displayName) {
    switch (displayName) {
      case 'Pending':
        return ['SUBMITTED'];
      case 'Approved':
        return ['APPROVED_BY_RAILWAY'];
      case 'Scoring Pending':
        return ['SCORING_IN_PROGRESS'];
      case 'Locked':
        return ['LOCKED'];
      case 'Approved by Contractor':
        return ['AUTO_APPROVED', 'AUTO-APPROVE'];
      case 'Rejected':
        return ['REJECTED_BY_RAILWAY'];
      case 'Re-submitted':
        return ['RE-SUBMITTED'];
      case 'Scored':
        return ['SCORED'];
      default:
        return [displayName];
    }
  }

  List<CoachForm> _coachForms = [];
  List<FormData> _premisesForms = [];
  List<CTSForm> _ctsForms = [];
  List<CTSForm> _ctsPendingForms = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = "";

  late TabController _tabController;
  late ScrollController _coachScrollController;
  late ScrollController _premisesScrollController;
  late ScrollController _ctsScrollContoller;

  final Map<String, Map<String, List<String>>> zoneDivisionDepot = {
    "Central Railway": {
      "Mumbai": ["GICC", "CRD", "CSMT"],
      "Bhusawal": ["BSL Depot 1", "BSL Depot 2"],
      "Nagpur": ["NGP Main", "Ajni"],
      "Pune": ["PUNE-1", "PUNE-2"],
      "Solapur": ["SUR Depot"],
    },
    "Western Railway": {
      "Ahmedabad": ["ADI Yard", "Maninagar"],
      "Vadodara": ["BRC-1", "BRC-2"],
    },
  };

  String? selectedDivision;
  String? selectedDepot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _coachScrollController = ScrollController();
    _premisesScrollController = ScrollController();
    _ctsScrollContoller = ScrollController();
    selectedDivision = zoneDivisionDepot[userZone]!.keys.first;
    selectedDepot = zoneDivisionDepot[userZone]![selectedDivision!]!.first;

    if (widget.initialStatus != null) {
      _selectedStatus = widget.initialStatus!;
      _isFiltersExpanded = true;
    }

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });


    _setupStatusListener();
    _setupTabListener();

    _fetchApprovedEntities();
    _fetchAllForms();
  }

  void _setupTabListener() {
    final navController = Get.find<ContractorNavController>();

    ever(navController.formsInnerTabIndex, (int? tabIndex) {
      if (tabIndex != null && mounted) {
        _tabController.animateTo(tabIndex);
        _fetchAllForms();

        Future.delayed(const Duration(milliseconds: 500), () {
          navController.clearFormsInnerTabIndex();
        });
      }
    });
  }


  void _setupStatusListener() {
    final navController = Get.find<ContractorNavController>();


    ever(navController.formStatusFilter, (String? status) {
      if (status != null) {
        setState(() {
          _selectedStatus = status;
          _isFiltersExpanded = true;
        });


        Future.delayed(Duration(milliseconds: 500), () {
          navController.clearFormStatusFilter();
        });
      }
    });
  }

  Future<void> _fetchApprovedEntities() async {
    try {
      final entities = await ApiService.getApprovedEntity();
      setState(() {
        _approvedEntities = entities;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _coachScrollController.dispose();
    _premisesScrollController.dispose();
    _ctsScrollContoller.dispose();
    super.dispose();
  }

  Future<void> _fetchAllForms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _coachForms = [];
      _premisesForms = [];
      _ctsForms = [];
      _ctsPendingForms = [];
    });

    try {
      final api = ApiService();

      final results = await Future.wait([
        api.getIncomingCoachForms().catchError((e) => null),
        api.getScoredCoachForm().catchError((e) => null),
        api.getPendingPremiseForm().catchError((e) => null),
        api.getScoredPremisesForm().catchError((e) => null),
        api.getSubmittedCTSForms().catchError((e) => null),
        api.getPendingCTSForms().catchError((e) => null),
      ]);

      List<CoachForm> allCoachForms = [];
      List<FormData> allPremisesForms = [];
      List<CTSForm> allCTSForms = [];
      List<CTSForm> allCTSPendingForms = [];

      if (results[0] != null) {
        final res = results[0] as CoachFormsResponse;
        allCoachForms.addAll(res.forms);
      }

      if (results[1] != null) {
        final res = results[1] as CoachFormsResponse;
        allCoachForms.addAll(res.forms);
      }

      if (results[2] != null) {
        final res = results[2] as FormResponse;
        allPremisesForms.addAll(res.forms);
      }

      if (results[3] != null) {
        final res = results[3] as FormResponse;
        allPremisesForms.addAll(res.forms);
      }

      if (results[4] != null) {
        final res = results[4] as CTSFormsResponse;
        allCTSForms.addAll(res.forms);
      }

      if (results[5] != null) {
        final res = results[5] as CTSFormsResponse;
        allCTSPendingForms.addAll(res.forms);
      }

      setState(() {
        _coachForms = allCoachForms;
        _premisesForms = allPremisesForms;
        _ctsForms = allCTSForms;
        _ctsPendingForms = allCTSPendingForms;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Forms',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
              onPressed: _fetchAllForms,
              icon: const Icon(Icons.refresh, color: Colors.white))
        ],
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Coach'),
            Tab(text: 'Premises'),
            Tab(text: 'CTS'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoachFormsView(),
          _buildPremisesFormsView(),
          _buildCTSFormView(),
        ],
      ),
      floatingActionButton: (Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Super Admin' || widget.role == 'Super Admin') ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SelectFormTypeScreen()),
          );
        },
        backgroundColor: kRailwayBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Create Form",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ) : null,
    );
  }


  Widget _buildCoachFormsView() {
    return CustomScrollView(
      controller: _coachScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // _buildUserCard(),
                // const SizedBox(height: 14),
                _buildNewSubmissionsCard(),
                const SizedBox(height: 20),
                _buildFiltersAlternative(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildCoachFormsList(),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: const SizedBox(height: 30),
          ),
        ),
      ],
    );
  }


  Widget _buildPremisesFormsView() {
    return CustomScrollView(
      controller: _premisesScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // _buildUserCard(),
                // const SizedBox(height: 14),
                _buildNewSubmissionsCard(),
                const SizedBox(height: 20),
                _buildFiltersAlternative(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildPremisesFormsList(),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: const SizedBox(height: 30),
          ),
        ),
      ],
    );
  }



  Widget _buildCTSFormView() {
    return CustomScrollView(
      controller: _ctsScrollContoller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNewSubmissionsCard(),
                const SizedBox(height: 20),
                _buildFiltersAlternative(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildCTSFormsList(),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: const SizedBox(height: 30),
          ),
        ),
      ],
    );
  }



  Widget _buildCoachFormsList() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: kRailwayBlue),
              const SizedBox(height: 12),
              Text(
                'Loading coach forms...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    if (_coachForms.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No coach forms found.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    final filtered = _coachForms.where((form) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.submittedByName.toLowerCase().contains(query) ||
          form.submittedByEntityName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      if (_selectedEntityId != null && form.submittedByEntityId != _selectedEntityId) {
        return false;
      }


      if (_selectedDateRange != 'All Time') {
        final formDate = DateTime.fromMillisecondsSinceEpoch(form.createdAt.seconds * 1000);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        switch (_selectedDateRange) {
          case 'Today':
            final formDateOnly = DateTime(formDate.year, formDate.month, formDate.day);
            if (!formDateOnly.isAtSameMomentAs(today)) return false;
            break;
          case 'Last 7 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 7)))) return false;
            break;
          case 'Last 30 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 30)))) return false;
            break;
          case 'Last 90 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 90)))) return false;
            break;
        }
      }


      if (_selectedFilterDivision != null && form.submittedByDivision != _selectedFilterDivision) {
        return false;
      }


      if (_selectedFilterDepot != null && form.submittedByDepot != _selectedFilterDepot) {
        return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No matching coach forms.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final coachForm = filtered[index];
        return RailwayCoachFormCard(
          form: coachForm,
          onView: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorFormDetailsWithScorecard(form: coachForm),
              ),
            );
            _fetchAllForms();
          },
          onScore: () {
            _fetchAllForms();
          },
        );
      },
    );
  }


  Widget _buildPremisesFormsList() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: kRailwayBlue),
              const SizedBox(height: 12),
              Text(
                'Loading premises forms...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    if (_premisesForms.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No premises forms found.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    final filtered = _premisesForms.where((form) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = query.isEmpty ||
          form.location.toLowerCase().contains(query) ||
          form.submittedByName.toLowerCase().contains(query) ||
          form.submittedByEntityName.toLowerCase().contains(query) ||
          form.status.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      if (_selectedEntityId != null && form.submittedByEntityId != _selectedEntityId) {
        return false;
      }

      if (_selectedDateRange != 'All Time') {
        final formDate = DateTime.fromMillisecondsSinceEpoch(form.createdAt.seconds * 1000);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        switch (_selectedDateRange) {
          case 'Today':
            final formDateOnly = DateTime(formDate.year, formDate.month, formDate.day);
            if (!formDateOnly.isAtSameMomentAs(today)) return false;
            break;
          case 'Last 7 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 7)))) return false;
            break;
          case 'Last 30 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 30)))) return false;
            break;
          case 'Last 90 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 90)))) return false;
            break;
        }
      }

      if (_selectedFilterDivision != null && form.submittedByDivision != _selectedFilterDivision) {
        return false;
      }

      if (_selectedFilterDepot != null && form.submittedByDepot != _selectedFilterDepot) {
        return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No matching premises forms.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final premisesForm = filtered[index];
        return PremisesStatusCard(
          form: premisesForm,
          onView: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorPremisesFormDetails(model: premisesForm),
              ),
            );
            _fetchAllForms();
          },
          onRefresh: _fetchAllForms,
          onScore: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => CommonPremisesCleaningScorecard(model: premisesForm,)));
            _fetchAllForms();
          },
          onApprove: () async {
            final result = await ApiService.approvePremisesForm(formId: premisesForm.uid);
            if (result['success'] == true || result.containsKey('form')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Form approved successfully')),
              );
              _fetchAllForms();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to approve: ${result['message'] ?? 'Unknown error'}')),
              );
            }
          },
          onReject: (remark) async {
            final result = await ApiService.rejectPremisesForm(
              formId: premisesForm.uid,
              rejectRemark: remark,
            );
            if (result['success'] == true || result.containsKey('form')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Form rejected successfully')),
              );
              _fetchAllForms();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to reject: ${result['message'] ?? 'Unknown error'}')),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCTSFormsList() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: kRailwayBlue),
              const SizedBox(height: 12),
              Text(
                'Loading CTS forms...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    if (_ctsForms.isEmpty && _ctsPendingForms.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No CTS forms found.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    // Filter submitted CTS forms
    final filteredSubmitted = _ctsForms.where((form) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.submittedByName!.toLowerCase().contains(query) ||
          form.submittedByEntityName!.toLowerCase().contains(query) ||
          (form.status ?? '').toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status ?? '')) {
          return false;
        }
      }

      if (_selectedEntityId != null && form.submittedByEntityId != _selectedEntityId) {
        return false;
      }

      if (_selectedDateRange != 'All Time') {
        final formDate = DateTime.fromMillisecondsSinceEpoch(form.createdAt!.seconds * 1000);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        switch (_selectedDateRange) {
          case 'Today':
            final formDateOnly = DateTime(formDate.year, formDate.month, formDate.day);
            if (!formDateOnly.isAtSameMomentAs(today)) return false;
            break;
          case 'Last 7 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 7)))) return false;
            break;
          case 'Last 30 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 30)))) return false;
            break;
          case 'Last 90 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 90)))) return false;
            break;
        }
      }

      if (_selectedFilterDivision != null && form.submittedTo.division != _selectedFilterDivision) {
        return false;
      }

      if (_selectedFilterDepot != null && form.submittedTo.depot != _selectedFilterDepot) {
        return false;
      }

      return true;
    }).toList();

    // Filter pending CTS forms
    final filteredPending = _ctsPendingForms.where((form) {
      final query = _searchQuery.toLowerCase();
      bool matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.submittedByName!.toLowerCase().contains(query) ||
          form.submittedByEntityName!.toLowerCase().contains(query) ||
          (form.status ?? '').toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status ?? '')) {
          return false;
        }
      }

      if (_selectedEntityId != null && form.submittedByEntityId != _selectedEntityId) {
        return false;
      }

      if (_selectedDateRange != 'All Time') {
        final formDate = DateTime.fromMillisecondsSinceEpoch(form.createdAt!.seconds * 1000);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        switch (_selectedDateRange) {
          case 'Today':
            final formDateOnly = DateTime(formDate.year, formDate.month, formDate.day);
            if (!formDateOnly.isAtSameMomentAs(today)) return false;
            break;
          case 'Last 7 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 7)))) return false;
            break;
          case 'Last 30 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 30)))) return false;
            break;
          case 'Last 90 Days':
            if (formDate.isBefore(today.subtract(const Duration(days: 90)))) return false;
            break;
        }
      }

      if (_selectedFilterDivision != null && form.submittedTo.division != _selectedFilterDivision) {
        return false;
      }

      if (_selectedFilterDepot != null && form.submittedTo.depot != _selectedFilterDepot) {
        return false;
      }

      return true;
    }).toList();

    if (filteredSubmitted.isEmpty && filteredPending.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(
            'No matching CTS forms.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: filteredSubmitted.length + filteredPending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ctsForm = index < filteredSubmitted.length
            ? filteredSubmitted[index]
            : filteredPending[index - filteredSubmitted.length];

        return RailwayCTSFormCard(
          form: ctsForm,
          onView: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContractorCTSFormDetails(form: ctsForm),
              ),
            );
            _fetchAllForms();
          },
          onScore: () {
            _fetchAllForms();
          },
        );
      },
    );
  }

  int _getSubmittedCTSFormsCount() {
    final submittedCount = _ctsForms.where((form) =>
    form.status == 'SUBMITTED' || form.status == 'RE-SUBMITTED'
    ).length;

    final pendingCount = _ctsPendingForms.where((form) =>
    form.status == 'SUBMITTED' || form.status == 'RE-SUBMITTED'
    ).length;

    return submittedCount + pendingCount;
  }

  Widget _buildUserCard() {
    final user = Provider.of<AuthProvider>(context).currentUser;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFE9C8)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3BB273).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.apartment, color: Color(0xFF3BB273)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.fullName ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF26734D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.role ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF26734D),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getSubmittedCoachFormsCount() {
    return _coachForms.where((form) =>
    form.status == 'SUBMITTED' || form.status == 'RE-SUBMITTED'
    ).length;
  }

  int _getSubmittedPremisesFormsCount() {
    return _premisesForms.where((form) =>
    form.status == 'SUBMITTED' || form.status == 'RE-SUBMITTED'
    ).length;
  }

  Widget _buildNewSubmissionsCard() {
    final int submittedCount = _tabController.index == 0
        ? _getSubmittedCoachFormsCount()
        : _tabController.index == 1
            ? _getSubmittedPremisesFormsCount()
            : _getSubmittedCTSFormsCount();

    final String formType = _tabController.index == 0
        ? 'coach'
        : _tabController.index == 1
            ? 'premises'
            : 'CTS';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9DBFF)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3D73FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.notifications_none, color: Color(0xFF3D73FF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Submissions Available',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF2E56CC),
                  ),
                ),
                const SizedBox(height: 4),
                _isLoading
                    ? const Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E56CC),
                    height: 1.3,
                  ),
                )
                    : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '$submittedCount $formType ${submittedCount == 1 ? 'form' : 'forms'} ready for review',
                    key: ValueKey('$formType-$submittedCount'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E56CC),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAlternative() {
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isFiltersExpanded = !_isFiltersExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isFiltersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isFiltersExpanded
                ? Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown()),
                          const SizedBox(width: 10),
                          Expanded(child: _buildEntityDropdown()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDateRangeDropdown()),
                          const SizedBox(width: 10),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ZoneDivisionDepotDropdowns(
                        user: user!,
                        onChanged: (division, depot) {
                          setState(() {
                            _selectedFilterDivision = division;
                            _selectedFilterDepot = depot;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = "";
                        _selectedStatus = 'All';
                        _selectedEntityId = null;
                        _selectedDateRange = 'All Time';
                        _selectedFilterDivision = null;
                        _selectedFilterDepot = null;
                      });
                    },
                    child: const Text(
                      'Clear All Filters',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final displayStatusOptions = ['All', 'Pending', 'Re-submitted', 'Approved', 'Scoring Pending', 'Scored', 'Locked', 'Approved by Contractor', 'Rejected'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: displayStatusOptions.contains(_selectedStatus) ? _selectedStatus : 'All',
              items: displayStatusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedStatus = val ?? 'All';
                });
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedEntityId,
              hint: const Text('All Entities', style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Entities', style: TextStyle(fontSize: 12))),
                ..._approvedEntities.map((entity) => DropdownMenuItem<String?>(
                  value: entity.uid,
                  child: Text(entity.contractorName ?? 'Unknown', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                )).toList(),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedEntityId = val;
                });
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeDropdown() {
    final dateRangeOptions = ['All Time', 'Today', 'Last 7 Days', 'Last 30 Days', 'Last 90 Days'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDateRange,
              items: dateRangeOptions.map((range) => DropdownMenuItem(value: range, child: Text(range, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedDateRange = val ?? 'All Time';
                });
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

}