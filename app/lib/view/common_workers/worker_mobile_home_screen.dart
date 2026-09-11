import 'package:crm_train/view/common_railways/alert/common_alert_screen.dart';
import 'package:crm_train/view/common_workers/worker_complaints_screen.dart';
import 'package:crm_train/view/common_workers/worker_profile_screen.dart';
import 'package:crm_train/view/common_workers/worker_rating_screen.dart';
import 'package:crm_train/view/common_workers/worker_station_cleaning_screen.dart';
import 'package:crm_train/view/common_workers/worker_task_screen.dart';
import 'package:crm_train/view/common_workers/worker_pest_control_screen.dart';
import 'package:crm_train/view/common_workers/worker_machine_screen.dart';
import 'package:crm_train/view/common_workers/worker_garbage_screen.dart';
import 'package:crm_train/view/common_workers/worker_audit_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:crm_train/utills/app_colors.dart';
import '../../controllers/worker_controller.dart';
import 'attendance_issue_screen.dart';

class WorkerMobileHomeScreen extends StatelessWidget {
  const WorkerMobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WorkerController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Work',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
        actions: [
          Obx(() {
            controller.workerProfile.value;
            final name = controller.workerName;
            return IconButton(
              icon: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: name.isNotEmpty
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: kRailwayBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.person, color: kRailwayBlue),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkerProfileScreen(),
                  ),
                );
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommonAlertScreen(),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshData,
          color: kRailwayBlue,
          child: Obx(() {
            // show full-screen loader only on very first load (no cache yet)
            if (controller.isProfileLoading.value &&
                controller.workerProfile.value == null &&
                controller.currentUser.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(controller),

                  const SizedBox(height: 20),

                  const Text(
                    'Attendance Checklist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAttendanceCard(controller),

                  if (!controller.startAttendance.value) ...[
                    const SizedBox(height: 20),
                    _buildStartRequiredCard(),
                  ] else ...[
                    const SizedBox(height: 20),
                    _buildTaskCountCard(controller),
                    const SizedBox(height: 20),
                    const Text(
                      'Assigned Coaches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCoachesCard(controller),

                    const SizedBox(height: 20),
                    const Text(
                      'Work Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildGrid(controller),

                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'Passenger Service Center', // Updated title
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCategorizedTasksSection(controller),
                  const SizedBox(height: 20),
                  _buildQuickActions(context, controller),
                  const SizedBox(height: 20),
                  _buildFeedbackSection(context),

                  const SizedBox(height: 20),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(WorkerController controller) {
    return Obx(() {
      controller.workerProfile.value;

      final name = controller.workerName;
      final trainNo = controller.trainNo;
      final trainName = controller.trainName;
      final instanceId = controller.instanceId;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.home_work_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trainNo.isNotEmpty || trainName.isNotEmpty)
                    Text(
                      '$trainNo  |  $trainName',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (instanceId.isNotEmpty)
                    Text(
                      instanceId,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (controller.isProfileLoading.value)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: kRailwayBlue,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildCoachesCard(WorkerController controller) {
    return Obx(() {
      controller.workerProfile.value;
      final coaches = controller.assignedCoaches;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: coaches.isEmpty
            ? Text(
                'No coaches assigned yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: coaches.map((coach) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: kRailwayBlue.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      coach,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kRailwayBlue,
                      ),
                    ),
                  );
                }).toList(),
              ),
      );
    });
  }

  Widget _buildGrid(WorkerController controller) {
    return Obx(() {
      if (controller.isStatsLoading.value) {
        return const SizedBox(
          height: 160,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text(
                  'Loading stats...',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      return _buildGridContent(controller);
    });
  }

  Widget _buildGridContent(WorkerController controller) {
    final items = [
      {'title': 'Due Tasks', 'value': controller.dueTasks.value.toString()},
      {'title': 'Overdue', 'value': controller.overdueTasks.value.toString()},
      {
        'title': 'Completed',
        'value': controller.completedTasks.value.toString(),
      },
      {'title': 'Upcoming', 'value': controller.upcomingTasks.value.toString()},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final aspectRatio = w < 320
            ? 1.5
            : w < 360
            ? 1.6
            : 1.8;
        final titleFs = w < 320
            ? 11.0
            : w < 360
            ? 12.0
            : 14.0;
        final valueFs = w < 320
            ? 18.0
            : w < 360
            ? 20.0
            : 22.0;
        final spacing = w < 320 ? 8.0 : 12.0;
        final pad = w < 320 ? 8.0 : 10.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: TextStyle(
                      fontSize: titleFs,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['value'] ?? '0',
                    style: TextStyle(
                      fontSize: valueFs,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Attendance Item ───────────────────────────────────────────────────────

  Widget _buildAttendanceCard(WorkerController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          _buildAttendanceItem(
            controller: controller,
            title: 'Start Attendance',
            subtitle: 'Mark your start time',
            icon: Icons.login,
            type: 'start',
          ),
          Obx(() {
            if (controller.startAttendance.value) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  _buildAttendanceItem(
                    controller: controller,
                    title: 'Mid Check-in',
                    subtitle: 'Progress verification',
                    icon: Icons.schedule,
                    type: 'mid',
                  ),
                  const SizedBox(height: 12),
                  _buildAttendanceItem(
                    controller: controller,
                    title: 'End Attendance',
                    subtitle: 'Mark completion time',
                    icon: Icons.logout,
                    type: 'end',
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Get.to(() => AttendanceIssueScreen(
                attendanceType: controller.endAttendance.value 
                  ? 'end' 
                  : controller.midCheckin.value ? 'mid' : 'start'
              ));
            },
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            label: const Text(
              'Reporting Attendance Issue?',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.orange.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartRequiredCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dashboard and tasks will unlock after start attendance.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCountCard(WorkerController controller) {
    return Obx(() {
      final completed = controller.completedTasks.value;
      final total = controller.totalAssignedTasks;
      final allTasksCompleted = total > 0 && completed >= total;
      final nextTarget = completed < 3 ? 3 : total;
      final progressTarget = total > 0 ? total : 3;
      final progress = (completed / progressTarget).clamp(0.0, 1.0);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: kRailwayBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task Count: $completed${total > 0 ? ' / $total' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  allTasksCompleted
                      ? Colors.green
                      : completed >= 3
                      ? Colors.orange
                      : kRailwayBlue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (!controller.startAttendance.value) return const SizedBox.shrink();
              return Text(
                allTasksCompleted
                    ? 'End attendance unlocked'
                    : completed >= 3
                    ? 'Mid check-in unlocked. Complete all assigned tasks for end attendance.'
                    : 'Complete $nextTarget tasks to unlock mid check-in.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildAttendanceItem({
    required WorkerController controller,
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
  }) {
    return Obx(() {
      final isCompleted = type == 'start'
          ? controller.startAttendance.value
          : type == 'mid'
          ? controller.midCheckin.value
          : controller.endAttendance.value;
      final canMark = controller.canMarkAttendance(type);
      final isBusy = type == 'start'
          ? controller.isStartLoading.value
          : type == 'mid'
          ? controller.isMidLoading.value
          : controller.isEndLoading.value;
      final effectiveSubtitle = isCompleted
          ? subtitle
          : type == 'start'
          ? subtitle
          : controller.attendanceLockReason(type);
      final accentColor = isCompleted
          ? Colors.green.shade700
          : canMark
          ? kRailwayBlue
          : Colors.grey.shade500;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.green.shade50
              : canMark
              ? Colors.grey.shade50
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted
                ? Colors.green.shade300
                : canMark
                ? Colors.grey.shade300
                : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withValues(alpha: 0.15)
                    : canMark
                    ? Colors.blue.shade50
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (effectiveSubtitle != subtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      effectiveSubtitle,
                      style: TextStyle(fontSize: 11, color: accentColor),
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted)
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 22)
            else
              InkWell(
                onTap: canMark && !isBusy
                    ? () => controller.markAttendanceAction(type)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: canMark && !isBusy
                        ? kRailwayBlue
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBusy) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else if (!canMark) ...[
                        const Icon(Icons.lock, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isBusy
                            ? 'Wait'
                            : canMark
                            ? 'Mark'
                            : 'Locked',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildQuickActions(BuildContext context, WorkerController controller) {
    return Obx(() {
      final actions = [
        {
          'icon': Icons.task_alt,
          'title': 'Work To Do',
          'subtitle': '${controller.dueTasks.value} tasks pending',
          'color': kRailwayBlue,
        },
        {
          'icon': Icons.upcoming,
          'title': 'Upcoming',
          'subtitle': '${controller.upcomingTasks.value} scheduled',
          'color': Colors.orange,
        },
        {
          'icon': Icons.history,
          'title': 'History',
          'subtitle': '${controller.completedTasks.value} completed',
          'color': Colors.purple,
        },
        {
          'icon': Icons.report_problem_outlined,
          'title': 'Complaints',
          'subtitle': 'View & raise',
          'color': Colors.red,
        },
        // ── Station Cleaning: hidden (commented) per requirement ──
        // {
        //   'icon': Icons.cleaning_services,
        //   'title': 'Station Cleaning',
        //   'subtitle': 'My platform tasks',
        //   'color': Colors.teal,
        // },
        {
          'icon': Icons.bug_report,
          'title': 'Pest Control',
          'subtitle': 'Record pest activity',
          'color': Colors.brown,
        },
        {
          'icon': Icons.precision_manufacturing,
          'title': 'Machines',
          'subtitle': 'Deployed equipment',
          'color': Colors.indigo,
        },
        {
          'icon': Icons.delete,
          'title': 'Garbage',
          'subtitle': 'Disposal records',
          'color': Colors.green,
        },
        {
          'icon': Icons.history,
          'title': 'Audit Trail',
          'subtitle': 'My activity log',
          'color': Colors.brown,
        },
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final aspectRatio = constraints.maxWidth < 400 ? 1.6 : 1.8;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: aspectRatio,
                ),
                itemBuilder: (context, index) {
                    final action = actions[index];
                    return GestureDetector(
                    onTap: () {
                      final title = action['title'] as String;
                      final sid = controller.currentUser.value?.stationId;
                      Widget page;
                      if (title == 'Complaints') {
                        page = const WorkerComplaintsScreen();
                      } else if (title == 'Station Cleaning') {
                        page = const WorkerStationCleaningScreen();
                      } else if (title == 'Pest Control') {
                        page = WorkerPestControlScreen(stationId: sid);
                      } else if (title == 'Machines') {
                        page = const WorkerMachineScreen();
                      } else if (title == 'Garbage') {
                        page = WorkerGarbageScreen(stationId: sid);
                      } else if (title == 'Audit Trail') {
                        page = const WorkerAuditScreen();
                      } else {
                        page = const WorkerTaskScreen();
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            action['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            action['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildFeedbackSection(BuildContext context) {
    final roles = [
      {'title': 'TT Feedback', 'icon': Icons.train, 'color': Colors.blueGrey},
      {'title': 'Staff Signature', 'icon': Icons.assignment_ind, 'color': Colors.teal},
      {'title': 'Official Rating', 'icon': Icons.stars, 'color': Colors.indigo},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feedback & Signatures',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: roles.map((role) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  final title = role['title'] as String;
                  if (title == 'Official Rating') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkerRatingScreen(
                          isOfficialMode: true,
                        ),
                      ),
                    );
                  } else {
                    Get.snackbar(
                      'Info',
                      '${role['title']} form coming soon!',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (role['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          role['icon'] as IconData,
                          color: role['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          role['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildCategorizedTasksSection(WorkerController controller) {
    return Column(
      children: [
        _buildTaskCategoryCard(
          title: '1. Scheduled Tasks',
          subtitle: 'System Generated Routine Work',
          icon: Icons.calendar_today,
          color: kRailwayBlue,
          onTap: () => Get.to(() => const WorkerTaskScreen()), // Existing task screen
          count: controller.dueTasks.value + controller.upcomingTasks.value,
        ),
        const SizedBox(height: 12),
        _buildTaskCategoryCard(
          title: '2. Passenger Requests',
          subtitle: 'Active Passenger Service Requests',
          icon: Icons.person_pin_circle,
          color: Colors.orange,
          onTap: () => _showTaskCategoryDialog('Passenger Requests', controller.complaintTasks, controller),
          count: controller.complaintTasks.length,
          isLoading: controller.isTasksLoading.value,
        ),
        const SizedBox(height: 12),
        _buildTaskCategoryCard(
          title: '3. Emergency Tasks',
          subtitle: 'CTS Generated Immediate Action',
          icon: Icons.report_gmailerrorred_outlined,
          color: Colors.red,
          onTap: () => _showTaskCategoryDialog('Emergency Tasks', controller.emergencyTasks, controller),
          count: controller.emergencyTasks.length,
          isLoading: controller.isTasksLoading.value,
        ),
      ],
    );
  }

  Widget _buildTaskCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int count,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskCategoryDialog(String title, List<Map<String, dynamic>> tasks, WorkerController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(child: Text('No pending tasks in this category.'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final t = tasks[index];
                        return ListTile(
                          title: Text(t['taskType'] ?? 'Unknown Task'),
                          subtitle: Text('Coach: ${t['coachNo']} | ${t['description'] ?? ""}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Get.back();
                            // Logic to start/execute the selected exception task
                            final taskModel = WorkerTaskModel.fromJson(t);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useRootNavigator: true,
                              useSafeArea: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (ctx) => TaskExecutionBottomSheet(task: taskModel),
                            ).then((submitted) {
                              if (submitted == true) {
                                controller.fetchTasksByCategories();
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
