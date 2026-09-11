import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/model/task_type_model.dart';
import 'package:crm_train/repositories/task_type_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'task_type_form_screen.dart';

class TaskTypeListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const TaskTypeListScreen({super.key, required this.stationId, required this.stationName});
  @override State<TaskTypeListScreen> createState() => _TaskTypeListScreenState();
}

class _TaskTypeListScreenState extends State<TaskTypeListScreen> {
  bool _isLoading = false;
  List<TaskType> _taskTypes = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _taskTypes = await TaskTypeRepository.list();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  bool _canManage() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final r = (user.role ?? '').toUpperCase().replaceAll(' ', '_');
    return ['SUPER_ADMIN', 'ADMIN', 'COMPANY_MASTER', 'RAILWAY_ADMIN', 'CONTRACTOR_ADMIN'].contains(r);
  }

  Future<void> _delete(TaskType tt) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Task Type'),
      content: Text('Delete "${tt.label}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    try {
      await TaskTypeRepository.remove(tt.uid);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Types - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _taskTypes.isEmpty
                ? ListView(children: const [SizedBox(height: 200, child: Center(child: Text('No task types found')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _taskTypes.length,
                    itemBuilder: (ctx, i) {
                      final tt = _taskTypes[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tt.isActive ? Colors.green.shade100 : Colors.grey.shade100,
                            child: Icon(tt.isActive ? Icons.check_circle : Icons.cancel, color: tt.isActive ? Colors.green : Colors.grey),
                          ),
                          title: Text(tt.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${tt.name}  |  ${tt.category}'),
                          trailing: _canManage() ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => TaskTypeFormScreen(taskType: tt, stationId: widget.stationId, stationName: widget.stationName)))
                                  .then((_) => _load());
                              } else if (v == 'delete') {
                                _delete(tt);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ) : null,
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: _canManage() ? FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskTypeFormScreen(stationId: widget.stationId, stationName: widget.stationName)))
          .then((_) => _load()),
      ) : null,
    );
  }
}
