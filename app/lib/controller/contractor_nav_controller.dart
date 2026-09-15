import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

class ContractorNavController extends GetxController {
  late PersistentTabController tabController;

  var formStatusFilter = Rx<String?>(null);
  var formsInnerTabIndex = Rx<int?>(null);

  // Increments every time the Dashboard tab (index 0) is (re)selected from a
  // different tab, so the dashboard can reload its data when it becomes
  // visible again.
  var dashboardRefreshTick = Rx<int>(0);

  int _lastTabIndex = 0;

  @override
  void onInit() {
    tabController = PersistentTabController(initialIndex: 0);
    super.onInit();
  }

  void changeTab(int index) {
    _setTab(index);
  }

  void onTabSelected(int index) {
    _setTab(index);
  }

  void _setTab(int index) {
    final wasDashboard = _lastTabIndex == 0;
    tabController.index = index;
    _lastTabIndex = index;
    if (index == 0 && !wasDashboard) {
      dashboardRefreshTick.value++;
    }
    update();
  }

  void navigateToFormsWithStatus(String status) {
    formStatusFilter.value = status;
    _setTab(1);
  }

  void navigateToFormsTab(int innerTabIndex) {
    formsInnerTabIndex.value = innerTabIndex; // Set CTS tab index
    _setTab(1);
  }

  void clearFormStatusFilter() {
    formStatusFilter.value = null;
  }

  void clearFormsInnerTabIndex() {
    formsInnerTabIndex.value = null;
  }
}
