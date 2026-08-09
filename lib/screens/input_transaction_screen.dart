import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kasir_brilink/services/pdf_export_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InputTransactionScreen extends StatefulWidget {
  final int sessionId;
  final String menuTitle;
  final String trxType;

  const InputTransactionScreen({
    super.key,
    required this.sessionId,
    required this.menuTitle,
    required this.trxType,
  });

  @override
  State<InputTransactionScreen> createState() => _InputTransactionScreenState();
}

class _InputTransactionScreenState extends State<InputTransactionScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";

  int myOutletId = 1;
  int myKaryawanId = 0;
  String myKaryawanName = "";

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController nominalController = TextEditingController();
  final TextEditingController feeController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController ppobTargetController = TextEditingController();

  // ============ UNTUK QRIS MODE ============
  String qrisMode = 'bayar';
  final List<String> qrisModes = ['bayar', 'tarik_tunai'];

  // ============ UNTUK KATEGORI PENGELUARAN ============
  final TextEditingController kategoriController = TextEditingController();
  final TextEditingController kategoriDeskripsiController = TextEditingController();
  
  String? selectedPengeluaranType;
  final List<String> pengeluaranTypes = ['operasional', 'beban_toko'];
  String getPengeluaranTypeLabel(String type) {
    switch (type) {
      case 'operasional':
        return 'Pengeluaran Operasional';
      case 'beban_toko':
        return 'Pengeluaran Beban Toko';
      default:
        return type;
    }
  }
  
  String? selectedKategoriId;
  String? selectedKategoriName;
  List<dynamic> kategoriList = [];
  bool isLoadingKategori = false;
  bool isAddingKategori = false;
  bool isDeletingKategori = false;

  // ============ UNTUK TAB PIUTANG / HUTANG ============
  int _selectedTabIndex = 0;

  // ============ UNTUK PIUTANG ADMIN ============
  List<dynamic> piutangAdminList = [];
  List<dynamic> uniquePeminjamList = [];
  bool isLoadingPiutangAdmin = false;
  String? selectedPeminjam;
  String? selectedPiutangId;
  Map<String, dynamic>? selectedPiutangData;
  double totalPiutang = 0;
  double sisaPiutang = 0;
  List<dynamic> selectedPeminjamPiutangList = [];

  bool isBulkPiutang = false;
  double totalSisaPiutang = 0;
  List<dynamic> selectedPiutangBulkList = [];

  // ============ UNTUK HUTANG ADMIN ============
  List<dynamic> hutangAdminList = [];
  List<dynamic> uniquePeminjamHutangList = [];
  bool isLoadingHutangAdmin = false;
  String? selectedPeminjamHutang;
  String? selectedHutangId;
  Map<String, dynamic>? selectedHutangData;
  double totalHutang = 0;
  double sisaHutang = 0;

  bool isBulkHutang = false;
  double totalSisaHutang = 0;
  List<dynamic> selectedHutangBulkList = [];

  // ============ UNTUK TOPUP E-WALLET ============
  String? selectedTopupAccountId;
  double currentTopupBalance = 0;

  // ============ UNTUK METODE PEMBAYARAN ============
  String selectedMetode = 'cash';

  // ============ UNTUK SETORAN BRILINK ============
  String? setoranBrilinkMode = 'pelanggan';
  final List<String> setoranBrilinkModes = ['pelanggan', 'topup', 'pindah_saldo'];
  String? selectedTopupSourceAccountId;
  double topupSourceBalance = 0;
  bool isTransferSetoranKeOutletLain = false;
  String? selectedSetoranTargetOutletId;
  String? selectedSetoranDestinationAccountId;
  List<dynamic> setoranOutletOptions = [];
  List<dynamic> setoranTargetAccountsOptions = [];
  bool isLoadingSetoranOutlets = false;
  bool isLoadingSetoranTargetAccounts = false;
  double setoranDestinationBalance = 0;
  bool tandaiPengeluaran = false;

  bool _isPiutangLunas(Map<String, dynamic> piutang) {
    String status = piutang['status']?.toString().toLowerCase() ?? '';
    double sisa = double.tryParse(piutang['sisa_hutang']?.toString() ?? '0') ?? 0;
    return status == 'lunas' || sisa <= 0;
  }

  bool _isHutangLunas(Map<String, dynamic> hutang) {
    String status = hutang['status']?.toString().toLowerCase() ?? '';
    double sisa = double.tryParse(hutang['sisa_hutang']?.toString() ?? '0') ?? 0;
    return status == 'lunas' || sisa <= 0;
  }

  // ============ UNTUK MEMBUAT PIUTANG BARU ============
  final TextEditingController namaPiutangController = TextEditingController();
  final TextEditingController namaPeminjamController = TextEditingController();
  final TextEditingController nominalPiutangController = TextEditingController();
  final TextEditingController keteranganPiutangController = TextEditingController();
  DateTime? selectedJatuhTempo;
  bool isCreatingPiutang = false;
  String? selectedPiutangSourceAccountId;
  double piutangSourceBalance = 0;

  // ============ UNTUK MEMBUAT HUTANG BARU ============
  final TextEditingController namaHutangController = TextEditingController();
  final TextEditingController namaPeminjamHutangController = TextEditingController();
  final TextEditingController nominalHutangController = TextEditingController();
  final TextEditingController keteranganHutangController = TextEditingController();
  DateTime? selectedJatuhTempoHutang;
  bool isCreatingHutang = false;
  String? selectedHutangDestinationAccountId;
  double hutangDestinationBalance = 0;

  bool isOutletPusat = false;

  List<Map<String, dynamic>> peminjamDropdownList = [];
  List<Map<String, dynamic>> krediturDropdownList = [];
  bool isLoadingPeminjamDropdown = false;
  bool isLoadingKrediturDropdown = false;
  String? selectedPeminjamDropdownId;
  String? selectedPeminjamDropdownName;
  String? selectedKrediturDropdownId;
  String? selectedKrediturDropdownName;

  List<dynamic> dropdownOptions = [];
  List<dynamic> outletOptions = [];
  List<dynamic> targetOutletAccountsOptions = [];
  List<dynamic> karyawanList = [];

  String? selectedSourceAccountId;
  String? selectedDestinationAccountId;
  String? selectedTargetOutletId;
  int? selectedKaryawanId;

  double currentSourceBalance = 0;
  double currentDestinationBalance = 0;
  double cashLaciCurrent = 0;

  double targetOutletCashBalance = 0;
  bool isLoadingTargetOutletCash = false;

  bool isLoadingAccounts = false;
  bool isLoadingOutlets = false;
  bool isLoadingTargetAccounts = false;
  bool isLoadingKaryawan = false;
  bool isSubmitting = false;
  bool isTransferKeOutletLain = false;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  @override
  void initState() {
    super.initState();
    loadOutletSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dropdownOptions.isEmpty) {
        fetchAccountsData();
      }
    });
  }

  @override
  void dispose() {
    customerNameController.dispose();
    nominalController.dispose();
    feeController.dispose();
    descController.dispose();
    ppobTargetController.dispose();
    kategoriController.dispose();
    kategoriDeskripsiController.dispose();
    namaPiutangController.dispose();
    namaPeminjamController.dispose();
    nominalPiutangController.dispose();
    keteranganPiutangController.dispose();
    namaHutangController.dispose();
    namaPeminjamHutangController.dispose();
    nominalHutangController.dispose();
    keteranganHutangController.dispose();
    super.dispose();
  }

  Future<void> checkOutletPusat() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/check_outlet_pusat.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          isOutletPusat = data['is_pusat'] ?? false;
        });
      }
    } catch (e) {
      print("Error check outlet pusat: $e");
    }
  }

  Future<void> fetchPeminjamDropdown() async {
    setState(() => isLoadingPeminjamDropdown = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_peminjam.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          peminjamDropdownList = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      print("Error fetch peminjam dropdown: $e");
    } finally {
      setState(() => isLoadingPeminjamDropdown = false);
    }
  }

  // ============ FETCH KREDITUR UNTUK DROPDOWN ============
  Future<void> fetchKrediturDropdown() async {
    setState(() => isLoadingKrediturDropdown = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_kreditur.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          krediturDropdownList = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      print("Error fetch kreditur dropdown: $e");
    } finally {
      setState(() => isLoadingKrediturDropdown = false);
    }
  }

  Future<void> loadOutletSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id') ?? 0;
      myKaryawanName = prefs.getString('nama_karyawan') ?? "Kasir";
    });

    await checkOutletPusat();
    await fetchPeminjamDropdown();
    await fetchKrediturDropdown();
    await fetchKaryawan();
    
    if (widget.trxType == 'bayar piutang') {
      await fetchPiutangAdmin();
      await fetchHutangAdmin();
    }
    
    if (widget.trxType == 'pengeluaran operasional') {
      selectedPengeluaranType = 'operasional';
      await fetchKategoriPengeluaran();
    }
    
    if (widget.trxType == 'pindah kas' || widget.trxType == 'pindah saldo' || widget.trxType == 'setoran brilink') {
      await fetchOutletsData();
    }

    if (widget.trxType == 'pindah kas') {
      selectedSourceAccountId = "cash_laci";
      await fetchAccountsData();
    } else if (widget.trxType.contains('tarik tunai')) {
      selectedSourceAccountId = "cash_laci";
      await fetchAccountsData();
    } else if (widget.trxType == 'qris') {
      selectedSourceAccountId = null;
      await fetchAccountsData();
    } else if (widget.trxType == 'setoran brilink') {
      await fetchAccountsData();
      setoranBrilinkMode = 'pelanggan';
      tandaiPengeluaran = false;
    } else {
      await fetchAccountsData();
    }
  }

  // ============ FETCH HUTANG ADMIN ============
  Future<void> fetchHutangAdmin() async {
    setState(() => isLoadingHutangAdmin = true);
    try {
      // ============ JANGAN KIRIM PARAMETER STATUS ============
      // Hapus parameter status agar semua data terambil
      final response = await http.get(
        Uri.parse("$baseUrl/get_hutang_admin_for_kasir.php"), // Tanpa parameter
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        
        // ============ SIMPAN SEMUA DATA (TERMASUK YANG LUNAS) ============
        setState(() {
          hutangAdminList = list;
          
          // Buat map peminjam dari SEMUA data (termasuk lunas)
          Map<String, List<dynamic>> peminjamMap = {};
          for (var item in list) {
            String namaPeminjam = item['nama_peminjam'] ?? 'Unknown';
            if (!peminjamMap.containsKey(namaPeminjam)) {
              peminjamMap[namaPeminjam] = [];
            }
            peminjamMap[namaPeminjam]!.add(item);
          }
          uniquePeminjamHutangList = peminjamMap.keys.toList();
        });
        
        // ============ REFRESH SELECTED PEMINJAM ============
        if (selectedPeminjamHutang != null) {
          _updateSelectedHutangTotal(selectedPeminjamHutang!);
        }
      }
    } catch (e) {
      print("Gagal fetch hutang admin: $e");
    } finally {
      setState(() => isLoadingHutangAdmin = false);
    }
  }

  void _updateSelectedHutangTotal(String peminjam) {
    // ============ AMBIL SEMUA HUTANG DARI PEMINJAM (TERMASUK LUNAS) ============
    var allHutangList = hutangAdminList.where((item) => 
      item['nama_peminjam'] == peminjam
    ).toList();
    
    // ============ HITUNG TOTAL NOMINAL SEMUA HUTANG ============
    double totalNominalAll = 0;
    for (var item in allHutangList) {
      totalNominalAll += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
    }
    
    // ============ AMBIL HUTANG YANG BELUM LUNAS ============
    var hutangBelumLunas = hutangAdminList.where((item) => 
      item['nama_peminjam'] == peminjam && 
      item['status'] != 'lunas' &&
      (double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0) > 0
    ).toList();
    
    setState(() {
      selectedHutangBulkList = hutangBelumLunas;
      
      double totalSisa = 0;
      for (var item in hutangBelumLunas) {
        totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
      }
      
      totalHutang = totalNominalAll;  // TOTAL SEMUA HUTANG
      sisaHutang = totalSisa;          // SISA YANG BELUM DIBAYAR
      
      // ============ PERBAIKAN: nominalController diisi dengan SISA HUTANG ============
      nominalController.text = _formatIdr(sisaHutang);  // <-- ISI DENGAN SISA HUTANG
      
      if (hutangBelumLunas.isNotEmpty) {
        selectedHutangData = hutangBelumLunas.first;
        selectedHutangId = hutangBelumLunas.first['id'].toString();
      }
    });
  }

  void selectPeminjamHutang(String? peminjam) {
    setState(() {
      selectedPeminjamHutang = peminjam;
      selectedHutangId = null;
      selectedHutangData = null;
      totalHutang = 0;
      sisaHutang = 0;
      nominalController.clear();
      selectedHutangBulkList = [];
      
      if (peminjam != null) {
        // ============ AMBIL SEMUA HUTANG DARI PEMINJAM (TERMASUK YANG SUDAH LUNAS) ============
        var allHutangList = hutangAdminList.where((item) => 
          item['nama_peminjam'] == peminjam
        ).toList();
        
        // ============ HITUNG TOTAL NOMINAL SEMUA HUTANG ============
        double totalNominalAll = 0;
        for (var item in allHutangList) {
          totalNominalAll += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
        }
        
        // ============ AMBIL HUTANG YANG BELUM LUNAS UNTUK DIBAYAR ============
        var hutangBelumLunas = hutangAdminList.where((item) => 
          item['nama_peminjam'] == peminjam && 
          item['status'] != 'lunas' &&
          (double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0) > 0
        ).toList();
        
        selectedHutangBulkList = hutangBelumLunas;

        // ============ HITUNG TOTAL SISA HUTANG (BELUM LUNAS) ============
        double totalSisa = 0;
        for (var item in hutangBelumLunas) {
          totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
        }

        // ============ SET TOTAL DAN SISA ============
        totalHutang = totalNominalAll;  // TOTAL SEMUA HUTANG (termasuk lunas)
        sisaHutang = totalSisa;          // SISA YANG BELUM DIBAYAR
        
        // ============ PERBAIKAN: nominalController diisi dengan SISA HUTANG ============
        nominalController.text = _formatIdr(sisaHutang);  // <-- ISI DENGAN SISA HUTANG
        
        if (hutangBelumLunas.isNotEmpty) {
          selectedHutangData = hutangBelumLunas.first;
          selectedHutangId = hutangBelumLunas.first['id'].toString();
        }
      }
    });
  }

  void selectHutang(Map<String, dynamic> hutang) {
    setState(() {
      selectedHutangData = hutang;
      selectedHutangId = hutang['id'].toString();
      totalHutang = double.tryParse(hutang['nominal']?.toString() ?? '0') ?? 0;
      sisaHutang = double.tryParse(hutang['sisa_hutang']?.toString() ?? '0') ?? 0;
      nominalController.text = _formatIdr(sisaHutang);
    });
  }

  // ============ FUNGSI MEMBUAT HUTANG BARU ============
  Future<void> createHutangBaru() async {
    if (namaHutangController.text.trim().isEmpty) {
      showSnackBar("Masukkan nama hutang!", isError: true);
      return;
    }
    
    // ============ AMBIL NAMA KREDITUR DARI DROPDOWN ATAU INPUT BARU ============
    String namaKreditur = '';
    if (selectedKrediturDropdownId != null && selectedKrediturDropdownId!.isNotEmpty) {
      final selected = krediturDropdownList.firstWhere(
        (k) => k['id'].toString() == selectedKrediturDropdownId,
        orElse: () => {'nama_kreditur': ''},
      );
      namaKreditur = selected['nama_kreditur'] ?? '';
    }
    
    // Jika tidak ada yang dipilih dari dropdown, gunakan dari TextField (buat baru)
    if (namaKreditur.isEmpty) {
      namaKreditur = namaPeminjamHutangController.text.trim();
    }
    
    if (namaKreditur.isEmpty) {
      showSnackBar("Pilih atau masukkan nama kreditur terlebih dahulu!", isError: true);
      return;
    }
    
    if (nominalHutangController.text.isEmpty) {
      showSnackBar("Masukkan nominal hutang!", isError: true);
      return;
    }
    
    String cleanNominal = nominalHutangController.text.replaceAll('.', '');
    double nominal = double.tryParse(cleanNominal) ?? 0;
    if (nominal <= 0) {
      showSnackBar("Nominal harus lebih dari 0!", isError: true);
      return;
    }
    
    // VALIDASI TUJUAN PENYIMPANAN
    if (selectedHutangDestinationAccountId == null || selectedHutangDestinationAccountId!.isEmpty) {
      showSnackBar("Pilih tujuan penyimpanan saldo terlebih dahulu!", isError: true);
      return;
    }
    
    setState(() => isCreatingHutang = true);
    
    try {
      // ============ TENTUKAN DESTINATION ACCOUNT ID ============
      String? destinationAccountId;
      if (selectedHutangDestinationAccountId == 'cash_laci' || selectedHutangDestinationAccountId == '0') {
        destinationAccountId = 'cash_laci';
      } else {
        destinationAccountId = selectedHutangDestinationAccountId;
      }
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_hutang_admin.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "nama_hutang": namaHutangController.text.trim(),
          "nama_peminjam": namaKreditur,
          "nominal": nominal,
          "tanggal_jatuh_tempo": selectedJatuhTempoHutang != null 
              ? DateFormat('yyyy-MM-dd').format(selectedJatuhTempoHutang!)
              : null,
          "keterangan": keteranganHutangController.text.trim(),
          "outlet_id": myOutletId,
          "destination_account_id": destinationAccountId,
          "admin_id": selectedKaryawanId,
          "karyawan_id": selectedKaryawanId, // <-- TAMBAHKAN INI
          "session_id": widget.sessionId,
          "user_outlet_id": myOutletId,
          "trx_type": "buat hutang",
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("✅ Hutang baru berhasil ditambahkan!");
        
        // ============ RESET FORM ============
        namaHutangController.clear();
        namaPeminjamHutangController.clear();
        nominalHutangController.clear();
        keteranganHutangController.clear();
        setState(() {
          selectedJatuhTempoHutang = null;
          selectedPeminjamHutang = null;
          selectedHutangData = null;
          selectedHutangId = null;
          totalHutang = 0;
          sisaHutang = 0;
          nominalController.clear();
          selectedHutangDestinationAccountId = null;
          hutangDestinationBalance = 0;
          selectedKrediturDropdownId = null;
          selectedKrediturDropdownName = null;
        });
        
        Navigator.pop(context);
        
        // ============ REFRESH SEMUA DATA ============
        await fetchHutangAdmin();
        await fetchAccountsData();
        await fetchKrediturDropdown();
        
      } else {
        showSnackBar(data['message'] ?? "Gagal menambahkan hutang", isError: true);
      }
    } catch (e) {
      showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isCreatingHutang = false);
    }
  }


  // ============ PROSES BAYAR PIUTANG LANGSUNG ============
  Future<void> _prosesBayarPiutang() async {
    if (selectedPeminjam == null || selectedPeminjamPiutangList.isEmpty) {
      showSnackBar("Tidak ada piutang yang bisa dibayar!", isError: true);
      return;
    }
    
    // HITUNG TOTAL SISA
    double totalSisa = 0;
    for (var p in selectedPeminjamPiutangList) {
      totalSisa += double.tryParse(p['sisa_hutang']?.toString() ?? '0') ?? 0;
    }
    
    if (totalSisa <= 0) {
      showSnackBar("Semua piutang sudah lunas!", isError: true);
      return;
    }
    
    // ============ VALIDASI NOMINAL ============
    String cleanNominal = nominalController.text.replaceAll('.', '');
    double nominal = double.tryParse(cleanNominal) ?? 0;
    
    if (nominal <= 0) {
      showSnackBar("Masukkan nominal pembayaran!", isError: true);
      return;
    }
    if (nominal > totalSisa) {
      showSnackBar("Nominal melebihi total sisa! Maks: Rp ${_formatIdr(totalSisa)}", isError: true);
      return;
    }
    if (selectedDestinationAccountId == null) {
      showSnackBar("Pilih tujuan penyimpanan saldo!", isError: true);
      return;
    }
    if (selectedMetode.isEmpty) {
      showSnackBar("Pilih metode pembayaran!", isError: true);
      return;
    }
    
    // ============ TAMPILKAN LOADING ============
    setState(() => isSubmitting = true);
    
    try {
      // ============ AMBIL ID PIUTANG ============
      List<int> piutangIds = selectedPeminjamPiutangList.map((p) => int.parse(p['id'].toString())).toList();
      String namaPeminjam = selectedPeminjam ?? '';

      // ============ TENTUKAN DESTINATION ACCOUNT ID ============
      String? finalDestinationId;
      if (selectedDestinationAccountId == 'cash_laci' || selectedDestinationAccountId == '0') {
        // Jika memilih Kas Laci, kirim NULL
        finalDestinationId = null;
      } else {
        finalDestinationId = selectedDestinationAccountId;
      }
      
      // ============ KIRIM KE save_transaction.php ============
      Map<String, dynamic> payload = {
        "session_id": widget.sessionId,
        "outlet_id": myOutletId,
        "trx_type": 'bayar piutang',
        "customer_name": namaPeminjam,
        "nominal_source": 0,
        "nominal_destination": nominal,
        "fee": 0,
        "description": "Bayar Piutang Bulk - $namaPeminjam (${piutangIds.length} piutang) - Rp ${_formatIdr(nominal)}",
        "source_account_id": null,
        "destination_account_id": finalDestinationId, // <-- PERUBAHAN DI SINI
        "target_outlet_id": null,
        "karyawan_id": selectedKaryawanId,
        "metode_pembayaran": selectedMetode,
        "piutang_ids": piutangIds,
        "piutang_bulk": true,
      };
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_transaction.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      
      final data = json.decode(response.body);
      print("📥 Response: $data");
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? '✅ Pembayaran piutang berhasil!');
        
        // ============ RESET STATE ============
        _resetPiutangState();
        
        // ============ REFRESH SEMUA DATA ============
        await fetchPiutangAdmin();      // Refresh daftar piutang
        await fetchAccountsData();      // Refresh saldo akun
        
        // ============ CLOSE SCREEN ============
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        
      } else {
        showSnackBar(data['message'] ?? '❌ Gagal membayar', isError: true);
      }
    } catch (e) {
      print("❌ Error: $e");
      showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _resetPiutangState() {
    setState(() {
      selectedPeminjam = null;
      selectedPiutangData = null;
      selectedPiutangId = null;
      sisaPiutang = 0;
      totalPiutang = 0;
      nominalController.clear();
      descController.clear();
      selectedPeminjamPiutangList = [];
    });
  }

  // ============ PROSES BAYAR HUTANG ============
  Future<void> _prosesBayarHutang() async {
    if (selectedPeminjamHutang == null || selectedHutangBulkList.isEmpty) {
      showSnackBar("Silakan pilih peminjam hutang terlebih dahulu!", isError: true);
      return;
    }
    if (selectedSourceAccountId == null) {
      showSnackBar("Pilih sumber dana!", isError: true);
      return;
    }
    
    // HITUNG TOTAL SISA
    double totalSisa = 0;
    for (var item in selectedHutangBulkList) {
      totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
    }
    
    String cleanNominal = nominalController.text.replaceAll('.', '');
    double nominal = double.tryParse(cleanNominal) ?? 0;
    
    if (nominal <= 0) {
      showSnackBar("Masukkan nominal pembayaran!", isError: true);
      return;
    }
    if (nominal > totalSisa) {
      showSnackBar("Nominal melebihi total sisa hutang! Maks: Rp ${_formatIdr(totalSisa)}", isError: true);
      return;
    }
    if (nominal > currentSourceBalance) {
      showSnackBar("Saldo tidak cukup! Saldo tersedia: Rp ${_formatIdr(currentSourceBalance)}", isError: true);
      return;
    }
    if (selectedMetode.isEmpty) {
      showSnackBar("Pilih metode pembayaran!", isError: true);
      return;
    }
    
    // ============ AMBIL ID HUTANG ============
    List<int> hutangIds = selectedHutangBulkList.map((item) => int.parse(item['id'].toString())).toList();
    String namaPeminjam = selectedPeminjamHutang ?? '';
    
    // ============ TENTUKAN SOURCE ACCOUNT ID ============
    String? finalSourceId;
    if (selectedSourceAccountId == 'cash_laci' || selectedSourceAccountId == '0') {
      // Jika memilih Kas Laci, kirim NULL
      finalSourceId = null;
    } else {
      finalSourceId = selectedSourceAccountId;
    }
    
    setState(() => isSubmitting = true);
    
    try {
      // ============ KIRIM KE API BAYAR HUTANG BULK ============
      Map<String, dynamic> payload = {
        "session_id": widget.sessionId,
        "outlet_id": myOutletId,
        "trx_type": 'bayar hutang',
        "customer_name": namaPeminjam,
        "nominal_source": nominal,
        "nominal_destination": 0,
        "fee": 0,
        "description": "Bayar Hutang Bulk - $namaPeminjam (${hutangIds.length} hutang) - Rp ${_formatIdr(nominal)}",
        "source_account_id": finalSourceId, // <-- PERUBAHAN DI SINI
        "destination_account_id": null,
        "target_outlet_id": null,
        "karyawan_id": selectedKaryawanId,
        "metode_pembayaran": selectedMetode,
        "hutang_ids": hutangIds,
        "hutang_bulk": true,
        "is_cash_laci": selectedSourceAccountId == 'cash_laci' || selectedSourceAccountId == '0', // Tandai jika Kas Laci
      };
      
      print("📤 Bayar Hutang Bulk Payload: $payload");
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_transaction.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      
      final data = json.decode(response.body);
      print("📥 Response: $data");
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? '✅ Pembayaran hutang bulk berhasil!');
        
        // ============ REFRESH DATA ============
        await fetchHutangAdmin();       // Refresh daftar hutang
        await fetchAccountsData();      // Refresh saldo akun
        
        // ============ RESET STATE ============
        setState(() {
          selectedPeminjamHutang = null;
          selectedHutangData = null;
          selectedHutangId = null;
          totalHutang = 0;
          sisaHutang = 0;
          selectedHutangBulkList = [];
          nominalController.clear();
          descController.clear();
          selectedSourceAccountId = null;
          currentSourceBalance = 0;
        });
        
        // ============ CLOSE SCREEN ============
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
        
      } else {
        showSnackBar(data['message'] ?? '❌ Gagal membayar hutang', isError: true);
      }
    } catch (e) {
      print("❌ Error: $e");
      showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> fetchKategoriPengeluaran() async {
    setState(() => isLoadingKategori = true);
    try {
      String url = "$baseUrl/get_kategori_pengeluaran.php";
      if (selectedPengeluaranType != null) {
        url += "?jenis=$selectedPengeluaranType";
      }
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          kategoriList = data['data'] ?? [];
          if (kategoriList.isNotEmpty) {
            selectedKategoriId = kategoriList[0]['id'].toString();
            selectedKategoriName = kategoriList[0]['nama_kategori'].toString();
          }
        });
      }
    } catch (e) {
      print("Gagal mengambil kategori pengeluaran: $e");
    } finally {
      setState(() => isLoadingKategori = false);
    }
  }

  Future<void> _exportPdfTagihanPiutang() async {
    if (selectedPeminjam == null || selectedPeminjam!.isEmpty) {
      showSnackBar("Pilih peminjam terlebih dahulu", isError: true);
      return;
    }

    // Filter piutang yang belum lunas
    var tagihanList = piutangAdminList.where((p) {
      String status = p['status'] ?? '';
      double sisa = double.tryParse(p['sisa_hutang']?.toString() ?? '0') ?? 0;
      return p['nama_peminjam'] == selectedPeminjam && status != 'lunas' && sisa > 0;
    }).toList();

    if (tagihanList.isEmpty) {
      showSnackBar("Tidak ada tagihan yang belum lunas untuk peminjam ini", isError: true);
      return;
    }

    // Hitung total
    double totalPiutang = 0;
    double totalSisa = 0;
    for (var item in tagihanList) {
      totalPiutang += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
      totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
    }

    String outletName = "Barokah Sport Outlet $myOutletId";
    String tanggalCetak = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());
    String fileName = "Tagihan_${selectedPeminjam?.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf";

    try {
      // Tampilkan loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final pdfBytes = await PdfExportService.generateTagihanPdf(
        peminjamName: selectedPeminjam ?? 'Unknown',
        piutangList: tagihanList,
        totalPiutang: totalPiutang,
        totalSisa: totalSisa,
        outletName: outletName,
        tanggalCetak: tanggalCetak,
        formatIdr: (dynamic number) {
          try {
            double value = double.tryParse(number.toString()) ?? 0;
            String str = value.toInt().toString();
            RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
            return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
          } catch (e) {
            return '0';
          }
        },
      );

      // Tutup loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Download PDF
      await PdfExportService.downloadPdf(pdfBytes, fileName);

      showSnackBar("✅ PDF berhasil di download");
      
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      showSnackBar("❌ Error export PDF: $e", isError: true);
    }
  }

  Future<void> fetchPiutangAdmin() async {
    setState(() => isLoadingPiutangAdmin = true);
    try {
      // ============ PASTIKAN TIDAK ADA PARAMETER STATUS ============
      final response = await http.get(
        Uri.parse("$baseUrl/get_piutang_admin_for_kasir.php"), // TANPA PARAMETER
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        
        // ============ CETAK UNTUK DEBUG ============
        print("📊 Total data dari API: ${list.length}");
        for (var item in list) {
          print("📊 ${item['nama_peminjam']} - ${item['nominal']} - ${item['status']}");
        }
        
        // ============ SIMPAN SEMUA DATA (TERMASUK YANG LUNAS) ============
        setState(() {
          piutangAdminList = list;
          
          // ============ PERBAIKAN: HANYA TAMPILKAN PEMINJAM YANG MEMILIKI PIUTANG BELUM LUNAS ============
          // Buat map peminjam dari data yang BELUM LUNAS saja
          Map<String, List<dynamic>> peminjamMap = {};
          for (var item in list) {
            // Cek apakah piutang ini belum lunas
            String status = item['status']?.toString().toLowerCase() ?? '';
            double sisa = double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
            
            // Hanya tampilkan jika status != 'lunas' DAN sisa > 0
            if (status != 'lunas' && sisa > 0) {
              String namaPeminjam = item['nama_peminjam'] ?? 'Unknown';
              if (!peminjamMap.containsKey(namaPeminjam)) {
                peminjamMap[namaPeminjam] = [];
              }
              peminjamMap[namaPeminjam]!.add(item);
            }
          }
          uniquePeminjamList = peminjamMap.keys.toList();
          print("📊 Peminjam dengan piutang belum lunas: ${uniquePeminjamList.length}");
        });
        
        // ============ REFRESH SELECTED PEMINJAM ============
        if (selectedPeminjam != null) {
          // Cek apakah selectedPeminjam masih ada di uniquePeminjamList
          if (uniquePeminjamList.contains(selectedPeminjam)) {
            _updateSelectedPiutangTotal(selectedPeminjam!);
          } else {
            // Jika tidak ada, reset selection
            setState(() {
              selectedPeminjam = null;
              selectedPiutangData = null;
              selectedPiutangId = null;
              totalPiutang = 0;
              sisaPiutang = 0;
              nominalController.clear();
              selectedPeminjamPiutangList = [];
            });
          }
        }
      }
    } catch (e) {
      print("Gagal fetch piutang admin: $e");
    } finally {
      setState(() => isLoadingPiutangAdmin = false);
    }
  }

  void _updateSelectedPiutangTotal(String peminjam) {
    // ============ AMBIL SEMUA PIUTANG DARI PEMINJAM (TERMASUK LUNAS) ============
    var allPiutangList = piutangAdminList.where((item) => 
      item['nama_peminjam'] == peminjam
    ).toList();
    
    // ============ HITUNG TOTAL NOMINAL SEMUA PIUTANG ============
    double totalNominalAll = 0;
    for (var item in allPiutangList) {
      totalNominalAll += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
    }
    
    // ============ AMBIL PIUTANG YANG BELUM LUNAS ============
    var piutangBelumLunas = piutangAdminList.where((item) => 
      item['nama_peminjam'] == peminjam && 
      item['status'] != 'lunas' &&
      (double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0) > 0
    ).toList();
    
    setState(() {
      selectedPeminjamPiutangList = piutangBelumLunas;
      
      double totalSisa = 0;
      for (var item in piutangBelumLunas) {
        totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
      }
      
      totalPiutang = totalNominalAll;  // TOTAL SEMUA PIUTANG
      sisaPiutang = totalSisa;          // SISA YANG BELUM DIBAYAR
      
      // ============ ISI DENGAN SISA PIUTANG ============
      nominalController.text = _formatIdr(sisaPiutang);
      
      if (piutangBelumLunas.isNotEmpty) {
        selectedPiutangData = piutangBelumLunas.first;
        selectedPiutangId = piutangBelumLunas.first['id'].toString();
      }
    });
  }

  void selectPeminjam(String? peminjam) {
    setState(() {
      selectedPeminjam = peminjam;
      selectedPiutangId = null;
      selectedPiutangData = null;
      totalPiutang = 0;
      sisaPiutang = 0;
      nominalController.clear();
      selectedPeminjamPiutangList = [];
      
      if (peminjam != null) {
        // ============ AMBIL SEMUA PIUTANG DARI PEMINJAM (TERMASUK YANG SUDAH LUNAS) ============
        var allPiutangList = piutangAdminList.where((item) => 
          item['nama_peminjam'] == peminjam
        ).toList();
        
        // ============ HITUNG TOTAL NOMINAL SEMUA PIUTANG ============
        double totalNominalAll = 0;
        for (var item in allPiutangList) {
          totalNominalAll += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
        }
        
        // ============ AMBIL PIUTANG YANG BELUM LUNAS UNTUK DIBAYAR ============
        var piutangBelumLunas = piutangAdminList.where((item) => 
          item['nama_peminjam'] == peminjam && 
          item['status'] != 'lunas' &&
          (double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0) > 0
        ).toList();
        
        selectedPeminjamPiutangList = piutangBelumLunas;

        // ============ HITUNG TOTAL SISA PIUTANG (BELUM LUNAS) ============
        double totalSisa = 0;
        for (var item in piutangBelumLunas) {
          totalSisa += double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;
        }

        // ============ SET TOTAL DAN SISA ============
        totalPiutang = totalNominalAll;  // TOTAL SEMUA PIUTANG (termasuk lunas)
        sisaPiutang = totalSisa;          // SISA YANG BELUM DIBAYAR
        
        // ============ ISI DENGAN SISA PIUTANG ============
        nominalController.text = _formatIdr(sisaPiutang);
        
        if (piutangBelumLunas.isNotEmpty) {
          selectedPiutangData = piutangBelumLunas.first;
          selectedPiutangId = piutangBelumLunas.first['id'].toString();
        }
      }
    });
  }

  void selectSpecificPiutang(Map<String, dynamic> piutang) {
    setState(() {
      selectedPiutangData = piutang;
      selectedPiutangId = piutang['id'].toString();
      totalPiutang = double.tryParse(piutang['nominal']?.toString() ?? '0') ?? 0;
      sisaPiutang = double.tryParse(piutang['sisa_hutang']?.toString() ?? '0') ?? 0;
      nominalController.text = _formatIdr(sisaPiutang);
    });
  }

  void selectPiutang(Map<String, dynamic> piutang) {
    setState(() {
      selectedPiutangData = piutang;
      selectedPiutangId = piutang['id'].toString();
      totalPiutang = double.tryParse(piutang['nominal']?.toString() ?? '0') ?? 0;
      sisaPiutang = double.tryParse(piutang['sisa_hutang']?.toString() ?? '0') ?? 0;
      nominalController.text = _formatIdr(sisaPiutang);
    });
  }

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : primaryBlue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> addKategoriPengeluaran() async {
    if (kategoriController.text.trim().isEmpty) {
      showSnackBar("Masukkan nama kategori!", isError: true);
      return;
    }

    setState(() => isAddingKategori = true);
    
    try {
      final payload = {
        "nama_kategori": kategoriController.text.trim(),
        "deskripsi": kategoriDeskripsiController.text.trim(),
        "jenis": selectedPengeluaranType ?? 'operasional',
      };
      
      final response = await http.post(
        Uri.parse("$baseUrl/add_kategori_pengeluaran.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("Kategori berhasil ditambahkan!");
        kategoriController.clear();
        kategoriDeskripsiController.clear();
        await fetchKategoriPengeluaran();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        showSnackBar(data['message'] ?? "Gagal menambah kategori", isError: true);
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e", isError: true);
    } finally {
      setState(() => isAddingKategori = false);
    }
  }

  void showAddKategoriDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_rounded, color: primaryBlue, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              "Tambah Kategori ${getPengeluaranTypeLabel(selectedPengeluaranType ?? 'operasional')}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kategoriController,
                decoration: InputDecoration(
                  labelText: "Nama Kategori",
                  hintText: "Contoh: Belanja Bulanan",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kategoriDeskripsiController,
                decoration: InputDecoration(
                  labelText: "Deskripsi (Opsional)",
                  hintText: "Keterangan tambahan",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("BATAL", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: isAddingKategori ? null : addKategoriPengeluaran,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: isAddingKategori
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("TAMBAH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteKategoriPengeluaran(String kategoriId, String kategoriName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Hapus Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Apakah Anda yakin ingin menghapus kategori?",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_rounded, color: primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    kategoriName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "⚠️ Kategori yang dihapus tidak dapat dikembalikan.",
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
            Text(
              "Pastikan tidak ada transaksi yang menggunakan kategori ini.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("BATAL", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "HAPUS",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;

    setState(() => isDeletingKategori = true);
    
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_kategori_pengeluaran.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "kategori_id": int.parse(kategoriId),
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Kategori berhasil dihapus");
        await fetchKategoriPengeluaran();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus kategori", isError: true);
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e", isError: true);
    } finally {
      setState(() => isDeletingKategori = false);
    }
  }

  Future<void> fetchKaryawan() async {
    setState(() => isLoadingKaryawan = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_karyawan.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          karyawanList = data['data'] ?? [];
          
          if (myKaryawanId > 0 && karyawanList.isNotEmpty) {
            var found = karyawanList.firstWhere(
              (k) => int.parse(k['id'].toString()) == myKaryawanId,
              orElse: () => null,
            );
            
            if (found != null) {
              selectedKaryawanId = myKaryawanId;
              myKaryawanName = found['nama_karyawan']?.toString() ?? "Kasir";
            } else {
              selectedKaryawanId = int.parse(karyawanList[0]['id'].toString());
              myKaryawanName = karyawanList[0]['nama_karyawan']?.toString() ?? "Kasir";
            }
          } else if (karyawanList.isNotEmpty) {
            selectedKaryawanId = int.parse(karyawanList[0]['id'].toString());
            myKaryawanName = karyawanList[0]['nama_karyawan']?.toString() ?? "Kasir";
          }
        });
      }
    } catch (e) {
      print("Gagal mengambil data karyawan: $e");
    } finally {
      setState(() => isLoadingKaryawan = false);
    }
  }

  Future<void> fetchOutletsData() async {
    setState(() => isLoadingOutlets = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_outlets.php"));
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          outletOptions = (data['data'] as List)
              .where((element) => element['id'].toString() != myOutletId.toString())
              .toList();
          setoranOutletOptions = data['data'] as List;
        });
      }
    } catch (e) {
      print("Gagal memuat master data outlet: $e");
    } finally {
      setState(() => isLoadingOutlets = false);
    }
  }

  Future<void> fetchTargetOutletAccountsData(String targetOutletId) async {
    setState(() {
      isLoadingTargetAccounts = true;
      targetOutletAccountsOptions.clear();
      selectedDestinationAccountId = null;
    });
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_accounts_by_outlet.php?outlet_id=$targetOutletId"));
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          targetOutletAccountsOptions = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Gagal mengambil rekening target outlet: $e");
    } finally {
      setState(() => isLoadingTargetAccounts = false);
    }
  }

  Future<void> fetchSetoranTargetAccountsData(String targetOutletId) async {
    setState(() {
      isLoadingSetoranTargetAccounts = true;
      setoranTargetAccountsOptions.clear();
      selectedSetoranDestinationAccountId = null;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/get_accounts_by_outlet.php?outlet_id=$targetOutletId"));
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> accounts = data['data'] ?? [];
        List<dynamic> filteredAccounts = accounts.where((acc) {
          String category = (acc['category'] ?? '').toString().toLowerCase();
          return category == 'bank';
        }).toList();
        setState(() {
          setoranTargetAccountsOptions = filteredAccounts;
        });
      }
    } catch (e) {
      print("Gagal mengambil rekening target outlet setoran: $e");
    } finally {
      setState(() => isLoadingSetoranTargetAccounts = false);
    }
  }

  Future<void> fetchTargetOutletCashBalance(String targetOutletId) async {
    setState(() {
      isLoadingTargetOutletCash = true;
      targetOutletCashBalance = 0;
    });
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_all_balances_dashboard.php?outlet_id=$targetOutletId"));
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        var laciRaw = data['cash_laci_current'] ?? data['cash_laci'] ?? '0';
        String cleanLaci = laciRaw.toString().replaceAll(RegExp(r'[^\d.]'), '');
        double laciCurrent = double.tryParse(cleanLaci) ?? 0.0;
        setState(() {
          targetOutletCashBalance = laciCurrent;
        });
      }
    } catch (e) {
      print("Gagal mengambil kas laci target outlet: $e");
    } finally {
      setState(() => isLoadingTargetOutletCash = false);
    }
  }

  Future<void> fetchAccountsData() async {
    setState(() => isLoadingAccounts = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_all_balances_dashboard.php?outlet_id=$myOutletId"));
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        var laciRaw = data['cash_laci_current'] ?? data['cash_laci'] ?? '0';
        String cleanLaci = laciRaw.toString().replaceAll(RegExp(r'[^\d.]'), '');
        double laciCurrent = double.tryParse(cleanLaci) ?? 0.0;

        List<dynamic> bankAccounts = data['accounts'] ?? data['data'] ?? [];
        List<dynamic> builtOptions = [];

        builtOptions.add({
          "id": "cash_laci",
          "name": "Uang Kas (Laci)",
          "category": "Laci Fisik",
          "balance": laciCurrent
        });

        String menuName = widget.menuTitle.toLowerCase();
        
        bool isSetoranBrilink = widget.trxType == 'setoran brilink';
        bool isSetoranPelanggan = isSetoranBrilink && setoranBrilinkMode == 'pelanggan';
        bool isSetoranTopup = isSetoranBrilink && setoranBrilinkMode == 'topup';

        for (var bank in bankAccounts) {
          if (bank == null) continue;

          String category = bank['category']?.toString() ?? "Bank";
          String categoryLower = category.toLowerCase();

          if (isSetoranBrilink) {
            if (isSetoranPelanggan) {
              if (categoryLower != 'bank') {
                continue;
              }
            } else if (isSetoranTopup) {
              if (categoryLower == 'cash' || categoryLower == 'laci fisik') {
                continue;
              }
            } else {
              if (categoryLower == 'cash' || categoryLower == 'laci fisik') {
                continue;
              }
            }
          }

          if (widget.trxType != 'qris') {
            bool isTarikTunaiLayanan = menuName.contains('tarik tunai');
            
            if (isTarikTunaiLayanan &&
                (categoryLower == 'e-wallet' || categoryLower == 'ewallet' || categoryLower == 'qris')) {
              continue;
            }

            bool isPpobLayanan = menuName.contains('ppob');
            if (isPpobLayanan && categoryLower != 'e-wallet' && categoryLower != 'ewallet') {
              continue;
            }
          }

          var bankBalanceRaw = bank['current_balance'] ?? bank['balance'] ?? '0';
          String cleanBankBalance = bankBalanceRaw.toString().replaceAll(RegExp(r'[^\d.]'), '');
          double bankBalance = double.tryParse(cleanBankBalance) ?? 0.0;

          builtOptions.add({
            "id": bank['id']?.toString() ?? '',
            "name": bank['name']?.toString() ?? 'Tanpa Nama',
            "category": category,
            "sub_category": bank['sub_category'] ?? '-',
            "balance": bankBalance
          });
        }

        setState(() {
          cashLaciCurrent = laciCurrent;
          dropdownOptions = builtOptions;
          
          if (widget.trxType == 'pindah kas' || widget.trxType.contains('tarik tunai')) {
            currentSourceBalance = laciCurrent;
          }

          if (widget.trxType == 'qris') {
            if (qrisMode == 'tarik_tunai') {
              selectedSourceAccountId = "cash_laci";
              currentSourceBalance = laciCurrent;
            }
            
            final List<dynamic> qrisOptions = builtOptions.where((a) => a['category'].toString().toLowerCase() == 'qris').toList();
            if (qrisOptions.length == 1) {
              selectedDestinationAccountId = qrisOptions[0]['id'].toString();
              currentDestinationBalance = double.tryParse(qrisOptions[0]['balance'].toString()) ?? 0.0;
            }
          }
        });
      } else {
        showSnackBar("API merespons gagal: ${data['message'] ?? 'Tanpa pesan'}");
      }
    } catch (e) {
      print("Error Detail Parsing: $e");
      showSnackBar("Gagal memuat master data (Format Error): $e");
    } finally {
      setState(() => isLoadingAccounts = false);
    }
  }

  void updateSourceAccount(String? accountId) {
    if (accountId == null) return;
    var option = dropdownOptions.firstWhere((element) => element['id'].toString() == accountId);
    setState(() {
      selectedSourceAccountId = accountId;
      currentSourceBalance = double.tryParse(option['balance'].toString()) ?? 0;
    });
  }

  void updateDestinationAccount(String? accountId) {
    if (accountId == null) return;
    var option = dropdownOptions.firstWhere((element) => element['id'].toString() == accountId);
    setState(() {
      selectedDestinationAccountId = accountId;
      currentDestinationBalance = double.tryParse(option['balance'].toString()) ?? 0;
    });
  }

  void updateTopupAccount(String? accountId) {
    if (accountId == null) return;
    var option = dropdownOptions.firstWhere((element) => element['id'].toString() == accountId);
    setState(() {
      selectedTopupAccountId = accountId;
      currentTopupBalance = double.tryParse(option['balance'].toString()) ?? 0;
    });
  }

  List<dynamic> getEwalletOptions() {
    return dropdownOptions.where((a) => 
      a['id'] != 'cash_laci' && 
      (a['category'].toString().toLowerCase() == 'e-wallet' || 
       a['category'].toString().toLowerCase() == 'ewallet')
    ).toList();
  }

  void updateTopupSourceAccount(String? accountId) {
    if (accountId == null) return;
    var option = dropdownOptions.firstWhere((element) => element['id'].toString() == accountId);
    setState(() {
      selectedTopupSourceAccountId = accountId;
      topupSourceBalance = double.tryParse(option['balance'].toString()) ?? 0;
    });
  }

  void updateSetoranDestinationAccount(String? accountId) {
    if (accountId == null) return;
    var option = setoranTargetAccountsOptions.firstWhere((element) => element['id'].toString() == accountId);
    setState(() {
      selectedSetoranDestinationAccountId = accountId;
      setoranDestinationBalance = double.tryParse(option['balance'].toString()) ?? 0;
    });
  }

  Future<void> submitTransaction() async {
    if (selectedKaryawanId == null) {
      showSnackBar("Silakan pilih karyawan yang melakukan transaksi!");
      return;
    }

    String finalDescription = descController.text.trim();

    bool isBayarPiutang = widget.trxType == 'bayar piutang';
    bool isPengeluaranOperasional = widget.trxType == 'pengeluaran operasional';
    bool isSetoranBrilink = widget.trxType == 'setoran brilink';
    bool isQRIS = widget.trxType == 'qris';
    bool isQRISTarikTunai = isQRIS && qrisMode == 'tarik_tunai';
    bool isPPOB = widget.trxType == 'PPOB';
    bool isTopupEwallet = isPengeluaranOperasional && selectedKategoriName == 'Topup E-Wallet';
    bool isPindahKas = widget.trxType == 'pindah kas';
    bool isPindahSaldo = widget.trxType == 'pindah saldo';

    // ============ PARSING NOMINAL ============
    String cleanNominal = nominalController.text.replaceAll('.', '');
    double parsedNominal = double.tryParse(cleanNominal) ?? 0.0;

    // ============ VALIDASI PPOB ============
    if (isPPOB) {
      if (ppobTargetController.text.trim().isEmpty) {
        showSnackBar("Silakan masukkan Nomor Pelanggan / Tujuan PPOB!");
        return;
      }
      if (selectedSourceAccountId == null) {
        showSnackBar("Silakan pilih sumber dana E-Wallet!");
        return;
      }
      if (nominalController.text.isEmpty) {
        showSnackBar("Nominal transaksi wajib diisi!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal harus lebih dari 0!");
        return;
      }
    }

    // ============ VALIDASI SETORAN BRILINK ============
    if (isSetoranBrilink) {
      if (setoranBrilinkMode == 'pelanggan') {
        if (customerNameController.text.trim().isEmpty) {
          showSnackBar("Nama pelanggan wajib diisi!");
          return;
        }
        if (selectedSourceAccountId == null) {
          showSnackBar("Silakan pilih rekening sumber!");
          return;
        }
        if (selectedDestinationAccountId == null) {
          showSnackBar("Silakan pilih tujuan penyimpanan saldo!");
          return;
        }
        if (nominalController.text.isEmpty) {
          showSnackBar("Nominal setoran wajib diisi!");
          return;
        }
        if (parsedNominal <= 0) {
          showSnackBar("Nominal harus lebih dari 0!");
          return;
        }
      } else if (setoranBrilinkMode == 'topup') {
        if (selectedTopupSourceAccountId == null) {
          showSnackBar("Silakan pilih sumber rekening!");
          return;
        }
        if (selectedDestinationAccountId == null) {
          showSnackBar("Silakan pilih tujuan topup!");
          return;
        }
        if (nominalController.text.isEmpty) {
          showSnackBar("Nominal topup wajib diisi!");
          return;
        }
        if (parsedNominal <= 0) {
          showSnackBar("Nominal harus lebih dari 0!");
          return;
        }
      } else if (setoranBrilinkMode == 'pindah_saldo') {
        if (selectedTopupSourceAccountId == null) {
          showSnackBar("Silakan pilih sumber rekening!");
          return;
        }
        if (selectedSetoranTargetOutletId == null) {
          showSnackBar("Silakan pilih outlet tujuan!");
          return;
        }
        if (selectedSetoranDestinationAccountId == null) {
          showSnackBar("Silakan pilih akun tujuan di outlet tersebut!");
          return;
        }
        if (nominalController.text.isEmpty) {
          showSnackBar("Nominal pindah saldo wajib diisi!");
          return;
        }
        if (parsedNominal <= 0) {
          showSnackBar("Nominal harus lebih dari 0!");
          return;
        }
      }
    }

    // ============ VALIDASI TOPUP E-WALLET ============
    if (isTopupEwallet) {
      if (selectedSourceAccountId == null) {
        showSnackBar("Silakan pilih sumber dana!");
        return;
      }
      if (selectedTopupAccountId == null) {
        showSnackBar("Silakan pilih akun E-Wallet tujuan!");
        return;
      }
      if (nominalController.text.isEmpty) {
        showSnackBar("Masukkan nominal topup!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal harus lebih dari 0!");
        return;
      }
      if (parsedNominal > currentSourceBalance) {
        showSnackBar("Saldo tidak cukup! Saldo maksimal sumber saat ini: Rp ${_formatIdr(currentSourceBalance)}");
        return;
      }
    }

    // ============ VALIDASI QRIS ============
    if (isQRISTarikTunai) {
      if (selectedSourceAccountId == null) {
        showSnackBar("Sumber dana (Kas) tidak ditemukan!");
        return;
      }
      if (selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih akun QRIS tujuan!");
        return;
      }
      if (nominalController.text.isEmpty) {
        showSnackBar("Nominal tarik tunai wajib diisi!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal harus lebih dari 0!");
        return;
      }
      if (parsedNominal > cashLaciCurrent) {
        showSnackBar("Saldo kas tidak cukup! Kas saat ini: Rp ${_formatIdr(cashLaciCurrent)}");
        return;
      }
      if (customerNameController.text.trim().isEmpty) {
        showSnackBar("Nama pelanggan wajib diisi!");
        return;
      }
    }

    if (isQRIS && qrisMode == 'bayar') {
      if (selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih akun QRIS Merchant penampung!");
        return;
      }
      if (nominalController.text.isEmpty) {
        showSnackBar("Nominal transaksi wajib diisi!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal harus lebih dari 0!");
        return;
      }
      if (customerNameController.text.trim().isEmpty) {
        showSnackBar("Nama pelanggan wajib diisi!");
        return;
      }
    }

    // ============ VALIDASI BAYAR PIUTANG / HUTANG ============
    if (isBayarPiutang) {
      if (_selectedTabIndex == 0) {
        if (selectedPeminjam == null) {
          showSnackBar("Silakan pilih peminjam terlebih dahulu!");
          return;
        }
        if (selectedDestinationAccountId == null) {
          showSnackBar("Silakan pilih tujuan penyimpanan saldo!");
          return;
        }
        
        double totalSisa = 0;
        for (var p in selectedPeminjamPiutangList) {
          totalSisa += double.tryParse(p['sisa_hutang']?.toString() ?? '0') ?? 0;
        }
        
        if (parsedNominal <= 0) {
          showSnackBar("Masukkan nominal pembayaran!");
          return;
        }
        if (parsedNominal > totalSisa) {
          showSnackBar("Nominal tidak boleh melebihi total sisa piutang! Maks: Rp ${_formatIdr(totalSisa)}");
          return;
        }
      } else {
        if (selectedPeminjamHutang == null || selectedHutangData == null) {
          showSnackBar("Silakan pilih peminjam dan hutang terlebih dahulu!");
          return;
        }
        if (selectedSourceAccountId == null) {
          showSnackBar("Silakan pilih sumber dana!");
          return;
        }
        if (parsedNominal <= 0) {
          showSnackBar("Masukkan nominal pembayaran!");
          return;
        }
        if (parsedNominal > sisaHutang) {
          showSnackBar("Nominal tidak boleh melebihi sisa hutang! Maks: Rp ${_formatIdr(sisaHutang)}");
          return;
        }
        if (parsedNominal > currentSourceBalance) {
          showSnackBar("Saldo tidak cukup! Saldo tersedia: Rp ${_formatIdr(currentSourceBalance)}");
          return;
        }
      }
      
      if (selectedMetode.isEmpty) {
        showSnackBar("Pilih metode pembayaran!");
        return;
      }
    }

    // ============ VALIDASI PENGELUARAN OPERASIONAL ============
    if (isPengeluaranOperasional && !isTopupEwallet) {
      if (selectedPengeluaranType == null) {
        showSnackBar("Silakan pilih jenis pengeluaran (Operasional atau Beban Toko)!");
        return;
      }
      
      if (selectedKategoriId == null || selectedKategoriId!.isEmpty) {
        showSnackBar("Silakan pilih kategori ${getPengeluaranTypeLabel(selectedPengeluaranType!)}!");
        return;
      }
      
      if (selectedSourceAccountId == null || selectedSourceAccountId!.isEmpty) {
        showSnackBar("Silakan pilih sumber dana!");
        return;
      }
      
      if (nominalController.text.isEmpty) {
        showSnackBar("Nominal pengeluaran wajib diisi!");
        return;
      }
      
      if (parsedNominal <= 0) {
        showSnackBar("Nominal harus lebih dari 0!");
        return;
      }
      
      if (parsedNominal > currentSourceBalance) {
        showSnackBar("Saldo tidak cukup! Saldo tersedia: Rp ${_formatIdr(currentSourceBalance)}");
        return;
      }
      
      if (descController.text.trim().isEmpty) {
        showSnackBar("Silakan masukkan keterangan pengeluaran!");
        return;
      }
    }

    // ============ VALIDASI NOMINAL WAJIB ============
    if (nominalController.text.isEmpty && !isPPOB && !isPengeluaranOperasional) {
      showSnackBar("Nominal transaksi wajib diisi!");
      return;
    }

    // ============ VALIDASI PINDAH KAS / PINDAH SALDO ============
    if (widget.trxType == 'pindah kas') {
      if (selectedTargetOutletId == null) {
        showSnackBar("Silakan tentukan Cabang Outlet Tujuan terlebih dahulu!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal kas yang dikirim harus lebih dari 0!");
        return;
      }
      if (parsedNominal > cashLaciCurrent) {
        showSnackBar("Saldo kas tidak cukup! Kas saat ini: Rp ${_formatIdr(cashLaciCurrent)}");
        return;
      }
    } else if (widget.trxType == 'pindah saldo' && isTransferKeOutletLain) {
      if (selectedTargetOutletId == null || selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih Outlet dan Rekening Bank Tujuan!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal saldo yang dipindahkan harus lebih dari 0!");
        return;
      }
      if (parsedNominal > currentSourceBalance) {
        showSnackBar("Saldo tidak cukup! Saldo tersedia: Rp ${_formatIdr(currentSourceBalance)}");
        return;
      }
    } else if (widget.trxType == 'qris' && qrisMode == 'bayar') {
      if (selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih akun QRIS Merchant penampung!");
        return;
      }
    } else if (widget.trxType.contains('tarik tunai')) {
      if (selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih Saldo Akun Tujuan penyimpanan dana!");
        return;
      }
    } else if (widget.trxType != 'pengeluaran operasional' && 
              widget.trxType != 'bayar piutang' && 
              !isSetoranBrilink && 
              !isQRISTarikTunai && 
              !isPPOB) {
      if (selectedSourceAccountId == null || selectedDestinationAccountId == null) {
        showSnackBar("Pilih Saldo Sumber dan Saldo Tujuan!");
        return;
      }
      if (parsedNominal <= 0) {
        showSnackBar("Nominal transaksi harus lebih dari 0!");
        return;
      }
      if (parsedNominal > currentSourceBalance) {
        showSnackBar("Saldo tidak cukup! Saldo maksimal sumber saat ini: Rp ${_formatIdr(currentSourceBalance)}");
        return;
      }
    }

    setState(() => isSubmitting = true);

    // ============ TENTUKAN TRX TYPE ============
    String finalTrxType = widget.trxType;
    if (isQRISTarikTunai) {
      finalTrxType = 'tarik tunai qris';
    }

    if (isPengeluaranOperasional && !isTopupEwallet) {
      if (selectedPengeluaranType == 'operasional') {
        finalTrxType = 'pengeluaran operasional konveksi';
      } else if (selectedPengeluaranType == 'beban_toko') {
        // ============ PERBAIKAN: Gunakan 'pengeluaran operasional' untuk Prive ============
        finalTrxType = 'pengeluaran operasional';
      }
    }

    if (isSetoranBrilink) {
      if (setoranBrilinkMode == 'topup' || setoranBrilinkMode == 'pindah_saldo') {
        finalTrxType = 'pengeluaran operasional brilink';
        tandaiPengeluaran = false;
      }
    }

    // ============ DEKLARASI VARIABEL SOURCE/DESTINATION (HARUS DI SINI) ============
    bool isPindahKasLuar = widget.trxType == 'pindah kas';
    bool isPindahSaldoLuar = widget.trxType == 'pindah saldo' && isTransferKeOutletLain;

    String? finalSourceId = selectedSourceAccountId;
    String? finalDestinationId = selectedDestinationAccountId;
    String? finalTargetOutletId = (isPindahKasLuar || isPindahSaldoLuar) ? selectedTargetOutletId : null;

    if (isTopupEwallet) {
      finalSourceId = selectedSourceAccountId;
      finalDestinationId = selectedTopupAccountId;
    }

    if (isQRISTarikTunai) {
      finalSourceId = "cash_laci";
    }

    if (isSetoranBrilink) {
      if (setoranBrilinkMode == 'pelanggan') {
        finalSourceId = selectedSourceAccountId;
        finalDestinationId = selectedDestinationAccountId;
      } else if (setoranBrilinkMode == 'topup') {
        finalSourceId = selectedTopupSourceAccountId;
        finalDestinationId = selectedDestinationAccountId;
      } else if (setoranBrilinkMode == 'pindah_saldo') {
        finalSourceId = selectedTopupSourceAccountId;
        finalDestinationId = selectedSetoranDestinationAccountId;
        finalTargetOutletId = selectedSetoranTargetOutletId;
      }
    }

    // ============ FEE ============
    String cleanFee = "0";

    if (isPengeluaranOperasional) {
      cleanFee = "0";
    } else if (isPPOB) {
      cleanFee = feeController.text.isEmpty ? "0" : feeController.text.replaceAll('.', '');
    } else if (isSetoranBrilink && setoranBrilinkMode == 'pelanggan') {
      cleanFee = feeController.text.isEmpty ? "0" : feeController.text.replaceAll('.', '');
    } else if (isQRISTarikTunai) {
      cleanFee = feeController.text.isEmpty ? "0" : feeController.text.replaceAll('.', '');
    } else if (widget.trxType != 'pindah kas' && 
              widget.trxType != 'PPOB' && 
              widget.trxType != 'pindah saldo' && 
              widget.trxType != 'pengeluaran operasional' && 
              widget.trxType != 'bayar piutang' && 
              !isSetoranBrilink && 
              !(isQRIS && qrisMode == 'bayar') && 
              !isTopupEwallet) {
      cleanFee = feeController.text.isEmpty ? "0" : feeController.text.replaceAll('.', '');
    }

    if (isQRIS && qrisMode == 'bayar') {
      cleanFee = "0";
    }

    if (isTopupEwallet) {
      cleanFee = "0";
    }

    // ============ FUNGSI UNTUK MENDAPATKAN NAMA AKUN DENGAN SUB_CATEGORY ============
    String getAccountNameWithSubCategory(Map<String, dynamic> account) {
      String name = account['name'] ?? 'Akun';
      String subCategory = account['sub_category'] ?? '';
      if (subCategory.isNotEmpty && subCategory != '-') {
        return "$name ($subCategory)";
      }
      return name;
    }

    // ============ SETORAN BRILINK ============
    if (isSetoranBrilink) {
      if (setoranBrilinkMode == 'pelanggan') {
        String namaPelanggan = customerNameController.text.trim();
        finalDescription = "Setoran Pelanggan - $namaPelanggan";
        
      } else if (setoranBrilinkMode == 'topup') {
        String sumberName = "Rekening Sumber";
        String tujuanName = "Akun Tujuan";
        
        if (selectedTopupSourceAccountId != null) {
          var sumber = dropdownOptions.firstWhere(
            (a) => a['id'].toString() == selectedTopupSourceAccountId,
            orElse: () => {'name': 'Rekening Sumber', 'sub_category': ''}
          );
          sumberName = getAccountNameWithSubCategory(sumber);
        }
        
        if (selectedDestinationAccountId != null) {
          var tujuan = dropdownOptions.firstWhere(
            (a) => a['id'].toString() == selectedDestinationAccountId,
            orElse: () => {'name': 'Akun Tujuan', 'sub_category': ''}
          );
          tujuanName = getAccountNameWithSubCategory(tujuan);
        }
        
        String nominalText = nominalController.text.isNotEmpty 
            ? "Rp ${nominalController.text}" 
            : "";
        
        String keterangan = descController.text.trim().isNotEmpty 
            ? " - ${descController.text.trim()}" 
            : "";
        
        finalDescription = "Topup Setoran [$sumberName → $tujuanName] $nominalText$keterangan";
        
      } else if (setoranBrilinkMode == 'pindah_saldo') {
        String sumberName = "Rekening Sumber";
        String tujuanName = "Akun Tujuan";
        String outletTujuan = "";
        
        if (selectedTopupSourceAccountId != null) {
          var sumber = dropdownOptions.firstWhere(
            (a) => a['id'].toString() == selectedTopupSourceAccountId,
            orElse: () => {'name': 'Rekening Sumber', 'sub_category': ''}
          );
          sumberName = getAccountNameWithSubCategory(sumber);
        }
        
        if (selectedSetoranDestinationAccountId != null) {
          var tujuan = setoranTargetAccountsOptions.firstWhere(
            (a) => a['id'].toString() == selectedSetoranDestinationAccountId,
            orElse: () => {'name': 'Akun Tujuan', 'sub_category': ''}
          );
          tujuanName = getAccountNameWithSubCategory(tujuan);
        }
        
        if (selectedSetoranTargetOutletId != null) {
          var outlet = setoranOutletOptions.firstWhere(
            (o) => o['id'].toString() == selectedSetoranTargetOutletId,
            orElse: () => {'nama_outlet': 'Outlet Tujuan'}
          );
          outletTujuan = " (${outlet['nama_outlet']})";
        }
        
        String nominalText = nominalController.text.isNotEmpty 
            ? "Rp ${nominalController.text}" 
            : "";
        
        String keterangan = descController.text.trim().isNotEmpty 
            ? " - ${descController.text.trim()}" 
            : "";
        
        finalDescription = "Pindah Saldo Setoran [$sumberName → $tujuanName$outletTujuan] $nominalText$keterangan";
      }
    }

    // ============ PPOB ============
    if (isPPOB) {
      String ppobTarget = ppobTargetController.text.trim();
      String keterangan = descController.text.trim();
      
      String sumberName = "E-Wallet";
      if (selectedSourceAccountId != null) {
        var sumber = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedSourceAccountId,
          orElse: () => {'name': 'E-Wallet', 'sub_category': ''}
        );
        sumberName = getAccountNameWithSubCategory(sumber);
      }
      
      finalDescription = "PPOB - $ppobTarget ($sumberName)";
      if (keterangan.isNotEmpty) {
        finalDescription += " - $keterangan";
      }
    }

    // ============ PINDAH KAS ============
    if (isPindahKas) {
      String outletTujuan = "Outlet Tujuan";
      if (selectedTargetOutletId != null) {
        var outlet = outletOptions.firstWhere(
          (o) => o['id'].toString() == selectedTargetOutletId,
          orElse: () => {'nama_outlet': 'Outlet Tujuan'}
        );
        outletTujuan = outlet['nama_outlet'] ?? 'Outlet Tujuan';
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String keterangan = descController.text.trim().isNotEmpty 
          ? " - ${descController.text.trim()}" 
          : "";
      
      finalDescription = "Pindah Kas ke $outletTujuan $nominalText$keterangan";
    }

    // ============ PINDAH SALDO ============
    if (isPindahSaldo) {
      String sumberName = "Rekening Sumber";
      String tujuanName = "Akun Tujuan";
      
      if (selectedSourceAccountId != null) {
        var sumber = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedSourceAccountId,
          orElse: () => {'name': 'Rekening Sumber', 'sub_category': ''}
        );
        sumberName = getAccountNameWithSubCategory(sumber);
      }
      
      if (selectedDestinationAccountId != null) {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedDestinationAccountId,
          orElse: () => {'name': 'Akun Tujuan', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      }
      
      String outletInfo = "";
      if (isTransferKeOutletLain && selectedTargetOutletId != null) {
        var outlet = outletOptions.firstWhere(
          (o) => o['id'].toString() == selectedTargetOutletId,
          orElse: () => {'nama_outlet': 'Outlet Tujuan'}
        );
        outletInfo = " ke ${outlet['nama_outlet']}";
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String keterangan = descController.text.trim().isNotEmpty 
          ? " - ${descController.text.trim()}" 
          : "";
      
      finalDescription = "Pindah Saldo [$sumberName → $tujuanName$outletInfo] $nominalText$keterangan";
    }

    // ============ TOPUP E-WALLET ============
    if (isTopupEwallet) {
      String sumberName = "Sumber";
      String tujuanName = "E-Wallet Tujuan";
      
      if (selectedSourceAccountId != null) {
        var sumber = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedSourceAccountId,
          orElse: () => {'name': 'Sumber', 'sub_category': ''}
        );
        sumberName = getAccountNameWithSubCategory(sumber);
      }
      
      if (selectedTopupAccountId != null) {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedTopupAccountId,
          orElse: () => {'name': 'E-Wallet Tujuan', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String keterangan = descController.text.trim().isNotEmpty 
          ? " - ${descController.text.trim()}" 
          : "";
      
      finalDescription = "[Topup E-Wallet] $sumberName → $tujuanName $nominalText$keterangan";
    }

    // ============ PENGELUARAN OPERASIONAL ============
    if (widget.trxType == 'pengeluaran operasional' && selectedKategoriName != null) {
      if (!isTopupEwallet) {
        String jenisLabel = getPengeluaranTypeLabel(selectedPengeluaranType ?? 'operasional');
        String sumberName = "Sumber";
        
        if (selectedSourceAccountId != null) {
          var sumber = dropdownOptions.firstWhere(
            (a) => a['id'].toString() == selectedSourceAccountId,
            orElse: () => {'name': 'Sumber', 'sub_category': ''}
          );
          sumberName = getAccountNameWithSubCategory(sumber);
        }
        
        String nominalText = nominalController.text.isNotEmpty 
            ? "Rp ${nominalController.text}" 
            : "";
        
        finalDescription = "[${jenisLabel} - ${selectedKategoriName}] ${descController.text.trim()} ($sumberName) $nominalText";
      }
    }

    // ============ QRIS TARIK TUNAI ============
    if (isQRISTarikTunai) {
      String tujuanName = "QRIS Tujuan";
      
      if (selectedDestinationAccountId != null) {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedDestinationAccountId,
          orElse: () => {'name': 'QRIS Tujuan', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String feeText = feeController.text.isNotEmpty 
          ? " (Fee: Rp ${feeController.text})" 
          : "";
      
      String namaPelanggan = customerNameController.text.trim().isNotEmpty 
          ? customerNameController.text.trim() 
          : "Nasabah";
      
      finalDescription = "Tarik Tunai QRIS - $namaPelanggan → $tujuanName $nominalText$feeText";
    }

    // ============ QRIS BAYAR ============
    if (isQRIS && qrisMode == 'bayar') {
      String tujuanName = "QRIS Merchant";
      
      if (selectedDestinationAccountId != null) {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedDestinationAccountId,
          orElse: () => {'name': 'QRIS Merchant', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String namaPelanggan = customerNameController.text.trim().isNotEmpty 
          ? customerNameController.text.trim() 
          : "Nasabah";
      
      finalDescription = "QRIS Bayar - $namaPelanggan → $tujuanName $nominalText";
    }

    // ============ TARIK TUNAI (EDC / M-BANKING) ============
    if (widget.trxType.contains('tarik tunai') && !isQRISTarikTunai) {
      String jenis = widget.trxType == 'tarik tunai mbanking' ? 'M-Banking' : 'EDC';
      String tujuanName = "Akun Tujuan";
      
      if (selectedDestinationAccountId != null) {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedDestinationAccountId,
          orElse: () => {'name': 'Akun Tujuan', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String namaPelanggan = customerNameController.text.trim().isNotEmpty 
          ? customerNameController.text.trim() 
          : "Nasabah";
      
      finalDescription = "Tarik Tunai $jenis - $namaPelanggan → $tujuanName $nominalText";
    }

    // ============ TRANSAKSI REGULER (Transfer antar akun) ============
    if (!isPengeluaranOperasional && 
        !isBayarPiutang && 
        !isSetoranBrilink && 
        !isQRIS && 
        !isPPOB && 
        !isPindahKas && 
        !isPindahSaldo) {
      
      String sumberName = "Sumber";
      String tujuanName = "Tujuan";
      
      if (selectedSourceAccountId != null && selectedSourceAccountId != "cash_laci") {
        var sumber = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedSourceAccountId,
          orElse: () => {'name': 'Sumber', 'sub_category': ''}
        );
        sumberName = getAccountNameWithSubCategory(sumber);
      } else if (selectedSourceAccountId == "cash_laci") {
        sumberName = "Uang Kas (Laci)";
      }
      
      if (selectedDestinationAccountId != null && selectedDestinationAccountId != "cash_laci") {
        var tujuan = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedDestinationAccountId,
          orElse: () => {'name': 'Tujuan', 'sub_category': ''}
        );
        tujuanName = getAccountNameWithSubCategory(tujuan);
      } else if (selectedDestinationAccountId == "cash_laci") {
        tujuanName = "Uang Kas (Laci)";
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      String keterangan = descController.text.trim().isNotEmpty 
          ? " - ${descController.text.trim()}" 
          : "";
      
      String feeText = feeController.text.isNotEmpty 
          ? " (Fee: Rp ${feeController.text})" 
          : "";
      
      finalDescription = "Transfer [$sumberName → $tujuanName] $nominalText$feeText$keterangan";
    }

    // ============ BAYAR PIUTANG BULK ============
    if (isBayarPiutang && _selectedTabIndex == 0) {
      if (selectedPeminjam == null || selectedPeminjamPiutangList.isEmpty) {
        showSnackBar("Silakan pilih peminjam terlebih dahulu!");
        setState(() => isSubmitting = false);
        return;
      }
      if (selectedDestinationAccountId == null) {
        showSnackBar("Silakan pilih tujuan penyimpanan saldo!");
        setState(() => isSubmitting = false);
        return;
      }
      
      double totalSisa = 0;
      for (var p in selectedPeminjamPiutangList) {
        totalSisa += double.tryParse(p['sisa_hutang']?.toString() ?? '0') ?? 0;
      }
      
      if (parsedNominal <= 0) {
        showSnackBar("Masukkan nominal pembayaran!");
        setState(() => isSubmitting = false);
        return;
      }
      if (parsedNominal > totalSisa) {
        showSnackBar("Nominal tidak boleh melebihi total sisa piutang! Maks: Rp ${_formatIdr(totalSisa)}");
        setState(() => isSubmitting = false);
        return;
      }
      
      List<int> piutangIds = selectedPeminjamPiutangList.map((p) => int.parse(p['id'].toString())).toList();
      
      // ============ TENTUKAN DESTINATION ACCOUNT ID ============
      String? finalDestinationId;
      if (selectedDestinationAccountId == 'cash_laci' || selectedDestinationAccountId == '0') {
        // Jika memilih Kas Laci, kirim NULL
        finalDestinationId = null;
      } else {
        finalDestinationId = selectedDestinationAccountId;
      }
      
      Map<String, dynamic> payload = {
        "session_id": widget.sessionId,
        "outlet_id": myOutletId,
        "trx_type": 'bayar piutang bulk',
        "customer_name": selectedPeminjam ?? customerNameController.text.trim(),
        "nominal_source": 0,
        "nominal_destination": parsedNominal,
        "fee": 0,
        "description": "Bayar Piutang Bulk - $selectedPeminjam (${piutangIds.length} piutang) - Rp ${_formatIdr(parsedNominal)}",
        "source_account_id": null,
        "destination_account_id": finalDestinationId, // <-- PERUBAHAN DI SINI
        "target_outlet_id": null,
        "karyawan_id": selectedKaryawanId,
        "metode_pembayaran": selectedMetode,
        "piutang_ids": piutangIds,
      };
      
      try {
        final response = await http.post(
          Uri.parse("$baseUrl/save_transaction.php"),
          headers: {"Content-Type": "application/json"},
          body: json.encode(payload),
        );
        
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == true) {
          showSnackBar(data['message'] ?? "Pembayaran piutang bulk berhasil!");
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          showSnackBar(data['message'] ?? "Gagal menyimpan transaksi", isError: true);
        }
      } catch (e) {
        showSnackBar("Terjadi error sistem: $e", isError: true);
      } finally {
        setState(() => isSubmitting = false);
      }
      return;
    }

    // ============ BAYAR HUTANG ============
    if (isBayarPiutang && _selectedTabIndex == 1) {
      if (selectedPeminjamHutang == null || selectedHutangData == null) {
        showSnackBar("Silakan pilih peminjam dan hutang terlebih dahulu!");
        setState(() => isSubmitting = false);
        return;
      }
      if (selectedSourceAccountId == null) {
        showSnackBar("Silakan pilih sumber dana!");
        setState(() => isSubmitting = false);
        return;
      }
      
      if (parsedNominal <= 0) {
        showSnackBar("Masukkan nominal pembayaran!");
        setState(() => isSubmitting = false);
        return;
      }
      if (parsedNominal > sisaHutang) {
        showSnackBar("Nominal tidak boleh melebihi sisa hutang! Maks: Rp ${_formatIdr(sisaHutang)}");
        setState(() => isSubmitting = false);
        return;
      }
      if (parsedNominal > currentSourceBalance) {
        showSnackBar("Saldo tidak cukup! Saldo tersedia: Rp ${_formatIdr(currentSourceBalance)}");
        setState(() => isSubmitting = false);
        return;
      }
      
      String hutangName = selectedHutangData?['nama_hutang'] ?? 'Hutang';
      String peminjam = selectedHutangData?['nama_peminjam'] ?? 'Peminjam';
      String sumberName = "Sumber";
      
      if (selectedSourceAccountId != null && selectedSourceAccountId != "cash_laci") {
        var sumber = dropdownOptions.firstWhere(
          (a) => a['id'].toString() == selectedSourceAccountId,
          orElse: () => {'name': 'Sumber', 'sub_category': ''}
        );
        sumberName = getAccountNameWithSubCategory(sumber);
      } else if (selectedSourceAccountId == "cash_laci") {
        sumberName = "Uang Kas (Laci)";
      }
      
      String nominalText = nominalController.text.isNotEmpty 
          ? "Rp ${nominalController.text}" 
          : "";
      
      finalDescription = "Bayar Hutang - $hutangName ($peminjam) dari $sumberName $nominalText";
      
      Map<String, dynamic> payload = {
        "session_id": widget.sessionId,
        "outlet_id": myOutletId,
        "trx_type": 'bayar hutang',
        "customer_name": selectedHutangData?['nama_peminjam'] ?? '',
        "nominal_source": parsedNominal,
        "nominal_destination": 0,
        "fee": 0,
        "description": finalDescription,
        "source_account_id": finalSourceId ?? '',
        "destination_account_id": null,
        "target_outlet_id": null,
        "karyawan_id": selectedKaryawanId,
        "metode_pembayaran": selectedMetode,
        "hutang_admin_id": selectedHutangId != null ? int.parse(selectedHutangId!) : 0,
      };
      
      try {
        final response = await http.post(
          Uri.parse("$baseUrl/save_transaction.php"),
          headers: {"Content-Type": "application/json"},
          body: json.encode(payload),
        );
        
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == true) {
          showSnackBar(data['message'] ?? "Pembayaran hutang berhasil!");
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          showSnackBar(data['message'] ?? "Gagal menyimpan transaksi", isError: true);
        }
      } catch (e) {
        showSnackBar("Terjadi error sistem: $e", isError: true);
      } finally {
        setState(() => isSubmitting = false);
      }
      return;
    }

    // ============ PAYLOAD UTAMA ============
    try {
      Map<String, dynamic> payload = {
        "session_id": widget.sessionId,
        "outlet_id": myOutletId,
        "trx_type": finalTrxType,
        "customer_name": customerNameController.text.trim(),
        "nominal_source": parsedNominal,
        "nominal_destination": parsedNominal, // <-- JANGAN 0
        "fee": double.parse(cleanFee),
        "description": finalDescription,
        "source_account_id": finalSourceId ?? '',
        "destination_account_id": finalDestinationId ?? '',
        "target_outlet_id": finalTargetOutletId,
        "karyawan_id": selectedKaryawanId,
        "metode_pembayaran": selectedMetode,
      };

      if (isPengeluaranOperasional && !isTopupEwallet) {
        payload["kategori_pengeluaran_id"] = int.parse(selectedKategoriId!);
        payload["pengeluaran_jenis"] = selectedPengeluaranType ?? 'operasional';
      }

      final response = await http.post(
        Uri.parse("$baseUrl/save_transaction.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        showSnackBar("Server error: HTTP ${response.statusCode}");
        setState(() => isSubmitting = false);
        return;
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("Transaksi berhasil dibukukan!");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan transaksi");
      }
    } catch (e) {
      showSnackBar("Terjadi error sistem: $e", isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
      labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip(double balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet, size: 13, color: primaryBlue),
          const SizedBox(width: 4),
          Text(
            "Rp ${_formatIdr(balance)}",
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDropdownItem(Map<String, dynamic> account) {
    String name = account['name'] ?? 'Tanpa Nama';
    String category = account['category']?.toString().toLowerCase() ?? '';
    String subCategory = account['sub_category'] ?? '-';

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (category == 'bank' && subCategory != '-') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              subCategory,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============ DIALOG BUAT PIUTANG BARU ============
  void _showCreatePiutangDialog() {
    namaPiutangController.clear();
    namaPeminjamController.clear();
    nominalPiutangController.clear();
    keteranganPiutangController.clear();
    setState(() {
      selectedJatuhTempo = null;
      selectedPeminjamDropdownId = null;
      selectedPeminjamDropdownName = null;
    });
    
    // ============ TAMBAHKAN: FLAG UNTUK MODE TAMBAH BARU ============
    bool isAddingNewPeminjam = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.add_circle_rounded, color: Colors.orange.shade700, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Tambah Piutang Baru",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabelForm("Nama Piutang"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: namaPiutangController,
                                decoration: _inputDecorationForm(
                                  hint: "Contoh: Piutang Usaha",
                                  icon: Icons.assignment_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // ============ NAMA PEMINJAM - DROPDOWN + TOMBOL BARU ============
                              _buildLabelForm("Nama Peminjam"),
                              const SizedBox(height: 6),
                              if (isLoadingPeminjamDropdown)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: selectedPeminjamDropdownId,
                                        hint: Text(
                                          "Pilih peminjam",
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          prefixIcon: Icon(Icons.person_rounded, color: Colors.grey.shade500),
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: '',
                                            child: Text("-- Pilih Peminjam --", style: TextStyle(fontSize: 13)),
                                          ),
                                          ...peminjamDropdownList.map((peminjam) {
                                            String nama = peminjam['nama_peminjam'] ?? 'Unknown';
                                            String telepon = peminjam['no_telepon'] ?? '';
                                            String label = telepon.isNotEmpty ? "$nama ($telepon)" : nama;
                                            return DropdownMenuItem<String>(
                                              value: peminjam['id'].toString(),
                                              child: Text(label, style: const TextStyle(fontSize: 13)),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            selectedPeminjamDropdownId = value;
                                            isAddingNewPeminjam = false;
                                            if (value != null && value.isNotEmpty) {
                                              final selected = peminjamDropdownList.firstWhere(
                                                (p) => p['id'].toString() == value,
                                                orElse: () => {'nama_peminjam': ''},
                                              );
                                              selectedPeminjamDropdownName = selected['nama_peminjam'] ?? '';
                                              namaPeminjamController.text = selectedPeminjamDropdownName!;
                                            } else {
                                              selectedPeminjamDropdownName = null;
                                              namaPeminjamController.clear();
                                            }
                                          });
                                        },
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // ============ TOMBOL BUAT BARU ============
                                    Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                                        onPressed: () {
                                          setDialogState(() {
                                            isAddingNewPeminjam = true;
                                            selectedPeminjamDropdownId = null;
                                            selectedPeminjamDropdownName = null;
                                            namaPeminjamController.clear();
                                          });
                                        },
                                        tooltip: "Buat peminjam baru",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                ),
                              // ============ FORM BUAT PEMINJAM BARU ============
                              if (isAddingNewPeminjam)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person_add_rounded, color: Colors.green.shade700, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Peminjam Baru",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                isAddingNewPeminjam = false;
                                                namaPeminjamController.clear();
                                              });
                                            },
                                            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: namaPeminjamController,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: "Masukkan nama peminjam baru *",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          prefixIcon: Icon(Icons.person_rounded, color: Colors.green.shade700),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "💡 Nama peminjam akan otomatis tersimpan ke database",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // ================================================
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Nominal Piutang"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nominalPiutangController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: _inputDecorationForm(
                                  hint: "Masukkan nominal",
                                  icon: Icons.money_rounded,
                                  prefixText: "Rp ",
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Sumber Dana"),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedPiutangSourceAccountId,
                                hint: Text(
                                  "Pilih sumber dana",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.grey.shade500),
                                ),
                                items: [
                                  // ============ TAMBAHKAN OPSI KAS LACI ============
                                  const DropdownMenuItem<String>(
                                    value: 'cash_laci',
                                    child: Text("Uang Kas (Laci)", style: TextStyle(fontSize: 13)),
                                  ),
                                  // ============ AKUN LAINNYA ============
                                  ...dropdownOptions
                                      .where((a) => a['id'] != 'cash_laci' && a['category'].toString().toLowerCase() != 'qris')
                                      .map((a) => DropdownMenuItem<String>(
                                        value: a['id'].toString(),
                                        child: _buildAccountDropdownItem(a),
                                      ))
                                      .toList(),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedPiutangSourceAccountId = value;
                                    if (value != null && value != 'cash_laci') {
                                      var option = dropdownOptions.firstWhere(
                                        (a) => a['id'].toString() == value,
                                      );
                                      piutangSourceBalance = double.tryParse(option['balance'].toString()) ?? 0;
                                    } else if (value == 'cash_laci') {
                                      // Untuk Kas Laci, gunakan saldo dari cashLaciCurrent
                                      piutangSourceBalance = cashLaciCurrent;
                                    }
                                  });
                                },
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedPiutangSourceAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("Saldo tersedia: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryBlue.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          selectedPiutangSourceAccountId == 'cash_laci'
                                              ? "Rp ${_formatIdr(cashLaciCurrent)}"
                                              : "Rp ${_formatIdr(piutangSourceBalance)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Tanggal Jatuh Tempo"),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedJatuhTempo ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedJatuhTempo = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, color: Colors.grey.shade500),
                                      const SizedBox(width: 12),
                                      Text(
                                        selectedJatuhTempo != null
                                            ? DateFormat('dd MMMM yyyy').format(selectedJatuhTempo!)
                                            : "Pilih Tanggal Jatuh Tempo",
                                        style: TextStyle(
                                          color: selectedJatuhTempo != null ? Colors.black87 : Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (selectedJatuhTempo != null)
                                        GestureDetector(
                                          onTap: () => setDialogState(() => selectedJatuhTempo = null),
                                          child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Keterangan"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: keteranganPiutangController,
                                maxLines: 3,
                                decoration: _inputDecorationForm(
                                  hint: "Keterangan tambahan (opsional)",
                                  icon: Icons.note_rounded,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Piutang baru akan tersimpan dan bisa langsung dibayar.",
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  "Batal",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isCreatingPiutang ? null : createPiutangBaru,
                                child: isCreatingPiutang
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Simpan Piutang",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============ FUNGSI MEMBUAT PIUTANG BARU ============
  Future<void> createPiutangBaru() async {
    if (namaPiutangController.text.trim().isEmpty) {
      showSnackBar("Masukkan nama piutang!", isError: true);
      return;
    }
    
    // ============ AMBIL NAMA PEMINJAM DARI DROPDOWN ATAU INPUT BARU ============
    String namaPeminjam = '';
    if (selectedPeminjamDropdownId != null && selectedPeminjamDropdownId!.isNotEmpty) {
      final selected = peminjamDropdownList.firstWhere(
        (p) => p['id'].toString() == selectedPeminjamDropdownId,
        orElse: () => {'nama_peminjam': ''},
      );
      namaPeminjam = selected['nama_peminjam'] ?? '';
    }
    
    // Jika tidak ada yang dipilih dari dropdown, gunakan dari TextField (buat baru)
    if (namaPeminjam.isEmpty) {
      namaPeminjam = namaPeminjamController.text.trim();
    }
    
    if (namaPeminjam.isEmpty) {
      showSnackBar("Pilih atau masukkan nama peminjam terlebih dahulu!", isError: true);
      return;
    }
    
    if (nominalPiutangController.text.isEmpty) {
      showSnackBar("Masukkan nominal piutang!", isError: true);
      return;
    }
    
    String cleanNominal = nominalPiutangController.text.replaceAll('.', '');
    double nominal = double.tryParse(cleanNominal) ?? 0;
    if (nominal <= 0) {
      showSnackBar("Nominal harus lebih dari 0!", isError: true);
      return;
    }
    
    // VALIDASI SUMBER DANA
    if (selectedPiutangSourceAccountId == null || selectedPiutangSourceAccountId!.isEmpty) {
      showSnackBar("Pilih sumber dana terlebih dahulu!", isError: true);
      return;
    }
    
    // ============ CEK SALDO UNTUK KAS LACI ============
    if (selectedPiutangSourceAccountId == 'cash_laci') {
      if (nominal > cashLaciCurrent) {
        showSnackBar("Saldo kas tidak cukup! Tersedia Rp ${_formatIdr(cashLaciCurrent)}", isError: true);
        return;
      }
    } else {
      // CEK SALDO UNTUK AKUN LAIN
      if (nominal > piutangSourceBalance) {
        showSnackBar("Saldo tidak mencukupi! Tersedia Rp ${_formatIdr(piutangSourceBalance)}", isError: true);
        return;
      }
    }
    
    setState(() => isCreatingPiutang = true);
    
    try {
      // ============ TENTUKAN SOURCE ACCOUNT ID ============
      String? sourceAccountId;
      if (selectedPiutangSourceAccountId == 'cash_laci' || selectedPiutangSourceAccountId == '0') {
        sourceAccountId = 'cash_laci';
      } else {
        sourceAccountId = selectedPiutangSourceAccountId;
      }
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_piutang_kasir.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "nama_piutang": namaPiutangController.text.trim(),
          "nama_peminjam": namaPeminjam,
          "nominal": nominal,
          "tanggal_jatuh_tempo": selectedJatuhTempo != null 
              ? DateFormat('yyyy-MM-dd').format(selectedJatuhTempo!)
              : null,
          "keterangan": keteranganPiutangController.text.trim(),
          "outlet_id": myOutletId,
          "source": "kasir",
          "source_account_id": sourceAccountId,
          "user_outlet_id": myOutletId,
          "session_id": widget.sessionId,
          "karyawan_id": selectedKaryawanId,  // <-- KIRIM KARYAWAN_ID
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("✅ Piutang baru berhasil ditambahkan!");
        
        // ============ RESET FORM ============
        namaPiutangController.clear();
        namaPeminjamController.clear();
        nominalPiutangController.clear();
        keteranganPiutangController.clear();
        setState(() {
          selectedJatuhTempo = null;
          selectedPeminjam = null;
          selectedPiutangData = null;
          selectedPiutangId = null;
          totalPiutang = 0;
          sisaPiutang = 0;
          nominalController.clear();
          selectedPiutangSourceAccountId = null;
          piutangSourceBalance = 0;
          selectedPeminjamDropdownId = null;
          selectedPeminjamDropdownName = null;
        });
        
        Navigator.pop(context);
        
        // ============ REFRESH SEMUA DATA ============
        await fetchPiutangAdmin();
        await fetchAccountsData();
        await fetchPeminjamDropdown();
        
      } else {
        showSnackBar(data['message'] ?? "Gagal menambahkan piutang", isError: true);
      }
    } catch (e) {
      showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => isCreatingPiutang = false);
    }
  }

  // ============ DIALOG BUAT HUTANG BARU ============
  void _showCreateHutangDialog() {
    namaHutangController.clear();
    namaPeminjamHutangController.clear();
    nominalHutangController.clear();
    keteranganHutangController.clear();
    setState(() {
      selectedJatuhTempoHutang = null;
      selectedKrediturDropdownId = null;
      selectedKrediturDropdownName = null;
    });
    
    // ============ TAMBAHKAN: FLAG UNTUK MODE TAMBAH BARU ============
    bool isAddingNewKreditur = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.add_circle_rounded, color: Colors.red.shade700, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Tambah Hutang Baru",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabelForm("Nama Hutang"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: namaHutangController,
                                decoration: _inputDecorationForm(
                                  hint: "Contoh: Hutang ke Supplier",
                                  icon: Icons.assignment_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // ============ NAMA KREDITUR - DROPDOWN + TOMBOL BARU ============
                              _buildLabelForm("Nama Kreditur"),
                              const SizedBox(height: 6),
                              if (isLoadingKrediturDropdown)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: selectedKrediturDropdownId,
                                        hint: Text(
                                          "Pilih kreditur",
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          prefixIcon: Icon(Icons.person_rounded, color: Colors.grey.shade500),
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: '',
                                            child: Text("-- Pilih Kreditur --", style: TextStyle(fontSize: 13)),
                                          ),
                                          ...krediturDropdownList.map((kreditur) {
                                            String nama = kreditur['nama_kreditur'] ?? 'Unknown';
                                            String telepon = kreditur['no_telepon'] ?? '';
                                            String label = telepon.isNotEmpty ? "$nama ($telepon)" : nama;
                                            return DropdownMenuItem<String>(
                                              value: kreditur['id'].toString(),
                                              child: Text(label, style: const TextStyle(fontSize: 13)),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          setDialogState(() {
                                            selectedKrediturDropdownId = value;
                                            isAddingNewKreditur = false;
                                            if (value != null && value.isNotEmpty) {
                                              final selected = krediturDropdownList.firstWhere(
                                                (k) => k['id'].toString() == value,
                                                orElse: () => {'nama_kreditur': ''},
                                              );
                                              selectedKrediturDropdownName = selected['nama_kreditur'] ?? '';
                                              namaPeminjamHutangController.text = selectedKrediturDropdownName!;
                                            } else {
                                              selectedKrediturDropdownName = null;
                                              namaPeminjamHutangController.clear();
                                            }
                                          });
                                        },
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // ============ TOMBOL BUAT BARU ============
                                    Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                                        onPressed: () {
                                          setDialogState(() {
                                            isAddingNewKreditur = true;
                                            selectedKrediturDropdownId = null;
                                            selectedKrediturDropdownName = null;
                                            namaPeminjamHutangController.clear();
                                          });
                                        },
                                        tooltip: "Buat kreditur baru",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                ),
                              // ============ FORM BUAT KREDITUR BARU ============
                              if (isAddingNewKreditur)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person_add_rounded, color: Colors.green.shade700, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Kreditur Baru",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                isAddingNewKreditur = false;
                                                namaPeminjamHutangController.clear();
                                              });
                                            },
                                            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: namaPeminjamHutangController,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: "Masukkan nama kreditur baru *",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          prefixIcon: Icon(Icons.person_rounded, color: Colors.green.shade700),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "💡 Nama kreditur akan otomatis tersimpan ke database",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // =====================================================
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Nominal Hutang"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nominalHutangController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: _inputDecorationForm(
                                  hint: "Masukkan nominal",
                                  icon: Icons.money_rounded,
                                  prefixText: "Rp ",
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Tujuan Penyimpanan Saldo"),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedHutangDestinationAccountId,
                                hint: Text(
                                  "Pilih tujuan penyimpanan saldo",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.grey.shade500),
                                ),
                                items: [
                                  // ============ TAMBAHKAN OPSI KAS LACI ============
                                  const DropdownMenuItem<String>(
                                    value: 'cash_laci',
                                    child: Text("Uang Kas (Laci)", style: TextStyle(fontSize: 13)),
                                  ),
                                  // ============ AKUN LAINNYA ============
                                  ...dropdownOptions
                                      .where((a) => a['id'] != 'cash_laci' && a['category'].toString().toLowerCase() != 'qris')
                                      .map((a) => DropdownMenuItem<String>(
                                        value: a['id'].toString(),
                                        child: _buildAccountDropdownItem(a),
                                      ))
                                      .toList(),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedHutangDestinationAccountId = value;
                                    if (value != null && value != 'cash_laci') {
                                      var option = dropdownOptions.firstWhere(
                                        (a) => a['id'].toString() == value,
                                      );
                                      hutangDestinationBalance = double.tryParse(option['balance'].toString()) ?? 0;
                                    } else if (value == 'cash_laci') {
                                      // Untuk Kas Laci, gunakan saldo dari cashLaciCurrent
                                      hutangDestinationBalance = cashLaciCurrent;
                                    }
                                  });
                                },
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedHutangDestinationAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("Saldo tersedia: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryBlue.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          selectedHutangDestinationAccountId == 'cash_laci'
                                              ? "Rp ${_formatIdr(cashLaciCurrent)}"
                                              : "Rp ${_formatIdr(hutangDestinationBalance)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Tanggal Jatuh Tempo"),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedJatuhTempoHutang ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedJatuhTempoHutang = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, color: Colors.grey.shade500),
                                      const SizedBox(width: 12),
                                      Text(
                                        selectedJatuhTempoHutang != null
                                            ? DateFormat('dd MMMM yyyy').format(selectedJatuhTempoHutang!)
                                            : "Pilih Tanggal Jatuh Tempo",
                                        style: TextStyle(
                                          color: selectedJatuhTempoHutang != null ? Colors.black87 : Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (selectedJatuhTempoHutang != null)
                                        GestureDetector(
                                          onTap: () => setDialogState(() => selectedJatuhTempoHutang = null),
                                          child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildLabelForm("Keterangan"),
                              const SizedBox(height: 6),
                              TextField(
                                controller: keteranganHutangController,
                                maxLines: 3,
                                decoration: _inputDecorationForm(
                                  hint: "Keterangan tambahan (opsional)",
                                  icon: Icons.note_rounded,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Colors.red.shade700, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Hutang baru akan tersimpan dan bisa langsung dibayar.",
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  "Batal",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isCreatingHutang ? null : createHutangBaru,
                                child: isCreatingHutang
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Simpan Hutang",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabelForm(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  InputDecoration _inputDecorationForm({
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
    );
  }

  Widget _buildSetoranBrilinkForm() {
    return Column(
      children: [
        _buildSectionHeader("Mode Setoran", Icons.settings_rounded),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      setoranBrilinkMode = 'pelanggan';
                      tandaiPengeluaran = false;
                      selectedSourceAccountId = null;
                      selectedDestinationAccountId = null;
                      selectedTopupSourceAccountId = null;
                      selectedTopupAccountId = null;
                    });
                    fetchAccountsData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: setoranBrilinkMode == 'pelanggan' ? primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_rounded, color: setoranBrilinkMode == 'pelanggan' ? Colors.white : Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text("PELANGGAN", style: TextStyle(fontWeight: FontWeight.bold, color: setoranBrilinkMode == 'pelanggan' ? Colors.white : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      setoranBrilinkMode = 'topup';
                      tandaiPengeluaran = false;
                      selectedSourceAccountId = null;
                      selectedDestinationAccountId = null;
                      selectedTopupSourceAccountId = null;
                      selectedTopupAccountId = null;
                    });
                    fetchAccountsData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: setoranBrilinkMode == 'topup' ? primaryOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android_rounded, color: setoranBrilinkMode == 'topup' ? Colors.white : Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text("TOPUP", style: TextStyle(fontWeight: FontWeight.bold, color: setoranBrilinkMode == 'topup' ? Colors.white : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      setoranBrilinkMode = 'pindah_saldo';
                      tandaiPengeluaran = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: setoranBrilinkMode == 'pindah_saldo' ? const Color(0xFF00838F) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.currency_exchange_rounded, color: setoranBrilinkMode == 'pindah_saldo' ? Colors.white : Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text("PINDAH SALDO", style: TextStyle(fontWeight: FontWeight.bold, color: setoranBrilinkMode == 'pindah_saldo' ? Colors.white : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (setoranBrilinkMode == 'pelanggan') ...[
          _buildSectionHeader("Rekening Sumber", Icons.arrow_upward),
          DropdownButtonFormField<String>(
            value: selectedSourceAccountId,
            hint: Text("Pilih rekening sumber", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: dropdownOptions
                .where((a) => 
                    a['id'] != 'cash_laci' && 
                    a['category'].toString().toLowerCase() == 'bank')
                .map((a) => DropdownMenuItem<String>(
                  value: a['id'].toString(),
                  child: _buildAccountDropdownItem(a),
                ))
                .toList(),
            onChanged: updateSourceAccount,
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          if (selectedSourceAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
            )
          else
            const SizedBox(height: 12),

          _buildSectionHeader("Penyimpanan Uang Pelanggan", Icons.arrow_downward),
          DropdownButtonFormField<String>(
            value: selectedDestinationAccountId,
            hint: Text("Pilih akun tujuan", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: dropdownOptions
                .where((a) => 
                    a['category'].toString().toLowerCase() == 'bank' ||
                    a['id'] == 'cash_laci')
                .map((a) => DropdownMenuItem<String>(
                  value: a['id'].toString(),
                  child: _buildAccountDropdownItem(a),
                ))
                .toList(),
            onChanged: updateDestinationAccount,
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          if (selectedDestinationAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
            )
          else
            const SizedBox(height: 12),

          _buildSectionHeader("Nominal Setoran", Icons.monetization_on_outlined),
          TextField(
            controller: nominalController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
            decoration: _buildInputDecoration("Nominal", hint: "0"),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader("Fee / Admin Toko (Rp)", Icons.payments_outlined),
          TextField(
            controller: feeController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
            decoration: _buildInputDecoration("Fee Admin", hint: "0"),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader("Keterangan", Icons.note_outlined),
          TextField(
            controller: descController,
            maxLines: 2,
            decoration: _buildInputDecoration("Tambahkan keterangan", hint: "Opsional"),
          ),
          const SizedBox(height: 16),
        ],

        if (setoranBrilinkMode == 'topup') ...[
          _buildSectionHeader("Sumber Rekening", Icons.arrow_upward),
          DropdownButtonFormField<String>(
            value: selectedTopupSourceAccountId,
            hint: Text("Pilih rekening sumber", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: dropdownOptions
                .where((a) => 
                    a['id'] != 'cash_laci' && 
                    (a['category'].toString().toLowerCase() == 'bank' ||
                    a['category'].toString().toLowerCase() == 'e-wallet' ||
                    a['category'].toString().toLowerCase() == 'ewallet' ||
                    a['category'].toString().toLowerCase() == 'qris'))
                .map((a) => DropdownMenuItem<String>(
                  value: a['id'].toString(),
                  child: _buildAccountDropdownItem(a),
                ))
                .toList(),
            onChanged: updateTopupSourceAccount,
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          if (selectedTopupSourceAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(topupSourceBalance)]),
            )
          else
            const SizedBox(height: 12),

          _buildSectionHeader("Tujuan Topup", Icons.phone_android_rounded),
          DropdownButtonFormField<String>(
            value: selectedDestinationAccountId,
            hint: Text("Pilih akun E-Wallet tujuan topup", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: dropdownOptions
                .where((a) => 
                    a['id'] != 'cash_laci' && 
                    (a['category'].toString().toLowerCase() == 'e-wallet' || 
                    a['category'].toString().toLowerCase() == 'ewallet' ||
                    a['category'].toString().toLowerCase() == 'qris'))
                .map((a) => DropdownMenuItem<String>(
                  value: a['id'].toString(),
                  child: _buildAccountDropdownItem(a),
                ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                var option = dropdownOptions.firstWhere(
                  (element) => element['id'].toString() == val,
                  orElse: () => {'balance': '0', 'name': 'Unknown', 'category': 'Unknown'}
                );
                setState(() {
                  selectedDestinationAccountId = val;
                  currentDestinationBalance = double.tryParse(option['balance'].toString()) ?? 0;
                });
              }
            },
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          if (selectedDestinationAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
            )
          else
            const SizedBox(height: 12),

          _buildSectionHeader("Nominal Topup", Icons.monetization_on_outlined),
          TextField(
            controller: nominalController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
            decoration: _buildInputDecoration("Nominal", hint: "0"),
          ),
          const SizedBox(height: 16),
        ],

        if (setoranBrilinkMode == 'pindah_saldo') ...[
          _buildSectionHeader("Sumber Rekening", Icons.arrow_upward),
          DropdownButtonFormField<String>(
            value: selectedTopupSourceAccountId,
            hint: Text("Pilih rekening sumber", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: dropdownOptions.map((a) => DropdownMenuItem<String>(
              value: a['id'].toString(),
              child: _buildAccountDropdownItem(a),
            )).toList(),
            onChanged: updateTopupSourceAccount,
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          if (selectedTopupSourceAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(topupSourceBalance)]),
            )
          else
            const SizedBox(height: 12),

          _buildSectionHeader("Outlet Tujuan", Icons.arrow_downward),
          DropdownButtonFormField<String>(
            value: selectedSetoranTargetOutletId,
            hint: Text("Pilih outlet tujuan", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            decoration: _buildInputDecoration(""),
            items: setoranOutletOptions.map((o) => DropdownMenuItem<String>(
              value: o['id'].toString(),
              child: Text(o['nama_outlet'].toString(), style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (val) {
              setState(() {
                selectedSetoranTargetOutletId = val;
                selectedSetoranDestinationAccountId = null;
                setoranTargetAccountsOptions.clear();
              });
              if (val != null) {
                fetchSetoranTargetAccountsData(val);
              }
            },
            isExpanded: true,
            dropdownColor: Colors.white,
          ),
          const SizedBox(height: 16),

          if (selectedSetoranTargetOutletId != null) ...[
            _buildSectionHeader("Akun Tujuan di Outlet", Icons.account_balance_wallet_rounded),
            isLoadingSetoranTargetAccounts
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : DropdownButtonFormField<String>(
                    value: selectedSetoranDestinationAccountId,
                    hint: Text("Pilih akun tujuan", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    decoration: _buildInputDecoration(""),
                    items: setoranTargetAccountsOptions.map((a) => DropdownMenuItem<String>(
                      value: a['id'].toString(),
                      child: _buildAccountDropdownItem(a),
                    )).toList(),
                    onChanged: updateSetoranDestinationAccount,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                  ),
            if (selectedSetoranDestinationAccountId != null && !isLoadingSetoranTargetAccounts)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Saldo tujuan: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    _buildBalanceChip(setoranDestinationBalance)
                  ],
                ),
              )
            else
              const SizedBox(height: 12),
          ],

          _buildSectionHeader("Nominal Topup", Icons.monetization_on_outlined),
          TextField(
            controller: nominalController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
            decoration: _buildInputDecoration("Nominal", hint: "0"),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTarikTunai = widget.trxType.contains('tarik tunai');
    bool isPPOB = widget.trxType == 'PPOB';
    bool isQRIS = widget.trxType == 'qris';
    bool isPindahSaldo = widget.trxType == 'pindah saldo';
    bool isSetoranBrilink = widget.trxType == 'setoran brilink';
    bool isPindahKas = widget.trxType == 'pindah kas';
    bool isPengeluaranOperasional = widget.trxType == 'pengeluaran operasional';
    bool isBayarPiutang = widget.trxType == 'bayar piutang';
    bool isQRISTarikTunai = isQRIS && qrisMode == 'tarik_tunai';
    bool isTopupEwallet = isPengeluaranOperasional && selectedKategoriName == 'Topup E-Wallet';

    bool showCashLaciCard = !isPPOB && !isQRIS && !isSetoranBrilink && !isPindahSaldo && !isPindahKas && !isPengeluaranOperasional && !isBayarPiutang;
    bool showCustomerNameField = !isPindahKas && !isPindahSaldo && !isQRIS && !isPengeluaranOperasional && !isBayarPiutang && !(isSetoranBrilink && setoranBrilinkMode != 'pelanggan');
    bool showFeeField = widget.trxType != 'pindah kas' && !isPPOB && !isQRIS && !isPindahSaldo && !isPengeluaranOperasional && !isBayarPiutang && !isSetoranBrilink;

    final List<dynamic> ppobFilteredOptions = dropdownOptions.where((a) => a['category'].toString().toLowerCase() == 'e-wallet' || a['category'].toString().toLowerCase() == 'ewallet').toList();
    final List<dynamic> qrisFilteredOptions = dropdownOptions.where((a) => a['category'].toString().toLowerCase() == 'qris').toList();
    final List<dynamic> pindahSaldoFilteredOptions = dropdownOptions.where((a) => a['id'] != 'cash_laci' && a['category'].toString().toLowerCase() != 'qris').toList();
    final List<dynamic> ewalletOptions = getEwalletOptions();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.menuTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: primaryOrange),
        ),
      ),
      body: (isLoadingAccounts || isLoadingKaryawan || isLoadingKategori || ((widget.trxType == 'pindah kas' || widget.trxType == 'pindah saldo' || widget.trxType == 'setoran brilink') && isLoadingOutlets))
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // KASIR / KARYAWAN
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_rounded, color: primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Kasir / Karyawan", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.verified_rounded, color: Colors.green, size: 14),
                                      const SizedBox(width: 6),
                                      Text(myKaryawanName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Text("AKTIF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (showCashLaciCard) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: primaryOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Icon(Icons.account_balance_rounded, size: 20, color: primaryOrange),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Kas Laci Saat Ini", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text("Rp ${_formatIdr(cashLaciCurrent)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                child: Text("Live", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: primaryBlue)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (showCustomerNameField) ...[
                              _buildSectionHeader("Identitas Pelanggan", Icons.person_outline_rounded),
                              TextField(
                                controller: customerNameController,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                decoration: _buildInputDecoration("Nama Konsumen", hint: "Masukkan nama lengkap nasabah"),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ============ QRIS ============
                            if (isQRIS) ...[
                              _buildSectionHeader("Mode Transaksi QRIS", Icons.settings_rounded),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            qrisMode = 'bayar';
                                            selectedSourceAccountId = null;
                                            fetchAccountsData();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: qrisMode == 'bayar' ? primaryBlue : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.payment_rounded, color: qrisMode == 'bayar' ? Colors.white : Colors.grey.shade600, size: 20),
                                              const SizedBox(width: 8),
                                              Text("BAYAR", style: TextStyle(fontWeight: FontWeight.bold, color: qrisMode == 'bayar' ? Colors.white : Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            qrisMode = 'tarik_tunai';
                                            selectedSourceAccountId = "cash_laci";
                                            currentSourceBalance = cashLaciCurrent;
                                            fetchAccountsData();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: qrisMode == 'tarik_tunai' ? primaryOrange : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.arrow_upward_rounded, color: qrisMode == 'tarik_tunai' ? Colors.white : Colors.grey.shade600, size: 20),
                                              const SizedBox(width: 8),
                                              Text("TARIK TUNAI", style: TextStyle(fontWeight: FontWeight.bold, color: qrisMode == 'tarik_tunai' ? Colors.white : Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (qrisMode == 'bayar') ...[
                                _buildSectionHeader("Identitas Pelanggan", Icons.person_outline_rounded),
                                TextField(
                                  controller: customerNameController,
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  decoration: _buildInputDecoration("Nama Konsumen", hint: "Masukkan nama lengkap pembayar"),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Akun QRIS Merchant Tujuan", Icons.qr_code_scanner_rounded),
                                DropdownButtonFormField<String>(
                                  value: selectedDestinationAccountId,
                                  hint: const Text("Pilih akun QRIS penampung", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: qrisFilteredOptions.map((a) => DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  )).toList(),
                                  onChanged: updateDestinationAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedDestinationAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
                                  )
                                else
                                  const SizedBox(height: 12),
                                
                                _buildSectionHeader("Nominal Masuk QRIS", Icons.monetization_on_outlined),
                                TextField(
                                  controller: nominalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  decoration: _buildInputDecoration("Nominal Transaksi", hint: "0"),
                                ),
                                const SizedBox(height: 20),

                                _buildSectionHeader("Keterangan Catatan", Icons.note_outlined),
                                TextField(
                                  controller: descController,
                                  maxLines: 2,
                                  decoration: _buildInputDecoration("Tambahkan keterangan", hint: "Opsional"),
                                ),
                                const SizedBox(height: 24),
                              ],

                              if (qrisMode == 'tarik_tunai') ...[
                                _buildSectionHeader("Identitas Pelanggan", Icons.person_outline_rounded),
                                TextField(
                                  controller: customerNameController,
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  decoration: _buildInputDecoration("Nama Konsumen", hint: "Masukkan nama lengkap nasabah"),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Sumber Dana (Otomatis)", Icons.arrow_upward),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    "Uang Kas (Laci) - Saldo: Rp ${_formatIdr(cashLaciCurrent)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Nominal Tarik Tunai", Icons.monetization_on_outlined),
                                TextField(
                                  controller: nominalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                  decoration: _buildInputDecoration("Nominal Tarik Tunai", hint: "0"),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Tujuan Penyimpanan Saldo (QRIS)", Icons.qr_code_scanner_rounded),
                                DropdownButtonFormField<String>(
                                  value: selectedDestinationAccountId,
                                  hint: const Text("Pilih akun QRIS tujuan", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: qrisFilteredOptions.map((a) => DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  )).toList(),
                                  onChanged: updateDestinationAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedDestinationAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
                                  )
                                else
                                  const SizedBox(height: 12),

                                _buildSectionHeader("Fee / Admin Toko (Rp)", Icons.payments_outlined),
                                TextField(
                                  controller: feeController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                  decoration: _buildInputDecoration("Fee Admin", hint: "0"),
                                ),
                                const SizedBox(height: 16),

                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Transaksi akan mengurangi kas dan menambah saldo QRIS. Fee akan ditambahkan ke kas.",
                                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Keterangan Catatan", Icons.note_outlined),
                                TextField(
                                  controller: descController,
                                  maxLines: 2,
                                  decoration: _buildInputDecoration("Tambahkan keterangan", hint: "Opsional"),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ]

                            // ============ PPOB ============
                            else if (isPPOB) ...[
                              _buildSectionHeader("Sumber Dana (E-Wallet)", Icons.arrow_upward),
                              DropdownButtonFormField<String>(
                                value: selectedSourceAccountId,
                                hint: const Text("Pilih akun e-wallet sumber", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                decoration: _buildInputDecoration(""),
                                items: ppobFilteredOptions.map((a) => DropdownMenuItem<String>(
                                  value: a['id'].toString(),
                                  child: _buildAccountDropdownItem(a),
                                )).toList(),
                                onChanged: updateSourceAccount,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedSourceAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
                                )
                              else
                                const SizedBox(height: 12),

                              _buildSectionHeader("Nomor Pelanggan / Tujuan PPOB", Icons.phone_android_rounded),
                              TextField(
                                controller: ppobTargetController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                decoration: _buildInputDecoration("No. HP / ID Pelanggan / VA tujuan", hint: "Contoh: 08123456xxx atau 5321xxx"),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildSectionHeader("Nominal Transaksi", Icons.monetization_on_outlined),
                              TextField(
                                controller: nominalController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                decoration: _buildInputDecoration("Nominal", hint: "0"),
                              ),
                              const SizedBox(height: 16),
                              
                            ]

                            // ============ PINDAH KAS ============
                            else if (widget.trxType == 'pindah kas') ...[
                              _buildSectionHeader("Sumber Kas Asal (Otomatis)", Icons.arrow_upward),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                child: Text("Uang Kas (Laci) - Saldo: Rp ${_formatIdr(cashLaciCurrent)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: nominalController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                decoration: _buildInputDecoration("Nominal Kas Yang Dikirim", hint: "0"),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildSectionHeader("Target Cabang Tujuan", Icons.arrow_downward),
                              DropdownButtonFormField<String>(
                                value: selectedTargetOutletId,
                                hint: const Text("Pilih lokasi cabang target", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                decoration: _buildInputDecoration(""),
                                items: outletOptions.map((o) => DropdownMenuItem<String>(
                                  value: o['id'].toString(),
                                  child: Text(o['nama_outlet'].toString(), style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (val) async {
                                  setState(() {
                                    selectedTargetOutletId = val;
                                    targetOutletCashBalance = 0;
                                  });
                                  if (val != null) {
                                    await fetchTargetOutletCashBalance(val);
                                  }
                                },
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedTargetOutletId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("Saldo Kas Tujuan: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      isLoadingTargetOutletCash ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : _buildBalanceChip(targetOutletCashBalance),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ]

                            // ============ TARIK TUNAI ============
                            else if (isTarikTunai) ...[
                              _buildSectionHeader("Sumber Dana (Otomatis)", Icons.arrow_upward),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                child: Text("Uang Kas (Laci) - Saldo: Rp ${_formatIdr(cashLaciCurrent)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: nominalController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                decoration: _buildInputDecoration("Nominal Tarik Tunai", hint: "0"),
                              ),
                              const SizedBox(height: 20),

                              _buildSectionHeader("Tujuan Penyimpanan Saldo", Icons.arrow_downward),
                              DropdownButtonFormField<String>(
                                value: selectedDestinationAccountId,
                                hint: const Text("Pilih akun bank penampung", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                decoration: _buildInputDecoration(""),
                                items: dropdownOptions.where((a) => a['id'] != 'cash_laci').map((a) => DropdownMenuItem<String>(
                                  value: a['id'].toString(),
                                  child: _buildAccountDropdownItem(a),
                                )).toList(),
                                onChanged: updateDestinationAccount,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedDestinationAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
                                )
                              else
                                const SizedBox(height: 12),
                            ]

                            // ============ SETORAN BRILINK ============
                            else if (isSetoranBrilink) ...[
                              _buildSetoranBrilinkForm(),
                            ]

                            // ============ PINDAH SALDO ============
                            else if (isPindahSaldo) ...[
                              _buildSectionHeader("Rekening Sumber Dana", Icons.arrow_upward),
                              DropdownButtonFormField<String>(
                                value: selectedSourceAccountId,
                                hint: const Text("Pilih bank/e-wallet asal", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                decoration: _buildInputDecoration(""),
                                items: pindahSaldoFilteredOptions.map((a) {
                                  return DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  );
                                }).toList(),
                                onChanged: updateSourceAccount,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedSourceAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
                                )
                              else
                                const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Kirim Saldo ke Outlet Lain?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  Switch(
                                    value: isTransferKeOutletLain,
                                    activeColor: primaryOrange,
                                    onChanged: (val) {
                                      setState(() {
                                        isTransferKeOutletLain = val;
                                        selectedDestinationAccountId = null;
                                        selectedTargetOutletId = null;
                                        targetOutletAccountsOptions.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (isTransferKeOutletLain) ...[
                                _buildSectionHeader("Cabang Outlet Penerima Dana", Icons.arrow_downward),
                                DropdownButtonFormField<String>(
                                  value: selectedTargetOutletId,
                                  hint: const Text("Pilih lokasi cabang target", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: outletOptions.map((o) => DropdownMenuItem<String>(
                                    value: o['id'].toString(),
                                    child: Text(o['nama_outlet'].toString(), style: const TextStyle(fontSize: 13)),
                                  )).toList(),
                                  onChanged: (val) {
                                    setState(() => selectedTargetOutletId = val);
                                    if (val != null) {
                                      fetchTargetOutletAccountsData(val);
                                    }
                                  },
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                const SizedBox(height: 16),

                                if (selectedTargetOutletId != null) ...[
                                  _buildSectionHeader("Rekening Bank Penerima di Outlet Tujuan", Icons.account_balance_wallet_rounded),
                                  isLoadingTargetAccounts 
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 10),
                                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: selectedDestinationAccountId,
                                          hint: const Text("Pilih bank penerima di outlet tujuan", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                          decoration: _buildInputDecoration(""),
                                          items: targetOutletAccountsOptions.map((a) {
                                            return DropdownMenuItem<String>(
                                              value: a['id'].toString(),
                                              child: _buildAccountDropdownItem(a),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              var selectedAccount = targetOutletAccountsOptions.firstWhere((element) => element['id'].toString() == val.toString());
                                              setState(() {
                                                selectedDestinationAccountId = val;
                                                currentDestinationBalance = double.tryParse(selectedAccount['balance'].toString()) ?? 0.0;
                                              });
                                            }
                                          },
                                          isExpanded: true,
                                          dropdownColor: Colors.white,
                                        ),
                                  if (selectedDestinationAccountId != null && !isLoadingTargetAccounts)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text("Saldo tersedia di tujuan: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          _buildBalanceChip(currentDestinationBalance)
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 16),
                                ],
                              ] else ...[
                                _buildSectionHeader("Rekening Tujuan Dana (Internal)", Icons.arrow_downward),
                                DropdownButtonFormField<String>(
                                  value: selectedDestinationAccountId,
                                  hint: const Text("Pilih bank/e-wallet target", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: pindahSaldoFilteredOptions.map((a) {
                                    return DropdownMenuItem<String>(
                                      value: a['id'].toString(),
                                      child: _buildAccountDropdownItem(a),
                                    );
                                  }).toList(),
                                  onChanged: updateDestinationAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedDestinationAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
                                  )
                                else
                                  const SizedBox(height: 12),
                              ],
                              
                              _buildSectionHeader("Nominal Saldo Yang Dipindahkan", Icons.monetization_on_outlined),
                              TextField(
                                controller: nominalController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                decoration: _buildInputDecoration("Nominal", hint: "0"),
                              ),
                              const SizedBox(height: 20),
                            ]

                            // ============ TRANSAKSI REGULER ============
                            else if (!isPengeluaranOperasional && !isBayarPiutang) ...[
                              _buildSectionHeader(
                                isSetoranBrilink ? "Rekening Berkurang" : "Sumber Dana",
                                Icons.arrow_upward
                              ),
                              DropdownButtonFormField<String>(
                                value: selectedSourceAccountId,
                                hint: Text(
                                  isSetoranBrilink ? "Pilih rekening yang akan berkurang" : "Pilih akun sumber",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)
                                ),
                                decoration: _buildInputDecoration(""),
                                items: dropdownOptions.map((a) => DropdownMenuItem<String>(
                                  value: a['id'].toString(),
                                  child: _buildAccountDropdownItem(a),
                                )).toList(),
                                onChanged: updateSourceAccount,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedSourceAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
                                )
                              else
                                const SizedBox(height: 12),

                              _buildSectionHeader(
                                isSetoranBrilink ? "Tujuan Penyimpanan Saldo" : "Tujuan Dana",
                                Icons.arrow_downward
                              ),
                              DropdownButtonFormField<String>(
                                value: selectedDestinationAccountId,
                                hint: Text(
                                  isSetoranBrilink ? "Pilih akun tujuan penyimpanan" : "Pilih akun tujuan",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)
                                ),
                                decoration: _buildInputDecoration(""),
                                items: dropdownOptions.map((a) => DropdownMenuItem<String>(
                                  value: a['id'].toString(),
                                  child: _buildAccountDropdownItem(a),
                                )).toList(),
                                onChanged: updateDestinationAccount,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                              if (selectedDestinationAccountId != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentDestinationBalance)]),
                                )
                              else
                                const SizedBox(height: 12),
                              
                              _buildSectionHeader(
                                isSetoranBrilink ? "Nominal Setoran" : "Nominal Transaksi",
                                Icons.monetization_on_outlined
                              ),
                              TextField(
                                controller: nominalController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                decoration: _buildInputDecoration(
                                  isSetoranBrilink ? "Nominal Setoran" : "Nominal Transaksi",
                                  hint: "0"
                                ),
                              ),
                              const SizedBox(height: 20),
                            ]

                            // ============ PENGELUARAN OPERASIONAL ============
                            else if (isPengeluaranOperasional) ...[
                              _buildSectionHeader("Jenis Pengeluaran", Icons.category_rounded),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedPengeluaranType = 'operasional';
                                            selectedKategoriId = null;
                                            selectedKategoriName = null;
                                            fetchKategoriPengeluaran();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selectedPengeluaranType == 'operasional' 
                                                ? Colors.red.shade700 
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.business_center_rounded,
                                                color: selectedPengeluaranType == 'operasional' 
                                                    ? Colors.white 
                                                    : Colors.grey.shade600,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "OPERASIONAL",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: selectedPengeluaranType == 'operasional' 
                                                      ? Colors.white 
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedPengeluaranType = 'beban_toko';
                                            selectedKategoriId = null;
                                            selectedKategoriName = null;
                                            fetchKategoriPengeluaran();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selectedPengeluaranType == 'beban_toko' 
                                                ? Colors.orange.shade700 
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.storefront_rounded,
                                                color: selectedPengeluaranType == 'beban_toko' 
                                                    ? Colors.white 
                                                    : Colors.grey.shade600,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "BEBAN TOKO",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: selectedPengeluaranType == 'beban_toko' 
                                                      ? Colors.white 
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildSectionHeader(
                                "Kategori ${getPengeluaranTypeLabel(selectedPengeluaranType ?? 'operasional')}",
                                Icons.label_rounded
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: isLoadingKategori
                                        ? Container(
                                            height: 50,
                                            alignment: Alignment.center,
                                            child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                          )
                                        : DropdownButtonFormField<String>(
                                            value: selectedKategoriId,
                                            hint: Text("Pilih kategori", style: TextStyle(fontSize: 13)),
                                            decoration: _buildInputDecoration(""),
                                            items: kategoriList.map((k) {
                                              return DropdownMenuItem<String>(
                                                value: k['id'].toString(),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.label_rounded, size: 14, color: primaryBlue),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        k['nama_kategori'].toString(),
                                                        style: const TextStyle(fontSize: 13),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                var selected = kategoriList.firstWhere((k) => k['id'].toString() == val);
                                                setState(() {
                                                  selectedKategoriId = val;
                                                  selectedKategoriName = selected['nama_kategori'].toString();
                                                });
                                              }
                                            },
                                            isExpanded: true,
                                            dropdownColor: Colors.white,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 50,
                                    width: 46,
                                    decoration: BoxDecoration(
                                      color: selectedPengeluaranType == 'operasional' 
                                          ? Colors.red.shade700 
                                          : Colors.orange.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                                      onPressed: showAddKategoriDialog,
                                      tooltip: "Tambah Kategori",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (selectedKategoriId != null)
                                    Container(
                                      height: 50,
                                      width: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 20),
                                        onPressed: isDeletingKategori 
                                            ? null 
                                            : () => deleteKategoriPengeluaran(selectedKategoriId!, selectedKategoriName ?? ''),
                                        tooltip: "Hapus Kategori",
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (isTopupEwallet) ...[
                                _buildSectionHeader("Sumber Dana", Icons.arrow_upward),
                                DropdownButtonFormField<String>(
                                  value: selectedSourceAccountId,
                                  hint: Text("Pilih akun sumber dana", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: dropdownOptions.map((a) => DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  )).toList(),
                                  onChanged: updateSourceAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedSourceAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
                                  )
                                else
                                  const SizedBox(height: 12),

                                _buildSectionHeader("Akun E-Wallet Tujuan", Icons.phone_android_rounded),
                                DropdownButtonFormField<String>(
                                  value: selectedTopupAccountId,
                                  hint: Text("Pilih akun E-Wallet yang akan di-topup", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: ewalletOptions.map((a) => DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  )).toList(),
                                  onChanged: updateTopupAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedTopupAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text("Saldo E-Wallet: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        _buildBalanceChip(currentTopupBalance)
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox(height: 12),

                                _buildSectionHeader("Nominal Topup", Icons.monetization_on_outlined),
                                TextField(
                                  controller: nominalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                  decoration: _buildInputDecoration("Nominal Topup", hint: "0"),
                                ),
                                const SizedBox(height: 16),

                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Topup akan mengurangi saldo sumber dan menambah saldo E-Wallet tujuan.",
                                          style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildSectionHeader("Keterangan", Icons.note_add_rounded),
                                TextField(
                                  controller: descController,
                                  maxLines: 2,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                  decoration: _buildInputDecoration("Keterangan", hint: "Contoh: Topup DANA untuk pembelian"),
                                ),
                                const SizedBox(height: 16),

                              ] else ...[
                                _buildSectionHeader("Sumber Dana", Icons.arrow_upward),
                                DropdownButtonFormField<String>(
                                  value: selectedSourceAccountId,
                                  hint: Text("Pilih akun sumber dana", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                  decoration: _buildInputDecoration(""),
                                  items: dropdownOptions.map((a) => DropdownMenuItem<String>(
                                    value: a['id'].toString(),
                                    child: _buildAccountDropdownItem(a),
                                  )).toList(),
                                  onChanged: updateSourceAccount,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                ),
                                if (selectedSourceAccountId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildBalanceChip(currentSourceBalance)]),
                                  )
                                else
                                  const SizedBox(height: 12),
                                
                                _buildSectionHeader("Nominal ${getPengeluaranTypeLabel(selectedPengeluaranType ?? 'operasional')}", Icons.monetization_on_outlined),
                                TextField(
                                  controller: nominalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [CurrencyInputFormatter()],
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                  decoration: _buildInputDecoration("Nominal", hint: "0"),
                                ),
                                const SizedBox(height: 20),
                                
                                _buildSectionHeader("Keterangan Pengeluaran", Icons.note_add_rounded),
                                TextField(
                                  controller: descController,
                                  maxLines: 2,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                  decoration: _buildInputDecoration("Keterangan", hint: "Contoh: Beli ATK, Bayar Listrik, dll"),
                                ),
                                const SizedBox(height: 16),
                                
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selectedPengeluaranType == 'operasional' 
                                        ? Colors.red.shade50 
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedPengeluaranType == 'operasional' 
                                          ? Colors.red.shade200 
                                          : Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: selectedPengeluaranType == 'operasional' 
                                            ? Colors.red.shade700 
                                            : Colors.orange.shade700,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          selectedPengeluaranType == 'operasional'
                                              ? "Pengeluaran operasional akan mengurangi saldo dari sumber dana yang dipilih."
                                              : "Pengeluaran beban toko akan mengurangi saldo dari sumber dana yang dipilih.",
                                          style: TextStyle(
                                            color: selectedPengeluaranType == 'operasional' 
                                                ? Colors.red.shade700 
                                                : Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ]

                            // ============ BAYAR PIUTANG / HUTANG ============
                            else if (isBayarPiutang) ...[
                              // ============ TAB PIUTANG / HUTANG ============
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedTabIndex = 0;
                                            selectedPeminjam = null;
                                            selectedPiutangData = null;
                                            selectedPiutangId = null;
                                            selectedPeminjamHutang = null;
                                            selectedHutangData = null;
                                            selectedHutangId = null;
                                            nominalController.clear();
                                            if (piutangAdminList.isEmpty) {
                                              fetchPiutangAdmin();
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: _selectedTabIndex == 0
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.account_balance_rounded,
                                                size: 18,
                                                color: _selectedTabIndex == 0 ? Colors.orange.shade700 : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Piutang",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: _selectedTabIndex == 0 ? Colors.orange.shade700 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedTabIndex = 1;
                                            selectedPeminjam = null;
                                            selectedPiutangData = null;
                                            selectedPiutangId = null;
                                            selectedPeminjamHutang = null;
                                            selectedHutangData = null;
                                            selectedHutangId = null;
                                            nominalController.clear();
                                            if (hutangAdminList.isEmpty) {
                                              fetchHutangAdmin();
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: _selectedTabIndex == 1
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.account_balance_rounded,
                                                size: 18,
                                                color: _selectedTabIndex == 1 ? Colors.red.shade700 : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Hutang",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: _selectedTabIndex == 1 ? Colors.red.shade700 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ============ CONTENT PIUTANG ============
                              if (_selectedTabIndex == 0) ...[
                                // Pilih Peminjam Piutang
                                _buildSectionHeader("Pilih Peminjam Piutang", Icons.person_search_rounded),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: isLoadingPiutangAdmin
                                            ? const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(vertical: 20),
                                                  child: CircularProgressIndicator(),
                                                ),
                                              )
                                            : DropdownButtonFormField<String>(
                                                value: selectedPeminjam,
                                                hint: Text(
                                                  "Pilih nama peminjam",
                                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: Colors.grey.shade50,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: primaryBlue, width: 2),
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                ),
                                                items: [
                                                  const DropdownMenuItem<String>(
                                                    value: null,
                                                    child: Text("Pilih Peminjam"),
                                                  ),
                                                  ...uniquePeminjamList.map((peminjam) {
                                                    return DropdownMenuItem<String>(
                                                      value: peminjam,
                                                      child: Text(
                                                        peminjam,
                                                        style: const TextStyle(fontSize: 14),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                                onChanged: selectPeminjam,
                                                isExpanded: true,
                                                dropdownColor: Colors.white,
                                                icon: Icon(Icons.arrow_drop_down_rounded, color: primaryBlue),
                                              ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          minimumSize: const Size(44, 44),
                                          elevation: 2,
                                        ),
                                        onPressed: _showCreatePiutangDialog,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.add_rounded, size: 20),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Baru",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // ============ TAMPILAN TOTAL PIUTANG ============
                                if (selectedPeminjam != null && selectedPeminjamPiutangList.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Peminjam",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              selectedPeminjam ?? '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Divider(color: Colors.orange.shade200),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "TOTAL PIUTANG (Semua)",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              "Rp ${_formatIdr(totalPiutang)}",  // TOTAL SEMUA PIUTANG
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Sisa Piutang (Belum Lunas)",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              "Rp ${_formatIdr(sisaPiutang)}",  // SISA YANG BELUM LUNAS
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: sisaPiutang > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Jumlah Piutang",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              "${selectedPeminjamPiutangList.length} Piutang",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Pembayaran Piutang",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Colors.orange.shade800,
                                                ),
                                              ),
                                              Text(
                                                "Pembayaran akan mengurangi sisa piutang dan menambah saldo akun tujuan.",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // ============ NOMINAL PEMBAYARAN ============
                                  _buildSectionHeader("Nominal Pembayaran", Icons.monetization_on_outlined),
                                  TextField(
                                    controller: nominalController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [CurrencyInputFormatter()],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600, 
                                      color: Colors.grey.shade900, 
                                      fontSize: 15
                                    ),
                                    decoration: _buildInputDecoration(
                                      "Nominal Pembayaran (Maks Rp ${_formatIdr(sisaPiutang)})",
                                      hint: "0"
                                    ),
                                    onChanged: (value) {
                                      String clean = value.replaceAll('.', '');
                                      double nominal = double.tryParse(clean) ?? 0;
                                      if (nominal > sisaPiutang && sisaPiutang > 0) {
                                        nominalController.text = _formatIdr(sisaPiutang);
                                        showSnackBar("Nominal tidak boleh melebihi sisa piutang!", isError: true);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // ============ TUJUAN PENYIMPANAN SALDO ============
                                  _buildSectionHeader("Tujuan Penyimpanan Saldo", Icons.account_balance_wallet_rounded),
                                  DropdownButtonFormField<String>(
                                    value: selectedDestinationAccountId,
                                    hint: Text(
                                      "Pilih akun tujuan penyimpanan",
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.green, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    items: dropdownOptions.map((a) {
                                      String category = a['category']?.toString().toLowerCase() ?? '';
                                      // TAMPILKAN SEMUA AKUN termasuk cash_laci
                                      return DropdownMenuItem<String>(
                                        value: a['id'].toString(),
                                        child: _buildAccountDropdownItem(a),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == 'cash_laci' || value == '0') {
                                        // Jika memilih Kas Laci, set destination_account_id ke null
                                        setState(() {
                                          selectedDestinationAccountId = 'cash_laci';
                                          currentDestinationBalance = cashLaciCurrent;
                                        });
                                      } else {
                                        updateDestinationAccount(value);
                                      }
                                    },
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                  ),
                                  if (selectedDestinationAccountId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text("Saldo tersedia: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          _buildBalanceChip(
                                            selectedDestinationAccountId == 'cash_laci' 
                                                ? cashLaciCurrent 
                                                : currentDestinationBalance
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 12),
                                  
                                  // ============ METODE PEMBAYARAN ============
                                  _buildSectionHeader("Metode Pembayaran", Icons.payment_rounded),
                                  DropdownButtonFormField<String>(
                                    value: selectedMetode,
                                    hint: Text(
                                      "Pilih Metode",
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.green, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'cash', child: Text("Cash")),
                                      DropdownMenuItem(value: 'transfer', child: Text("Transfer")),
                                      DropdownMenuItem(value: 'ewallet', child: Text("E-Wallet")),
                                      DropdownMenuItem(value: 'lainnya', child: Text("Lainnya")),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedMetode = value ?? 'cash';
                                      });
                                    },
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // ============ KETERANGAN ============
                                  _buildSectionHeader("Keterangan", Icons.note_add_rounded),
                                  TextField(
                                    controller: descController,
                                    maxLines: 2,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                    decoration: _buildInputDecoration("Keterangan (Opsional)", hint: "Catatan pembayaran"),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // ============ TOMBOL BAYAR (HANYA 1 TOMBOL) ============
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: isSubmitting ? null : _prosesBayarPiutang,
                                      child: isSubmitting
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.payments_rounded, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Bayar",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // ============ TOMBOL EXPORT PDF ============
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.red.shade700),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _exportPdfTagihanPiutang,
                                      icon: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 20),
                                      label: Text(
                                        "Export PDF Tagihan",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                
                                // ============ TAMPILKAN PESAN JIKA BELUM PILIH PEMINJAM ============
                                if (selectedPeminjam == null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Pilih peminjam untuk memulai",
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          "Data piutang akan muncul setelah memilih peminjam",
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],

                              // ============ CONTENT HUTANG ============
                              if (_selectedTabIndex == 1) ...[
                                // ============ CEK OUTLET PUSAT ============
                                if (!isOutletPusat) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "Fitur Hutang hanya tersedia untuk outlet tipe PUSAT",
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  // ============ PILIH PEMINJAM HUTANG ============
                                  _buildSectionHeader("Pilih Peminjam Hutang", Icons.person_search_rounded),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: isLoadingHutangAdmin
                                              ? const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 20),
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                )
                                              : DropdownButtonFormField<String>(
                                                  value: selectedPeminjamHutang,
                                                  hint: Text(
                                                    "Pilih nama peminjam",
                                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                                  ),
                                                  decoration: InputDecoration(
                                                    filled: true,
                                                    fillColor: Colors.grey.shade50,
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      borderSide: BorderSide(color: primaryBlue, width: 2),
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                  ),
                                                  items: [
                                                    const DropdownMenuItem<String>(
                                                      value: null,
                                                      child: Text("Pilih Peminjam"),
                                                    ),
                                                    ...uniquePeminjamHutangList.map((peminjam) {
                                                      return DropdownMenuItem<String>(
                                                        value: peminjam,
                                                        child: Text(
                                                          peminjam,
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                  onChanged: selectPeminjamHutang,
                                                  isExpanded: true,
                                                  dropdownColor: Colors.white,
                                                  icon: Icon(Icons.arrow_drop_down_rounded, color: primaryBlue),
                                                ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade700,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            minimumSize: const Size(44, 44),
                                            elevation: 2,
                                          ),
                                          onPressed: _showCreateHutangDialog,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.add_rounded, size: 20),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Baru",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // ============ TAMPILAN TOTAL HUTANG ============
                                  if (selectedPeminjamHutang != null && selectedHutangBulkList.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Peminjam",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                selectedPeminjamHutang ?? '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Divider(color: Colors.red.shade200),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Total Hutang",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                "Rp ${_formatIdr(totalHutang)}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Sisa Hutang",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                "Rp ${_formatIdr(sisaHutang)}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: sisaHutang > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Jumlah Hutang",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Text(
                                                "${selectedHutangBulkList.length} Hutang",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded, color: Colors.red.shade700, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Pembayaran Hutang",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: Colors.red.shade800,
                                                  ),
                                                ),
                                                Text(
                                                  "Pembayaran akan mengurangi semua sisa hutang dan mengurangi saldo sumber dana yang dipilih.",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // ============ NOMINAL PEMBAYARAN ============
                                    _buildSectionHeader("Nominal Pembayaran", Icons.monetization_on_outlined),
                                    TextField(
                                      controller: nominalController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600, 
                                        color: Colors.grey.shade900, 
                                        fontSize: 15
                                      ),
                                      decoration: _buildInputDecoration(
                                        "Nominal Pembayaran (Maks Rp ${_formatIdr(sisaHutang)})",
                                        hint: "0"
                                      ),
                                      onChanged: (value) {
                                        String clean = value.replaceAll('.', '');
                                        double nominal = double.tryParse(clean) ?? 0;
                                        if (nominal > sisaHutang && sisaHutang > 0) {
                                          nominalController.text = _formatIdr(sisaHutang);
                                          showSnackBar("Nominal tidak boleh melebihi sisa hutang!", isError: true);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // ============ SUMBER DANA (UNTUK HUTANG) ============
                                    _buildSectionHeader("Sumber Dana", Icons.arrow_upward),
                                    DropdownButtonFormField<String>(
                                      value: selectedSourceAccountId,
                                      hint: Text(
                                        "Pilih sumber dana untuk membayar hutang",
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: [
                                        // ============ TAMBAHKAN OPSI KAS LACI ============
                                        const DropdownMenuItem<String>(
                                          value: 'cash_laci',
                                          child: Text("Uang Kas (Laci)", style: TextStyle(fontSize: 13)),
                                        ),
                                        // ============ AKUN LAINNYA ============
                                        ...dropdownOptions
                                            .where((a) => a['id'] != 'cash_laci')
                                            .map((a) => DropdownMenuItem<String>(
                                              value: a['id'].toString(),
                                              child: _buildAccountDropdownItem(a),
                                            ))
                                            .toList(),
                                      ],
                                      onChanged: (value) {
                                        if (value == 'cash_laci' || value == '0') {
                                          setState(() {
                                            selectedSourceAccountId = 'cash_laci';
                                            currentSourceBalance = cashLaciCurrent;
                                          });
                                        } else {
                                          updateSourceAccount(value);
                                        }
                                      },
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                    ),
                                    if (selectedSourceAccountId != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text("Saldo tersedia: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                            _buildBalanceChip(
                                              selectedSourceAccountId == 'cash_laci' 
                                                  ? cashLaciCurrent 
                                                  : currentSourceBalance
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 12),
                                    
                                    // ============ METODE PEMBAYARAN ============
                                    _buildSectionHeader("Metode Pembayaran", Icons.payment_rounded),
                                    DropdownButtonFormField<String>(
                                      value: selectedMetode,
                                      hint: Text(
                                        "Pilih Metode",
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'cash', child: Text("Cash")),
                                        DropdownMenuItem(value: 'transfer', child: Text("Transfer")),
                                        DropdownMenuItem(value: 'ewallet', child: Text("E-Wallet")),
                                        DropdownMenuItem(value: 'lainnya', child: Text("Lainnya")),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMetode = value ?? 'cash';
                                        });
                                      },
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // ============ KETERANGAN ============
                                    _buildSectionHeader("Keterangan", Icons.note_add_rounded),
                                    TextField(
                                      controller: descController,
                                      maxLines: 2,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      decoration: _buildInputDecoration("Keterangan (Opsional)", hint: "Catatan pembayaran"),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // ============ TOMBOL BAYAR HUTANG ============
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 2,
                                        ),
                                        onPressed: isSubmitting ? null : _prosesBayarHutang,
                                        child: isSubmitting
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.payments_rounded, size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    selectedHutangBulkList.length > 1
                                                        ? "Bayar Hutang"
                                                        : "Bayar Hutang",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                  ] else if (selectedPeminjamHutang == null) ...[
                                    // ============ TAMPILKAN PESAN PILIH PEMINJAM ============
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Pilih peminjam untuk memulai",
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "Data hutang akan muncul setelah memilih peminjam",
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              ],
                            ],

                            if (showFeeField && !isQRIS && !isTopupEwallet) ...[
                              _buildSectionHeader("Fee / Profit Admin (Rp)", Icons.payments_outlined),
                              TextField(
                                controller: feeController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900, fontSize: 15),
                                decoration: _buildInputDecoration("Fee", hint: "0"),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ============ TOMBOL SIMPAN ============
                            if (!isBayarPiutang) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPengeluaranOperasional 
                                        ? (isTopupEwallet 
                                            ? Colors.blue.shade700 
                                            : (selectedPengeluaranType == 'operasional' 
                                                ? Colors.red.shade700 
                                                : Colors.orange.shade700))
                                        : (isSetoranBrilink ? const Color(0xFF2E7D32) : primaryBlue),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                  ),
                                  onPressed: isSubmitting ? null : submitTransaction,
                                  child: isSubmitting
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isPengeluaranOperasional 
                                                  ? (isTopupEwallet 
                                                      ? "Topup E-Wallet" 
                                                      : "Simpan ${getPengeluaranTypeLabel(selectedPengeluaranType ?? 'operasional')}")
                                                  : (isSetoranBrilink ? "Simpan Setoran" : "Simpan Transaksi"),
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isPengeluaranOperasional 
                                                  ? (isTopupEwallet 
                                                      ? Icons.phone_android_rounded 
                                                      : (selectedPengeluaranType == 'operasional'
                                                          ? Icons.money_off_rounded
                                                          : Icons.storefront_rounded))
                                                  : (isSetoranBrilink ? Icons.assignment_returned_rounded : Icons.arrow_forward_rounded),
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    
    String formatted = cleanText.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.'
    );
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}