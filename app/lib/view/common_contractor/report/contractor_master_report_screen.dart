import 'dart:io';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/view/common_railways/widgets/date_range_picker.dart';
import 'package:crm_train/view/station_cleaning/cleaning_form/station_cleaning_form_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../../providers/auth_provider.dart';
import '../../../services/api_services.dart';
import '../../../services/dashboard_counts_service.dart';

const kRailwayBlue = Color(0xFF1565C0);

class ContractorReportScreen extends StatefulWidget {
  final String? contractType;

  const ContractorReportScreen({
    super.key,
    this.contractType,
  });

  @override
  State<ContractorReportScreen> createState() => _ContractorReportScreenState();
}

class _ContractorReportScreenState extends State<ContractorReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime? startDate;
  DateTime? endDate;
  String selectedZone = 'All Zones';
  String selectedDivision = 'All Divisions';
  String selectedDepot = 'All Depots';

  String selectedContract = 'All Contracts';

  List<String> contracts = ['All Contracts'];

  bool premisesReportGenerated = false;
  bool coachReportGenerated = false;
  bool isLoading = false;
  bool isDownloading = false;
  bool isLoadingContracts = false;
  bool ctsReportGenerated = false;


  bool isLoadingStats = true;
  List<dynamic> ctsReportData = [];
  List<dynamic> availableContracts = [];
  List<dynamic> premisesReportData = [];
  List<dynamic> coachReportData = [];


  Map<String, dynamic> coachApiStats = {};
  Map<String, dynamic> premisesApiStats = {};
  Map<String, dynamic> ctsApiStats = {};
  Map<String, dynamic> premisesStats = {};
  Map<String, dynamic> coachStats = {};


  @override
  void initState() {
    super.initState();
    _loadContracts();
    final isStationCleaning = widget.contractType == 'station_cleaning';
    _tabController = TabController(length: isStationCleaning ? 1 : 3, vsync: this);
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => isLoadingStats = true);

    try {
      final premisesData = await FirebaseCountService.getPremisesCleaningStats(
        userRole: user.role,
        uid: user.uid,
        zone: user.zone,
        division: user.division,
        depot: user.depot,
        entityId: user.entityId,
        contractId: user.contractId,
      );

      final coachData = await FirebaseCountService.getCoachCleaningStats(
        userRole: user.role,
        uid: user.uid,
        zone: user.zone,
        division: user.division,
        depot: user.depot,
        entityId: user.entityId,
        contractId: user.contractId,
      );

      final apiCoachData = await ApiService.getCoachStats();
      final apiPremisesData = await ApiService.getPremisesStats();
      final apiCTSData = await ApiService.getCTSStats();

      setState(() {
        premisesStats = premisesData;
        coachStats = coachData;
        coachApiStats = apiCoachData;
        premisesApiStats = apiPremisesData;
        ctsApiStats = apiCTSData;
        isLoadingStats = false;
      });
    } catch (e) {
      setState(() => isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContracts() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final user = provider.currentUser;

    if (user?.entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User entity information not found")),
      );
      return;
    }

    setState(() => isLoadingContracts = true);

    try {
      final contractsList = await ApiService.getContractsByStatus(
        user!.entityId!,
        user.zone ?? '',
        user.division ?? '',
      );

      setState(() {
        availableContracts = contractsList;
        contracts = ['All Contracts'];

        for (var c in contractsList) {
          contracts.add(c.uid);
        }

        Map<String, String> contractDisplay = {
          'All Contracts': 'All Contracts'
        };

        for (var c in contractsList) {
          contractDisplay[c.uid] = '${c.contractNumber} - ${c.contractName}';
        }


        isLoadingContracts = false;
      });
    } catch (e) {
      setState(() => isLoadingContracts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading contracts: $e")),
      );
    }
  }

  Future<void> _generateCoachReport() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final user = provider.currentUser;


    if (user?.entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User information not found")),
      );
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date range")),
      );
      return;
    }


    setState(() => isLoading = true);

    try {
      final formattedStart = DateFormat('yyyy-MM-dd').format(startDate!);
      final formattedEnd = DateFormat('yyyy-MM-dd').format(endDate!);


      String? contractId;
      if (selectedContract != 'All Contracts') {
        contractId = selectedContract;
      } else {
      }


      final response = await ApiService.getCoachReportData(
        startDate: formattedStart,
        endDate: formattedEnd,
        contractorId: user?.entityId ?? '',
        contractId: contractId ?? '',
        zone: user?.zone ?? "",
        division: user?.division ?? '',
        depot: user?.depot ?? '',
        trainNo: '',
        coachNo: ''
      );

      final dataList = response['data'] as List<dynamic>? ?? [];

      setState(() {
        coachReportData = dataList;
        coachReportGenerated = dataList.isNotEmpty;
        isLoading = false;
      });

      if (dataList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data found for selected criteria")),
        );
        return;
      }

      _showReportGeneratedDialog(false);
    } catch (e, stackTrace) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _generatePremisesReport() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final user = provider.currentUser;


    if (user?.entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User information not found")),
      );
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date range")),
      );
      return;
    }


    setState(() => isLoading = true);

    String? contractId;
    if (selectedContract != 'All Contracts') {
      contractId = selectedContract;
    } else {
    }

    try {
      final formattedStart = DateFormat('yyyy-MM-dd').format(startDate!);
      final formattedEnd = DateFormat('yyyy-MM-dd').format(endDate!);


      final response = await ApiService.getPremisesReportData(
        startDate: formattedStart,
        endDate: formattedEnd,
        areaType: '',
        zone: user?.zone ?? "",
        contractorId: user?.entityId ?? '',
        contractId: contractId ?? '',
        division: user?.division ?? '',
        depot: user?.depot ?? '',
      );

      final dataList = response['data'] as List<dynamic>? ?? [];

      setState(() {
        premisesReportData = dataList;
        premisesReportGenerated = dataList.isNotEmpty;
        isLoading = false;
      });

      if (dataList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data found for selected criteria")),
        );
        return;
      }

      _showReportGeneratedDialog(true);
    } catch (e, stackTrace) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }


  Future<void> _generateCTSReport() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final user = provider.currentUser;

    if (user?.entityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User information not found")),
      );
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date range")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final formattedStart = DateFormat('yyyy-MM-dd').format(startDate!);
      final formattedEnd = DateFormat('yyyy-MM-dd').format(endDate!);

      String? contractId;
      if (selectedContract != 'All Contracts') {
        contractId = selectedContract;
      }

      final response = await ApiService.getCTSReportData(
        startDate: formattedStart,
        endDate: formattedEnd,
        contractorId: user?.entityId ?? '',
        contractId: contractId ?? '',
        zone: user?.zone ?? "",
        division: user?.division ?? '',
        depot: user?.depot ?? '',
        trainNo: '',
      );

      final dataList = response['data'] as List<dynamic>? ?? [];

      setState(() {
        ctsReportData = dataList;
        ctsReportGenerated = dataList.isNotEmpty;
        isLoading = false;
      });

      if (dataList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data found for selected criteria")),
        );
        return;
      }

      _showCTSReportGeneratedDialog();
    } catch (e, stackTrace) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error generating report: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showCTSReportGeneratedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Success", style: TextStyle(color: Colors.green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Report Generated Successfully!"),
            SizedBox(height: 8),
            Text(
              "${ctsReportData.length} record found",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text("Close"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.file_download, color: Colors.white, size: 18),
            label: Text("Download Excel", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _downloadCTSExcel();
            },
          ),
        ],
      ),
    );
  }

  void _showReportGeneratedDialog(bool isPremises) {
    final data = isPremises ? premisesReportData : coachReportData;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Success", style: TextStyle(color: Colors.green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Report Generated Successfully!"),
            SizedBox(height: 8),
            Text(
              "${data.length} record found",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text("Close"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.file_download, color: Colors.white, size: 18),
            label: Text("Download Excel", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (isPremises) {
                _downloadPremisesExcel();
              } else {
                _downloadCoachExcel();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPremisesExcel() async {
    if (premisesReportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available to download")),
      );
      return;
    }

    setState(() => isDownloading = true);

    try {
      final workbook = xlsio.Workbook();


      Map<String, List<dynamic>> groupedData = {};
      for (var item in premisesReportData) {
        final premiseName = item["premiseName"]?.toString() ?? "Unknown";
        if (!groupedData.containsKey(premiseName)) {
          groupedData[premiseName] = [];
        }
        groupedData[premiseName]!.add(item);
      }



      int sheetIndex = 0;
      for (var entry in groupedData.entries) {
        final premiseName = entry.key;
        final premiseData = entry.value;


        xlsio.Worksheet sheet;
        if (sheetIndex == 0) {
          sheet = workbook.worksheets[0];
          sheet.name = premiseName.length > 31 ? premiseName.substring(0, 31) : premiseName;
        } else {
          sheet = workbook.worksheets.add();
          sheet.name = premiseName.length > 31 ? premiseName.substring(0, 31) : premiseName;
        }


        final headerStyle = workbook.styles.add('headerStyle$sheetIndex')
          ..backColor = '#1F4E78'
          ..fontColor = '#FFFFFF'
          ..bold = true
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..wrapText = true
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        final subHeaderStyle = workbook.styles.add('subHeaderStyle$sheetIndex')
          ..backColor = '#4472C4'
          ..fontColor = '#FFFFFF'
          ..bold = true
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        final cellStyle = workbook.styles.add('cellStyle$sheetIndex')
          ..hAlign = xlsio.HAlignType.center
          ..vAlign = xlsio.VAlignType.center
          ..borders.all.lineStyle = xlsio.LineStyle.thin;

        sheet.getRangeByName('A1').setText('Date');
        sheet.getRangeByName('B1').setText('Premise Name');
        sheet.getRangeByName('C1').setText('Total Area in Sq Mtrs');
        sheet.getRangeByName('D1').setText('Area attended for Cleaning');
        sheet.getRangeByName('E1').setText('Area Not Attended / Not Cleaned');
        sheet.getRangeByName('F1').setText('Rating of Cleaning on the Day in %');
        sheet.getRangeByName('G1').setText('Housekeeping Score');
        sheet.getRangeByName('H1').setText('Pit-Line Score');
        sheet.getRangeByName('I1').setText('Garbage Score');
        sheet.getRangeByName('J1').setText('Overall Score');
        sheet.getRangeByName('K1').setText('90%+');

        sheet.getRangeByName('L1:N1').merge();
        sheet.getRangeByName('L1').setText('Penalty for Cleaning having rating');
        sheet.getRangeByName('L2').setText('81% to 90%');
        sheet.getRangeByName('M2').setText('71% to 80%');
        sheet.getRangeByName('N2').setText('70% and below');

        sheet.getRangeByName('A1:K1').cellStyle = headerStyle;
        sheet.getRangeByName('L1').cellStyle = headerStyle;
        sheet.getRangeByName('L2:N2').cellStyle = subHeaderStyle;

        sheet.getRangeByName('A1').columnWidth = 15;
        sheet.getRangeByName('B1').columnWidth = 20;
        sheet.getRangeByName('C1').columnWidth = 20;
        sheet.getRangeByName('D1').columnWidth = 22;
        sheet.getRangeByName('E1').columnWidth = 25;
        sheet.getRangeByName('F1').columnWidth = 25;
        sheet.getRangeByName('G1').columnWidth = 20;
        sheet.getRangeByName('H1').columnWidth = 20;
        sheet.getRangeByName('I1').columnWidth = 20;
        sheet.getRangeByName('J1').columnWidth = 20;
        sheet.getRangeByName('K1').columnWidth = 12;

        for (int i = 12; i <= 14; i++) {
          sheet.getRangeByIndex(1, i).columnWidth = 15;
        }

        int rowIndex = 3;

        for (var item in premiseData) {
          final totalArea = item["totalAreaSqMeters"]?.toString() ??
              item["totalArea"]?.toString() ?? "0";
          final areaAttended = item["areaAttendedForCleaning"]?.toString() ??
              item["totalAreaSqMeters"]?.toString() ??
              item["totalArea"]?.toString() ?? "0";

          sheet.getRangeByIndex(rowIndex, 1).setText(item["date"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 2).setText(item["premiseName"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 3).setText(totalArea);
          sheet.getRangeByIndex(rowIndex, 4).setText(areaAttended);
          sheet.getRangeByIndex(rowIndex, 5).setText("0");       // Area not attended = 0
          sheet.getRangeByIndex(rowIndex, 6).setText(item["ratingInPct"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 7).setText(item["housekeepingScore"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 8).setText(item["pitLineScore"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 9).setText(item["garbageScore"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 10).setText(item["overallScore"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 11).setText(item["above90"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 12).setText(item["penalty81to90"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 13).setText(item["penalty71to80"]?.toString() ?? "");
          sheet.getRangeByIndex(rowIndex, 14).setText(item["penaltyBelow70"]?.toString() ?? "");

          sheet.getRangeByName('A$rowIndex:N$rowIndex').cellStyle = cellStyle;
          sheet.getRangeByName('A$rowIndex:N$rowIndex').rowHeight = 25;

          rowIndex++;
        }

        sheetIndex++;
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/Premises_Cleaning_Report_$timestamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      setState(() => isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Report downloaded with ${groupedData.length} sheets!"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Open",
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      setState(() => isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> _downloadCoachExcel() async {
    if (coachReportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available to download")),
      );
      return;
    }

    setState(() => isDownloading = true);

    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];


      final yellowHeader = workbook.styles.add('yellowHeader')
        ..backColor = '#FFFFFF'
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final purpleHeader = workbook.styles.add('purpleHeader')
        ..backColor = '#9966CC'
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final lightBlueHeader = workbook.styles.add('lightBlueHeader')
        ..backColor = '#ADD8E6'
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final whiteHeader = workbook.styles.add('whiteHeader')
        ..backColor = '#FFFFFF'
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final dataStyle = workbook.styles.add('dataStyle')
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.getRangeByName('A1:A3').merge();
      sheet.getRangeByName('A1').setText('Date');
      sheet.getRangeByName('A1').cellStyle = whiteHeader;

      sheet.getRangeByName('B1:B3').merge();
      sheet.getRangeByName('B1').setText('Train');
      sheet.getRangeByName('B1').cellStyle = whiteHeader;


      sheet.getRangeByName('C1:C3').merge();
      sheet.getRangeByName('C1').setText('TYPE OF WORK\n(PRIMARY/\nSECONDARY/ RBPC WITH\nM/C / RBPC\nWITHOUT M/C');
      sheet.getRangeByName('C1').cellStyle = whiteHeader;

      sheet.getRangeByName('D1:D3').merge();
      sheet.getRangeByName('D1').setText('WITH OR\nWITHOUT\nACWP');
      sheet.getRangeByName('D1').cellStyle = whiteHeader;

      sheet.getRangeByName('E1:H1').merge();
      sheet.getRangeByName('E1').setText('Internal Cleaning');
      sheet.getRangeByName('E1').cellStyle = yellowHeader;
      sheet.getRangeByName('E2:H2').merge();
      sheet.getRangeByName('E2').setText('Primary or Secondary');
      sheet.getRangeByName('E2').cellStyle = yellowHeader;

      sheet.getRangeByName('I1:L1').merge();
      sheet.getRangeByName('I1').setText('Internal Cleaning');
      sheet.getRangeByName('I1').cellStyle = yellowHeader;
      sheet.getRangeByName('I2:L2').merge();
      sheet.getRangeByName('I2').setText('RBPC With Machine');
      sheet.getRangeByName('I2').cellStyle = yellowHeader;

      sheet.getRangeByName('M1:P1').merge();
      sheet.getRangeByName('M1').setText('Internal Cleaning');
      sheet.getRangeByName('M1').cellStyle = yellowHeader;
      sheet.getRangeByName('M2:P2').merge();
      sheet.getRangeByName('M2').setText('RBPC Without Machine');
      sheet.getRangeByName('M2').cellStyle = yellowHeader;


      sheet.getRangeByName('Q1:T1').merge();
      sheet.getRangeByName('Q1').setText('Intensive Cleaning');
      sheet.getRangeByName('Q1').cellStyle = yellowHeader;
      sheet.getRangeByName('Q2:T2').merge();
      sheet.getRangeByName('Q2').setText('Without ACWP');
      sheet.getRangeByName('Q2').cellStyle = yellowHeader;


      sheet.getRangeByName('U1:X1').merge();
      sheet.getRangeByName('U1').setText('External Cleaning');
      sheet.getRangeByName('U1').cellStyle = purpleHeader;
      sheet.getRangeByName('U2:X2').merge();
      sheet.getRangeByName('U2').setText('With ACWP');
      sheet.getRangeByName('U2').cellStyle = purpleHeader;

      sheet.getRangeByName('Y1:AB1').merge();
      sheet.getRangeByName('Y1').setText('External Cleaning');
      sheet.getRangeByName('Y1').cellStyle = purpleHeader;
      sheet.getRangeByName('Y2:AB2').merge();
      sheet.getRangeByName('Y2').setText('Without ACWP');
      sheet.getRangeByName('Y2').cellStyle = purpleHeader;


      sheet.getRangeByName('AC1:AE1').merge();
      sheet.getRangeByName('AC1').setText('Toiletries');
      sheet.getRangeByName('AC1').cellStyle = lightBlueHeader;

      sheet.getRangeByName('AF1:AH1').merge();
      sheet.getRangeByName('AF1').setText('Watering');
      sheet.getRangeByName('AF1').cellStyle = lightBlueHeader;

      sheet.getRangeByName('AI1:AK1').merge();
      sheet.getRangeByName('AI1').setText('Door Locking');
      sheet.getRangeByName('AI1').cellStyle = lightBlueHeader;


      sheet.getRangeByName('AL1:AL3').merge();
      sheet.getRangeByName('AL1').setText('ACTUAL MANPOWER (with ACWP)');
      sheet.getRangeByName('AL1').cellStyle = whiteHeader;

      sheet.getRangeByName('AM1:AM3').merge();
      sheet.getRangeByName('AM1').setText('ACTUAL MANPOWER (without ACWP)');
      sheet.getRangeByName('AM1').cellStyle = whiteHeader;

      sheet.getRangeByName('AN1:AN3').merge();
      sheet.getRangeByName('AN1').setText('MANPOWER SHORTAGE');
      sheet.getRangeByName('AN1').cellStyle = whiteHeader;

      sheet.getRangeByName('AO1:AO3').merge();
      sheet.getRangeByName('AO1').setText('Machine SHORTAGE');
      sheet.getRangeByName('AO1').cellStyle = whiteHeader;


      final subHeaders = ['A', 'B', 'C', 'D'];


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 5 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 5 + i).cellStyle = yellowHeader;
      }


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 9 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 9 + i).cellStyle = yellowHeader;
      }


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 13 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 13 + i).cellStyle = yellowHeader;
      }


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 17 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 17 + i).cellStyle = yellowHeader;
      }


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 21 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 21 + i).cellStyle = purpleHeader;
      }
      sheet.getRangeByIndex(3, 25).setText('NA');
      sheet.getRangeByIndex(3, 25).cellStyle = purpleHeader;


      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 25 + i).setText(subHeaders[i]);
        sheet.getRangeByIndex(3, 25 + i).cellStyle = purpleHeader;
      }


      final yesNoNaHeaders = ['Yes', 'No', 'NA'];


      for (int i = 0; i < 3; i++) {
        sheet.getRangeByIndex(3, 29 + i).setText(yesNoNaHeaders[i]);
        sheet.getRangeByIndex(3, 29 + i).cellStyle = lightBlueHeader;
      }


      for (int i = 0; i < 3; i++) {
        sheet.getRangeByIndex(3, 32 + i).setText(yesNoNaHeaders[i]);
        sheet.getRangeByIndex(3, 32 + i).cellStyle = lightBlueHeader;
      }


      for (int i = 0; i < 3; i++) {
        sheet.getRangeByIndex(3, 35 + i).setText(yesNoNaHeaders[i]);
        sheet.getRangeByIndex(3, 35 + i).cellStyle = lightBlueHeader;
      }


      sheet.getRangeByName('A1').columnWidth = 10;
      sheet.getRangeByName('B1').columnWidth = 35;
      sheet.getRangeByName('C1').columnWidth = 20;
      sheet.getRangeByName('D1').columnWidth = 15;

      for (int i = 5; i <= 37; i++) {
        sheet.getRangeByIndex(1, i).columnWidth = 5;
      }

      sheet.getRangeByName('AL1').columnWidth = 18;
      sheet.getRangeByName('AM1').columnWidth = 18;
      sheet.getRangeByName('AN1').columnWidth = 15;
      sheet.getRangeByName('AO1').columnWidth = 15;

      int rowIndex = 4;

      for (var item in coachReportData) {
        sheet.getRangeByIndex(rowIndex, 1).setText(item["date"]?.toString() ?? "");

        final trainNumber = item["trainNo"]?.toString() ?? "";
        final trainName = item["trainName"]?.toString() ?? "";
        final trainDisplay = trainName.isNotEmpty
            ? "$trainNumber - $trainName"
            : trainNumber;
        sheet.getRangeByIndex(rowIndex, 2).setText(trainDisplay);
        sheet.getRangeByIndex(rowIndex, 3).setText(item["workType"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 4).setText(item["acwpStatus"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 5).setText(item["int_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 6).setText(item["int_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 7).setText(item["int_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 8).setText(item["int_D"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 9).setText(item["rbpc_mach_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 10).setText(item["rbpc_mach_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 11).setText(item["rbpc_mach_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 12).setText(item["rbpc_mach_D"]?.toString() ?? "");

        sheet.getRangeByIndex(rowIndex, 13).setText(item["rbpc_man_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 14).setText(item["rbpc_man_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 15).setText(item["rbpc_man_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 16).setText(item["rbpc_man_D"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 17).setText(item["intense_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 18).setText(item["intense_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 19).setText(item["intense_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 20).setText(item["intense_D"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 21).setText(item["ext_acwp_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 22).setText(item["ext_acwp_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 23).setText(item["ext_acwp_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 24).setText(item["ext_acwp_D"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 25).setText(item["ext_acwp_NA"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 26).setText(item["ext_man_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 27).setText(item["ext_man_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 28).setText(item["ext_man_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 29).setText(item["ext_man_D"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 29).setText(item["toil_Yes"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 30).setText(item["toil_No"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 31).setText(item["toil_NA"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 32).setText(item["water_Yes"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 33).setText(item["water_No"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 34).setText(item["water_NA"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 35).setText(item["door_Yes"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 36).setText(item["door_No"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 37).setText(item["door_NA"]?.toString() ?? "");


        sheet.getRangeByIndex(rowIndex, 38).setText(item["actualWithACWP"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 39).setText(item["actualWithoutACWP"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 40).setText(item["manpowerShortage"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 41).setText(item["machineShortage"]?.toString() ?? "");


        for (int col = 1; col <= 41; col++) {
          sheet.getRangeByIndex(rowIndex, col).cellStyle = dataStyle;
        }

        rowIndex++;
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/Coach_Cleaning_Report_$timestamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      setState(() => isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Report downloaded successfully!"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Open",
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      setState(() => isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> _downloadCTSExcel() async {
    if (ctsReportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available to download")),
      );
      return;
    }

    setState(() => isDownloading = true);

    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'CTS Report';

      final headerStyle = workbook.styles.add('headerStyle')
        ..bold = true
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..wrapText = true
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      final dataStyle = workbook.styles.add('dataStyle')
        ..hAlign = xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin;

      sheet.getRangeByName('A1').columnWidth = 12;
      sheet.getRangeByName('B1').columnWidth = 30;
      sheet.getRangeByName('C1').columnWidth = 18;
      sheet.getRangeByName('D1').columnWidth = 18;
      sheet.getRangeByName('E1').columnWidth = 16;
      sheet.getRangeByName('F1').columnWidth = 16;
      sheet.getRangeByName('G1').columnWidth = 22;
      sheet.getRangeByName('H1').columnWidth = 22;
      sheet.getRangeByName('I1').columnWidth = 12;
      sheet.getRangeByName('J1').columnWidth = 16;
      sheet.getRangeByName('K1').columnWidth = 18;
      sheet.getRangeByName('L1').columnWidth = 8;
      sheet.getRangeByName('M1').columnWidth = 16;
      sheet.getRangeByName('N1').columnWidth = 18;
      sheet.getRangeByName('O1').columnWidth = 14;
      sheet.getRangeByName('P1').columnWidth = 18;

      for (int i = 17; i <= 28; i++) {
        sheet.getRangeByIndex(1, i).columnWidth = 8;
      }

      sheet.getRangeByName('AC1').columnWidth = 18;
      sheet.getRangeByName('AD1').columnWidth = 16;
      sheet.getRangeByName('AE1').columnWidth = 14;
      sheet.getRangeByName('AF1').columnWidth = 14;
      sheet.getRangeByName('AG1').columnWidth = 20;
      sheet.getRangeByName('AH1').columnWidth = 18;

      final row1Headers = [
        'Date', 'Train No.', 'Actual Arrival Time', 'Actual Departure Time',
        'Work Start Time', 'Work End Time', 'Contractor Supervisor Name',
        'Railway Supervisor Name', 'Total Coaches', 'Attended Coaches',
        'Unattended Coaches', 'Late', 'Garbage Disposed', 'Nominated Location',
        'Machines Used', 'Chemical Used (Liter)'
      ];

      for (int i = 0; i < row1Headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(row1Headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle = headerStyle;
      }

      sheet.getRangeByName('Q1:AB1').merge();
      sheet.getRangeByName('Q1').setText('Grade Distribution');
      sheet.getRangeByName('Q1').cellStyle = headerStyle;

      final finalRow1Headers = [
        'Sampled Coaches %', 'Sampled Coaches', 'Overall Grade',
        'Overall Score', 'Actual Manpower Used', 'Manpower Shortage'
      ];

      for (int i = 0; i < finalRow1Headers.length; i++) {
        sheet.getRangeByIndex(1, 29 + i).setText(finalRow1Headers[i]);
        sheet.getRangeByIndex(1, 29 + i).cellStyle = headerStyle;
      }

      sheet.getRangeByName('Q2:T2').merge();
      sheet.getRangeByName('Q2').setText('Jet Clean');
      sheet.getRangeByName('Q2').cellStyle = headerStyle;

      sheet.getRangeByName('U2:X2').merge();
      sheet.getRangeByName('U2').setText('Basin Clean');
      sheet.getRangeByName('U2').cellStyle = headerStyle;

      sheet.getRangeByName('Y2:AB2').merge();
      sheet.getRangeByName('Y2').setText('Disposal');
      sheet.getRangeByName('Y2').cellStyle = headerStyle;

      final gradeHeaders = ['A', 'B', 'C', 'D'];

      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 17 + i).setText(gradeHeaders[i]);
        sheet.getRangeByIndex(3, 17 + i).cellStyle = headerStyle;
      }

      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 21 + i).setText(gradeHeaders[i]);
        sheet.getRangeByIndex(3, 21 + i).cellStyle = headerStyle;
      }

      for (int i = 0; i < 4; i++) {
        sheet.getRangeByIndex(3, 25 + i).setText(gradeHeaders[i]);
        sheet.getRangeByIndex(3, 25 + i).cellStyle = headerStyle;
      }

      int rowIndex = 4;

      for (var item in ctsReportData) {
        sheet.getRangeByIndex(rowIndex, 1).setText(item["date"]?.toString() ?? "");

        final trainNumber = item["trainNo"]?.toString() ?? "";
        final trainName = item["trainName"]?.toString() ?? "";
        final trainDisplay = trainName.isNotEmpty ? "$trainNumber - $trainName" : trainNumber;
        sheet.getRangeByIndex(rowIndex, 2).setText(trainDisplay);

        sheet.getRangeByIndex(rowIndex, 3).setText(_formatDateTime(item["actualArrival"]?.toString() ?? ""));
        sheet.getRangeByIndex(rowIndex, 4).setText(_formatDateTime(item["actualDeparture"]?.toString() ?? ""));
        sheet.getRangeByIndex(rowIndex, 5).setText(_formatDateTime(item["workStart"]?.toString() ?? ""));
        sheet.getRangeByIndex(rowIndex, 6).setText(_formatDateTime(item["workEnd"]?.toString() ?? ""));
        sheet.getRangeByIndex(rowIndex, 7).setText(item["contractorSupervisor"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 8).setText(item["railwaySupervisor"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 9).setText(item["totalCoaches"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 10).setText(item["attendedCoaches"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 11).setText(item["unattendedCoaches"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 12).setText(item["late"]?.toString() ?? "No");
        sheet.getRangeByIndex(rowIndex, 13).setText(item["garbageDisposed"]?.toString() ?? "No");
        sheet.getRangeByIndex(rowIndex, 14).setText(item["location"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 15).setText(item["machinesUsedCount"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 16).setText(item["chemicalUsedLiter"]?.toString() ?? "");

        sheet.getRangeByIndex(rowIndex, 17).setText(item["jet_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 18).setText(item["jet_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 19).setText(item["jet_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 20).setText(item["jet_D"]?.toString() ?? "");

        sheet.getRangeByIndex(rowIndex, 21).setText(item["basin_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 22).setText(item["basin_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 23).setText(item["basin_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 24).setText(item["basin_D"]?.toString() ?? "");

        sheet.getRangeByIndex(rowIndex, 25).setText(item["disposal_A"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 26).setText(item["disposal_B"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 27).setText(item["disposal_C"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 28).setText(item["disposal_D"]?.toString() ?? "");

        sheet.getRangeByIndex(rowIndex, 29).setText(item["sampledPercentage"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 30).setText(item["sampledCoaches"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 31).setText(item["overallGrade"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 32).setText(item["overallScore"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 33).setText(item["actualManpower"]?.toString() ?? "");
        sheet.getRangeByIndex(rowIndex, 34).setText(item["manpowerShortage"]?.toString() ?? "");

        for (int col = 1; col <= 34; col++) {
          sheet.getRangeByIndex(rowIndex, col).cellStyle = dataStyle;
        }

        rowIndex++;
      }

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/CTS_Report_$timestamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      setState(() => isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("CTS Report downloaded with ${ctsReportData.length} record."),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Open",
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      setState(() => isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd-MM-yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Reports',
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: widget.contractType == 'station_cleaning'
              ? const [
                  Tab(text: "Station Cleaning"),
                ]
              : const [
                  Tab(text: "Coach"),
                  Tab(text: "Premises"),
                  Tab(text: "CTS"),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.contractType == 'station_cleaning'
            ? [_buildStationCleaningTab()]
            : [
                _buildCoachCleaningTab(),
                _buildPremisesCleaningTab(),
                _buildCTSTab(),
              ],
      ),
    );
  }


  Widget _buildCoachCleaningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Coach Cleaning Performance Report",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          _filterContainer(
            children: [
              const Text("Filter Reports",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _buildDropdown('Contract', selectedContract, contracts,
                      (v) => setState(() => selectedContract = v!)),
              const SizedBox(height: 12),
       DateRangePickerField(
        startDate: startDate,
        endDate: endDate,
        onTap: _selectDateRange,
      ),

              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assessment, color: Colors.white),
                label: Text(
                  isLoading ? "Generating..." : "Generate Report",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                onPressed: isLoading ? null : _generateCoachReport,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _summaryContainer(
            title: "Coach Cleaning Statistics",
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  double aspectRatio;
                  if (constraints.maxWidth < 320) {
                    aspectRatio = 1.3;
                  } else if (constraints.maxWidth < 360) {
                    aspectRatio = 1.5;
                  } else {
                    aspectRatio = 1.7;
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: aspectRatio,
                    children: [
                      _summaryCard(
                          title: "Total Trains Cleaned",
                          value: isLoadingStats
                              ? "..."
                              : (coachApiStats['cards']?['totalTrains']?.toString() ?? "0"),
                          color: Colors.blue),
                      _summaryCard(
                          title: "Total Coaches",
                          value: isLoadingStats
                              ? "..."
                              : (coachApiStats['cards']?['totalCoaches']?.toString() ?? "0"),
                          color: Colors.teal),
                      _summaryCard(
                          title: "Total Manpower Used",
                          value: isLoadingStats
                              ? "..."
                              : (coachApiStats['cards']?['totalManpower']?.toString() ?? "0"),
                          color: Colors.orange),
                      _summaryCard(
                          title: "Total Penalty",
                          value: isLoadingStats
                              ? "..."
                              : (coachApiStats['cards']?['totalPenalty']?.toString() ?? "0"),
                          color: Colors.purple),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Quality Grade Distribution",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _gradeBox(
                    'A',
                    isLoadingStats ? '...' : (coachApiStats['gradeDistribution']?['A']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${coachApiStats['gradeDistribution']?['A']?['pct'] ?? '0.0'}%',
                    Colors.green,
                  ),
                  _gradeBox(
                    'B',
                    isLoadingStats ? '...' : (coachApiStats['gradeDistribution']?['B']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${coachApiStats['gradeDistribution']?['B']?['pct'] ?? '0.0'}%',
                    Colors.blue,
                  ),
                  _gradeBox(
                    'C',
                    isLoadingStats ? '...' : (coachApiStats['gradeDistribution']?['C']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${coachApiStats['gradeDistribution']?['C']?['pct'] ?? '0.0'}%',
                    Colors.orange,
                  ),
                  _gradeBox(
                    'D',
                    isLoadingStats ? '...' : (coachApiStats['gradeDistribution']?['D']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${coachApiStats['gradeDistribution']?['D']?['pct'] ?? '0.0'}%',
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "CLEANING OPERATIONS SUMMARY",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _maintenanceBox(
                    title: "Toiletries\nCleaned",
                    done: isLoadingStats ? "..." : (coachApiStats['operations']?['toiletries']?['Yes']?.toString() ?? "0"),
                    cross: isLoadingStats ? "..." : (coachApiStats['operations']?['toiletries']?['No']?.toString() ?? "0"),
                    na: isLoadingStats ? "..." : (coachApiStats['operations']?['toiletries']?['NA']?.toString() ?? "0"),
                    color: Colors.teal,
                  ),
                  _maintenanceBox(
                    title: "Door\nLocking",
                    done: isLoadingStats ? "..." : (coachApiStats['operations']?['doors']?['Yes']?.toString() ?? "0"),
                    cross: isLoadingStats ? "..." : (coachApiStats['operations']?['doors']?['No']?.toString() ?? "0"),
                    na: isLoadingStats ? "..." : (coachApiStats['operations']?['doors']?['NA']?.toString() ?? "0"),
                    color: Colors.blue,
                  ),
                  _maintenanceBox(
                    title: "Watering\nDone",
                    done: isLoadingStats ? "..." : (coachApiStats['operations']?['watering']?['Yes']?.toString() ?? "0"),
                    cross: isLoadingStats ? "..." : (coachApiStats['operations']?['watering']?['No']?.toString() ?? "0"),
                    na: isLoadingStats ? "..." : (coachApiStats['operations']?['watering']?['NA']?.toString() ?? "0"),
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "RESOURCE UTILIZATION",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _shortageBox(
                    "Manpower\nDeployed",
                    isLoadingStats ? "..." : (coachApiStats['resources']?['manpowerDeployed']?.toString() ?? "0"),
                    "Active Today",
                    Colors.green.shade600
                  ),
                  _shortageBox(
                    "Machines\nUsed",
                    isLoadingStats ? "..." : (coachApiStats['resources']?['machinesUsed']?.toString() ?? "0"),
                    "Equipment",
                    Colors.blue.shade600
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPremisesCleaningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Premises Cleaning Performance Report",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          _filterContainer(
            children: [
              const Text("Filter Reports",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _buildDropdown('Contract', selectedContract, contracts,
                      (v) => setState(() => selectedContract = v!)),
              const SizedBox(height: 12),
              DateRangePickerField(
                startDate: startDate,
                endDate: endDate,
                onTap: _selectDateRange,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.assessment, color: Colors.white),
                label: const Text("Generate Report", style: TextStyle(color: Colors.white, fontSize: 15)),
                onPressed: isLoading ? null : _generatePremisesReport,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _summaryContainer(
            title: "Premises Cleaning Statistics",
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive aspect ratio
                  double aspectRatio;
                  if (constraints.maxWidth < 320) {
                    aspectRatio = 1.2;
                  } else if (constraints.maxWidth < 360) {
                    aspectRatio = 1.4;
                  } else {
                    aspectRatio = 1.5;
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: aspectRatio,
                    children: [
                      _summaryCard(
                          title: "Total Premises Cleaned",
                          value: isLoadingStats
                              ? "..."
                              : (premisesApiStats['cards']?['totalPremisesCleaned']?.toString() ?? "0"),
                          color: Colors.blue),
                      _summaryCard(
                          title: "Total Area Cleaned",
                          value: isLoadingStats
                              ? "..."
                              : "${premisesApiStats['cards']?['totalAreaCleaned']?.toString() ?? "0"} sqm",
                          color: Colors.green),
                      _summaryCard(
                          title: "Total Area Uncleaned",
                          value: isLoadingStats
                              ? "..."
                              : "${premisesApiStats['cards']?['totalAreaUncleaned']?.toString() ?? "0"} sq mtr",
                          color: Colors.orange),
                      _summaryCard(
                          title: "Manpower Deployed",
                          value: isLoadingStats
                              ? "..."
                              : (premisesApiStats['cards']?['manpowerDeployed']?.toString() ?? "0"),
                          color: Colors.purple),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Quality Performance Distribution",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _gradeBox(
                    'Above 90%',
                    isLoadingStats ? '...' : (premisesApiStats['qualityPerformanceDistribution']?['above90']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${premisesApiStats['qualityPerformanceDistribution']?['above90']?['pct'] ?? '0.0'}%',
                    Colors.green,
                  ),
                  _gradeBox(
                    '81-90%',
                    isLoadingStats ? '...' : (premisesApiStats['qualityPerformanceDistribution']?['range81to90']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${premisesApiStats['qualityPerformanceDistribution']?['range81to90']?['pct'] ?? '0.0'}%',
                    Colors.blue,
                  ),
                  _gradeBox(
                    '71-80%',
                    isLoadingStats ? '...' : (premisesApiStats['qualityPerformanceDistribution']?['range71to80']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${premisesApiStats['qualityPerformanceDistribution']?['range71to80']?['pct'] ?? '0.0'}%',
                    Colors.orange,
                  ),
                  _gradeBox(
                    'Below 70%',
                    isLoadingStats ? '...' : (premisesApiStats['qualityPerformanceDistribution']?['below70']?['count']?.toString() ?? '0'),
                    isLoadingStats ? '...' : '${premisesApiStats['qualityPerformanceDistribution']?['below70']?['pct'] ?? '0.0'}%',
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "MANPOWER ALLOCATION",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _shortageBox(
                    "Daily\nAverage",
                    isLoadingStats ? "..." : (premisesApiStats['manpowerAllocation']?['dailyAverage']?.toString() ?? "0"),
                    "Employees",
                    Colors.green.shade600
                  ),
                  _shortageBox(
                    "Peak\nHours",
                    isLoadingStats ? "..." : (premisesApiStats['manpowerAllocation']?['peakHours']?.toString() ?? "0"),
                    "Employees",
                    Colors.orange.shade600
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildCTSTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "CTS Form Performance Report",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          _filterContainer(
            children: [
              const Text("Filter Reports",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _buildDropdown('Contract', selectedContract, contracts,
                      (v) => setState(() => selectedContract = v!)),
              const SizedBox(height: 12),
              DateRangePickerField(
                startDate: startDate,
                endDate: endDate,
                onTap: _selectDateRange,
              ),

              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isLoading
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.assessment, color: Colors.white),
                label: Text(
                  isLoading ? "Generating..." : "Generate Report",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                onPressed: isLoading ? null : _generateCTSReport,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _summaryContainer(
            title: "CTS Form Statistics",
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  double aspectRatio;
                  if (constraints.maxWidth < 320) {
                    aspectRatio = 1.3;
                  } else if (constraints.maxWidth < 360) {
                    aspectRatio = 1.5;
                  } else {
                    aspectRatio = 1.7;
                  }

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: aspectRatio,
                    children: [
                      _summaryCard(
                          title: "Total Trains / Coaches Cleaned",
                          value: isLoadingStats
                              ? "..."
                              : "${(ctsApiStats['statistics']?['totalTrains']?.toString() ?? "0")} / ${ctsApiStats['statistics']?['totalCoachesCleaned'] ?? "0%"}",
                          color: Colors.blue),
                      _summaryCard(
                          title: "Total unattended coaches",
                          value: isLoadingStats
                              ? "..."
                              : (ctsApiStats['statistics']?['totalUnattendedCoaches']?.toString() ?? "0"),
                          color: Colors.teal),
                      _summaryCard(
                          title: "Sampled Coaches / Percentage",
                          value: isLoadingStats
                              ? "..."
                              : "${ctsApiStats['statistics']?['sampledCoaches']?.toString() ?? "0"} / ${ctsApiStats['statistics']?['samplingPercentage'] ?? "0%"}",
                          color: Colors.orange),
                      _summaryCard(
                          title: "Average Window Time",
                          value: isLoadingStats
                              ? "..."
                              : (ctsApiStats['statistics']?['averageWindowTime']?.toString() ?? "0 Min"),
                          color: Colors.purple),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Overall Grade Distribution",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              _buildCTSGradeRow(isLoadingStats, ctsApiStats),
              const SizedBox(height: 20),
              const Text(
                "CLEANING OPERATIONS SUMMARY",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _performanceSummary(
                    title: "Toilet\nOccupied",
                    done: isLoadingStats ? "..." : (ctsApiStats['cleaningOperations']?['toiletOccupied']?.toString() ?? "0"),
                  ),
                  _performanceSummary(
                    title: "Average\nScore",
                    done: isLoadingStats ? "..." : (ctsApiStats['cleaningOperations']?['averageScore']?.toString() ?? "0"),
                  ),
                  _performanceSummary(
                    title: "Toilet\nUnattended",
                    done: isLoadingStats ? "..." : (ctsApiStats['cleaningOperations']?['toiletUnattended']?.toString() ?? "0"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "RESOURCE USED",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _shortageBox(
                    "Manpower\nUses",
                    isLoadingStats ? "..." : (ctsApiStats['resourcesUsed']?['manpowerTotal']?.toString() ?? "0"),
                    "Total",
                    Colors.red.shade400,
                  ),
                  _shortageBox(
                    "Chemical\nUses",
                    isLoadingStats ? "..." : (ctsApiStats['resourcesUsed']?['chemicalQuantity']?.toString() ?? "0"),
                    "Liter",
                    Colors.red.shade400,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildCTSGradeRow(bool isLoadingStats, Map<String, dynamic> ctsStats) {
    final gradeDistribution = ctsStats['gradeDistribution'] ?? {};
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRailwayBlue),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _gradeItem(
            grade: 'A',
            count: isLoadingStats ? '...' : '${gradeDistribution['A']?['count'] ?? 0}',
            percent: isLoadingStats
                ? '...'
                : '${gradeDistribution['A']?['pct'] ?? '0.0'}%',
            color: Colors.green,
          ),
          _verticalDivider(),
          _gradeItem(
            grade: 'B',
            count: isLoadingStats ? '...' : '${gradeDistribution['B']?['count'] ?? 0}',
            percent: isLoadingStats
                ? '...'
                : '${gradeDistribution['B']?['pct'] ?? '0.0'}%',
            color: Colors.blue,
          ),
          _verticalDivider(),
          _gradeItem(
            grade: 'C',
            count: isLoadingStats ? '...' : '${gradeDistribution['C']?['count'] ?? 0}',
            percent: isLoadingStats
                ? '...'
                : '${gradeDistribution['C']?['pct'] ?? '0.0'}%',
            color: Colors.orange,
          ),
          _verticalDivider(),
          _gradeItem(
            grade: 'D',
            count: isLoadingStats ? '...' : '${gradeDistribution['D']?['count'] ?? 0}',
            percent: isLoadingStats
                ? '...'
                : '${gradeDistribution['D']?['pct'] ?? '0.0'}%',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.shade300);
  }

  Widget _gradeItem({
    required String grade,
    required String count,
    required String percent,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            percent,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _filterContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _summaryContainer(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value != null && items.contains(value) ? value : null,
              items: items
                  .map((uid) {
                    String displayText = uid;
                    if (uid != 'All Contracts') {
                      try {
                        final contract = availableContracts.firstWhere(
                          (c) => c.uid == uid,
                        );
                        displayText = '${contract.contractNumber} - ${contract.contractName}';
                      } catch (e) {
                        displayText = uid;
                      }
                    }
                    return DropdownMenuItem(value: uid, child: Text(displayText));
                  })
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    bool isMoney = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {

        double titleFontSize;
        double valueFontSize;
        double padding;

        if (constraints.maxWidth < 140) {
          titleFontSize = 11;
          valueFontSize = isMoney ? 14 : 16;
          padding = 12;
        } else if (constraints.maxWidth < 160) {
          titleFontSize = 12;
          valueFontSize = isMoney ? 15 : 18;
          padding = 14;
        } else {
          titleFontSize = 13;
          valueFontSize = isMoney ? 16 : 20;
          padding = 16;
        }

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  Widget _shortageBox(String title, String value, String subtitle,
      Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _gradeBox(String grade, String count, String percent, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(grade,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Text(count,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(percent,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }


  Widget _performanceSummary({
    required String title,
    required String done,
  }) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRailwayBlue.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kRailwayBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceBox({
    required String title,
    required String done,
    required String cross,
    required String na,
    required Color color,
  }) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(done,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const Icon(Icons.check, color: Colors.green, size: 16),
          Text("$cross X",
              style: const TextStyle(color: Colors.red, fontSize: 12)),
          Text("$na N/A",
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStationCleaningTab() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final stations = user?.stations ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Station Cleaning Reports",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (stations.isEmpty)
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
                final allStations = snapshot.data ?? [];
                return Column(
                  children: stations.map((sid) {
                    final station = allStations.cast<Station?>().firstWhere(
                      (s) => s?.uid == sid || s?.stationCode == sid || s?.stationName == sid,
                      orElse: () => null,
                    );
                    final displayName = station?.stationName ?? sid;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.bar_chart, color: kRailwayBlue),
                        title: Text(displayName),
                        subtitle: const Text('View station cleaning report'),
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
}
