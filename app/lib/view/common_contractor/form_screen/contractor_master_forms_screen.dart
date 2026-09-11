import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/view/common_contractor/form_screen/select_from_screen.dart';
import 'package:crm_train/view/station_cleaning/cleaning_form/station_cleaning_form_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import '../../../controller/contractor_nav_controller.dart';
import '../../../model/coach_form_model.dart' hide CoachEvaluation;
import '../../../model/coach_scorecard_model.dart';
import '../../../model/cts_form_model.dart';
import '../../../model/premises_form_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/draft_storage_service.dart';
import '../../common_railways/forms/widgets/common_cts_card.dart';
import '../../common_railways/forms/widgets/common_premises_card.dart';
import '../../common_railways/widgets/rolevise_dropdowns.dart';
import '../forms_details/contractor_coach_details.dart';
import '../forms_details/contractor_premises_details.dart';
import '../forms_details/contractor_cts_details.dart';
import 'forms/new_coach_form.dart';
import 'forms/new_premises_form.dart';

class ContractorMasterFormsScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? contractType;

  const ContractorMasterFormsScreen({super.key, this.initialTabIndex = 0, this.contractType});

  @override
  State<ContractorMasterFormsScreen> createState() => _ContractorMasterFormsScreenState();
}

class _ContractorMasterFormsScreenState extends State<ContractorMasterFormsScreen>
    with SingleTickerProviderStateMixin {
  FormResponse? _premisesResponse;
  bool _isFiltersExpanded = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  CoachFormsResponse? _response;
  CoachFormsResponse? _scoredResponse;
  CTSFormsResponse? _ctsPendingResponse;
  CTSFormsResponse? _ctsResponse;
  bool _isLoading = true;

  bool _isLoadingCTS = false;
  bool _isLoadingCTSPending = false;

  String? _coachErrorMessage;
  String? _premisesErrorMessage;
  String? _ctsErrorMessage;
  String _selectedDateRange = 'All Time';
  String? _selectedFilterDivision;
  String? _selectedFilterDepot;

  List<Map<String, dynamic>> _drafts = [];
  bool _isLoadingDrafts = false;

  List<Map<String, dynamic>> _premisesDrafts = [];
  bool _isLoadingPremisesDrafts = false;

  late TabController _tabController;

  Future<void> _fetchCoachForms() async {
    setState(() {
      _isLoading = true;
      _coachErrorMessage = null;
    });

    try {
      final api = ApiService();
      final result = await api.getSubmittedCoachForms();

      if (result != null) {
        setState(() {
          _response = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _coachErrorMessage = 'Failed to fetch forms';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _coachErrorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchScoredCoachForms() async {
    try {
      final api = ApiService();
      final result = await api.getScoredCoachForms(status: 'SCORED');

      if (result != null) {
        setState(() {
          _scoredResponse = result;
        });
      }
    } catch (e) {
      print('Error fetching scored forms: $e');
    }
  }

  Future<void> _fetchPremisesForms() async {
    setState(() {
      _isLoading = true;
      _premisesErrorMessage = null;
    });

    try {
      final api = ApiService();
      final result = await api.getSubmittedPremiseForm();

      if (result != null) {
        setState(() {
          _premisesResponse = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _premisesErrorMessage = 'Failed to fetch forms';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _premisesErrorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCTSForms() async {
    setState(() {
      _isLoadingCTS = true;
      _ctsErrorMessage = null;
    });

    try {
      final api = ApiService();
      final result = await api.getSubmittedCTSForms();

      if (result != null) {
        setState(() {
          _ctsResponse = result;
          _isLoadingCTS = false;
        });
      } else {
        setState(() {
          _ctsErrorMessage = 'Failed to fetch CTS forms';
          _isLoadingCTS = false;
        });
      }
    } catch (e) {
      setState(() {
        _ctsErrorMessage = 'Error: $e';
        _isLoadingCTS = false;
      });
    }
  }

  Future<void> _fetchCTSPendingForms() async {
    setState(() {
      _isLoadingCTSPending = true;
    });

    try {
      final api = ApiService();
      final result = await api.getPendingCTSForms();

      if (result != null) {
        setState(() {
          _ctsPendingResponse = result;
          _isLoadingCTSPending = false;
        });
      } else {
        setState(() {
          _isLoadingCTSPending = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCTSPending = false;
      });
      print('Error fetching pending CTS forms: $e');
    }
  }

  Future<void> _fetchDrafts() async {
    setState(() => _isLoadingDrafts = true);
    try {
      final drafts = await DraftStorageService.getDraftsList();
      setState(() {
        _drafts = drafts;
        _isLoadingDrafts = false;
      });
    } catch (e) {
      setState(() => _isLoadingDrafts = false);
      print('Error fetching drafts: $e');
    }
  }

  Future<void> _fetchPremisesDrafts() async {
    setState(() => _isLoadingPremisesDrafts = true);
    try {
      final drafts = await DraftStorageService.getPremisesDraftsList();
      setState(() {
        _premisesDrafts = drafts;
        _isLoadingPremisesDrafts = false;
      });
    } catch (e) {
      setState(() => _isLoadingPremisesDrafts = false);
      print('Error fetching premises drafts: $e');
    }
  }

  String _selectedStatus = 'All Status';

  final List<String> _statuses = [
    'All Status',
    'Pending',
    'Re-submitted',
    'Approved',
    'Scoring Pending',
    'Scored',
    'Locked',
    'Auto-Approved',
    'Rejected',
  ];


  List<String> _getBackendStatusCodes(String displayName) {
    switch (displayName) {
      case 'Pending':
        return ['SUBMITTED'];
      case 'Approved':
        return ['APPROVED_BY_RAILWAY'];
      case 'Scoring Pending':
        return ['APPROVED_BY_RAILWAY'];
      case 'Locked':
        return ['LOCKED', 'AUTO-APPROVED'];
      case 'Auto-Approved':
        return ['AUTO-APPROVED',];
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



  @override
  void initState() {
    super.initState();
    final isStationCleaning = widget.contractType == 'station_cleaning';
    _tabController = TabController(length: isStationCleaning ? 1 : 3, vsync: this, initialIndex: widget.initialTabIndex);
    _fetchCoachForms();
    _fetchPremisesForms();
    _fetchCTSForms();
    _fetchDrafts();
    _fetchPremisesDrafts();
    _setupTabListener();
    _fetchCTSPendingForms();
  }

  void _setupTabListener() {
    final navController = Get.find<ContractorNavController>();

    ever(navController.formsInnerTabIndex, (int? tabIndex) {
      if (tabIndex != null && mounted) {
        _tabController.animateTo(tabIndex);
        _fetchAllData();

        Future.delayed(const Duration(milliseconds: 500), () {
          navController.clearFormsInnerTabIndex();
        });
      }
    });
  }

  void _fetchAllData() {
    _fetchCoachForms();
    _fetchPremisesForms();
    _fetchCTSForms();
    _fetchDrafts();
    _fetchPremisesDrafts();
    _fetchCTSPendingForms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final bool canCreateForm = user?.role != 'Contractor Supervisor';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Forms Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchCoachForms();
                _fetchScoredCoachForms();
                _fetchPremisesForms();
                _fetchCTSForms();
                _fetchDrafts();
                _fetchPremisesDrafts();
                _fetchCTSPendingForms();
              },
              tooltip: 'Refresh',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: widget.contractType == 'station_cleaning'
                ? const [
                    Tab(child: Text('Station Cleaning', style: TextStyle(fontWeight: FontWeight.w600))),
                  ]
                : const [
                    Tab(child: Text('Coach', style: TextStyle(fontWeight: FontWeight.w600))),
                    Tab(child: Text('Premises', style: TextStyle(fontWeight: FontWeight.w600))),
                    Tab(child: Text('CTS', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.contractType == 'station_cleaning'
            ? [_buildStationCleaningFormsTab()]
            : [
                _buildCoachFormsTab(),
                _buildPremisesFormsTab(),
                _buildCtsFormsTab()
              ],
      ),
      floatingActionButton: canCreateForm ? FloatingActionButton.extended(
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


  Widget _buildCoachFormsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _buildUserCard(),
          // const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildFilterSection(),
          const SizedBox(height: 20),
          const Text("Coach Forms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildFormsList(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }



  Widget _buildPremisesFormsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _buildUserCard(),
          // const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildFilterSection(),
          const SizedBox(height: 20),
          const Text("Premises Forms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildFormsList2(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildStationCleaningFormsTab() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final stationIds = user?.stations ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Station Cleaning Forms",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (stationIds.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No stations assigned to your contract.',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            )
          else
            FutureBuilder<List<Station>>(
              future: ApiService.getStations(),
              builder: (ctx, snapshot) {
                final stations = snapshot.data ?? [];
                return Column(
                  children: stationIds.map((sid) {
                    final station = stations.cast<Station?>().firstWhere(
                      (s) => s?.uid == sid || s?.stationCode == sid || s?.stationName == sid,
                      orElse: () => null,
                    );
                    final displayName = station?.stationName ?? sid;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.train, color: kRailwayBlue),
                        title: Text(displayName),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StationCleaningFormListScreen(
                                stationId: sid,
                                stationName: displayName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCtsFormsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildFilterSection(),
          const SizedBox(height: 20),
          const Text("CTS Forms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildCtsFormsList(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }


  Widget _buildCtsFormsList() {
    if (_isLoadingCTS && _isLoadingCTSPending) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: kRailwayBlue),
        ),
      );
    }

    if (_ctsErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            _ctsErrorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    final submittedForms = _ctsResponse?.forms ?? [];
    final pendingForms = _ctsPendingResponse?.forms ?? [];

    print('DEBUG: Submitted forms: ${submittedForms.length}');
    print('DEBUG: Pending forms: ${pendingForms.length}');

    final filteredSubmittedForms = submittedForms.where((form) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.trainNumber.toLowerCase().contains(query) ||
          form.contractorName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      return true;
    }).toList();

    final filteredPendingForms = pendingForms.where((form) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.trainNumber.toLowerCase().contains(query) ||
          form.contractorName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      return true;
    }).toList();

    print('DEBUG: Filtered submitted: ${filteredSubmittedForms.length}');
    print('DEBUG: Filtered pending: ${filteredPendingForms.length}');

    if (filteredSubmittedForms.isEmpty && filteredPendingForms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No CTS forms found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...filteredSubmittedForms.map((form) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CTSFormStatusCard(
              form: form,
              onView: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContractorCTSFormDetails(form: form),
                  ),
                );
                _fetchCTSForms();
                _fetchCTSPendingForms();
              },
              onPdf: () {
                _fetchCTSForms();
                _fetchCTSPendingForms();
              },
              onScore: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scoring form ${form.uid}')),
                );
              },
            ),
          );
        }),

        ...filteredPendingForms.map((form) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CTSFormStatusCard(
              form: form,
              onView: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContractorCTSFormDetails(form: form),
                  ),
                );
                _fetchCTSForms();
                _fetchCTSPendingForms();
              },
              onPdf: () {
                _fetchCTSForms();
                _fetchCTSPendingForms();
              },
              onScore: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scoring form ${form.uid}')),
                );
              },
            ),
          );
        }),
      ],
    );
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
            child: const Icon(Icons.person, color: Color(0xFF3BB273)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.fullName}',
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.only(top: 12),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          hintText: "Search by Form ID, Train, Contractor...",
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
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


  Widget _buildFilterSection() {
    final user = Provider.of<AuthProvider>(context).currentUser;
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: kRailwayBlue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isFiltersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: kRailwayBlue,
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
                          Expanded(child: _buildDateRangeDropdown()),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterDropdown(
                              'Status',
                              _selectedStatus,
                              _statuses,
                              (v) => setState(() => _selectedStatus = v!),
                            ),
                          ),
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
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = "";
                          _selectedDateRange = 'All Time';
                          _selectedStatus = 'All Status';
                          _selectedFilterDivision = null;
                          _selectedFilterDepot = null;
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear Filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: kRailwayBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildFilterDropdown(
      String label,
      String value,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ))
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildFormsList() {
    if (_isLoading || _isLoadingDrafts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: kRailwayBlue),
        ),
      );
    }

    if (_coachErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            _coachErrorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    final forms = _response?.forms ?? [];

    final filteredForms = forms.where((form) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          form.trainName.toLowerCase().contains(query) ||
          form.submittedByName.toLowerCase().contains(query) ||
          form.submittedByEntityName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      final matchesDivision = _selectedFilterDivision == null ||
          _selectedFilterDivision!.isEmpty ||
          form.submittedByDivision == _selectedFilterDivision;

      if (!matchesDivision) return false;

      final matchesDepot = _selectedFilterDepot == null ||
          _selectedFilterDepot!.isEmpty ||
          form.submittedByDepot == _selectedFilterDepot;

      if (!matchesDepot) return false;

      if (_selectedDateRange != 'All Time' && form.createdAt != null) {
        final timestamp = form.createdAt!;
        final formDate = DateTime.fromMillisecondsSinceEpoch(
            timestamp.seconds * 1000 + (timestamp.nanoseconds / 1000000).round()
        );

        final now = DateTime.now();

        switch (_selectedDateRange) {
          case 'Today':
            final todayStart = DateTime(now.year, now.month, now.day);
            if (formDate.isBefore(todayStart)) return false;
            break;
          case 'Last 7 Days':
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            if (formDate.isBefore(sevenDaysAgo)) return false;
            break;
          case 'Last 30 Days':
            final thirtyDaysAgo = now.subtract(const Duration(days: 30));
            if (formDate.isBefore(thirtyDaysAgo)) return false;
            break;
          case 'Last 90 Days':
            final ninetyDaysAgo = now.subtract(const Duration(days: 90));
            if (formDate.isBefore(ninetyDaysAgo)) return false;
            break;
        }
      }

      return true;
    }).toList();

    final filteredDrafts = _drafts.where((draft) {
      final query = _searchQuery.toLowerCase();
      final trainName = draft['trainName']?.toString().toLowerCase() ?? '';
      final submittedBy = draft['submittedByName']?.toString().toLowerCase() ?? '';

      final matchesSearch = query.isEmpty ||
          trainName.contains(query) ||
          submittedBy.contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        return false;
      }

      final matchesDivision = _selectedFilterDivision == null ||
          _selectedFilterDivision!.isEmpty ||
          draft['division'] == _selectedFilterDivision;

      if (!matchesDivision) return false;

      final matchesDepot = _selectedFilterDepot == null ||
          _selectedFilterDepot!.isEmpty ||
          draft['depot'] == _selectedFilterDepot;

      return matchesDepot;
    }).toList();

    if (filteredForms.isEmpty && filteredDrafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No forms match the selected filters.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...filteredDrafts.map((draft) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DraftFormCard(
            draft: draft,
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewCoachFormScreen(draftData: draft),
                ),
              );
              if (result == true) {
                _fetchDrafts();
                _fetchCoachForms();
              }
            },
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Draft'),
                  content: const Text('Are you sure you want to delete this draft?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await DraftStorageService.deleteDraft(draft['draftId']);
                _fetchDrafts();
                _showSnack('Draft deleted');
              }
            },
          ),
        )),

        ...filteredForms.map((form) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormStatusCard(
            form: form,
            onView: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContractorFormDetailsWithScorecard(
                    form: form,
                    scorecard: form.ratingDetails != null
                        ? _convertToScorecardResponse(form)
                        : null,
                  ),
                ),
              );
              _fetchCoachForms();
              _fetchScoredCoachForms();
            },
            onPdf: () {
              _fetchCoachForms();
              _fetchScoredCoachForms();
            },
            onScore: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scoring form ${form.uid}')),
              );
            },
          ),
        )),
      ],
    );
  }


  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));



  Widget _buildFormsList2() {
    if (_isLoading || _isLoadingPremisesDrafts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: kRailwayBlue),
        ),
      );
    }

    if (_premisesErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            _premisesErrorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 15),
          ),
        ),
      );
    }

    final forms = _premisesResponse?.forms ?? [];

    // Filter regular forms
    final filteredForms = forms.where((form) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          form.location.toLowerCase().contains(query) ||
          form.submittedByName.toLowerCase().contains(query) ||
          form.submittedByEntityName.toLowerCase().contains(query) ||
          form.status.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        final backendCodes = _getBackendStatusCodes(_selectedStatus);
        if (!backendCodes.contains(form.status)) {
          return false;
        }
      }

      final matchesDivision = _selectedFilterDivision == null ||
          _selectedFilterDivision!.isEmpty ||
          form.submittedByDivision == _selectedFilterDivision;

      if (!matchesDivision) return false;

      final matchesDepot = _selectedFilterDepot == null ||
          _selectedFilterDepot!.isEmpty ||
          form.submittedByDepot == _selectedFilterDepot;

      if (!matchesDepot) return false;

      if (_selectedDateRange != 'All Time' && form.createdAt != null) {
        final timestamp = form.createdAt!;
        final formDate = DateTime.fromMillisecondsSinceEpoch(
            timestamp.seconds * 1000 + (timestamp.nanoseconds / 1000000).round()
        );

        final now = DateTime.now();

        switch (_selectedDateRange) {
          case 'Today':
            final todayStart = DateTime(now.year, now.month, now.day);
            if (formDate.isBefore(todayStart)) return false;
            break;
          case 'Last 7 Days':
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            if (formDate.isBefore(sevenDaysAgo)) return false;
            break;
          case 'Last 30 Days':
            final thirtyDaysAgo = now.subtract(const Duration(days: 30));
            if (formDate.isBefore(thirtyDaysAgo)) return false;
            break;
          case 'Last 90 Days':
            final ninetyDaysAgo = now.subtract(const Duration(days: 90));
            if (formDate.isBefore(ninetyDaysAgo)) return false;
            break;
        }
      }

      return true;
    }).toList();

    final filteredPremisesDrafts = _premisesDrafts.where((draft) {
      final query = _searchQuery.toLowerCase();
      final location = draft['location']?.toString().toLowerCase() ?? '';
      final submittedBy = draft['submittedByName']?.toString().toLowerCase() ?? '';

      final matchesSearch = query.isEmpty ||
          location.contains(query) ||
          submittedBy.contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatus != 'All Status') {
        return false;
      }

      final matchesDivision = _selectedFilterDivision == null ||
          _selectedFilterDivision!.isEmpty ||
          draft['division'] == _selectedFilterDivision;

      if (!matchesDivision) return false;

      final matchesDepot = _selectedFilterDepot == null ||
          _selectedFilterDepot!.isEmpty ||
          draft['depot'] == _selectedFilterDepot;

      return matchesDepot;
    }).toList();

    if (filteredForms.isEmpty && filteredPremisesDrafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No forms match the selected filters.',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...filteredPremisesDrafts.map((draft) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PremisesDraftFormCard(
            draft: draft,
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PremisesCleaningForm(draftData: draft),
                ),
              );
              if (result == true) {
                _fetchPremisesDrafts();
                _fetchPremisesForms();
              }
            },
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Draft'),
                  content: const Text('Are you sure you want to delete this draft?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await DraftStorageService.deletePremisesDraft(draft['draftId']);
                _fetchPremisesDrafts();
                _showSnack('Draft deleted');
              }
            },
          ),
        )),

        ...filteredForms.map((form) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PremisesStatusCard(
            form: form,
            onView: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContractorPremisesFormDetails(model: form),
                ),
              );
              _fetchPremisesForms();
            },
            onRefresh: _fetchPremisesForms,
            onScore: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scoring form ${form.uid}')),
            ),
          ),
        )),
      ],
    );
  }


  ScorecardResponse _convertToScorecardResponse(CoachForm form) {
    final ratingDetails = form.ratingDetails!;
    return ScorecardResponse(
      scorecardId: form.uid,
      formId: form.uid,
      workType: ratingDetails.workType,
      acwpStatus: ratingDetails.acwpStatus,
      evaluations: ratingDetails.coachEvaluationTable
          .map((e) => CoachEvaluation(
        coachNumber: e.coachNumber,
        internalCleaning: e.internalCleaning,
        externalCleaning: e.externalCleaning,
        intensiveCleaning: e.intensiveCleaning,
        toiletries: e.toiletries,
        doorsLocking: e.doorsLocking,
        watering: e.watering,
        penalty: e.penalty,
      ))
          .toList(),
      submittedBy: form.submittedTo.railwayEmployeeName,
      submittedDate: form.ratedAt?.toDateTime() ?? DateTime.now(),
      summary: {},
    );
  }
}

