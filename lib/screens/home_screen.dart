import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'buka_kas_screen.dart';
import '../widgets/sidebar.dart';
import 'input_transaction_screen.dart';
import 'log_transaksi_screen.dart';
import 'PosScreen.dart';
import 'KirimProdukScreen.dart';
import 'FeeBrilinkDailyScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> { 
  final String baseUrl = "https://barokahsport.com/brilink";
  
  bool isLoading = true;
  String sessionStatus = "none";
  int? sessionId;
  String namaKaryawan = "";

  int myOutletId = 1;
  String namaOutlet = "";
  String tipeOutlet = "cabang"; 

  final TextEditingController cashClosingController = TextEditingController();

  double cashOpeningSummary = 0;
  double cashClosingSummary = 0;
  double omsetKasirPPOB = 0;
  
  // ============ NOTIFIKASI PRODUK ============
  int pendingKirimCount = 0;
  bool isLoadingNotif = false;
  // =========================================

  // ============ NOTIFIKASI KAS MASUK ============
  int pendingKasMasukCount = 0;
  bool isLoadingKasNotif = false;
  List<dynamic> kasMasukList = [];
  // ============================================

  // ============ NOTIFIKASI PENAMBAHAN SALDO ============
  int pendingSaldoMasukCount = 0;
  bool isLoadingSaldoNotif = false;
  List<dynamic> saldoMasukList = [];
  // ====================================================

  // ============ QRIS DIBAGI 2 ============
  double saldoQRIS = 0;
  double tarikQRIS = 0;
  // =====================================
  
  double totalTarikEDC = 0;
  double totalTarikMBanking = 0;
  double totalSetoranBRILink = 0;
  double totalPendapatanFee = 0;
  double totalSelisihAkuntansi = 0;
  double totalPengeluaranOperasional = 0;
  double totalPOS = 0;
  double totalBayarPiutang = 0;
  
  double totalKMC = 0;

  double totalPindahSaldo = 0;
  double totalPindahKas = 0;

  List<dynamic> recentTransactions = [];

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  final Color kmcColor = const Color(0xFF00A86B);

  final List<Map<String, dynamic>> menuTransaksi = [
    {"title": "Tarik Tunai EDC", "icon": Icons.credit_card_rounded, "color": const Color(0xFF00529C), "type": "tarik tunai edc"},
    {"title": "Tarik Tunai M-Banking", "icon": Icons.phone_android_rounded, "color": const Color(0xFF1A6FB0), "type": "tarik tunai mbanking"},
    {"title": "Setoran BRILink", "icon": Icons.assignment_returned_rounded, "color": const Color(0xFF2E7D32), "type": "setoran brilink"},
    {"title": "PPOB (Pulsa/PLN)", "icon": Icons.receipt_long_rounded, "color": const Color(0xFFF26A25), "type": "PPOB"},
    {"title": "QRIS Merchant", "icon": Icons.qr_code_2_rounded, "color": const Color(0xFF7B1FA2), "type": "qris"},
    {"title": "Hutang & Piutang", "icon": Icons.payments_rounded, "color": const Color(0xFF2E7D32), "type": "bayar piutang"},
    {"title": "Penambahan Saldo", "icon": Icons.currency_exchange_rounded, "color": const Color(0xFF00838F), "type": "pindah saldo"},
    {"title": "Pindah Kas Outlet", "icon": Icons.local_shipping_rounded, "color": const Color(0xFFE65100), "type": "pindah kas"},
    {"title": "Pengeluaran", "icon": Icons.money_off_rounded, "color": const Color(0xFFD32F2F), "type": "pengeluaran operasional"},
    {"title": "Point of Sale (POS)", "icon": Icons.shopping_cart_rounded, "color": const Color(0xFF6C3483), "type": "pos"},
  ];

  @override
  void initState() {
    super.initState();
    // HAPUS: WidgetsBinding.instance.addObserver(this);
    loadUserDataAndSession();
  }

  @override
  void dispose() {
    // HAPUS: WidgetsBinding.instance.removeObserver(this);
    cashClosingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkTodaySession();
      cekNotifikasiProdukMasuk();
      cekNotifikasiKasMasuk();
      cekNotifikasiSaldoMasuk();
    }
  }

  // ============ FUNGSI REFRESH SEMUA DATA ============
  Future<void> refreshAllData() async {
    await checkTodaySession();
    await cekNotifikasiProdukMasuk();
    await cekNotifikasiKasMasuk();
    await cekNotifikasiSaldoMasuk();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Data berhasil di-refresh"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          backgroundColor: primaryBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // ====================================================

  Future<void> loadUserDataAndSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      namaKaryawan = prefs.getString('nama_karyawan') ?? "Kasir";
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      namaOutlet = prefs.getString('nama_outlet') ?? "Memuat nama outlet...";
      tipeOutlet = prefs.getString('tipe_outlet') ?? "cabang"; 
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/get_outlets.php?id=$myOutletId"));
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true && (data['data'] as List).isNotEmpty) {
        String nameResult = data['data'][0]['nama_outlet'].toString();
        String typeResult = data['data'][0]['type'].toString(); 
        
        setState(() {
          namaOutlet = nameResult;
          tipeOutlet = typeResult;
        });

        await prefs.setString('nama_outlet', nameResult);
        await prefs.setString('tipe_outlet', typeResult);
      }
    } catch (e) {
      print("Gagal sinkronisasi nama dan tipe outlet: $e");
    }

    // ============ CEK NOTIFIKASI ============
    await cekNotifikasiProdukMasuk();
    await cekNotifikasiKasMasuk();
    await cekNotifikasiSaldoMasuk();
    // =======================================

    checkTodaySession();
  }

  Future<void> checkTodaySession() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/check_session.php?outlet_id=$myOutletId"));
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        if (data['has_session'] == true) {
          sessionStatus = data['session_status'];
          sessionId = int.parse(data['data']['id'].toString());
          await fetchRecentTransactions();
        } else {
          sessionStatus = "none";
          sessionId = null;
          recentTransactions.clear();
        }
      }

      final summaryResponse = await http.get(Uri.parse("$baseUrl/get_today_summary.php?outlet_id=$myOutletId"));
      final summaryData = json.decode(summaryResponse.body);

      if (summaryResponse.statusCode == 200 && summaryData['status'] == true) {
        var sData = summaryData['data'];
        setState(() {
          cashOpeningSummary = double.tryParse(sData['cash_opening'].toString()) ?? 0;
          cashClosingSummary = double.tryParse(sData['cash_closing'].toString()) ?? 0;
          omsetKasirPPOB = double.tryParse(sData['omset_ppob'].toString()) ?? 0;
          
          double totalQris = double.tryParse(sData['omset_qris'].toString()) ?? 0;
          tarikQRIS = double.tryParse(sData['tarik_qris']?.toString() ?? '0') ?? 0;
          saldoQRIS = totalQris - tarikQRIS;
          
          totalTarikEDC = double.tryParse(sData['tarik_edc'].toString()) ?? 0;
          totalTarikMBanking = double.tryParse(sData['tarik_mbanking'].toString()) ?? 0;
          totalSetoranBRILink = double.tryParse(sData['setoran_brilink'].toString()) ?? 0;
          totalPendapatanFee = double.tryParse(sData['total_fee'].toString()) ?? 0;
          totalSelisihAkuntansi = double.tryParse(sData['selisih'].toString()) ?? 0;
          totalPengeluaranOperasional = double.tryParse(sData['total_pengeluaran']?.toString() ?? '0') ?? 0;
          totalPOS = double.tryParse(sData['total_pos']?.toString() ?? '0') ?? 0;
          totalBayarPiutang = double.tryParse(sData['total_bayar_piutang']?.toString() ?? '0') ?? 0;
          
          totalKMC = double.tryParse(sData['total_kmc']?.toString() ?? '0') ?? 0;
          
          totalPindahSaldo = double.tryParse(sData['total_pindah_saldo']?.toString() ?? '0') ?? 0;
          totalPindahKas = double.tryParse(sData['total_pindah_kas']?.toString() ?? '0') ?? 0;
        });
      } else {
        _resetSummaryState();
      }
    } catch (e) {
      showSnackBar("Gagal memuat status sesi dashboard: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ============ FUNGSI CEK NOTIFIKASI PRODUK MASUK ============
  Future<void> cekNotifikasiProdukMasuk() async {
    if (tipeOutlet != 'cabang') return;
    
    setState(() => isLoadingNotif = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_kirim_produk.php?outlet_id=$myOutletId&status=dikirim"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        setState(() {
          pendingKirimCount = list.length;
        });
      }
    } catch (e) {
      print("Gagal cek notifikasi produk: $e");
      setState(() => pendingKirimCount = 0);
    } finally {
      setState(() => isLoadingNotif = false);
    }
  }
  // ============================================================

  // ============ FUNGSI CEK NOTIFIKASI KAS MASUK ============
  Future<void> cekNotifikasiKasMasuk() async {
    if (sessionId == null || sessionId == 0) return;
    
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_tambahan_kas_notif.php?outlet_id=$myOutletId&session_id=$sessionId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            kasMasukList = list;
            pendingKasMasukCount = list.length;
          });
        }
        if (list.isNotEmpty) {
          checkTodaySession();
        }
      }
    } catch (e) {
      print("Gagal cek notifikasi kas masuk: $e");
      if (mounted) {
        setState(() {
          kasMasukList = [];
          pendingKasMasukCount = 0;
        });
      }
    }
  }
  
  Future<void> closeKasNotifikasi() async {
    if (kasMasukList.isEmpty) return;
    
    try {
      List<int> notifIds = kasMasukList.map((item) => int.parse(item['id'].toString())).toList();
      
      final response = await http.post(
        Uri.parse("$baseUrl/update_tambahan_kas_notif.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "notif_ids": notifIds,
          "outlet_id": myOutletId,
          "session_id": sessionId
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        print("Notifikasi kas berhasil ditutup: ${data['updated']} record");
        setState(() {
          pendingKasMasukCount = 0;
          kasMasukList = [];
        });
      }
    } catch (e) {
      print("Error close notifikasi kas: $e");
    }
  }
  // ============================================================

  // ============ FUNGSI CEK NOTIFIKASI PENAMBAHAN SALDO ============
  Future<void> cekNotifikasiSaldoMasuk() async {
    if (sessionId == null || sessionId == 0) return;
    
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_tambahan_saldo_notif.php?outlet_id=$myOutletId&session_id=$sessionId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            saldoMasukList = list;
            pendingSaldoMasukCount = list.length;
          });
        }
        if (list.isNotEmpty) {
          checkTodaySession();
        }
      }
    } catch (e) {
      print("Gagal cek notifikasi saldo masuk: $e");
      if (mounted) {
        setState(() {
          saldoMasukList = [];
          pendingSaldoMasukCount = 0;
        });
      }
    }
  }
  
  Future<void> closeSaldoNotifikasi() async {
    if (saldoMasukList.isEmpty) return;
    
    try {
      List<int> notifIds = saldoMasukList.map((item) => int.parse(item['id'].toString())).toList();
      
      final response = await http.post(
        Uri.parse("$baseUrl/update_tambahan_saldo_notif.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "notif_ids": notifIds,
          "outlet_id": myOutletId,
          "session_id": sessionId
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        print("Notifikasi saldo berhasil ditutup: ${data['updated']} record");
        setState(() {
          pendingSaldoMasukCount = 0;
          saldoMasukList = [];
        });
      }
    } catch (e) {
      print("Error close notifikasi saldo: $e");
    }
  }
  // ================================================================

  Future<void> fetchRecentTransactions() async {
    if (sessionId == null) return;
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_session_transactions.php?session_id=$sessionId&outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> allTrx = data['data'] ?? [];
        setState(() {
          recentTransactions = allTrx.take(3).toList();
        });
      }
    } catch (e) {
      print("Gagal memuat preview transaksi di home screen: $e");
    }
  }

  void _resetSummaryState() {
    setState(() {
      cashOpeningSummary = 0;
      cashClosingSummary = 0;
      omsetKasirPPOB = 0;
      saldoQRIS = 0;
      tarikQRIS = 0;
      totalTarikEDC = 0;
      totalTarikMBanking = 0;
      totalSetoranBRILink = 0;
      totalPendapatanFee = 0;
      totalSelisihAkuntansi = 0;
      totalPengeluaranOperasional = 0;
      totalPOS = 0;
      totalBayarPiutang = 0;
      totalKMC = 0;
      totalPindahSaldo = 0;
      totalPindahKas = 0;
      recentTransactions.clear();
    });
  }

  Future<void> closeSession() async {
    if (cashClosingController.text.isEmpty) {
      showSnackBar("Masukkan nominal kas akhir laci!");
      return;
    }

    String cleanNominal = cashClosingController.text.replaceAll('.', '');

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/close_session.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": sessionId,
          "outlet_id": myOutletId,
          "cash_closing": double.parse(cleanNominal),
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("Sesi harian resmi ditutup!");
        setState(() {
          sessionStatus = "closed";
        });
        if (!mounted) return;
        Navigator.pop(context);
        checkTodaySession();
      } else {
        showSnackBar(data['message'] ?? "Gagal menutup sesi");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    }
  }

  void showCloseSessionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.lock_clock, color: primaryOrange, size: 24),
              const SizedBox(width: 10),
              const Text("Tutup Sesi Harian", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Hitung fisik uang di laci Anda, lalu masukkan total kas akhir untuk menutup pembukuan hari ini:",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: cashClosingController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  label: const Text("Total Kas Akhir (Rp)"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixText: "Rp ",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("BATAL", style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: closeSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("TUTUP SESI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        backgroundColor: primaryBlue,
      ),
    );
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  Color _getTrxColor(String type) {
    String t = type.toLowerCase().trim();
    if (t.contains('qris')) return const Color(0xFF7B1FA2); 
    if (t.contains('edc')) return primaryBlue;
    if (t.contains('mbanking')) return const Color(0xFF1A6FB0);
    if (t.contains('setoran')) return const Color(0xFF2E7D32);
    if (t.contains('ppob')) return primaryOrange;
    if (t.contains('pindah saldo')) return const Color(0xFF00838F);
    if (t.contains('pindah kas')) return const Color(0xFFE65100);
    if (t.contains('pengeluaran')) return const Color(0xFFD32F2F);
    if (t.contains('kmc') || t.contains('kredit merchant')) return kmcColor;
    return const Color(0xFF555555); 
  }

  @override
  Widget build(BuildContext context) {
    bool isSessionOpen = sessionStatus == "open";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.account_balance_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    namaKaryawan,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "$namaOutlet (${tipeOutlet.toUpperCase()})",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: primaryOrange),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: isLoading ? null : refreshAllData,
            tooltip: "Refresh Data",
          ),
        ],
      ),
      drawer: Sidebar(
        sessionStatus: sessionStatus,
        sessionId: sessionId,
        onRefresh: () {
          checkTodaySession();
          cekNotifikasiProdukMasuk();
          cekNotifikasiKasMasuk();
          cekNotifikasiSaldoMasuk();
        },
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Memuat data...",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      if (!isSessionOpen)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryOrange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryOrange.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: primaryOrange, size: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  "Sesi kerja kasir belum aktif. Buka sesi melalui menu samping terlebih dahulu untuk mengakses transaksi.",
                                  style: const TextStyle(
                                    color: Color(0xFF6B3D00),
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ============ NOTIFIKASI PENAMBAHAN SALDO ============
                      if (isSessionOpen && pendingSaldoMasukCount > 0 && saldoMasukList.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.cyan.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.cyan.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.currency_exchange_rounded,
                                      color: Colors.cyan.shade700,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "💳 Ada Penambahan Saldo!",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.cyan.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                pendingSaldoMasukCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            InkWell(
                                              onTap: closeSaldoNotifikasi,
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.grey.shade500,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          "Ada $pendingSaldoMasukCount transaksi penambahan saldo dari outlet lain.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.cyan.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: saldoMasukList.take(3).map((item) {
                                    double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                                    String sourceOutlet = item['source_outlet_name'] ?? 'Outlet Lain';
                                    String accountName = item['destination_account_name'] ?? 'Akun Tujuan';
                                    String keterangan = item['keterangan'] ?? '';
                                    String createdAt = item['created_at'] ?? '';
                                    
                                    String formattedDate = '';
                                    try {
                                      if (createdAt.isNotEmpty) {
                                        DateTime dateTime = DateTime.parse(createdAt);
                                        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
                                      }
                                    } catch (e) {
                                      formattedDate = createdAt;
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_forward_rounded, color: Colors.cyan.shade700, size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Rp ${_formatIdr(nominal)} dari $sourceOutlet ke $accountName${keterangan.isNotEmpty ? " ($keterangan)" : ""}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          if (formattedDate.isNotEmpty)
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (saldoMasukList.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    "... dan ${saldoMasukList.length - 3} transaksi lainnya",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // =======================================================

                      // ============ NOTIFIKASI KAS MASUK ============
                      if (isSessionOpen && pendingKasMasukCount > 0 && kasMasukList.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.money_rounded,
                                      color: Colors.amber.shade700,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "💰 Ada Kas Masuk!",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                pendingKasMasukCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            InkWell(
                                              onTap: closeKasNotifikasi,
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.grey.shade500,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          "Ada $pendingKasMasukCount transaksi kas masuk dari outlet lain.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: kasMasukList.take(3).map((item) {
                                    double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                                    String sourceOutlet = item['source_outlet_name'] ?? 'Outlet Lain';
                                    String keterangan = item['keterangan'] ?? '';
                                    String createdAt = item['created_at'] ?? '';
                                    
                                    String formattedDate = '';
                                    try {
                                      if (createdAt.isNotEmpty) {
                                        DateTime dateTime = DateTime.parse(createdAt);
                                        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
                                      }
                                    } catch (e) {
                                      formattedDate = createdAt;
                                    }
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_forward_rounded, color: Colors.amber.shade700, size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Rp ${_formatIdr(nominal)} dari $sourceOutlet${keterangan.isNotEmpty ? " ($keterangan)" : ""}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          if (formattedDate.isNotEmpty)
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              if (kasMasukList.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    "... dan ${kasMasukList.length - 3} transaksi lainnya",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // ====================================================

                      // ============ NOTIFIKASI PRODUK MASUK ============
                      if (tipeOutlet == 'cabang' && pendingKirimCount > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const KirimProdukScreen(),
                                ),
                              ).then((_) {
                                cekNotifikasiProdukMasuk();
                                cekNotifikasiKasMasuk();
                                cekNotifikasiSaldoMasuk();
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.inbox_rounded,
                                    color: Colors.green.shade700,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "📦 Ada Produk Masuk!",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              pendingKirimCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "Ada $pendingKirimCount produk yang dikirim ke outlet Anda. Klik untuk terima.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.green.shade700,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // ====================================================

                      Text(
                        "Layanan Transaksi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, gridConstraints) {
                                int crossAxisCount =
                                    gridConstraints.maxWidth > 900 ? 5 : (gridConstraints.maxWidth > 600 ? 3 : 2);

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.08,
                                  ),
                                  itemCount: menuTransaksi.length,
                                  itemBuilder: (context, index) {
                                    return _buildMenuCard(menuTransaksi[index], isSessionOpen);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ============ RINGKASAN HARI INI ============
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Ringkasan Hari Ini",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Row 1: Kas Awal & Kas Saat Ini
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.attach_money_rounded,
                                    label: "Kas Awal",
                                    value: "Rp ${_formatIdr(cashOpeningSummary)}",
                                    color: primaryBlue,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: "Kas Saat Ini",
                                    value: "Rp ${_formatIdr(cashClosingSummary)}",
                                    color: primaryBlue,
                                    isHighlight: true,
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),
                            
                            // Row 2: Omset PPOB & Saldo QRIS (HANYA QRIS BAYAR)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.receipt_long_rounded,
                                    label: "Omset PPOB",
                                    value: "Rp ${_formatIdr(omsetKasirPPOB)}",
                                    color: primaryOrange,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.qr_code_2_rounded,
                                    label: "Saldo QRIS (Bayar)",
                                    value: "Rp ${_formatIdr(saldoQRIS)}",
                                    color: const Color(0xFF7B1FA2),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 3: Tarik Tunai QRIS & Tarik Tunai EDC
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.qr_code_scanner_rounded,
                                    label: "Tarik Tunai QRIS",
                                    value: "Rp ${_formatIdr(tarikQRIS)}",
                                    color: const Color(0xFF6C3483),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.credit_card_rounded,
                                    label: "Tarik EDC",
                                    value: "Rp ${_formatIdr(totalTarikEDC)}",
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 4: Tarik M-Banking & Setoran BRILink
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.phone_android_rounded,
                                    label: "Tarik M-Banking",
                                    value: "Rp ${_formatIdr(totalTarikMBanking)}",
                                    color: const Color(0xFF1A6FB0),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.assignment_returned_rounded,
                                    label: "Setoran BRILink",
                                    value: "Rp ${_formatIdr(totalSetoranBRILink)}",
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 5: Pendapatan Fee & Kredit Merchant (KMC)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.trending_up_rounded,
                                    label: "Pendapatan Fee",
                                    value: "Rp ${_formatIdr(totalPendapatanFee)}",
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.account_balance_rounded,
                                    label: "Kredit Merchant (KMC)",
                                    value: "Rp ${_formatIdr(totalKMC)}",
                                    color: kmcColor,
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 6: Bayar Piutang & POS
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.payments_rounded,
                                    label: "Bayar Piutang",
                                    value: "Rp ${_formatIdr(totalBayarPiutang)}",
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.shopping_cart_rounded,
                                    label: "Total POS",
                                    value: "Rp ${_formatIdr(totalPOS)}",
                                    color: const Color(0xFF6C3483),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 7: Pengeluaran Operasional & Pindah Saldo
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.money_off_rounded,
                                    label: "Pengeluaran Operasional",
                                    value: "Rp ${_formatIdr(totalPengeluaranOperasional)}",
                                    color: const Color(0xFFD32F2F),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.currency_exchange_rounded,
                                    label: "Penambahan Saldo",
                                    value: "Rp ${_formatIdr(totalPindahSaldo)}",
                                    color: const Color(0xFF00838F),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),

                            // Row 8: Pindah Kas & Selisih
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.local_shipping_rounded,
                                    label: "Pindah Kas",
                                    value: "Rp ${_formatIdr(totalPindahKas)}",
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                ),
                                Expanded(
                                  child: _buildSummaryListItem(
                                    icon: Icons.calculate_rounded,
                                    label: "Selisih",
                                    value: "Rp ${_formatIdr(totalSelisihAkuntansi)}",
                                    color: primaryOrange,
                                    isHighlight: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // =========================================================================
                      // LIVE LOG TRANSAKSI TERBARU
                      // =========================================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Log Transaksi Terkini",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ],
                          ),
                          if (isSessionOpen && sessionId != null)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LogTransaksiScreen(
                                      sessionId: sessionId!,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.arrow_forward_rounded, size: 16, color: primaryBlue),
                              label: Text(
                                "Lihat Semua",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: primaryBlue.withOpacity(0.3)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (!isSessionOpen || recentTransactions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                !isSessionOpen ? "Sesi belum aktif" : "Belum ada transaksi",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !isSessionOpen ? "Buka sesi untuk memulai transaksi" : "Transaksi akan muncul di sini",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentTransactions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade100,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              var trx = recentTransactions[index];
                              String type = trx['trx_type'] ?? 'Transaksi';
                              String name = trx['customer_name']?.toString() ?? '-';
                              String target = trx['ppob_target']?.toString() ?? '';
                              
                              double amount = 0;
                              if (trx.containsKey('nominal') && trx['nominal'] != null) {
                                amount = double.tryParse(trx['nominal'].toString()) ?? 0;
                              }
                              if (amount == 0) {
                                amount = double.tryParse(trx['nominal_destination'].toString()) ?? 0;
                              }
                              if (amount == 0) {
                                amount = double.tryParse(trx['nominal_source'].toString()) ?? 0;
                              }
                              
                              bool isPindahSaldoMasuk = trx['is_pindah_saldo_masuk'] == true;
                              
                              String displayType = type.toUpperCase();
                              if (isPindahSaldoMasuk) {
                                displayType = "TERIMA PENAMBAHAN SALDO";
                              }
                              
                              String displayDescription = "";
                              if (isPindahSaldoMasuk) {
                                displayDescription = trx['description'] ?? 'Penambahan saldo dari outlet pusat';
                              } else if (name == '-' || name.isEmpty) {
                                displayDescription = trx['description'] ?? 'Pindahan Dana';
                              } else {
                                displayDescription = "Pelanggan: $name ${target.isNotEmpty ? '($target)' : ''}";
                              }
                              
                              Color trxColor = isPindahSaldoMasuk ? const Color(0xFF00838F) : _getTrxColor(type);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: trxColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                displayType,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: trxColor,
                                                ),
                                              ),
                                              Text(
                                                "Rp ${_formatIdr(amount)}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            displayDescription,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B3D00),
                                              fontWeight: FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ============ _buildMenuCard dengan handle POS ============
  Widget _buildMenuCard(Map<String, dynamic> item, bool isActive) {
    Color itemColor = isActive ? item['color'] : Colors.grey.shade400;
    
    return Card(
      color: isActive ? Colors.white : Colors.grey.shade100,
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isActive ? Colors.grey.shade200 : Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isActive
          ? () async {
              if (item['type'] == 'pos') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PosScreen(
                      sessionId: sessionId!,
                    ),
                  ),
                );
                if (result == true) {
                  await checkTodaySession();
                  await cekNotifikasiKasMasuk();
                  await cekNotifikasiSaldoMasuk();
                }
              } else {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InputTransactionScreen(
                      sessionId: sessionId!,
                      menuTitle: item['title'],
                      trxType: item['type'],
                    ),
                  ),
                );
                if (result == true) {
                  await checkTodaySession();
                  await cekNotifikasiKasMasuk();
                  await cekNotifikasiSaldoMasuk();
                }
              }
            }
          : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive ? itemColor.withOpacity(0.12) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item['icon'],
                  color: isActive ? itemColor : Colors.grey.shade500,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item['title'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.grey.shade900 : Colors.grey.shade500,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryListItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: () async {
        if (label == "Kredit Merchant (KMC)") {
          if (sessionId == null || sessionId == 0) {
            showSnackBar("Sesi tidak aktif");
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FeeBrilinkHarianScreen(
                sessionId: sessionId!,
              ),
            ),
          );
          if (result == true) {
            await checkTodaySession();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
                      color: isHighlight ? primaryBlue : Colors.grey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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

double _getTransactionNominal(Map<String, dynamic> trx) {
  if (trx.containsKey('nominal') && trx['nominal'] != null) {
    double val = double.tryParse(trx['nominal'].toString()) ?? 0;
    if (val > 0) return val;
  }
  
  double dest = double.tryParse(trx['nominal_destination'].toString()) ?? 0;
  if (dest > 0) return dest;
  
  double src = double.tryParse(trx['nominal_source'].toString()) ?? 0;
  if (src > 0) return src;
  
  if (trx['trx_type'] == 'setoran brilink') {
    String desc = trx['description']?.toString() ?? '';
    RegExp regExp = RegExp(r'(\d+\.?\d*)');
    var matches = regExp.allMatches(desc);
    for (var match in matches) {
      String numberStr = match.group(1)?.replaceAll('.', '') ?? '0';
      double found = double.tryParse(numberStr) ?? 0;
      if (found > 0) return found;
    }
  }
  
  return 0;
}