import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/repositories/evidence_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'evidence_upload_screen.dart';

class EvidenceGalleryScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const EvidenceGalleryScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<EvidenceGalleryScreen> createState() => _EvidenceGalleryScreenState();
}

class _EvidenceGalleryScreenState extends State<EvidenceGalleryScreen> {
  bool _isLoading = false;
  String _selectedType = 'all';
  List<EvidenceMetadata> _evidenceList = [];
  double _totalStorageMb = 0.0;

  final List<String> _types = ['all', 'before_photo', 'after_photo', 'inspection', 'complaint'];

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    setState(() => _isLoading = true);
    String? errorMsg;
    try {
      final query = <String, String>{'stationId': widget.stationId};
      if (_selectedType != 'all') query['type'] = _selectedType;
      _evidenceList = await EvidenceRepository.search(query);
    } catch (e) {
      errorMsg = 'search: $e';
    }
    try {
      final analytics = await EvidenceRepository.getStorageAnalytics(widget.stationId);
      final totals = analytics['totals'] as Map<String, dynamic>?;
      _totalStorageMb = double.tryParse(totals?['totalMB']?.toString() ?? '0') ?? 0;
    } catch (e) {
      _totalStorageMb = 0;
      errorMsg = errorMsg ?? 'analytics: $e';
    }
    if (mounted) {
      setState(() {});
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load evidence: $errorMsg'), backgroundColor: kErrorRed, duration: const Duration(seconds: 4)),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'before_photo': return Icons.photo_library;
      case 'after_photo': return Icons.photo_filter;
      case 'inspection': return Icons.search;
      case 'complaint': return Icons.report;
      default: return Icons.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evidence - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvidence,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: kSuccessGreen.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.storage, color: kRailwayBlue),
                const SizedBox(width: 8),
                Text('Storage: ${_totalStorageMb.toStringAsFixed(1)} MB used',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _types.map((type) {
                final selected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: FilterChip(
                    label: Text(type.replaceAll('_', ' ').toUpperCase()),
                    selected: selected,
                    onSelected: (val) {
                      setState(() => _selectedType = type);
                      _loadEvidence();
                    },
                    selectedColor: kRailwayBlue.withOpacity(0.2),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _evidenceList.isEmpty
                    ? const Center(child: Text('No evidence found'))
                    : RefreshIndicator(
                        onRefresh: _loadEvidence,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: _evidenceList.length,
                          itemBuilder: (context, idx) {
                            final ev = _evidenceList[idx];
                            return GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.network(ev.url, fit: BoxFit.contain),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(ev.evidenceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ev.thumbnailUrl != null && ev.thumbnailUrl!.isNotEmpty
                                          ? Image.network(ev.thumbnailUrl!, fit: BoxFit.cover)
                                          : Container(
                                              color: Colors.grey[200],
                                              child: Icon(_typeIcon(ev.evidenceType), size: 32, color: Colors.grey),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        ev.evidenceType.replaceAll('_', ' '),
                                        style: const TextStyle(fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EvidenceUploadScreen(
                stationId: widget.stationId,
                stationName: widget.stationName,
              ),
            ),
          ).then((_) => _loadEvidence());
        },
      ),
    );
  }
}