class ScoredFormStatusCard extends StatelessWidget {
  final CoachForm form;
  final VoidCallback? onView;

  const ScoredFormStatusCard({
    super.key,
    required this.form,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final ratingDetails = form.ratingDetails;
    final totalPenalty = ratingDetails?.totalPenalty ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 1,
                child: const Text(
                  'Coach Cleaning',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SCORED ✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Train: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: form.trainName.isNotEmpty ? form.trainName : 'N/A'),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Work Type: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: ratingDetails?.workType ?? 'N/A'),
                const TextSpan(text: '   •   '),
                const TextSpan(
                    text: 'Total Penalty: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: '₹$totalPenalty',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Total Coaches: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: '${ratingDetails?.summary.totalCoaches ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRailwayBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Scorecard',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class FormStatusCard extends StatefulWidget {
  final CoachForm form;
  final VoidCallback? onView;
  final VoidCallback? onPdf;
  final VoidCallback? onScore;

  const FormStatusCard({
    super.key,
    required this.form,
    this.onView,
    this.onPdf,
    this.onScore,
  });

  @override
  State<FormStatusCard> createState() => _FormStatusCardState();
}

class _FormStatusCardState extends State<FormStatusCard> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final statusInfo = widget.form.getStatusInfo();
    final user = Provider.of<AuthProvider>(context).currentUser;
    final bool canPerformActions = user?.role != 'Contractor Supervisor';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 1,
                child: const Text(
                  'Coach\nCleaning',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color'],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                      () {
                    switch (widget.form.status) {
                      case 'SUBMITTED':
                        return 'Waiting for railway approval';

                      case 'APPROVED_BY_RAILWAY':
                        return 'Approved by railway';

                      case 'REJECTED_BY_RAILWAY':
                        return 'Reject by railway';

                      case 'SCORED':
                        return 'Auto approved in 30 min';

                      case 'AUTO-APPROVED':
                        return 'Locked';

                      case 'LOCKED':
                        return 'Locked';

                      default:
                        return widget.form.status;
                    }
                  }(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusInfo['textColor'],
                    fontWeight: FontWeight.w500,
                  ),
                ),

              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Train: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: widget.form.trainName.isNotEmpty ? widget.form.trainName : 'N/A'),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Submitted by: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: '${widget.form.submittedByName}   •   '),
                const TextSpan(
                    text: 'Submitted to: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: widget.form.submittedTo.railwayEmployeeName ?? 'N/A'),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Timestamp: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: '${widget.form.getFormattedDateTime()}   •   '),
                const TextSpan(
                    text: 'Division: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: widget.form.submittedByDivision),
                if (widget.form.submittedByDepot?.toString().isNotEmpty ?? false) ...[
                  const TextSpan(text: ' • '),
                  const TextSpan(
                    text: 'Depot: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: widget.form.submittedByDepot!),
                ]

              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton('View', Colors.grey.shade200, Colors.black, widget.onView, false),
              if (canPerformActions) _buildStatusActionButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      String text, Color bg, Color color, VoidCallback? onPressed, bool isLoading) {
    return Expanded(
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: color,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w600,fontSize: 12),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusActionButton(BuildContext context) {
    String btnText = '';
    Color btnColor = Colors.grey;
    VoidCallback? callback;
    bool isLoading = false;

    switch (widget.form.status) {
      case 'SUBMITTED':
        btnText = 'SUBMITTED';
        btnColor = Colors.grey;
        callback = null;
        break;

      case 'REJECTED_BY_RAILWAY':
        btnText = 'RE-SUBMIT';
        btnColor = Colors.blue;
        callback = () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewCoachFormScreen(
                existingForm: widget.form,
                isResubmit: true,
              ),
            ),
          );
          if (result == true && widget.onPdf != null) {
            widget.onPdf!();
          }
        };
        break;

      case 'APPROVED_BY_RAILWAY':
        btnText = 'IN REVIEW';
        btnColor = Colors.orange;
        callback = null;
        break;

      case 'AUTO-APPROVED':
        btnText = 'LOCKED';
        btnColor = Colors.red;
        callback = (){};
        break;

      case 'SCORED':
        btnText = 'ACCEPT';
        btnColor = Colors.green;
        isLoading = _isAccepting;
        callback = _isAccepting ? null : () => _acceptScoredForm(context);
        break;

      case 'LOCKED':
        btnText = 'LOCKED';
        btnColor = Colors.red;
        callback = () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This form is locked. You cannot process it any more."),
            ),
          );
        };
        break;

      default:
        btnText = widget.form.status;
        btnColor = kRailwayBlue;
        callback = widget.onPdf;
    }

    return _actionButton(btnText, btnColor, Colors.white, callback, isLoading);
  }
  Future<void> _acceptScoredForm(BuildContext context) async {
    setState(() => _isAccepting = true);

    try {
      final result = await ApiService.acceptScoredForm(formId: widget.form.uid);

      if (result["success"] != false) {
        if (mounted) {
          String message = result["message"] ?? "Form accepted successfully";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );

          if (widget.onPdf != null) {
            widget.onPdf!();
          }

          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        if (mounted) {
          String errorMsg = result["message"] ?? "Failed to accept form";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }
}

class DraftFormCard extends StatelessWidget {
  final Map<String, dynamic> draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DraftFormCard({
    super.key,
    required this.draft,
    required this.onEdit,
    required this.onDelete,
  });

  String _getDisplayValue(dynamic value, String fieldName) {
    if (value == null) return 'Empty';

    if (value is String && value.trim().isEmpty) return 'Empty';
    if (value is num && value == 0) return 'Empty';
    if (value is List && value.isEmpty) return 'Empty';
    if (value is Map && value.isEmpty) return 'Empty';

    return value.toString();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Empty';
    try {
      final dateTime = DateTime.parse(isoString);
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    } catch (e) {
      return 'Empty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final bool canPerformActions = user?.role != 'Contractor Supervisor';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 1,
                child: const Text(
                  'Coach\nCleaning',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Draft',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Train: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['trainName'], 'trainName'),
                  style: TextStyle(
                    color: draft['trainName']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Saved by: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['submittedByName'], 'submittedByName'),
                  style: TextStyle(
                    color: draft['submittedByName']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const TextSpan(text: '   •   '),
                const TextSpan(
                    text: 'Supervisor: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['supervisorName'], 'supervisorName'),
                  style: TextStyle(
                    color: draft['supervisorName']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: draft['updatedAt'] != null ? 'Updated at: ' : 'Saved at: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: _formatDateTime(draft['updatedAt'] ?? draft['savedAt']),
                  style: TextStyle(
                    color: (draft['updatedAt'] ?? draft['savedAt']) == null
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const TextSpan(text: '   •   '),
                const TextSpan(
                    text: 'Division: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['division'], 'division'),
                  style: TextStyle(
                    color: draft['division']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                if (draft['depot']?.toString().isNotEmpty ?? false) ...[
                  const TextSpan(text: '   •   '),
                  const TextSpan(
                    text: 'Depot: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: _getDisplayValue(draft['depot'], 'depot'),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ]

              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    onPressed: canPerformActions ? onEdit : null,
                    label: const Text(
                      'Edit Draft',
                      style: TextStyle(fontWeight: FontWeight.w600,color: Colors.black,fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    onPressed: canPerformActions ? onDelete : null,
                    label: const Text(
                      'DELETE',
                      style: TextStyle(fontWeight: FontWeight.w600,fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremisesDraftFormCard extends StatelessWidget {
  final Map<String, dynamic> draft;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PremisesDraftFormCard({
    super.key,
    required this.draft,
    required this.onEdit,
    required this.onDelete,
  });

  String _getDisplayValue(dynamic value, String fieldName) {
    if (value == null) return 'Empty';

    if (value is String && value.trim().isEmpty) return 'Empty';
    if (value is num && value == 0) return 'Empty';
    if (value is List && value.isEmpty) return 'Empty';
    if (value is Map && value.isEmpty) return 'Empty';

    return value.toString();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Empty';
    try {
      final dateTime = DateTime.parse(isoString);
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    } catch (e) {
      return 'Empty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final bool canPerformActions = user?.role != 'Contractor Supervisor';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 1,
                child: const Text(
                  'Premises\nCleaning',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Draft',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Location: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['location'], 'location'),
                  style: TextStyle(
                    color: draft['location']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text: 'Saved by: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['submittedByName'], 'submittedByName'),
                  style: TextStyle(
                    color: draft['submittedByName']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const TextSpan(text: '   •   '),
                const TextSpan(
                    text: 'Supervisor: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['supervisorName'], 'supervisorName'),
                  style: TextStyle(
                    color: draft['supervisorName']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: draft['updatedAt'] != null ? 'Updated at: ' : 'Saved at: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: _formatDateTime(draft['updatedAt'] ?? draft['savedAt']),
                  style: TextStyle(
                    color: (draft['updatedAt'] ?? draft['savedAt']) == null
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const TextSpan(text: '   •   '),
                const TextSpan(
                    text: 'Division: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                  text: _getDisplayValue(draft['division'], 'division'),
                  style: TextStyle(
                    color: draft['division']?.toString().isEmpty ?? true
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                if (draft['depot']?.toString().isNotEmpty ?? false) ...[
                  const TextSpan(text: '   •   '),
                  const TextSpan(
                    text: 'Depot: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: _getDisplayValue(draft['depot'], 'depot'),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ]
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: canPerformActions ? onEdit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Edit Draft',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black,fontSize: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: canPerformActions ? onDelete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'DELETE',
                      style: TextStyle(fontWeight: FontWeight.w600,fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}





