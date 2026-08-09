import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LogTransaksiScreen extends StatefulWidget {
  final int sessionId;

  const LogTransaksiScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<LogTransaksiScreen> createState() => _LogTransaksiScreenState();
}

class _LogTransaksiScreenState extends State<LogTransaksiScreen> with TickerProviderStateMixin {
  final String baseUrl = "https://barokahsport.com/brilink";

  int myOutletId = 1;
  int pusatOutletId = 1;
  bool isPusatOutlet = false;
  List<dynamic> transactions = [];
  List<dynamic> filteredTransactions = [];
  List<dynamic> karyawanList = [];
  List<dynamic> outletList = [];

  // ============ DATA KMC (KREDIT MERCHANT) ============
  List<dynamic> kmcList = [];
  double kmcTotal = 0;
  // ====================================================

  // Filter variables
  int? selectedKaryawanId;
  DateTime? selectedDate;
  String searchQuery = '';

  // ============ SUB-TAB OUTLET ============
  int? selectedOutletId;
  bool showOutletSubTab = false;
  // =======================================

  // Tab Controller
  late TabController _tabController;
  late TabController _outletSubTabController;

  bool isLoading = false;
  bool isLoadingKaryawan = false;
  bool isLoadingOutlets = false;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  // Daftar kategori transaksi (SAMA DENGAN AllLogTransaksiScreen)
  final List<String> transactionCategories = [
    'Semua',
    'PPOB',
    'QRIS Bayar',
    'Tarik Tunai QRIS',
    'Tarik Tunai EDC',
    'Tarik Tunai M-Banking',
    'Setoran Brilink',
    'Pindah Kas',
    'Penambahan Saldo',
    'Prive',                            
    'Pengeluaran Operasional Konveksi',        
    'Pengeluaran Operasional Brilink',         
    'Bayar Piutang',
    'Bayar Hutang',
    'POS',
    'Tambah Kas Brangkas',
    'KMC',
  ];

