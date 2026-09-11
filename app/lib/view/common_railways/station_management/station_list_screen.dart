import 'package:flutter/material.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'station_master_screen.dart';

class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  List<Station> _all = [];
  List<Station> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _all = await ApiService.getStations();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _queryCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((s) {
        if (q.isEmpty) return true;
        return s.stationName.toLowerCase().contains(q) ||
            s.stationCode.toLowerCase().contains(q) ||
            s.zone.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _openForm({Station? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StationMasterScreen(existingStation: existing)),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(Station s) async {
    try {
      await ApiService.updateStation(s.uid!, {'active': !s.active});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    }
  }

  Color _categoryColor(StationCategory c) {
    switch (c) {
      case StationCategory.a1: return Colors.purple;
      case StationCategory.a: return Colors.red;
      case StationCategory.b: return kRailwayBlue;
      case StationCategory.c: return Colors.teal;
      case StationCategory.d: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Stations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _queryCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search stations...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (_) => _applyFilter(),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.train, size: 80, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  const Text('No stations found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final s = _filtered[index];
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _openForm(existing: s),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48, height: 48,
                                              decoration: BoxDecoration(
                                                color: _categoryColor(s.category).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(s.categoryLabel, style: TextStyle(color: _categoryColor(s.category), fontWeight: FontWeight.bold, fontSize: 16)),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(s.stationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      _chip(s.stationCode, kRailwayBlue),
                                                      const SizedBox(width: 6),
                                                      _chip(s.zone, Colors.teal),
                                                      const SizedBox(width: 6),
                                                      _chip(s.typeLabel, Colors.indigo),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(s.division, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: Icon(s.active ? Icons.check_circle : Icons.cancel, color: s.active ? kSuccessGreen : Colors.grey, size: 22),
                                                  onPressed: () => _toggleActive(s),
                                                ),
                                                Text(s.active ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, color: s.active ? kSuccessGreen : Colors.grey)),
                                              ],
                                            ),
                                          ],
                                        ),
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
        onPressed: () => _openForm(),
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}
