import 'package:crm_train/data/zone_database.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/services/draft_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../utills/app_colors.dart';
import '../../../model/train_model.dart';
import '../../../model/station_models.dart';
import '../../../model/platform_model.dart';
import '../../../repositories/platform_repository.dart';
import '../widgets/approve_entity_dropdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import 'dart:convert';

class UserRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? draftData;
  final String? draftId;

  const UserRegistrationScreen({super.key, this.draftData, this.draftId});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _designation = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  String _selectedUserType = 'railway';
  String? _selectedRole;
  String? _selectedCompany;
  String? _zone;
  String? _division;
  String? _depot;
  bool _obscurePassword = true;

  List<String> zones = [];
  List<String> divisions = [];
  List<String> depots = [];
  List<dynamic> contractorCompanies = [];
  List<TrainModel> allTrains = [];
  String? _workerType;
  String? _trainId;
  List<String> _selectedTrainIds = [];

  String? _selectedStationId;
  String? _selectedAreaId;
  String? _selectedPlatformId;

  Map<String, String> pickedDocs = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    zones = DepotDatabase.zoneData.keys.toList();
    _generatePassword();

    if (widget.draftData != null) {
      _loadDraftData(widget.draftData!);
    }
    _loadAllTrains();
  }

  Future<void> _loadAllTrains() async {
    try {
      final trains = await ApiService.getActiveTrains();
      setState(() => allTrains = trains);
    } catch (e) {
      print('Error loading trains: $e');
    }
  }

  void _loadDraftData(Map<String, dynamic> draft) {
    setState(() {
      _fullName.text = draft['fullName'] ?? '';
      _designation.text = draft['designation'] ?? '';
      _email.text = draft['email'] ?? '';
      _mobile.text = draft['mobile'] ?? '';
      _password.text = draft['password'] ?? '';
      _selectedUserType = draft['userType'] ?? 'railway';
      _selectedRole = draft['role'];
      _selectedCompany = draft['entityId'];
      _zone = draft['zone'];
      _division = draft['division'];
      _depot = draft['depot'];
      _workerType = draft['worker_type'];
      _trainId = draft['trainId'];
      _selectedTrainIds = List<String>.from(draft['trainIds'] ?? []);

      if (_zone != null) {
        divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
        if (_division != null) {
          depots = DepotDatabase.zoneData[_zone]?[_division] ?? [];
        }
      }

      if (draft['documents'] != null && draft['documents'] is Map) {
        pickedDocs = Map<String, String>.from(draft['documents']);
      }
    });
  }


  void _generatePassword() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890@#\$%&';
    final rand = Random.secure();
    final password = List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    _password.text = password;
  }

  void _loadDivisions(String zone) {
    setState(() {
      divisions = DepotDatabase.zoneData[zone]?.keys.toList() ?? [];
      _division = null;
      depots = [];
      _depot = null;
    });
  }

  void _loadDepots(String zone, String division) {
    setState(() {
      depots = DepotDatabase.zoneData[zone]?[division] ?? [];
      _depot = null;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


  bool _shouldShowZone() {
    if (_selectedRole == null) return false;
    return true;
  }

  bool _shouldShowDivision() {
    if (_selectedRole == null || _zone == null) return false;
    return _selectedRole!.contains('Admin') || _selectedRole!.contains('Supervisor') || _selectedRole!.contains('Worker');
  }

  bool _shouldShowDepot() {
    if (_selectedRole == null || _division == null) return false;
    return _selectedRole!.contains('Supervisor') || _selectedRole!.contains('Worker');
  }

  bool _shouldShowWorkerType() {
    if (_selectedRole == null) return false;
    return _selectedRole!.toLowerCase().contains('worker');
  }

  bool _shouldShowTrainSelection() {
    if (_selectedRole == null) return false;
    final r = _selectedRole!.toUpperCase();
    return r.contains('SUPERVISOR') || r.contains('CTS');
  }

  bool _isMultiTrainExport() {
    if (_selectedRole == null) return false;
    return _selectedRole!.toUpperCase() == 'RAILWAY SUPERVISOR';
  }

  bool _isZoneReadOnly() {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    return currentUser?.role == 'Railway Admin' ||
        currentUser?.role == 'Railway Master' ||
        currentUser?.role == 'Contractor Admin' ||
        currentUser?.role == 'Contractor Master';
  }

  bool _isDivisionReadOnly() {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    return currentUser?.role == 'Railway Admin' ||
        currentUser?.role == 'Contractor Admin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kRailwayBlue,
        title: const Text('Create New User', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kRailwayBlue,
                ),
              ),
              const SizedBox(height: 16),


              DropdownButtonFormField<String>(
                value: _selectedUserType,
                decoration: const InputDecoration(
                  labelText: 'User Type *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'railway', child: Text('Railway')),
                  DropdownMenuItem(value: 'contractor', child: Text('Contractor')),
                ],
                onChanged: (v) => setState(() {
                  _selectedUserType = v!;
                  _selectedRole = null;
                  _zone = null;
                  _division = null;
                  _depot = null;
                }),
              ),
              const SizedBox(height: 12),


              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                ),
                items: _getRolesForUserType(_selectedUserType)
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                validator: (v) => v == null ? 'Select role' : null,
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v;
                    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;


                    if (currentUser?.role == 'Railway Admin') {
                      _zone = currentUser?.zone;
                      _division = currentUser?.division;
                      if (_zone != null) {
                        divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
                        if (_division != null) {
                          depots = DepotDatabase.zoneData[_zone]?[_division] ?? [];
                        }
                      }
                      _depot = null;
                    }

                    else if (currentUser?.role == 'Railway Master') {
                      _zone = currentUser?.zone;
                      if (_zone != null) {
                        divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
                      }
                      _division = null;
                      _depot = null;
                      depots = [];
                    }

                    else if (currentUser?.role == 'Contractor Admin') {
                      _zone = currentUser?.zone;
                      _division = currentUser?.division;
                      if (_zone != null) {
                        divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
                        if (_division != null) {
                          depots = DepotDatabase.zoneData[_zone]?[_division] ?? [];
                        }
                      }
                      _depot = null;
                    }

                    else if (currentUser?.role == 'Contractor Master') {
                      _zone = currentUser?.zone;
                      if (_zone != null) {
                        divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
                      }
                      _division = null;
                      _depot = null;
                      depots = [];
                    }

                    else {
                      _zone = null;
                      _division = null;
                      _depot = null;
                      divisions = [];
                      depots = [];
                    }
                  });
                },
              ),
              const SizedBox(height: 12),


              if (_selectedUserType == 'contractor')
                ApprovedEntityDropdown(
                  onSelected: (name) {
                    setState(() {
                      _selectedCompany = name;
                    });
                  },
                ),

              if (_selectedRole == 'Station Master' || _selectedRole == 'Area Master' || _selectedRole == 'Platform Master')
                FutureBuilder<List<Station>>(
                  future: ApiService.getStations(),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                    if (snap.hasError) return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Error loading stations', style: TextStyle(color: Colors.red)),
                    );
                    final stations = snap.data ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedStationId,
                        decoration: const InputDecoration(labelText: 'Station *', border: OutlineInputBorder()),
                        items: stations.map((s) => DropdownMenuItem(value: s.uid, child: Text(s.stationName))).toList(),
                        validator: (v) => v == null ? 'Select station' : null,
                        onChanged: (v) => setState(() {
                          _selectedStationId = v;
                          _selectedAreaId = null;
                          _selectedPlatformId = null;
                          if (v != null) {
                            final selectedStn = stations.firstWhere(
                              (s) => s.uid == v,
                              orElse: () => Station(stationCode: '', stationName: '', zone: '', division: ''),
                            );
                            if (selectedStn.zone.isNotEmpty) {
                              String? matchedZone;
                              for (final zKey in zones) {
                                if (zKey.toLowerCase() == selectedStn.zone.toLowerCase() ||
                                    zKey.toLowerCase().contains(selectedStn.zone.toLowerCase()) ||
                                    selectedStn.zone.toLowerCase().contains(zKey.toLowerCase())) {
                                  matchedZone = zKey;
                                  break;
                                }
                              }
                              if (matchedZone != null) {
                                _zone = matchedZone;
                                divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
                                String? matchedDiv;
                                for (final dKey in divisions) {
                                  if (dKey.toLowerCase() == selectedStn.division.toLowerCase() ||
                                      dKey.toLowerCase().contains(selectedStn.division.toLowerCase()) ||
                                      selectedStn.division.toLowerCase().contains(dKey.toLowerCase())) {
                                    matchedDiv = dKey;
                                    break;
                                  }
                                }
                                if (matchedDiv != null) {
                                  _division = matchedDiv;
                                  depots = DepotDatabase.zoneData[_zone]?[_division] ?? [];
                                } else {
                                  _division = null;
                                  depots = [];
                                }
                              }
                            }
                          }
                        }),
                      ),
                    );
                  },
                ),

              if ((_selectedRole == 'Platform Master' || _selectedRole == 'Area Master') && _selectedStationId != null)
                FutureBuilder<List<Platform>>(
                  future: PlatformRepository.getByStation(_selectedStationId!),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                    if (snap.hasError) return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Error loading platforms', style: TextStyle(color: Colors.red)),
                    );
                    final platforms = snap.data ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlatformId,
                        decoration: const InputDecoration(labelText: 'Platform *', border: OutlineInputBorder()),
                        items: platforms.map((p) => DropdownMenuItem(value: p.uid, child: Text(p.displayName))).toList(),
                        validator: (v) => v == null ? 'Select platform' : null,
                        onChanged: (v) => setState(() {
                          _selectedPlatformId = v;
                          _selectedAreaId = v; // Stored in areaId for DB consistency
                        }),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 12),


              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter full name (letters only)',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\.\-]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Full Name is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  if (v.trim().length > 50) {
                    return 'Name must not exceed 50 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(v.trim())) {
                    return 'Name can only contain letters, spaces, dots and hyphens';
                  }
                  if (!RegExp(r'^[a-zA-Z]').hasMatch(v.trim())) {
                    return 'Name must start with a letter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),


              TextFormField(
                controller: _designation,
                decoration: const InputDecoration(
                  labelText: 'Designation *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Senior Engineer, Manager',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\.\-\,]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Designation is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Designation must be at least 2 characters';
                  }
                  if (v.trim().length > 50) {
                    return 'Designation must not exceed 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),


              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Official Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),


              TextFormField(
                controller: _mobile,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  border: OutlineInputBorder(),
                  hintText: '10 digit number',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length != 10) return '10 digits required';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Generated Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _generatePassword();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password regenerated'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Location Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kRailwayBlue,
                ),
              ),
              const SizedBox(height: 16),

              if (_shouldShowZone())
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _zone,
                      decoration: InputDecoration(
                        labelText: 'Zone *',
                        border: const OutlineInputBorder(),
                        helperText: _selectedRole?.contains('Master') == true
                            ? 'Master has access to entire zone'
                            : null,
                      ),
                      items: zones
                          .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                          .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: _isZoneReadOnly() ? null : (v) {
                        setState(() {
                          _zone = v;
                          if (_selectedRole?.contains('Master') == true) {
                            _division = null;
                            _depot = null;
                            divisions = [];
                            depots = [];
                          } else if (v != null) {
                            _loadDivisions(v);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              if (_shouldShowDivision())
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _division,
                      decoration: InputDecoration(
                        labelText: 'Division *',
                        border: const OutlineInputBorder(),
                        helperText: _selectedRole!.contains('Admin')
                            ? 'Admin has access to entire division'
                            : null,
                      ),
                      items: divisions
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: _isDivisionReadOnly() ? null : (v) {
                        setState(() {
                          _division = v;
                          if (v != null && _zone != null) {
                            _loadDepots(_zone!, v);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              if (_shouldShowDepot())
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _depot,
                      decoration: const InputDecoration(
                        labelText: 'Depot',
                        border: OutlineInputBorder(),
                        helperText: 'Supervisor manages this depot',
                      ),
                      items: depots
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _depot = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              if (_shouldShowWorkerType())
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _workerType,
                      decoration: const InputDecoration(
                        labelText: 'Worker Type *',
                        border: OutlineInputBorder(),
                        helperText: 'Janitor (OBHS) or Attendant (Linen)',
                      ),
                      items: ['Janitor', 'Attendant']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setState(() => _workerType = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              if (_shouldShowTrainSelection())
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isMultiTrainExport())
                      DropdownButtonFormField<String>(
                        value: _trainId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Train *',
                          border: OutlineInputBorder(),
                          helperText: 'Contractor Supervisor mapped to one train',
                        ),
                        items: allTrains
                            .map((t) => DropdownMenuItem(
                                  value: t.uid,
                                  child: Text('${t.trainNo} - ${t.trainName}'),
                                ))
                            .toList(),
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (v) => setState(() {
                          _trainId = v;
                          _selectedTrainIds = v != null ? [v] : [];
                        }),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assigned Trains (Multiple allowed) *',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: allTrains.map((t) {
                                final isSelected =
                                    _selectedTrainIds.contains(t.uid);
                                return CheckboxListTile(
                                  title: Text('${t.trainNo} - ${t.trainName}'),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedTrainIds.add(t.uid!);
                                      } else {
                                        _selectedTrainIds.remove(t.uid);
                                      }
                                      _trainId = _selectedTrainIds.isNotEmpty
                                          ? _selectedTrainIds[0]
                                          : null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          if (_selectedTrainIds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 12),
                              child: Text('At least one train required',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                  ],
                ),

              const SizedBox(height: 24),

              const Text(
                'Document Uploads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kRailwayBlue,
                ),
              ),
              const SizedBox(height: 12),

              ..._buildDocumentUploadField('Aadhar Card'),
              ..._buildDocumentUploadField('PAN Card'),
              ..._buildDocumentUploadField('ID Proof'),
              ..._buildDocumentUploadField('Photo'),

              const SizedBox(height: 24),

              const Text(
                'Signature',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kRailwayBlue,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.grey[200]!,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Signature'),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: kRailwayBlue, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(Icons.save_outlined, color: kRailwayBlue),
                      label: Text(
                        'Save as Draft',
                        style: TextStyle(color: kRailwayBlue, fontSize: 12),
                      ),
                      onPressed: _saveDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRailwayBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        'Submit for Approval',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onPressed: _submitForm,
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

  List<Widget> _buildDocumentUploadField(String docName) {
    final fileName = pickedDocs[docName];
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                fileName != null ? Icons.check_circle : Icons.upload_file,
                color: fileName != null ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                docName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: fileName != null ? Colors.black87 : Colors.black54,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: fileName != null ? Colors.green.shade50 : Colors.blue.shade50,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: Icon(
              fileName != null ? Icons.check : Icons.upload,
              color: fileName != null ? Colors.green : Colors.blue,
              size: 18,
            ),
            label: Text(
              fileName != null ? 'Uploaded' : 'Upload',
              style: TextStyle(
                color: fileName != null ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  allowMultiple: false,
                );

                if (result != null && result.files.isNotEmpty) {
                  final pickedFile = result.files.first;
                  final fileName = pickedFile.name;

                  setState(() {
                    pickedDocs[docName] = fileName;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$docName selected: $fileName'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No file selected'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error picking file: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      if (fileName != null)
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    pickedDocs.remove(docName);
                  });
                },
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
    ];
  }



  List<String> _getRolesForUserType(String userType) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;

    if (userType == 'railway') {
      if (currentUser?.role == 'Railway Admin') {
        return ['Railway Supervisor', 'Railway Worker', 'Station Master', 'Area Master', 'Platform Master'];
      }
      else if (currentUser?.role == 'Railway Master') {
        return [
          'Railway Admin',
          'Railway Supervisor',
          'Railway Worker',
          'Station Master',
          'Area Master',
          'Platform Master',
        ];
      }
      else {
        return ['Railway Admin', 'Railway Supervisor', 'Railway Worker', 'Station Master', 'Area Master', 'Platform Master'];
      }
    } else {
      if (currentUser?.role == 'Contractor Admin') {
        return ['Contractor Supervisor', 'Contractor Worker'];
      }
      else if (currentUser?.role == 'Contractor Master') {
        return ['Contractor Admin', 'Contractor Supervisor', 'Contractor Worker'];
      }
      else if (currentUser?.role == 'Railway Admin') {
        return ['Contractor Supervisor', 'Contractor Worker'];
      }
      else {
        return ['Contractor Admin', 'Contractor Supervisor', 'Contractor Worker'];
      }
    }
  }

  Future<void> _saveDraft() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;

    if (currentUser?.uid == null) {
      _showError('User not logged in');
      return;
    }


    final draftData = {
      'fullName': _fullName.text.trim(),
      'designation': _designation.text.trim(),
      'email': _email.text.trim(),
      'mobile': _mobile.text.trim(),
      'password': _password.text.trim(),
      'userType': _selectedUserType,
      'role': _selectedRole,
      'entityId': _selectedCompany,
      'zone': _zone,
      'division': _division,
      'depot': _depot,
      'documents': pickedDocs,
    };

    setState(() => _isLoading = true);

    final success = await DraftStorageService.saveUserDraft(
      currentUserId: currentUser!.uid!,
      draftData: draftData,
      draftId: widget.draftId,
    );

    setState(() => _isLoading = false);

    if (success) {
      _showSuccess('Draft saved successfully');
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pop(context, true);
    } else {
      _showError('Failed to save draft');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;


    setState(() => _isLoading = true);

    try {
      final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
      
      String? base64Signature;
      if (_signatureController.isNotEmpty) {
        final signatureBytes = await _signatureController.toPngBytes();
        if (signatureBytes != null) {
          base64Signature = base64Encode(signatureBytes);
        }
      }

      final result = await ApiService.createUser(
        userType: _selectedUserType,
        role: _selectedRole!,
        fullName: _fullName.text.trim(),
        designation: _designation.text.trim(),
        email: _email.text.trim(),
        password: _password.text.trim(),
        mobile: _mobile.text.trim(),
        zone: _zone?.trim().isEmpty ?? true ? null : _zone?.trim(),
        division: _division?.trim().isEmpty ?? true ? null : _division?.trim(),
        depot: _depot?.trim().isEmpty ?? true ? null : _depot?.trim(),
        entityId: _selectedCompany?.trim().isEmpty ?? true ? null : _selectedCompany?.trim(),
        createdById: currentUser?.uid,
        worker_type: _workerType,
        trainId: _trainId,
        trainIds: _selectedTrainIds,
        stationId: _selectedStationId,
        areaId: _selectedAreaId,
        platformId: _selectedPlatformId,
        signatureBase64: base64Signature,
      );

      setState(() => _isLoading = false);

      if (widget.draftId != null) {
        await DraftStorageService.deleteUserDraft(
          currentUserId: currentUser!.uid!,
          draftId: widget.draftId!,
        );
      }

      final message = result['message'] ?? 'User created successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),

      );
      Navigator.pop(context,true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to create user: ${e.toString()}');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }


  @override
  void dispose() {
    _fullName.dispose();
    _designation.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _signatureController.dispose();
    super.dispose();
  }
}