  // Kategori yang memiliki sub-tab outlet (HANYA DI OUTLET PUSAT)
  final List<String> categoriesWithOutletSubTab = [
    'Tarik Tunai M-Banking',
    'Setoran Brilink',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: transactionCategories.length, vsync: this);
    _outletSubTabController = TabController(length: 1, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _loadDataForTab(_tabController.index);
          _updateOutletSubTabVisibility(_tabController.index);
          selectedOutletId = null;
        });
      }
    });
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outletSubTabController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      selectedDate = DateTime.now();
    });

    await fetchPusatOutlet();
    await fetchKaryawan();
    await fetchOutlets();
    await fetchTransactions();
    await fetchKMCData();
  }

  // ============ FETCH OUTLET PUSAT ============
  Future<void> fetchPusatOutlet() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_outlets.php"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> outlets = data['data'] ?? [];
        if (outlets.isNotEmpty) {
          outlets.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
          pusatOutletId = outlets.first['id'] as int;
          isPusatOutlet = (myOutletId == pusatOutletId);
          print("LogTransaksi - Outlet ID: $myOutletId, Pusat ID: $pusatOutletId, Is Pusat: $isPusatOutlet");
        }
      }
    } catch (e) {
      print("Gagal mengambil outlet pusat: $e");
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
        });
      }
    } catch (e) {
      print("Gagal mengambil data karyawan: $e");
    } finally {
      setState(() => isLoadingKaryawan = false);
    }
  }

  // ============ FETCH OUTLETS ============
  Future<void> fetchOutlets() async {
    setState(() => isLoadingOutlets = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_outlets.php"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          outletList = data['data'] ?? [];
          selectedOutletId = null;
        });
        if (showOutletSubTab && outletList.isNotEmpty && isPusatOutlet) {
          _reinitializeOutletSubTabController();
        }
      }
    } catch (e) {
      print("Gagal mengambil data outlet: $e");
    } finally {
      setState(() => isLoadingOutlets = false);
    }
  }
  // ======================================

  // ============ FETCH KMC DATA ============
  Future<void> fetchKMCData() async {
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate ?? DateTime.now());
      final response = await http.get(
        Uri.parse("$baseUrl/get_fee_brilink_harian.php?outlet_id=$myOutletId&tanggal=$dateStr"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> rawData = data['data'] ?? [];
        
        // ============ FORMAT DATA DENGAN ACCOUNT YANG DIPILIH ============
        List<dynamic> formattedData = rawData.map((item) {
          String accountName = item['account_name'] ?? 'BRI';
          String subCategory = item['account_sub_category'] ?? '';
          
          // Format display name
          String accountDisplay;
          if (subCategory.isNotEmpty && subCategory != '-' && subCategory != 'NULL') {
            accountDisplay = "$accountName ($subCategory)";
          } else {
            accountDisplay = accountName;
          }
          
          // Jika tidak ada account_name, gunakan default
          if (accountName == 'BRI' && subCategory.isEmpty) {
            accountDisplay = 'BRI (Penampung Outlet)';
          }
          
          return {
            'id': item['id'] ?? 0,
            'nominal': double.tryParse(item['nominal']?.toString() ?? '0') ?? 0,
            'keterangan': item['keterangan'] ?? '',
            'nama_karyawan': item['nama_karyawan'] ?? '',
            'created_at': item['created_at'] ?? '',
            'destination_account_id': item['destination_account_id'],
            'account_name': accountDisplay,
            'account_display': accountDisplay,
            'account_name_raw': accountName,
            'account_sub_category': subCategory,
          };
        }).toList();
        
        setState(() {
          kmcList = formattedData;
          kmcTotal = double.tryParse(data['total_fee']?.toString() ?? '0') ?? 0;
        });
        
        print("📊 KMC Data: ${formattedData.length} items");
        for (var kmc in formattedData) {
          print("📊 KMC: Rp ${kmc['nominal']} - ${kmc['account_display']}");
        }
      }
    } catch (e) {
      print("Gagal mengambil KMC: $e");
    }
  }
  // ========================================

  // ============ FETCH TRANSACTIONS ============
  Future<void> fetchTransactions() async {
    setState(() => isLoading = true);
    try {
      // Gunakan API get_all_transactions.php agar sama dengan AllLogTransaksiScreen
      final response = await http.get(
        Uri.parse("$baseUrl/get_all_transactions.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          transactions = data['data'] ?? [];
          applyFilters();
        });
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat transaksi");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }
  // ==========================================

  void _loadDataForTab(int index) {
    if (index == transactionCategories.length - 1) {
      fetchKMCData();
    }
    _updateOutletSubTabVisibility(index);
  }

  void _reinitializeOutletSubTabController() {
    if (!mounted) return;
    
    if (_outletSubTabController.length > 1) {
      _outletSubTabController.dispose();
    }

    _outletSubTabController = TabController(
      length: outletList.length + 1,
      vsync: this,
    );
    _outletSubTabController.addListener(_onOutletSubTabChanged);
  }

  void _onOutletSubTabChanged() {
    if (!mounted) return;
    if (_outletSubTabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _updateOutletSubTabVisibility(int index) {
    if (!mounted) return;
    
    String category = transactionCategories[index];
    bool show = isPusatOutlet && categoriesWithOutletSubTab.contains(category);
    
    setState(() {
      showOutletSubTab = show;
      if (show && outletList.isNotEmpty) {
        selectedOutletId = null;
        _reinitializeOutletSubTabController();
      } else {
        selectedOutletId = null;
      }
    });
  }

  // ============ GET DATA BERDASARKAN OUTLET ============
  List<dynamic> getFilteredByOutlet(List<dynamic> data, int? outletId) {
    if (outletId == null) return data;
    
    return data.where((trx) {
      int? sourceOutletId = trx['session_outlet_id'] != null 
          ? int.tryParse(trx['session_outlet_id'].toString()) 
          : null;
      int? targetOutletId = trx['target_outlet_id'] != null 
          ? int.tryParse(trx['target_outlet_id'].toString()) 
          : null;
      
      return sourceOutletId == outletId || targetOutletId == outletId;
    }).toList();
  }

  int getOutletCount(int? outletId, List<dynamic> data) {
    if (outletId == null) return data.length;
    return data.where((trx) {
      int? sourceOutletId = trx['session_outlet_id'] != null 
          ? int.tryParse(trx['session_outlet_id'].toString()) 
          : null;
      int? targetOutletId = trx['target_outlet_id'] != null 
          ? int.tryParse(trx['target_outlet_id'].toString()) 
          : null;
      return sourceOutletId == outletId || targetOutletId == outletId;
    }).length;
  }
  // ======================================================

  // ============ GET ALL DATA (TRANSACTIONS + KMC) ============
  List<dynamic> getAllData() {
    List<dynamic> allData = [];
    
    // ============ AMBIL TRANSAKSI NON-KMC ============
    var nonKMCTransactions = filteredTransactions.where((trx) {
      String customerName = trx['customer_name']?.toString()?.toLowerCase() ?? '';
      String description = trx['description']?.toString()?.toLowerCase() ?? '';
      String type = trx['trx_type']?.toString()?.toLowerCase() ?? '';
      
      if (customerName.contains('kmc') || 
          customerName.contains('kredit merchant') ||
          description.contains('kmc') || 
          description.contains('kredit merchant') ||
          type.contains('kredit merchant') || 
          type == 'kredit_merchant') {
        return false;
      }
      return true;
    }).toList();
    
    allData.addAll(nonKMCTransactions);

    // ============ TAMBAHKAN KMC DARI KMC LIST ============
    for (var kmc in kmcList) {
      // ============ PERBAIKAN: Gunakan account_display dari kmcList ============
      String accountDisplay = kmc['account_display'] ?? kmc['account_name'] ?? 'BRI (Penampung Outlet)';
      
      allData.add({
        'id': kmc['id'] ?? 0,
        'trx_type': 'Kredit Merchant (KMC)',
        'trx_type_raw': 'kredit_merchant',
        'customer_name': 'KMC',
        'nominal_source': 0,
        'nominal_destination': kmc['nominal'] ?? 0,
        'admin_fee': 0,
        'description': kmc['keterangan'] ?? 'Kredit Merchant',
        'karyawan_id': kmc['karyawan_id'],
        'karyawan_name': kmc['nama_karyawan'] ?? '',
        'source_account_name': 'Eksternal',
        'destination_account_name': accountDisplay,  // <-- PERBAIKAN
        'created_at': kmc['created_at'] ?? '',
        'trx_date': kmc['created_at'] ?? '',
        'is_kredit_merchant': true,
        'source_display': 'Eksternal (KMC)',
        'destination_display': accountDisplay,  // <-- PERBAIKAN
        'nominal': kmc['nominal'] ?? 0,
        'session_outlet_id': myOutletId,
        'is_from_fee_brilink': true,
      });
    }

    allData.sort((a, b) {
      String dateA = a['trx_date']?.toString() ?? '';
      String dateB = b['trx_date']?.toString() ?? '';
      return dateB.compareTo(dateA);
    });
    return allData;
  }
  // =========================================================

  void applyFilters() {
    var filtered = List<dynamic>.from(transactions);

    // Filter berdasarkan karyawan
    if (selectedKaryawanId != null && selectedKaryawanId! > 0) {
      filtered = filtered.where((trx) {
        int? karyawanId = trx['karyawan_id'] != null ? int.tryParse(trx['karyawan_id'].toString()) : null;
        return karyawanId == selectedKaryawanId;
      }).toList();
    }

    // Filter berdasarkan tanggal
    if (selectedDate != null) {
      String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      filtered = filtered.where((trx) {
        String trxDate = trx['trx_date']?.toString() ?? '';
        try {
          if (trxDate.contains(' ')) {
            String datePart = trxDate.split(' ')[0];
            return datePart == dateStr;
          } else {
            return trxDate.startsWith(dateStr);
          }
        } catch (e) {
          return trxDate.contains(dateStr);
        }
      }).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      String query = searchQuery.toLowerCase();
      filtered = filtered.where((trx) {
        String customerName = trx['customer_name']?.toString().toLowerCase() ?? '';
        String description = trx['description']?.toString().toLowerCase() ?? '';
        String type = trx['trx_type']?.toString().toLowerCase() ?? '';
        String target = trx['ppob_target']?.toString().toLowerCase() ?? '';
        return customerName.contains(query) ||
            description.contains(query) ||
            type.contains(query) ||
            target.contains(query);
      }).toList();
    }

    setState(() {
      filteredTransactions = filtered;
    });
  }

  // ============ FILTER BERDASARKAN KATEGORI ============
  List<dynamic> getFilteredByCategory(String category) {
    if (category == 'Semua') {
      return getAllData();
    }

    if (category == 'KMC') {
      return kmcList;
    }

    var filtered = filteredTransactions;

    // Jika sub-tab outlet aktif, filter berdasarkan outlet
    if (showOutletSubTab && selectedOutletId != null && categoriesWithOutletSubTab.contains(category)) {
      filtered = getFilteredByOutlet(filtered, selectedOutletId);
    }

    return filtered.where((trx) {
      String type = trx['trx_type_raw']?.toString().toLowerCase() ?? '';
      String description = trx['description']?.toString().toLowerCase() ?? '';

      bool isPOSQRIS = trx['is_pos_qris'] ?? false;

      switch (category) {
        case 'PPOB':
          return type == 'ppob';
        case 'QRIS Bayar':
          return type == 'qris' && !isPOSQRIS;
        case 'Tarik Tunai EDC':
          return type == 'tarik tunai edc';
        case 'Tarik Tunai M-Banking':
          return type == 'tarik tunai mbanking';
        case 'Tarik Tunai QRIS':
          return type == 'tarik tunai qris';
        case 'Setoran Brilink':
          return type == 'setoran brilink';
        case 'Pindah Kas':
          return type == 'pindah kas';
        case 'Penambahan Saldo':
          return type == 'pindah saldo';
        case 'Prive':
          return type == 'pengeluaran operasional' && (trx['pengeluaran_jenis'] ?? 'operasional') == 'beban_toko';
        case 'Pengeluaran Operasional Konveksi':
          return type == 'pengeluaran operasional konveksi';
        case 'Pengeluaran Operasional Brilink':
          return type == 'pengeluaran operasional brilink';
        // ============ PERBAIKAN: Tambahkan 'buat piutang' ============
        case 'Bayar Piutang':
          return type == 'bayar piutang' || type == 'buat piutang';
        // ==============================================================
        // ============ PERBAIKAN: Tambahkan 'buat hutang' ============
        case 'Bayar Hutang':
          return type == 'bayar hutang' || type == 'buat hutang';
        // ==============================================================
        case 'Tambah Kas Brangkas':
          return type == 'tambah kas brangkas';
        case 'POS':
          return (trx['is_pos'] ?? false) || isPOSQRIS;
        default:
          return true;
      }
    }).toList();
  }
  // ====================================================

  int getCategoryCount(String category) {
    if (category == 'KMC') {
      return kmcList.length;
    }
    if (category == 'Semua') {
      return getAllData().length;
    }
    
    var filtered = List<dynamic>.from(filteredTransactions);
    
    // ============ PERBAIKAN ============
    if (category == 'Bayar Piutang') {
      return filtered.where((trx) {
        String type = trx['trx_type_raw']?.toString().toLowerCase() ?? '';
        return type == 'bayar piutang' || type == 'buat piutang';
      }).length;
    }
    
    if (category == 'Bayar Hutang') {
      return filtered.where((trx) {
        String type = trx['trx_type_raw']?.toString().toLowerCase() ?? '';
        return type == 'bayar hutang' || type == 'buat hutang';
      }).length;
    }
    // ================================
    
    return getFilteredByCategory(category).length;
  }

  double getTotalAmount(String category) {
    if (category == 'KMC') {
      return kmcTotal;
    }

    if (category == 'Semua') {
      double total = 0;
      var allData = getAllData();
      for (var item in allData) {
        if (item['is_kredit_merchant'] == true) {
          total += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
        } else {
          String type = item['trx_type']?.toString()?.toLowerCase() ?? '';
          // ============ PERBAIKAN ============
          if (type.contains('bayar hutang') || type.contains('pengeluaran')) {
            total += double.tryParse(item['nominal_source']?.toString() ?? '0') ?? 0;
          } else {
            total += double.tryParse(item['nominal_destination']?.toString() ?? '0') ?? 0;
          }
          // ================================
        }
      }
      return total;
    }

    var filtered = getFilteredByCategory(category);
    return filtered.fold(0.0, (sum, trx) {
      String type = trx['trx_type']?.toString()?.toLowerCase() ?? '';
      double amount = 0;
      // ============ PERBAIKAN ============
      if (type.contains('bayar hutang') || type.contains('pengeluaran')) {
        amount = double.tryParse(trx['nominal_source']?.toString() ?? '0') ?? 0;
      } else {
        amount = double.tryParse(trx['nominal_destination']?.toString() ?? '0') ?? 0;
      }
      // ================================
      return sum + amount;
    });
  }

  double getTotalFee(String category) {
    if (category == 'KMC' || category == 'Semua') return 0;

    var filtered = getFilteredByCategory(category);
    return filtered.fold(0.0, (sum, trx) {
      double fee = double.tryParse(trx['admin_fee']?.toString() ?? '0') ?? 0;
      return sum + fee;
    });
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

  String _safeString(dynamic value) {
    return value?.toString() ?? '';
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  String nestedFormatIdr(double number) {
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
    if (t.contains('pindah kas')) return const Color(0xFFE65100);
    if (t.contains('pindah saldo')) return const Color(0xFF00838F);
    // ============ TAMBAHKAN UNTUK PEMBUATAN ============
    if (t.contains('buat piutang')) return const Color(0xFF1B5E20); // Hijau gelap
    if (t.contains('buat hutang')) return const Color(0xFFB71C1C); // Merah gelap
    // ====================================================
    if (t.contains('pengeluaran operasional konveksi')) return const Color(0xFFB71C1C);
    if (t.contains('pengeluaran operasional brilink')) return const Color(0xFFE65100);
    if (t.contains('pengeluaran operasional') || t.contains('prive')) return const Color(0xFF6A1B9A);
    if (t.contains('pengeluaran')) return const Color(0xFFD32F2F);
    if (t.contains('bayar piutang') || t.contains('piutang')) return const Color(0xFF2E7D32);
    if (t.contains('bayar hutang') || t.contains('hutang')) return const Color(0xFFD32F2F);
    if (t.contains('pos')) return const Color(0xFF6C3483);
    if (t.contains('tambah kas brangkas')) return Colors.amber.shade700;
    if (t.contains('kredit merchant') || t.contains('kmc')) return const Color(0xFF00A86B);
    return const Color(0xFF555555);
  }


  // ============ BUILD KMC CARD ============
  Widget _buildKMCCard(var item) {
    double nominal = _safeDouble(item['nominal']);
    String keterangan = _safeString(item['keterangan']);
    String namaKaryawan = _safeString(item['nama_karyawan']);
    String createdAt = _safeString(item['created_at']);
    
    // ============ AMBIL AKUN TUJUAN ============
    // Coba dari destination_display dulu, lalu destination_account_name, lalu account_display
    String accountDisplay = _safeString(item['destination_display']);
    if (accountDisplay.isEmpty) {
      accountDisplay = _safeString(item['account_display']);
    }
    if (accountDisplay.isEmpty) {
      accountDisplay = _safeString(item['destination_account_name']);
    }
    if (accountDisplay.isEmpty) {
      accountDisplay = 'BRI (Penampung Outlet)';
    }
    
    String formattedDate = '';

    try {
      if (createdAt.isNotEmpty) {
        DateTime dateTime = DateTime.parse(createdAt);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      }
    } catch (e) {
      formattedDate = createdAt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "KREDIT MERCHANT",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00A86B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.2)),
                            ),
                            child: const Text(
                              "KMC",
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A86B),
                              ),
                            ),
                          ),
                          // ============ TAMPILKAN AKUN TUJUAN ============
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              accountDisplay,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Text(
                "+ Rp ${nestedFormatIdr(nominal)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (keterangan.isNotEmpty)
            Text(
              keterangan,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (namaKaryawan.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        namaKaryawan,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_rounded, size: 12, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      "→ $accountDisplay",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ========================================

  // ============ BUILD TRANSACTION CARD ============
  Widget _buildTransactionCard(var trx) {
    if (trx['is_kredit_merchant'] == true || trx['trx_type_raw'] == 'kredit_merchant') {
      return _buildKMCCard(trx);
    }

    String type = _safeString(trx['trx_type']);
    String typeRaw = _safeString(trx['trx_type_raw']);
    String name = _safeString(trx['customer_name']);
    String target = _safeString(trx['ppob_target']);
    
    double amount = 0;
    String typeLower = type.toLowerCase();
    String typeRawLower = typeRaw.toLowerCase();
    if (typeLower.contains('bayar hutang') || 
        typeLower.contains('pengeluaran operasional') || 
        typeLower.contains('pengeluaran')) {
      amount = _safeDouble(trx['nominal_source']);
    } else {
      amount = _safeDouble(trx['nominal_destination']);
    }

    if (typeRawLower.contains('buat piutang')) {
      amount = _safeDouble(trx['nominal_source']);
    } else if (typeRawLower.contains('buat hutang')) {
      amount = _safeDouble(trx['nominal_destination']);
    } else if (typeLower.contains('bayar hutang') || 
              typeLower.contains('pengeluaran operasional') || 
              typeLower.contains('pengeluaran')) {
      amount = _safeDouble(trx['nominal_source']);
    } else {
      amount = _safeDouble(trx['nominal_destination']);
    }
    double feeTrx = _safeDouble(trx['admin_fee']);

    String srcAccName = _safeString(trx['source_account_name']);
    String destAccName = _safeString(trx['destination_account_name']);
    String targetOutletName = _safeString(trx['target_outlet_name']);
    String sourceOutletName = _safeString(trx['source_outlet_name']);
    String karyawanName = _safeString(trx['karyawan_name']);
    String trxDate = _safeString(trx['trx_date']);
    String kategoriName = _safeString(trx['kategori_pengeluaran_name']);

    String sourceDisplay = _safeString(trx['source_display']);
    String destinationDisplay = _safeString(trx['destination_display']);
    bool isPOS = trx['is_pos'] ?? false;
    bool isPOSQRIS = trx['is_pos_qris'] ?? false;

    // ============ AMBIL DATA DISKON ============
    bool hasDiskon = trx['has_diskon'] ?? false;
    double diskonPersen = _safeDouble(trx['diskon_persen']);
    double diskonNominal = _safeDouble(trx['diskon_nominal']);
    // ==========================================

    List<dynamic> posItems = [];
    if (trx['pos_items'] != null && trx['pos_items'] is List) {
      posItems = trx['pos_items'];
    }

    int? checkTargetOutletId = trx['target_outlet_id'] != null ? _safeInt(trx['target_outlet_id']) : null;
    bool isDanaMasukCabang = checkTargetOutletId == myOutletId;
    String displayType = type.toUpperCase();
    if (typeRawLower.contains('buat piutang')) {
      displayType = "BUAT PIUTANG";
    } else if (typeRawLower.contains('buat hutang')) {
      displayType = "BUAT HUTANG";
    } else if (typeLower.contains('pengeluaran operasional konveksi')) {
      displayType = "PENGELUARAN KONVEKSI";
    } else if (typeLower.contains('pengeluaran operasional brilink')) {
      displayType = "PENGELUARAN BRILINK";
    } else if (typeLower.contains('pengeluaran operasional')) {
      displayType = "PRIVE";
    } else if (typeLower.contains('pengeluaran')) {
      displayType = "PENGELUARAN";
    } else if (typeLower.contains('bayar piutang') || typeLower.contains('piutang')) {
      displayType = "BAYAR PIUTANG";
    } else if (typeLower.contains('bayar hutang') || typeLower.contains('hutang')) {
      displayType = "BAYAR HUTANG";
    } else if (isPOS) {
      displayType = "POS";
      if (isPOSQRIS) displayType = "POS (QRIS)";
    } else if (isDanaMasukCabang) {
      displayType = "TERIMA ${type.replaceFirst("pindah ", "")}";
    }

    // ============ LABEL OUTLET ============
    String outletLabel = '';
    int? sessionOutletId = trx['session_outlet_id'] != null ? _safeInt(trx['session_outlet_id']) : null;
    if (sessionOutletId != null && sessionOutletId != myOutletId && isPusatOutlet) {
      outletLabel = 'Dari Outlet Lain';
    }

    if (trx['source_account_id'] == null && type.contains('tarik tunai')) {
      srcAccName = "Uang Kas (Laci)";
    }
    if (trx['destination_account_id'] == null && type == 'PPOB') {
      destAccName = "Pihak Ketiga / Operator";
    }

    String displayDescription = "";
    if (name.isEmpty || name == '-') {
      displayDescription = _safeString(trx['description']);
      if (displayDescription.isEmpty) displayDescription = 'Pindahan Dana';
    } else {
      displayDescription = "Pelanggan: $name${target.isNotEmpty ? ' ($target)' : ''}";
    }

    String formattedDate = '';
    try {
      if (trxDate.isNotEmpty) {
        DateTime? dateTime;
        try {
          dateTime = DateTime.parse(trxDate);
        } catch (e) {
          try {
            dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(trxDate);
          } catch (e2) {
            formattedDate = trxDate;
          }
        }
        if (dateTime != null) {
          formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
        }
      }
    } catch (e) {
      formattedDate = trxDate;
    }

    Color borderColor = Colors.grey.shade200;
    if (typeLower.contains('pengeluaran')) {
      borderColor = Colors.red.shade200;
    } else if (typeLower.contains('bayar piutang') || typeLower.contains('piutang')) {
      borderColor = Colors.green.shade200;
    } else if (typeLower.contains('bayar hutang') || typeLower.contains('hutang')) {  // <-- TAMBAHKAN
      borderColor = Colors.red.shade200;
    } else if (isPOS) {
      borderColor = isPOSQRIS
          ? const Color(0xFF7B1FA2).withOpacity(0.3)
          : const Color(0xFF6C3483).withOpacity(0.3);
    }
    if (typeLower.contains('tambah kas brangkas')) {
      displayType = "TAMBAH KAS BRANGKAS";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getTrxColor(type),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getTrxColor(type),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPOS && isPOSQRIS)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7B1FA2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_rounded, size: 10, color: const Color(0xFF7B1FA2)),
                                  const SizedBox(width: 2),
                                  Text(
                                    "QRIS",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7B1FA2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (outletLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                outletLabel,
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Text(
                "Rp ${nestedFormatIdr(amount)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isPOS && posItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isPOSQRIS
                    ? const Color(0xFF7B1FA2).withOpacity(0.05)
                    : const Color(0xFF6C3483).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPOSQRIS
                      ? const Color(0xFF7B1FA2).withOpacity(0.2)
                      : const Color(0xFF6C3483).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        size: 14,
                        color: isPOSQRIS ? const Color(0xFF7B1FA2) : const Color(0xFF6C3483),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Produk Terjual",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPOSQRIS ? const Color(0xFF7B1FA2) : const Color(0xFF6C3483),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...posItems.map((item) {
                    int qty = _safeInt(item['quantity']);
                    double harga = _safeDouble(item['harga']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${qty}x ${_safeString(item['nama_produk'])}",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "Rp ${nestedFormatIdr(harga)}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

          // ============ TAMPILAN DISKON (untuk POS) ============
          if (isPOS && hasDiskon && diskonPersen > 0) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.discount_rounded, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "Diskon ${diskonPersen.toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "- Rp ${nestedFormatIdr(diskonNominal)}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (kategoriName.isNotEmpty && typeLower.contains('pengeluaran'))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                kategoriName,
                style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
              ),
            ),

          Text(
            displayDescription,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Icon(isDanaMasukCabang ? Icons.download_rounded : Icons.login_rounded, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sourceDisplay.isNotEmpty ? sourceDisplay : (srcAccName.isEmpty ? "Eksternal" : srcAccName),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Icon(isDanaMasukCabang ? Icons.account_balance_wallet_rounded : Icons.logout_rounded, size: 16, color: _getTrxColor(type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destinationDisplay.isNotEmpty ? destinationDisplay : (destAccName.isEmpty ? "Eksternal" : destAccName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (karyawanName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        karyawanName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (feeTrx > 0 && !isDanaMasukCabang)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    "+ Fee: Rp ${nestedFormatIdr(feeTrx)}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  // ================================================

  // ============ BUILD CONTENT DENGAN SUB-TAB OUTLET ============
  Widget _buildContentWithOutletSubTab(String category) {
    var filtered = getFilteredByCategory(category);
    
    // Siapkan data untuk sub-tab
    List<Map<String, dynamic>> outletTabs = [];
    outletTabs.add({
      'id': null,
      'name': 'Semua Outlet',
    });
    for (var outlet in outletList) {
      outletTabs.add({
        'id': _safeInt(outlet['id']),
        'name': _safeString(outlet['nama_outlet']),
      });
    }
    
    // Data berdasarkan outlet yang dipilih
    List<dynamic> dataForOutlet = getFilteredByOutlet(filtered, selectedOutletId);
    
    Color summaryColor = primaryBlue;
    if (category == 'Pengeluaran Operasional') {
      summaryColor = const Color(0xFFD32F2F);
    } else if (category == 'Bayar Piutang') {
      summaryColor = const Color(0xFF2E7D32);
    } else if (category == 'Bayar Hutang') {  // <-- TAMBAHKAN
      summaryColor = const Color(0xFFD32F2F);
    } else if (category == 'POS') {
      summaryColor = const Color(0xFF6C3483);
    } else if (category == 'QRIS Bayar') {
      summaryColor = const Color(0xFF7B1FA2);
    } else if (category == 'Tarik Tunai M-Banking') {
      summaryColor = const Color(0xFF1A6FB0);
    } else if (category == 'Setoran Brilink') {
      summaryColor = const Color(0xFF2E7D32);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: summaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: category == 'Pengeluaran Operasional' || 
                    category == 'Bayar Piutang' || 
                    category == 'POS' ||
                    category == 'QRIS'
                ? Border.all(color: summaryColor.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${dataForOutlet.length} Transaksi",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Row(
                children: [
                  Text(
                    "Total: Rp ${nestedFormatIdr(getTotalAmountForData(dataForOutlet))}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: summaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Sub-tab outlet HANYA di outlet pusat
        if (showOutletSubTab && outletList.isNotEmpty && isPusatOutlet)
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _outletSubTabController,
              isScrollable: true,
              indicator: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade700,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(2),
              tabs: outletTabs.map((outlet) {
                int count = getOutletCount(outlet['id'], filtered);
                return Tab(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(outlet['name']),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
              onTap: (index) {
                setState(() {
                  selectedOutletId = outletTabs[index]['id'];
                  if (_outletSubTabController.index != index) {
                    _outletSubTabController.animateTo(index);
                  }
                });
              },
            ),
          ),
        const SizedBox(height: 8),

        Expanded(
          child: dataForOutlet.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Tidak ada transaksi",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Belum ada transaksi untuk kategori ini",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: dataForOutlet.length,
                  itemBuilder: (context, index) {
                    var trx = dataForOutlet[index];
                    return _buildTransactionCard(trx);
                  },
                ),
        ),
      ],
    );
  }

  double getTotalAmountForData(List<dynamic> data) {
    double total = 0;
    for (var item in data) {
      if (item['is_kredit_merchant'] == true) {
        total += _safeDouble(item['nominal']);
      } else {
        String type = _safeString(item['trx_type']);
        // ============ PERBAIKAN ============
        if (type.toLowerCase().contains('bayar hutang') || 
            type.toLowerCase().contains('pengeluaran')) {
          total += _safeDouble(item['nominal_source']);
        } else {
          total += _safeDouble(item['nominal_destination']);
        }
        // ================================
      }
    }
    return total;
  }

  // ============ BUILD KMC CONTENT ============
  Widget _buildKMCContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00A86B).withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${kmcList.length} KMC",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Row(
                children: [
                  Text(
                    "Total: Rp ${nestedFormatIdr(kmcTotal)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A86B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: kmcList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_money_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Belum ada Kredit Merchant",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "KMC akan muncul di sini setelah diinput",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: kmcList.length,
                  itemBuilder: (context, index) {
                    var item = kmcList[index];
                    return _buildKMCCard(item);
                  },
                ),
        ),
      ],
    );
  }
  // =========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: "Kembali",
        ),
        title: const Text(
          "Log Transaksi",
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
            onPressed: () {
              fetchTransactions();
              fetchKMCData();
            },
            tooltip: "Refresh",
          ),
        ],
      ),
      body: isLoading || isLoadingKaryawan || isLoadingOutlets
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 12.0),
              child: Column(
                children: [
                  // ============ FILTER SECTION ============
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                    applyFilters();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Cari pelanggan, deskripsi, dll...",
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: primaryBlue, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                value: selectedKaryawanId,
                                hint: const Text("Semua Karyawan", style: TextStyle(fontSize: 13)),
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: Colors.grey.shade400),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: primaryBlue, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text("Semua Karyawan", style: TextStyle(fontSize: 13)),
                                  ),
                                  ...karyawanList.map((k) {
                                    return DropdownMenuItem<int>(
                                      value: _safeInt(k['id']),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person, size: 16, color: primaryBlue),
                                          const SizedBox(width: 8),
                                          Text(
                                            _safeString(k['nama_karyawan']),
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    selectedKaryawanId = val;
                                    applyFilters();
                                  });
                                },
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                  color: selectedDate != null ? primaryBlue : Colors.grey.shade600,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: primaryBlue,
                                            onPrimary: Colors.white,
                                            onSurface: Colors.black87,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      selectedDate = picked;
                                      applyFilters();
                                      fetchKMCData();
                                    });
                                  }
                                },
                                tooltip: "Filter Tanggal",
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selectedKaryawanId != null || selectedDate != null)
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedKaryawanId = null;
                                      selectedDate = DateTime.now();
                                      applyFilters();
                                      fetchKMCData();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade200,
                                    foregroundColor: Colors.grey.shade700,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.clear_all_rounded, size: 16),
                                      SizedBox(width: 4),
                                      Text("Reset", style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (selectedDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today, size: 12, color: primaryBlue),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(selectedDate!),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedDate = DateTime.now();
                                            applyFilters();
                                            fetchKMCData();
                                          });
                                        },
                                        child: const Icon(Icons.close, size: 12, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${getAllData().length} transaksi ditemukan",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ======================================

                  const SizedBox(height: 8),

                  // ============ TAB BAR ============
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicator: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade700,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      padding: const EdgeInsets.all(3),
                      tabs: transactionCategories.map((category) {
                        int count = getCategoryCount(category);
                        return Tab(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(category),
                                if (count > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onTap: (index) {
                        _updateOutletSubTabVisibility(index);
                      },
                    ),
                  ),
                  // =================================

                  const SizedBox(height: 8),

                  // ============ TAB CONTENT ============
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: transactionCategories.map((category) {
                        if (category == 'KMC') {
                          return _buildKMCContent();
                        }

                        // Sub-tab outlet HANYA di outlet pusat
                        if (isPusatOutlet && categoriesWithOutletSubTab.contains(category)) {
                          return _buildContentWithOutletSubTab(category);
                        }

                        var filtered = getFilteredByCategory(category);

                        Color summaryColor = primaryBlue;
                        if (category == 'Pengeluaran Operasional') {
                          summaryColor = const Color(0xFFD32F2F);
                        } else if (category == 'Bayar Piutang') {
                          summaryColor = const Color(0xFF2E7D32);
                        } else if (category == 'POS') {
                          summaryColor = const Color(0xFF6C3483);
                        } else if (category == 'QRIS Bayar') {
                          summaryColor = const Color(0xFF7B1FA2);
                        }

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: summaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: category == 'Pengeluaran Operasional' ||
                                        category == 'Bayar Piutang' ||
                                        category == 'POS' ||
                                        category == 'QRIS Bayar'
                                    ? Border.all(color: summaryColor.withOpacity(0.3))
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${filtered.length} Transaksi",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Total: Rp ${nestedFormatIdr(getTotalAmount(category))}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: summaryColor,
                                        ),
                                      ),
                                      if (getTotalFee(category) > 0) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          "+ Fee: Rp ${nestedFormatIdr(getTotalFee(category))}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long_rounded,
                                            size: 48,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Tidak ada transaksi",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Belum ada transaksi untuk kategori ini",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        var trx = filtered[index];
                                        return _buildTransactionCard(trx);
                                      },
                                    ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  // =====================================
                ],
              ),
            ),
    );
  }
}