import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_services.dart';
import '../../../utills/app_colors.dart';

class AttendanceExceptionDashboard extends StatefulWidget {
  const AttendanceExceptionDashboard({super.key});

  @override
  State<AttendanceExceptionDashboard> createState() => _AttendanceExceptionDashboardState();
}

class _AttendanceExceptionDashboardState extends State<AttendanceExceptionDashboard> {
  List<dynamic> _exceptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExceptions();
  }

  Future<void> _fetchExceptions() async {
    setState(() => _isLoading = true);
    try {
      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/attendance/exceptions?status=PENDING'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _exceptions = jsonDecode(response.body)['exceptions'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _takeAction(String? exceptionId, String action, String? remark) async {
    if (exceptionId == null || exceptionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Exception ID is null or empty')),
      );
      return;
    }
    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/attendance/exceptions/action'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'exceptionId': exceptionId,
          'action': action,
          'adminRemark': remark ?? '',
        }),
      );

      if (response.statusCode == 200) {
        _fetchExceptions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception $action successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Exceptions', style: TextStyle(color: Colors.white)),
        backgroundColor: kRailwayBlue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exceptions.isEmpty
              ? const Center(child: Text('No pending exceptions found.'))
              : ListView.builder(
                  itemCount: _exceptions.length,
                  itemBuilder: (context, index) {
                    final exc = _exceptions[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  exc['workerName'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    exc['issueType'] ?? 'Issue',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Run Instance: ${exc['runInstanceId']}'),
                            Text('Remark: ${exc['remark']}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _takeAction(
                                    exc['exceptionId'] ?? exc['id'] ?? exc['uid'],
                                    'REJECTED',
                                    'Rejected by CTS',
                                  ),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => _takeAction(
                                    exc['exceptionId'] ?? exc['id'] ?? exc['uid'],
                                    'APPROVED',
                                    'Approved by CTS',
                                  ),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
