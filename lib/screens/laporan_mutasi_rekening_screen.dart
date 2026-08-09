// lib/screens/laporan_mutasi_rekening_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class LaporanMutasiRekeningScreen extends StatefulWidget {
  const LaporanMutasiRekeningScreen({super.key});

  @override
  State<LaporanMutasiRekeningScreen> createState() => _LaporanMutasiRekeningScreenState();
}

class _LaporanMutasiRekeningScreenState extends State<LaporanMutasiRekeningScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  bool isLoading = false;
  
  // Data
  List<dynamic> accounts = [];
  List<dynamic> karyawanList = [];
  List<dynamic> allData = [];
  double totalDebitAll = 0;
  double totalKreditAll = 0;
  int totalTransaksiAll = 0;
  
  // Filter
  DateTime selectedDate = DateTime.now();
  DateTime? startDate;
  DateTime? endDate;
  bool useCustomRange = false;
  
  int selectedKaryawanId = 0;
  int selectedAccountId = 0;
  
  // Expand
  Set<int> expandedAccounts = {};
  
  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color primaryRed = const Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      selectedDate = DateTime.now();
    });
    
    await fetchKaryawan();
    await fetchMutasiRekening();
  }

  Future<void> fetchKaryawan() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_karyawan.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          karyawanList = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Gagal fetch karyawan: $e");
    }
  }

  Future<void> fetchMutasiRekening() async {
    setState(() => isLoading = true);
    
    try {
      String url = "$baseUrl/get_mutasi_rekening.php?outlet_id=$myOutletId";
      
      if (useCustomRange) {
        if (startDate != null && endDate != null) {
          url += "&start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}";
          url += "&end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}";
        }
      } else {
        String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
        url += "&start_date=$dateStr&end_date=$dateStr";
      }
      
      if (selectedKaryawanId > 0) {
        url += "&karyawan_id=$selectedKaryawanId";
      }
      
      if (selectedAccountId > 0) {
        url += "&account_id=$selectedAccountId";
      }
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          allData = data['data']?['accounts'] ?? [];
          totalDebitAll = double.tryParse(data['data']?['total_semua_debit']?.toString() ?? '0') ?? 0;
          totalKreditAll = double.tryParse(data['data']?['total_semua_kredit']?.toString() ?? '0') ?? 0;
          totalTransaksiAll = int.tryParse(data['data']?['total_semua_transaksi']?.toString() ?? '0') ?? 0;
          
          accounts = allData.map((acc) {
            return {
              'id': acc['account_id'],
              'name': acc['account_name'],
            };
          }).toList();
        });
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat data");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ============ NAVIGASI TANGGAL ============
  void _previousDate() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      useCustomRange = false;
      startDate = null;
      endDate = null;
    });
    fetchMutasiRekening();
  }

  void _nextDate() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      useCustomRange = false;
      startDate = null;
      endDate = null;
    });
    fetchMutasiRekening();
  }

  void _goToToday() {
    setState(() {
      selectedDate = DateTime.now();
      useCustomRange = false;
      startDate = null;
      endDate = null;
    });
    fetchMutasiRekening();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        useCustomRange = false;
        startDate = null;
        endDate = null;
      });
      fetchMutasiRekening();
    }
  }

  void _selectCustomRange() async {
    final pickedStart = await showDatePicker(
      context: context,
      initialDate: startDate ?? selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedStart != null) {
      final pickedEnd = await showDatePicker(
        context: context,
        initialDate: endDate ?? pickedStart,
        firstDate: pickedStart,
        lastDate: DateTime.now(),
      );
      if (pickedEnd != null) {
        setState(() {
          startDate = pickedStart;
          endDate = pickedEnd;
          useCustomRange = true;
        });
        fetchMutasiRekening();
      }
    }
  }

  void resetFilters() {
    setState(() {
      selectedDate = DateTime.now();
      startDate = null;
      endDate = null;
      useCustomRange = false;
      selectedKaryawanId = 0;
      selectedAccountId = 0;
      expandedAccounts.clear();
    });
    fetchMutasiRekening();
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
    try {
      bool isNegative = number < 0;
      String str = number.abs().toInt().toString();
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      String formatted = str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
      return isNegative ? "-$formatted" : formatted;
    } catch (e) {
      return '0';
    }
  }

  String _formatTanggalDisplay(DateTime date) {
    final Map<int, String> hari = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 
      4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Minggu'
    };
    
    final Map<int, String> bulan = {
      1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April',
      5: 'Mei', 6: 'Juni', 7: 'Juli', 8: 'Agustus',
      9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember'
    };
    
    String hariNama = hari[date.weekday] ?? '';
    String bulanNama = bulan[date.month] ?? '';
    
    return '$hariNama, ${date.day} $bulanNama ${date.year}';
  }

  String _formatTanggal(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      try {
        DateTime dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(date);
        return DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (e2) {
        return date;
      }
    }
  }

  Color _getTypeColor(String type) {
    String t = type.toLowerCase();
    if (t.contains('piutang')) return const Color(0xFF2E7D32);
    if (t.contains('hutang')) return const Color(0xFFD32F2F);
    if (t.contains('setoran')) return const Color(0xFF1A6FB0);
    if (t.contains('tarik')) return const Color(0xFFE65100);
    if (t.contains('pengeluaran')) return const Color(0xFF6A1B9A);
    if (t.contains('pindah')) return const Color(0xFF00838F);
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Laporan Mutasi Rekening",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: fetchMutasiRekening,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
              child: Column(
                children: [
                  // ============ FILTER ============
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ============ ROW 1: NAVIGASI TANGGAL ============
                        Row(
                          children: [
                            // Tombol Kiri
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                                color: primaryBlue,
                                onPressed: _previousDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Tampilan Tanggal
                            Expanded(
                              child: InkWell(
                                onTap: useCustomRange ? _selectCustomRange : _selectDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 18,
                                        color: primaryBlue,
                                      ),
                                      const SizedBox(width: 10),
                                      if (useCustomRange && startDate != null && endDate != null)
                                        Text(
                                          "${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        )
                                      else
                                        Text(
                                          _formatTanggalDisplay(selectedDate),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Tombol Kanan
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                                color: primaryBlue,
                                onPressed: _nextDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Tombol Hari Ini
                            Container(
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.today_rounded, size: 20),
                                color: primaryBlue,
                                onPressed: _goToToday,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                                tooltip: "Hari Ini",
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Tombol Custom Range
                            Container(
                              decoration: BoxDecoration(
                                color: useCustomRange 
                                    ? primaryOrange.withOpacity(0.15) 
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: useCustomRange 
                                    ? Border.all(color: primaryOrange, width: 1.5) 
                                    : null,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.date_range_rounded,
                                  size: 20,
                                  color: useCustomRange ? primaryOrange : Colors.grey.shade600,
                                ),
                                onPressed: _selectCustomRange,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                                tooltip: "Pilih Rentang Tanggal",
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Tombol Reset
                            if (selectedKaryawanId > 0 || selectedAccountId > 0 || useCustomRange)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.clear_all_rounded, size: 20, color: Colors.red.shade700),
                                  onPressed: resetFilters,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                  tooltip: "Reset Filter",
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // ============ ROW 2: FILTER KARYAWAN & AKUN ============
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedKaryawanId,
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down, color: primaryBlue),
                                    hint: const Text("Semua Karyawan", style: TextStyle(fontSize: 13)),
                                    items: [
                                      const DropdownMenuItem(value: 0, child: Text("Semua Karyawan", style: TextStyle(fontSize: 13))),
                                      ...karyawanList.map((k) {
                                        return DropdownMenuItem(
                                          value: int.parse(k['id'].toString()),
                                          child: Text(k['nama_karyawan'] ?? 'Unknown', style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedKaryawanId = value ?? 0;
                                      });
                                      fetchMutasiRekening();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: selectedAccountId,
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down, color: primaryBlue),
                                    hint: const Text("Semua Akun", style: TextStyle(fontSize: 13)),
                                    items: [
                                      const DropdownMenuItem(value: 0, child: Text("Semua Akun", style: TextStyle(fontSize: 13))),
                                      ...accounts.map((acc) {
                                        int id = 0;
                                        String name = 'Unknown';
                                        if (acc != null) {
                                          try {
                                            id = int.tryParse(acc['id']?.toString() ?? '0') ?? 0;
                                            name = acc['name']?.toString() ?? 'Unknown';
                                          } catch (e) {}
                                        }
                                        return DropdownMenuItem<int>(
                                          value: id,
                                          child: Text(
                                            name, 
                                            style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        selectedAccountId = value ?? 0;
                                        expandedAccounts.clear();
                                      });
                                      fetchMutasiRekening();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // ============ INFO PERIODE ============
                        if (useCustomRange && startDate != null && endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryOrange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primaryOrange.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.date_range_rounded, size: 14, color: primaryOrange),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Rentang: ${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ============ SUMMARY ============
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Total Debit",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              Text(
                                "Rp ${_formatIdr(totalDebitAll)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Total Kredit",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              Text(
                                "Rp ${_formatIdr(totalKreditAll)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Total Transaksi",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              Text(
                                "$totalTransaksiAll",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ============ LIST ============
                  Expanded(
                    child: allData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  "Tidak ada data mutasi",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Belum ada transaksi untuk periode ini",
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: allData.length,
                            itemBuilder: (context, index) {
                              var account = allData[index];
                              return _buildAccountCard(account);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountCard(dynamic account) {
    if (account == null) return const SizedBox.shrink();
    
    int accountId = account['account_id'] ?? 0;
    String accountName = account['account_name'] ?? 'Unknown';
    String category = account['category'] ?? '';
    String subCategory = account['sub_category'] ?? '';
    bool isVirtual = account['is_virtual'] ?? false;
    bool isExpanded = expandedAccounts.contains(accountId);
    List<dynamic> mutasi = account['mutasi'] ?? [];
    double saldoAwal = double.tryParse(account['saldo_awal']?.toString() ?? '0') ?? 0;
    double saldoAkhir = double.tryParse(account['saldo_akhir']?.toString() ?? '0') ?? 0;
    double totalDebit = double.tryParse(account['total_debit']?.toString() ?? '0') ?? 0;
    double totalKredit = double.tryParse(account['total_kredit']?.toString() ?? '0') ?? 0;
    int totalTransaksi = account['total_transaksi'] ?? 0;

    String displayName = accountName;
    if (subCategory.isNotEmpty && subCategory != '-') {
      displayName = "$accountName ($subCategory)";
    }

    bool hasTransaksi = mutasi.isNotEmpty;
    
    // ============ ICON UNTUK KAS LACI ============
    IconData accountIcon;
    Color iconColor;
    if (isVirtual) {
      accountIcon = Icons.money_rounded;
      iconColor = Colors.orange.shade700;
    } else if (category == 'Bank') {
      accountIcon = Icons.account_balance_rounded;
      iconColor = primaryBlue;
    } else {
      accountIcon = Icons.account_balance_wallet_rounded;
      iconColor = primaryBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVirtual ? Colors.orange.shade200 : (hasTransaksi ? Colors.grey.shade200 : Colors.grey.shade300),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ============ HEADER ============
          InkWell(
            onTap: () {
              if (hasTransaksi) {
                setState(() {
                  if (isExpanded) {
                    expandedAccounts.remove(accountId);
                  } else {
                    expandedAccounts.add(accountId);
                  }
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isVirtual 
                          ? Colors.orange.shade50 
                          : (hasTransaksi ? primaryBlue.withOpacity(0.08) : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      accountIcon,
                      color: isVirtual ? Colors.orange.shade700 : (hasTransaksi ? primaryBlue : Colors.grey.shade400),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: hasTransaksi ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                            if (isVirtual) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  "KAS",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                            if (!hasTransaksi) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Belum ada transaksi",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Saldo: Rp ${_formatIdr(saldoAkhir)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: hasTransaksi 
                                ? (saldoAkhir >= 0 ? Colors.green.shade700 : Colors.red.shade700)
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasTransaksi ? Colors.grey.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${mutasi.length} trx",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasTransaksi ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  if (hasTransaksi) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // ============ BODY ============
          if (isExpanded && hasTransaksi) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Summary account
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text("Saldo Awal", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(saldoAwal)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Total Debit", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(totalDebit)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryGreen)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Total Kredit", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(totalKredit)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryRed)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Saldo Akhir", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(saldoAkhir)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryBlue)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 8),
                  
                  // ============ TABLE MUTASI ============
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30, 
                          child: Text(
                            "No", 
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                          )
                        ),
                        Expanded(
                          flex: 2, 
                          child: Text(
                            "Tanggal", 
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                          )
                        ),
                        Expanded(
                          flex: 3, 
                          child: Text(
                            "Keterangan", 
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                          )
                        ),
                        Expanded(
                          flex: 2, 
                          child: Container(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Debit", 
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                            ),
                          )
                        ),
                        Expanded(
                          flex: 2, 
                          child: Container(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Kredit", 
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                            ),
                          )
                        ),
                        Expanded(
                          flex: 2, 
                          child: Container(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "Saldo", 
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                  
                  // Data rows
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mutasi.length,
                    itemBuilder: (context, idx) {
                      var item = mutasi[idx];
                      double debit = double.tryParse(item['debit']?.toString() ?? '0') ?? 0;
                      double kredit = double.tryParse(item['kredit']?.toString() ?? '0') ?? 0;
                      double saldo = double.tryParse(item['saldo']?.toString() ?? '0') ?? 0;
                      String type = item['type'] ?? '';
                      String keterangan = item['keterangan'] ?? '';
                      String tanggal = _formatTanggal(item['tanggal']);
                      String karyawan = item['karyawan'] ?? '';
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                          color: idx % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                "${idx + 1}",
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                tanggal,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _getTypeColor(type),
                                    ),
                                  ),
                                  Text(
                                    keterangan,
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (karyawan.isNotEmpty)
                                    Text(
                                      "Karyawan: $karyawan",
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade400),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  debit > 0 ? "Rp ${_formatIdr(debit)}" : "-",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: debit > 0 ? FontWeight.w600 : FontWeight.normal,
                                    color: debit > 0 ? primaryGreen : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  kredit > 0 ? "Rp ${_formatIdr(kredit)}" : "-",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: kredit > 0 ? FontWeight.w600 : FontWeight.normal,
                                    color: kredit > 0 ? primaryRed : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "Rp ${_formatIdr(saldo)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: saldo >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}