import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class SupervisorDailyLogScreen extends StatefulWidget {
  const SupervisorDailyLogScreen({super.key});

  @override
  State<SupervisorDailyLogScreen> createState() => _SupervisorDailyLogScreenState();
}

class _SupervisorDailyLogScreenState extends State<SupervisorDailyLogScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _activitiesCtrl = TextEditingController();
  final _machineUsageCtrl = TextEditingController();
  final _issuesCtrl = TextEditingController();
  final _handoverCtrl = TextEditingController();

  @override
  void dispose() {
    _activitiesCtrl.dispose();
    _machineUsageCtrl.dispose();
    _issuesCtrl.dispose();
    _handoverCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Auth token not available');

      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/station-cleaning/daily-logs'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'activitiesSummary': _activitiesCtrl.text.trim(),
          'machineUsage': _machineUsageCtrl.text.trim(),
          'issuesEncountered': _issuesCtrl.text.trim(),
          'handoverNotes': _handoverCtrl.text.trim(),
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode != 201 || decoded['success'] != true) {
        throw Exception(decoded['error'] ?? 'Failed to submit daily log');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily log submitted successfully'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Daily Log'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('End of Shift Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _activitiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Activities Summary *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _machineUsageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Machine Usage & Downtime',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _issuesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issues Encountered & Unresolved Work',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _handoverCtrl,
                decoration: const InputDecoration(
                  labelText: 'Handover Notes for Next Shift',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Daily Log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
