import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============ IMPORT ALLLOGTRANSAKSI ============
// Kita akan menggunakan kode yang sama persis dengan AllLogTransaksiScreen
// ===============================================

class TutupKasScreen extends StatefulWidget {
  final int sessionId;

  const TutupKasScreen({super.key, required this.sessionId});

  @override
  State<TutupKasScreen> createState() => _TutupKasScreenState();
}

// ============ LOG TRANSAKSI WIDGET (SAMA PERSIS DENGAN ALLLOGTRANSAKSI) ============
class _LogTransaksiWidget extends StatefulWidget {
  final int outletId;
  final int sessionId;

  const _LogTransaksiWidget({
    required this.outletId,
    required this.sessionId,
  });

  @override
  State<_LogTransaksiWidget> createState() => _LogTransaksiWidgetState();
}

class _LogTransaksiWidgetState extends State<_LogTransaksiWidget> with TickerProviderStateMixin {
  final String baseUrl = "https://barokahsport.com/brilink";

  int myOutletId = 1;
  int pusatOutletId = 1;
  bool isPusatOutlet = false;
  List<dynamic> transactions = [];
  List<dynamic> filteredTransactions = [];
  List<dynamic> karyawanList = [];
  List<dynamic> outletList = [];
  
  List<dynamic> kmcList = [];
  double kmcTotal = 0;

  int? selectedKaryawanId;
  DateTime? selectedDate;
  String searchQuery = '';
  
  int? selectedOutletId;
  bool showOutletSubTab = false;

  late TabController _tabController;
  late TabController _outletSubTabController;

  bool isLoading = false;
  bool isLoadingKaryawan = false;
  bool isLoadingOutlets = false;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

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

  final List<String> categoriesWithOutletSubTab = [
    'Tarik Tunai M-Banking',
    'Setoran Brilink',
  ];

  @override
  void initState() {
    super.initState();
    myOutletId = widget.outletId;
    _tabController = TabController(length: transactionCategories.length, vsync: this);
    _outletSubTabController = TabController(length: 1, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          selectedOutletId = null;
          _loadDataForTab(_tabController.index);
        });
        _updateOutletSubTabVisibility(_tabController.index);
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
    setState(() {
      selectedDate = DateTime.now();
    });

    await fetchPusatOutlet();
    await fetchKaryawan();
    await fetchOutlets();
    await fetchAllTransactions();
    await fetchKMCData();
  }

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

  Future<void> fetchKMCData() async {
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate ?? DateTime.now());
      final response = await http.get(
        Uri.parse("$baseUrl/get_fee_brilink_harian.php?outlet_id=$myOutletId&tanggal=$dateStr"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> rawData = data['data'] ?? [];
        
        List<dynamic> formattedData = rawData.map((item) {
          String accountName = item['account_name'] ?? 'BRI';
          String subCategory = item['account_sub_category'] ?? '';
          
          String accountDisplay;
          if (subCategory.isNotEmpty && subCategory != '-' && subCategory != 'NULL') {
            accountDisplay = "$accountName ($subCategory)";
          } else {
            accountDisplay = accountName;
          }
          
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
      }
    } catch (e) {
      print("Gagal mengambil KMC: $e");
    }
  }

  Future<void> fetchAllTransactions() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_all_transactions.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          transactions = data['data'] ?? [];
          transactions = transactions.where((trx) {
            return trx['session_id']?.toString() == widget.sessionId.toString();
          }).toList();
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

  void applyFilters() {
    var filtered = List.from(transactions);

    if (selectedKaryawanId != null && selectedKaryawanId! > 0) {
      filtered = filtered.where((trx) {
        int? karyawanId = trx['karyawan_id'] != null ? int.tryParse(trx['karyawan_id'].toString()) : null;
        return karyawanId == selectedKaryawanId;
      }).toList();
    }

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

  void _loadDataForTab(int index) {
    if (index == transactionCategories.length - 1) {
      if (selectedDate == null) {
        setState(() {
          selectedDate = DateTime.now();
        });
      }
      fetchKMCData();
    }
    _updateOutletSubTabVisibility(index);
  }

  void _reinitializeOutletSubTabController() {
    final oldController = _outletSubTabController;

    _outletSubTabController = TabController(
      length: outletList.length + 1, vsync: this,
    );
    _outletSubTabController.addListener(_onOutletSubTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
  }

  void _onOutletSubTabChanged() {
    if (!mounted) return;
    if (_outletSubTabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _updateOutletSubTabVisibility(int index) {
    String category = transactionCategories[index];
    bool show = isPusatOutlet && categoriesWithOutletSubTab.contains(category);
    
    if (showOutletSubTab != show) {
      setState(() {
        showOutletSubTab = show;
        if (show && outletList.isNotEmpty) {
          _reinitializeOutletSubTabController();
        }
      });
    }
  }

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

  List<dynamic> getAllData() {
    List<dynamic> allData = [];
    
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
    
    for (var kmc in kmcList) {
      String accountDisplay = kmc['account_display'] ?? 'BRI (Penampung Outlet)';
      
      allData.add({
        'id': kmc['id'] ?? 0,
        'trx_type': 'Kredit Merchant (KMC)',
        'trx_type_raw': 'kredit_merchant',
        'customer_name': 'KMC - BRI',
        'nominal_source': 0,
        'nominal_destination': double.tryParse(kmc['nominal']?.toString() ?? '0') ?? 0,
        'admin_fee': 0,
        'description': kmc['keterangan'] ?? 'Kredit Merchant',
        'karyawan_id': kmc['karyawan_id'],
        'karyawan_name': kmc['nama_karyawan'] ?? '',
        'source_account_name': 'Eksternal',
        'destination_account_name': accountDisplay,
        'created_at': kmc['created_at'] ?? '',
        'trx_date': kmc['created_at'] ?? '',
        'is_kredit_merchant': true,
        'source_display': 'Eksternal (KMC)',
        'destination_display': accountDisplay,
        'nominal': double.tryParse(kmc['nominal']?.toString() ?? '0') ?? 0,
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

  List<dynamic> getFilteredByCategory(String category) {
    if (category == 'Semua') {
      return getAllData();
    }
    
    if (category == 'KMC') {
      return kmcList;
    }

    return filteredTransactions.where((trx) {
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
        case 'Bayar Piutang':
          return type == 'bayar piutang' || type == 'buat piutang';
        case 'Bayar Hutang':
          return type == 'bayar hutang' || type == 'buat hutang';
        case 'Tambah Kas Brangkas':
          return type == 'tambah kas brangkas';
        case 'POS':
          return (trx['is_pos'] ?? false) || isPOSQRIS;
        default:
          return true;
      }
    }).toList();
  }

  double getTotalAmount(String category) {
    if (category == 'KMC') {
      return kmcTotal;
    }
    
    if (category == 'Semua') {
      double total = 0;
      var allData = getAllData();
      for (var item in allData) {
        double amount = 0;
        if (item['is_kredit_merchant'] == true) {
          amount = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
        } else {
          String type = item['trx_type']?.toString() ?? '';
          if (type.toLowerCase().contains('bayar hutang') || 
              type.toLowerCase().contains('pengeluaran')) {
            amount = double.tryParse(item['nominal_source']?.toString() ?? '0') ?? 0;
          } else {
            amount = double.tryParse(item['nominal_destination']?.toString() ?? '0') ?? 0;
          }
        }
        total += amount;
      }
      return total;
    }
    
    var filtered = getFilteredByCategory(category);
    return filtered.fold(0.0, (sum, trx) {
      String type = trx['trx_type']?.toString() ?? '';
      double amount = 0;
      
      if (type.toLowerCase().contains('bayar hutang') || 
          type.toLowerCase().contains('pengeluaran')) {
        amount = double.tryParse(trx['nominal_source']?.toString() ?? '0') ?? 0;
      } else {
        amount = double.tryParse(trx['nominal_destination']?.toString() ?? '0') ?? 0;
      }
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

  int getCategoryCount(String category) {
    if (category == 'KMC') {
      return kmcList.length;
    }
    if (category == 'Semua') {
      return getAllData().length;
    }
    
    var filtered = List<dynamic>.from(filteredTransactions);
    
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
    
    return getFilteredByCategory(category).length;
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

  String nestedFormatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
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

  Color _getTrxColor(String type) {
    String t = type.toLowerCase().trim();
    if (t.contains('qris')) return const Color(0xFF7B1FA2);
    if (t.contains('edc')) return primaryBlue;
    if (t.contains('mbanking')) return const Color(0xFF1A6FB0);
    if (t.contains('setoran')) return const Color(0xFF2E7D32);
    if (t.contains('ppob')) return primaryOrange;
    if (t.contains('pindah kas')) return const Color(0xFFE65100);
    if (t.contains('pindah saldo')) return const Color(0xFF00838F);
    if (t.contains('buat piutang')) return const Color(0xFF1B5E20);
    if (t.contains('buat hutang')) return const Color(0xFFB71C1C);
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

  Widget _buildKMCCard(var item) {
    double nominal = _safeDouble(item['nominal']);
    String keterangan = _safeString(item['keterangan']);
    String namaKaryawan = _safeString(item['nama_karyawan']);
    String createdAt = _safeString(item['created_at']);
    String accountDisplay = _safeString(item['account_display'] ?? item['account_name'] ?? 'BRI (Penampung Outlet)');
    
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

  Widget _buildTransactionCard(var trx) {
    if (trx['is_kredit_merchant'] == true) {
      return _buildKMCCardFromTransaction(trx);
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
    
    String subCategorySource = _safeString(trx['sub_category_source'] ?? '');
    String subCategoryDest = _safeString(trx['sub_category_destination'] ?? '');
    
    String sourceDisplay = _safeString(trx['source_display']);
    String destinationDisplay = _safeString(trx['destination_display']);
    bool isPOS = trx['is_pos'] ?? false;
    bool isPOSQRIS = trx['is_pos_qris'] ?? false;

    bool hasDiskon = trx['has_diskon'] ?? false;
    double diskonPersen = _safeDouble(trx['diskon_persen']);
    double diskonNominal = _safeDouble(trx['diskon_nominal']);

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

    String displayDescription = "";
    if (name.isEmpty || name == '-') {
      displayDescription = _safeString(trx['description']);
      if (displayDescription.isEmpty) displayDescription = 'Pindahan Dana';
    } else {
      displayDescription = "Pelanggan: $name${target.isNotEmpty ? ' ($target)' : ''}";
    }
    
    if (subCategorySource.isNotEmpty && subCategorySource != '-') {
      sourceDisplay = '$sourceDisplay ($subCategorySource)';
    }
    if (subCategoryDest.isNotEmpty && subCategoryDest != '-') {
      destinationDisplay = '$destinationDisplay ($subCategoryDest)';
    }

    String outletLabel = '';
    int? sessionOutletId = trx['session_outlet_id'] != null ? _safeInt(trx['session_outlet_id']) : null;
    if (sessionOutletId != null && sessionOutletId != myOutletId && isPusatOutlet) {
      outletLabel = 'Dari Outlet Lain';
    }

    Color borderColor = Colors.grey.shade200;
    if (typeLower.contains('pengeluaran operasional konveksi')) {
      borderColor = const Color(0xFFB71C1C).withOpacity(0.3);
    } else if (typeLower.contains('pengeluaran operasional brilink')) {
      borderColor = const Color(0xFFE65100).withOpacity(0.3);
    } else if (typeLower.contains('pengeluaran')) {
      borderColor = Colors.red.shade200;
    } else if (typeLower.contains('bayar piutang') || typeLower.contains('piutang')) {
      borderColor = Colors.green.shade200;
    } else if (typeLower.contains('bayar hutang') || typeLower.contains('hutang')) {
      borderColor = Colors.red.shade200;
    } else if (isPOS) {
      borderColor = isPOSQRIS 
          ? const Color(0xFF7B1FA2).withOpacity(0.3)
          : const Color(0xFF6C3483).withOpacity(0.3);
    }

    if (typeLower.contains('tambah kas brangkas')) {
        displayType = "TAMBAH KAS BRANGKAS";
        srcAccName = "Brangkas";
        destAccName = "Uang Kas (Laci)";
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
                          if (isPOSQRIS)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C3483).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF6C3483).withOpacity(0.2)),
                              ),
                              child: Text(
                                "POS",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6C3483),
                                ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.label_rounded, size: 12, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text(
                    kategoriName,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
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
                Icon(
                  isDanaMasukCabang ? Icons.download_rounded : Icons.login_rounded, 
                  size: 16, 
                  color: Colors.grey.shade500
                ),
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
                Icon(
                  isDanaMasukCabang ? Icons.account_balance_wallet_rounded : Icons.logout_rounded, 
                  size: 16, 
                  color: _getTrxColor(type)
                ),
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

  Widget _buildKMCCardFromTransaction(var item) {
    double nominal = _safeDouble(item['nominal']);
    String keterangan = _safeString(item['description']);
    String namaKaryawan = _safeString(item['karyawan_name']);
    String createdAt = _safeString(item['created_at']);
    String accountDisplay = _safeString(item['destination_display'] ?? 'BRI (Penampung Outlet)');
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

  Widget _buildContentWithOutletSubTab(String category) {
    var filtered = getFilteredByCategory(category);
    
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
    
    List<dynamic> dataForOutlet = getFilteredByOutlet(filtered, selectedOutletId);
    
    Color summaryColor = primaryBlue;
    if (category == 'Prive') {
      summaryColor = const Color(0xFF6A1B9A);
    } else if (category == 'Pengeluaran Operasional Konveksi') {
      summaryColor = const Color(0xFFB71C1C);
    } else if (category == 'Pengeluaran Operasional Brilink') {
      summaryColor = const Color(0xFFE65100);
    } else if (category == 'Bayar Piutang') {
      summaryColor = const Color(0xFF2E7D32);
    } else if (category == 'Bayar Hutang') {
      summaryColor = const Color(0xFFD32F2F);
    } else if (category == 'POS') {
      summaryColor = const Color(0xFF6C3483);
    } else if (category == 'QRIS') {
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
            border: category == 'Prive' || 
                    category == 'Pengeluaran Operasional Konveksi' ||
                    category == 'Pengeluaran Operasional Brilink' ||
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
        if (type.toLowerCase().contains('bayar hutang') || 
            type.toLowerCase().contains('pengeluaran')) {
          total += _safeDouble(item['nominal_source']);
        } else {
          total += _safeDouble(item['nominal_destination']);
        }
      }
    }
    return total;
  }

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Live Audit Log Transaksi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF00529C),
                    ),
                  ),
                  Text(
                    "${transactions.length} Total Transaksi",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Rp ${nestedFormatIdr(getTotalAmount('Semua'))}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: primaryBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedKaryawanId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: "Pilih Karyawan",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            const Text(
                              "Semua Karyawan",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      ...karyawanList.map((karyawan) {
                        return DropdownMenuItem<int>(
                          value: int.parse(karyawan['id'].toString()),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 16, color: primaryBlue),
                              const SizedBox(width: 8),
                              Text(karyawan['nama_karyawan'] ?? 'Tanpa Nama'),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (newValue) {
                      setState(() {
                        selectedKaryawanId = newValue;
                        applyFilters();
                      });
                    },
                  ),
                ),
                if (selectedKaryawanId != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                    onPressed: () {
                      setState(() {
                        selectedKaryawanId = null;
                        applyFilters();
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
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
              padding: const EdgeInsets.all(2),
              tabs: transactionCategories.map((category) {
                int count = getCategoryCount(category);
                
                return Tab(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category, style: const TextStyle(fontSize: 10)),
                        if (count > 0) ...[
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: transactionCategories.map((category) {
                if (category == 'KMC') {
                  return _buildKMCContent();
                }
                
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
                } else if (category == 'QRIS') {
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
                                category == 'QRIS'
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
        ],
      ),
    );
  }
}

// ============ MUTASI REKENING WIDGET ============
class _MutasiRekeningWidget extends StatefulWidget {
  final int outletId;
  final int sessionId;
  final String baseUrl;

  const _MutasiRekeningWidget({
    required this.outletId,
    required this.sessionId,
    required this.baseUrl,
  });

  @override
  State<_MutasiRekeningWidget> createState() => _MutasiRekeningWidgetState();
}

class _MutasiRekeningWidgetState extends State<_MutasiRekeningWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  final Color primaryGreen = const Color(0xFF2E7D32);
  final Color primaryRed = const Color(0xFFD32F2F);

  bool isLoading = false;
  List<dynamic> allData = [];
  List<dynamic> accounts = [];
  List<dynamic> karyawanList = [];
  
  double totalDebitAll = 0;
  double totalKreditAll = 0;
  int totalTransaksiAll = 0;
  
  DateTime selectedDate = DateTime.now();
  DateTime? startDate;
  DateTime? endDate;
  bool useCustomRange = false;
  int selectedKaryawanId = 0;
  int selectedAccountId = 0;
  
  Set<int> expandedAccounts = {};

  @override
  void initState() {
    super.initState();
    fetchKaryawan();
    fetchMutasiRekening();
  }

  Future<void> fetchKaryawan() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.baseUrl}/get_karyawan.php?outlet_id=${widget.outletId}"),
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
      String url = "${widget.baseUrl}/get_mutasi_rekening.php?outlet_id=${widget.outletId}";
      
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
        _showSnackBar(data['message'] ?? "Gagal memuat data");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

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

  void _showSnackBar(String message) {
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
    if (t.contains('qris')) return const Color(0xFF7B1FA2);
    if (t.contains('pos')) return const Color(0xFF6C3483);
    if (t.contains('ppob')) return const Color(0xFFF26A25);
    if (t.contains('kredit merchant') || t.contains('kmc')) return const Color(0xFF00A86B);
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mutasi Rekening",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF00529C),
                      ),
                    ),
                    Text(
                      "${allData.length} Akun",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLoading)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: primaryBlue, size: 20),
                  onPressed: fetchMutasiRekening,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Refresh",
                ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 24),
                      color: primaryBlue,
                      onPressed: _previousDate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: useCustomRange ? _selectCustomRange : _selectDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              if (useCustomRange && startDate != null && endDate != null)
                                Text(
                                  "${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                )
                              else
                                Text(
                                  _formatTanggalDisplay(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 24),
                      color: primaryBlue,
                      onPressed: _nextDate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.today_rounded, size: 18, color: primaryBlue),
                      onPressed: _goToToday,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                      tooltip: "Hari Ini",
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.date_range_rounded,
                        size: 18,
                        color: useCustomRange ? primaryOrange : Colors.grey.shade600,
                      ),
                      onPressed: _selectCustomRange,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                      tooltip: "Pilih Rentang Tanggal",
                    ),
                    if (selectedKaryawanId > 0 || selectedAccountId > 0 || useCustomRange)
                      IconButton(
                        icon: Icon(Icons.clear_all_rounded, size: 18, color: Colors.red.shade700),
                        onPressed: resetFilters,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                        tooltip: "Reset Filter",
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedKaryawanId,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: primaryBlue, size: 20),
                            hint: const Text("Semua Karyawan", style: TextStyle(fontSize: 11)),
                            items: [
                              const DropdownMenuItem(value: 0, child: Text("Semua Karyawan", style: TextStyle(fontSize: 11))),
                              ...karyawanList.map((k) {
                                return DropdownMenuItem(
                                  value: int.parse(k['id'].toString()),
                                  child: Text(k['nama_karyawan'] ?? 'Unknown', style: const TextStyle(fontSize: 11)),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedAccountId,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: primaryBlue, size: 20),
                            hint: const Text("Semua Akun", style: TextStyle(fontSize: 11)),
                            items: [
                              const DropdownMenuItem(value: 0, child: Text("Semua Akun", style: TextStyle(fontSize: 11))),
                              ...accounts.map((acc) {
                                int id = int.tryParse(acc['id']?.toString() ?? '0') ?? 0;
                                String name = acc['name']?.toString() ?? 'Unknown';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    name, 
                                    style: const TextStyle(fontSize: 11),
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
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Total Debit",
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        ),
                        Text(
                          "Rp ${_formatIdr(totalDebitAll)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Total Kredit",
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        ),
                        Text(
                          "Rp ${_formatIdr(totalKreditAll)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.shade300),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Total Transaksi",
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        ),
                        Text(
                          "$totalTransaksiAll",
                          style: TextStyle(
                            fontSize: 12,
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
            const SizedBox(height: 10),

            Expanded(
              child: allData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            "Tidak ada data mutasi",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Belum ada transaksi untuk periode ini",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: allData.length,
                      itemBuilder: (context, index) {
                        var account = allData[index];
                        return _buildAccountCard(account);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(dynamic account) {
    if (account == null) return const SizedBox.shrink();
    
    int accountId = account['account_id'] ?? 0;
    String accountName = account['account_name'] ?? 'Unknown';
    String category = account['category'] ?? '';
    String subCategory = account['sub_category'] ?? '';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasTransaksi ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
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
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasTransaksi 
                          ? primaryBlue.withOpacity(0.08) 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      category == 'Bank' ? Icons.account_balance_rounded : Icons.account_balance_wallet_rounded,
                      color: hasTransaksi ? primaryBlue : Colors.grey.shade400,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: hasTransaksi ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          "Saldo: Rp ${_formatIdr(saldoAkhir)}",
                          style: TextStyle(
                            fontSize: 10,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasTransaksi ? Colors.grey.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${mutasi.length} trx",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: hasTransaksi ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  if (hasTransaksi) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.grey.shade600,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          if (isExpanded && hasTransaksi) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text("Saldo Awal", style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(saldoAwal)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Debit", style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(totalDebit)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryGreen)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Kredit", style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(totalKredit)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryRed)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text("Saldo Akhir", style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                            Text("Rp ${_formatIdr(saldoAkhir)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryBlue)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 6),
                  
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24, 
                                  child: Text(
                                    "No", 
                                    style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Text(
                                    "Tanggal", 
                                    style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                  )
                                ),
                                Expanded(
                                  flex: 3, 
                                  child: Text(
                                    "Keterangan", 
                                    style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Debit", 
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                    ),
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Kredit", 
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                    ),
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Saldo", 
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500, fontWeight: FontWeight.bold)
                                    ),
                                  )
                                ),
                              ],
                            ),
                          ),
                          
                          ...mutasi.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var item = entry.value;
                            double debit = double.tryParse(item['debit']?.toString() ?? '0') ?? 0;
                            double kredit = double.tryParse(item['kredit']?.toString() ?? '0') ?? 0;
                            double saldo = double.tryParse(item['saldo']?.toString() ?? '0') ?? 0;
                            String type = item['type'] ?? '';
                            String keterangan = item['keterangan'] ?? '';
                            String tanggal = _formatTanggal(item['tanggal']);
                            String karyawan = item['karyawan'] ?? '';
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                color: idx % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      "${idx + 1}",
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      tanggal,
                                      style: TextStyle(fontSize: 8, color: Colors.grey.shade800),
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
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: _getTypeColor(type),
                                          ),
                                        ),
                                        if (keterangan.isNotEmpty)
                                          Text(
                                            keterangan,
                                            style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (karyawan.isNotEmpty)
                                          Text(
                                            "Karyawan: $karyawan",
                                            style: TextStyle(fontSize: 6, color: Colors.grey.shade400),
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
                                          fontSize: 9,
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
                                          fontSize: 9,
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
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: saldo >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
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

// ============ TUTUP KAS SCREEN UTAMA ============
class _TutupKasScreenState extends State<TutupKasScreen> 
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // ============ TAB CONTROLLER ============
  late TabController _tabController;
  int _selectedTabIndex = 0;

  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  int pusatOutletId = 1;
  bool isPusatOutlet = false;

  List<dynamic> activeAccounts = [];
  List<dynamic> sessionTransactions = [];
  List<dynamic> karyawanList = [];
  List<dynamic> outletList = [];
  
  Map<int, double> openingBalancesMap = {};
  double cashOpening = 0;

  List<dynamic> kmcList = [];
  double kmcTotal = 0;
  
  double totalSelisihEWallet = 0;
  String selisihEWalletText = "Rp 0";
  String? akunEWalletYangDihitung;

  int? loggedInKaryawanId;
  String? loggedInKaryawanName;

  DateTime? selectedDate;

  Map<int, TextEditingController> closingControllers = {};
  final TextEditingController cashLaciPhysicalController = TextEditingController();
  
  Map<int, TextEditingController> keteranganControllers = {};
  final TextEditingController cashLaciKeteranganController = TextEditingController();

  double cashLaciSystemAmount = 0;

  bool isLoadingData = false;
  bool isLoadingOutlets = false;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  final Color primaryGreen = const Color(0xFF00A86B);

  bool isSubmitting = false;

  final _cardBorderRadius = BorderRadius.circular(16);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    loadOutletSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    cashLaciPhysicalController.dispose();
    cashLaciKeteranganController.dispose();
    for (var controller in closingControllers.values) {
      controller.dispose();
    }
    for (var controller in keteranganControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadOutletSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      selectedDate = DateTime.now();
    });

    await fetchPusatOutlet();
    await fetchLoggedInKaryawan();
    await fetchKaryawan();
    await fetchOutlets();
    await fetchOpeningBalances();
    await fetchActiveBalances();
    await fetchAllTransactions();
  }

  Future<void> fetchLoggedInKaryawan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int? karyawanId = prefs.getInt('karyawan_id');
      String? karyawanName = prefs.getString('karyawan_nama');
      
      if (karyawanId != null && karyawanId > 0) {
        setState(() {
          loggedInKaryawanId = karyawanId;
          loggedInKaryawanName = karyawanName ?? 'Karyawan';
        });
      } else {
        final response = await http.get(
          Uri.parse("$baseUrl/get_karyawan.php?outlet_id=$myOutletId&limit=1"),
        );
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == true) {
          List<dynamic> karyawan = data['data'] ?? [];
          if (karyawan.isNotEmpty) {
            setState(() {
              loggedInKaryawanId = int.parse(karyawan.first['id'].toString());
              loggedInKaryawanName = karyawan.first['nama_karyawan'] ?? 'Karyawan';
            });
          }
        }
      }
    } catch (e) {
      print("Gagal mengambil karyawan login: $e");
    }
  }

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
        }
      }
    } catch (e) {
      print("Gagal mengambil outlet pusat: $e");
    }
  }

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
        });
      }
    } catch (e) {
      print("Gagal mengambil data outlet: $e");
    } finally {
      setState(() => isLoadingOutlets = false);
    }
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
      print("Gagal mengambil data karyawan: $e");
    }
  }

  Future<void> fetchOpeningBalances() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_opening_balances.php?outlet_id=$myOutletId&session_id=${widget.sessionId}"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> openingData = data['data'] ?? [];
        Map<int, double> tempMap = {};
        
        for (var item in openingData) {
          int accountId = int.parse(item['account_id'].toString());
          double amount = double.tryParse(item['opening_balance']?.toString() ?? item['balance']?.toString() ?? '0') ?? 0;
          tempMap[accountId] = amount;
        }
        
        setState(() {
          openingBalancesMap = tempMap;
        });
      }
    } catch (e) {
      print("Gagal mengambil opening balances: $e");
    }
  }

  Future<void> fetchActiveBalances() async {
    setState(() => isLoadingData = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_balances_for_closing.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        double laciCurrent = double.tryParse(data['cash_laci_current']?.toString() ?? '0') ?? 0.0;
        double opening = double.tryParse(data['cash_opening']?.toString() ?? '0') ?? 0.0;
        if (opening == 0) {
          opening = double.tryParse(data['cash_laci_awal']?.toString() ?? '0') ?? 0.0;
        }
        
        List<dynamic> accounts = data['data'] ?? [];

        setState(() {
          cashLaciSystemAmount = laciCurrent;
          cashOpening = opening;
          cashLaciPhysicalController.text = "0"; 
          cashLaciKeteranganController.text = "";
          activeAccounts = accounts;
          
          for (var acc in activeAccounts) {
            int accId = int.parse(acc['id'].toString());
            closingControllers[accId] = TextEditingController(text: "0");
            keteranganControllers[accId] = TextEditingController(text: "");
          }
        });
        
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat saldo");
      }
    } catch (e) {
      showSnackBar("Gagal memuat saldo berjalan sesi ini: $e");
    } finally {
      setState(() => isLoadingData = false);
    }
  }

  Future<void> fetchAllTransactions() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_all_transactions.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> allTransactions = data['data'] ?? [];
        List<dynamic> transactionsForThisSession = allTransactions.where((trx) {
          return trx['session_id']?.toString() == widget.sessionId.toString();
        }).toList();
        setState(() {
          sessionTransactions = transactionsForThisSession;
        });
      }
    } catch (e) {
      print("Error mengambil semua transaksi: $e");
      showSnackBar("Gagal memuat log transaksi");
    }
  }

  bool _isAllDataFilled() {
    if (cashLaciPhysicalController.text.isEmpty || 
        cashLaciPhysicalController.text == '0' || 
        cashLaciPhysicalController.text == 'Rp 0') {
      return false;
    }
    
    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double openingBalance = openingBalancesMap[id] ?? 0;
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      
      if (openingBalance == 0 && systemBalance == 0) {
        continue;
      }
      
      var controller = closingControllers[id];
      if (controller == null || 
          controller.text.isEmpty || 
          controller.text == '0' || 
          controller.text == 'Rp 0') {
        return false;
      }
    }
    
    return true;
  }
  
  bool _isAccountVisible(dynamic acc) {
    int id = int.parse(acc['id'].toString());
    double openingBalance = openingBalancesMap[id] ?? 0;
    double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
    
    if (openingBalance == 0 && systemBalance == 0) {
      return false;
    }
    return true;
  }

  String _getSelisihStatus(double systemValue, String physicalText) {
    if (physicalText.isEmpty || physicalText == '0' || physicalText == 'Rp 0') {
      return 'Belum ada data';
    }
    
    String cleanText = physicalText.replaceAll('.', '');
    cleanText = cleanText.replaceAll('Rp ', '');
    double physicalValue = double.tryParse(cleanText) ?? 0;
    double selisih = physicalValue - systemValue;
    
    if (selisih == 0) {
      return '✅ Cocok';
    } else if (selisih > 0) {
      return '⬆️ Kelebihan';
    } else {
      return '⬇️ Kurang';
    }
  }

  Color _getSelisihStatusColor(double systemValue, String physicalText) {
    if (physicalText.isEmpty || physicalText == '0' || physicalText == 'Rp 0') {
      return Colors.grey;
    }
    
    String cleanText = physicalText.replaceAll('.', '');
    cleanText = cleanText.replaceAll('Rp ', '');
    double physicalValue = double.tryParse(cleanText) ?? 0;
    double selisih = physicalValue - systemValue;
    
    if (selisih == 0) {
      return Colors.green;
    } else if (selisih > 0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  bool _isCashNegative() {
    if (cashLaciPhysicalController.text.isEmpty || 
        cashLaciPhysicalController.text == '0' || 
        cashLaciPhysicalController.text == 'Rp 0') {
      return false;
    }
    String cleanText = cashLaciPhysicalController.text.replaceAll('.', '');
    cleanText = cleanText.replaceAll('Rp ', '');
    double value = double.tryParse(cleanText) ?? 0;
    return value < 0;
  }

  bool _isAccountNegative(int accountId) {
    var controller = closingControllers[accountId];
    if (controller == null || controller.text.isEmpty || 
        controller.text == '0' || controller.text == 'Rp 0') {
      return false;
    }
    String cleanText = controller.text.replaceAll('.', '');
    cleanText = cleanText.replaceAll('Rp ', '');
    double value = double.tryParse(cleanText) ?? 0;
    return value < 0;
  }

  bool _hasNegativeData() {
    if (cashLaciPhysicalController.text.isNotEmpty &&
        cashLaciPhysicalController.text != '0' &&
        cashLaciPhysicalController.text != 'Rp 0') {
      
      String cleanText = cashLaciPhysicalController.text
          .replaceAll('.', '')
          .replaceAll('Rp ', '')
          .replaceAll('Rp', '')
          .trim();

      double physicalValue = double.tryParse(cleanText) ?? 0;
      double selisih = physicalValue - cashLaciSystemAmount;

      if (selisih < 0) {
        return true;
      }
    }

    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());

      double openingBalance = openingBalancesMap[id] ?? 0;
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;

      if (openingBalance == 0 && systemBalance == 0) {
        continue;
      }

      final controller = closingControllers[id];

      if (controller == null ||
          controller.text.isEmpty ||
          controller.text == '0' ||
          controller.text == 'Rp 0') {
        continue;
      }

      String cleanText = controller.text
          .replaceAll('.', '')
          .replaceAll('Rp ', '')
          .replaceAll('Rp', '')
          .trim();

      double physicalValue = double.tryParse(cleanText) ?? 0;
      double selisih = physicalValue - systemBalance;

      if (selisih < 0) {
        return true;
      }
    }

    return false;
  }

  Future<void> _showKeteranganDialog(String title, TextEditingController controller) async {
    final TextEditingController tempController = TextEditingController(text: controller.text);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.45,
            constraints: const BoxConstraints(maxWidth: 500, minWidth: 350),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryBlue, primaryBlue.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.note_add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Keterangan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keterangan untuk akun ini',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tempController,
                        maxLines: 6,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Tulis keterangan tambahan...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryBlue, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Maksimal 500 karakter',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
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
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Batal',
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
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: primaryBlue.withOpacity(0.3),
                        ),
                        onPressed: () {
                          controller.text = tempController.text;
                          setState(() {});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Keterangan berhasil disimpan',
                                style: const TextStyle(fontSize: 13),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                              backgroundColor: primaryGreen,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Simpan Keterangan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showNegativeDataConfirmation() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            constraints: const BoxConstraints(maxWidth: 450, minWidth: 320),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange.shade200, width: 2),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '⚠️ Data Negatif Terdeteksi!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
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
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Terdapat nilai negatif pada salah satu kolom fisik.\n'
                              'Apakah Anda yakin ingin melanjutkan penutupan kas?',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade800,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
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
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: Text(
                          'Batal, Perbaiki',
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
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: Colors.orange.withOpacity(0.3),
                        ),
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Lanjutkan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> submitCloseSession() async {
    if (cashLaciPhysicalController.text.isEmpty || 
        cashLaciPhysicalController.text == '0' || 
        cashLaciPhysicalController.text == 'Rp 0') {
      showSnackBar("⚠️ Silakan isi total uang fisik akhir di laci kasir!");
      return;
    }

    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double openingBalance = openingBalancesMap[id] ?? 0;
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      
      if (openingBalance == 0 && systemBalance == 0) {
        continue;
      }
      
      if (closingControllers[id] == null || 
          closingControllers[id]!.text.isEmpty ||
          closingControllers[id]!.text == '0' ||
          closingControllers[id]!.text == 'Rp 0') {
        showSnackBar("⚠️ Mohon lengkapi seluruh rincian kas saldo akhir akun!");
        return;
      }
    }

    if (loggedInKaryawanId == null || loggedInKaryawanId! <= 0) {
      showSnackBar("⚠️ Data karyawan yang login tidak ditemukan!");
      return;
    }

    if (_hasNegativeData()) {
      bool? confirm = await _showNegativeDataConfirmation();
      if (confirm != true) {
        return;
      }
    }

    setState(() => isSubmitting = true);

    Map<int, double> amountPerAkun = {};
    Map<int, double> selisihPerAkun = {};

    for (final acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      String physicalText = closingControllers[id]?.text ?? '0';
      physicalText = physicalText.replaceAll('.', '');
      physicalText = physicalText.replaceAll('Rp ', '');
      double physicalAmount = double.tryParse(physicalText) ?? 0;
      
      double amount = physicalAmount;
      double selisih = physicalAmount - systemBalance;
      
      amountPerAkun[id] = amount;
      if (selisih != 0) {
          selisihPerAkun[id] = selisih;
      }
    }

    List<Map<String, dynamic>> balancesPayload = [];
    closingControllers.forEach((accountId, controller) {
      double amount = amountPerAkun[accountId] ?? 0;
      double selisih = selisihPerAkun[accountId] ?? 0;
      String keterangan = keteranganControllers[accountId]?.text ?? '';
      
      balancesPayload.add({
        "account_id": accountId,
        "amount": amount,
        "selisih_e_wallet": selisih,
        "keterangan": keterangan
      });
    });

    String cleanCashLaci = cashLaciPhysicalController.text.replaceAll('.', '');
    cleanCashLaci = cleanCashLaci.replaceAll('Rp ', '');
    String cashKeterangan = cashLaciKeteranganController.text;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save_closing_balances.php"),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode({
          "session_id": widget.sessionId,
          "outlet_id": myOutletId,
          "karyawan_id": loggedInKaryawanId ?? 0,
          "cash_closing_total": double.parse(cleanCashLaci),
          "cash_keterangan": cashKeterangan,
          "balances": balancesPayload,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("✅ Sesi Kasir Berhasil Ditutup!");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        showSnackBar(data['message'] ?? "Gagal memproses penutupan kas");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan koneksi database: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        backgroundColor: message.contains('✅') ? primaryGreen : primaryBlue,
        duration: const Duration(seconds: 3),
      ),
    );
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

  double _getSelisih(double systemValue, String physicalText) {
    if (physicalText.isEmpty) return 0;
    String cleanText = physicalText.replaceAll('.', '');
    cleanText = cleanText.replaceAll('Rp ', '');
    double physicalValue = double.tryParse(cleanText) ?? 0;
    return physicalValue - systemValue;
  }

  Color _getSelisihColor(double selisih) {
    if (selisih == 0) return Colors.green;
    if (selisih > 0) return Colors.orange;
    return Colors.red;
  }

  String _getSelisihText(double selisih) {
    if (selisih == 0) return "Sama";
    if (selisih > 0) return "+${_formatIdr(selisih)}";
    return _formatIdr(selisih);
  }

  String _getTotalSelisihText() {
    double totalSelisih = 0;
    totalSelisih += _getSelisih(cashLaciSystemAmount, cashLaciPhysicalController.text);
    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      String physicalText = closingControllers[id]?.text ?? '';
      totalSelisih += _getSelisih(systemBalance, physicalText);
    }
    return _getSelisihText(totalSelisih);
  }

  Color _getTotalSelisihColor() {
    double totalSelisih = 0;
    totalSelisih += _getSelisih(cashLaciSystemAmount, cashLaciPhysicalController.text);
    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      String physicalText = closingControllers[id]?.text ?? '';
      totalSelisih += _getSelisih(systemBalance, physicalText);
    }
    return _getSelisihColor(totalSelisih);
  }

  Widget _buildSelisihWidget(double systemValue, String physicalText) {
    String status = _getSelisihStatus(systemValue, physicalText);
    Color statusColor = _getSelisihStatusColor(systemValue, physicalText);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTotalSelisihWidget() {
    double totalSelisih = 0;
    totalSelisih += _getSelisih(cashLaciSystemAmount, cashLaciPhysicalController.text);
    for (var acc in activeAccounts) {
      int id = int.parse(acc['id'].toString());
      double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
      String physicalText = closingControllers[id]?.text ?? '';
      totalSelisih += _getSelisih(systemBalance, physicalText);
    }
    Color color = _getSelisihColor(totalSelisih);
    String text = _getSelisihText(totalSelisih);
    
    bool allFilled = _isAllDataFilled();
    
    if (!allFilled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
        ),
        child: Text(
          "Belum ada data",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          textAlign: TextAlign.right,
        ),
      );
    }
    
    String statusIcon = '';
    if (totalSelisih == 0) {
      statusIcon = '✅ ';
    } else if (totalSelisih > 0) {
      statusIcon = '⬆️ ';
    } else {
      statusIcon = '⬇️ ';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusIcon,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    bool isDataComplete = _isAllDataFilled();
    bool hasNegative = _hasNegativeData();
    List<dynamic> visibleAccounts = activeAccounts.where((acc) => _isAccountVisible(acc)).toList();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              "Tutup Kas",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryOrange, primaryOrange.withOpacity(0.5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
      body: isLoadingData || isLoadingOutlets
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFF26A25),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Memuat data...",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1920),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GRID KIRI (Rekonsiliasi) - 55%
                      Expanded(
                        flex: 55,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: _cardBorderRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Input hasil opname fisik untuk penutupan kas",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "Outlet #$myOutletId",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // SUMMARY CARD
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: _cardBorderRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryItem(
                                        label: "Total Selisih",
                                        value: _getTotalSelisihText(),
                                        color: _getTotalSelisihColor(),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 44,
                                      color: Colors.grey.shade200,
                                    ),
                                    Expanded(
                                      child: _buildSummaryItem(
                                        label: "Total Transaksi",
                                        value: sessionTransactions.length.toString(),
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Rekonsiliasi Table
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: _cardBorderRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryBlue.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.fact_check_rounded,
                                            color: primaryBlue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          "Komparasi Saldo Pembukuan",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00529C),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(height: 1, color: Colors.grey.shade100),
                                    const SizedBox(height: 12),

                                    // HEADER
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            flex: 4,
                                            child: Text(
                                              "Komponen Akun",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "Saldo Awal",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "Sistem",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              "Fisik",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                "Selisih",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Color(0xFFF26A25),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                "Keterangan",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(height: 1, color: Colors.grey.shade200),

                                    // UANG KAS (LACI)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: primaryOrange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Icon(
                                                    Icons.money_rounded,
                                                    size: 16,
                                                    color: primaryOrange,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  "Uang Kas (Laci)",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Rp ${_formatIdr(cashOpening)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: primaryBlue.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Rp ${_formatIdr(cashLaciSystemAmount)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: primaryBlue,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 38,
                                                    child: TextField(
                                                      controller: cashLaciPhysicalController,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [CurrencyInputFormatter()],
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: _isCashNegative() ? Colors.red : Colors.black87,
                                                      ),
                                                      decoration: InputDecoration(
                                                        prefixText: "Rp ",
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                            color: _isCashNegative() ? Colors.red : Colors.grey.shade300,
                                                          ),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                            color: _isCashNegative() ? Colors.red : const Color(0xFFF26A25),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        filled: true,
                                                        fillColor: _isCashNegative() ? Colors.red.shade50 : Colors.grey.shade50,
                                                      ),
                                                      onChanged: (value) {
                                                        setState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                if (_isCashNegative())
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Icon(
                                                      Icons.warning_rounded,
                                                      color: Colors.red,
                                                      size: 16,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _buildSelisihWidget(
                                                cashLaciSystemAmount,
                                                cashLaciPhysicalController.text,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 4),
                                              child: SizedBox(
                                                height: 38,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: cashLaciKeteranganController.text.isNotEmpty 
                                                        ? primaryBlue 
                                                        : Colors.grey.shade200,
                                                    foregroundColor: cashLaciKeteranganController.text.isNotEmpty 
                                                        ? Colors.white 
                                                        : Colors.grey.shade600,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    elevation: cashLaciKeteranganController.text.isNotEmpty ? 2 : 0,
                                                    shadowColor: cashLaciKeteranganController.text.isNotEmpty 
                                                        ? primaryBlue.withOpacity(0.3) 
                                                        : Colors.transparent,
                                                  ),
                                                  onPressed: () {
                                                    _showKeteranganDialog(
                                                      'Uang Kas (Laci)', 
                                                      cashLaciKeteranganController
                                                    );
                                                  },
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        cashLaciKeteranganController.text.isNotEmpty 
                                                            ? Icons.edit_note_rounded 
                                                            : Icons.note_add_rounded,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        cashLaciKeteranganController.text.isNotEmpty 
                                                            ? 'Edit' 
                                                            : 'Keterangan',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(color: Colors.grey.shade100, height: 1),

                                    // AKUN LAINNYA - HANYA YANG VISIBLE
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: visibleAccounts.length,
                                      separatorBuilder: (context, idx) => Divider(color: Colors.grey.shade100, height: 1),
                                      itemBuilder: (context, index) {
                                        var acc = visibleAccounts[index];
                                        int id = int.parse(acc['id'].toString());
                                        double systemBalance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
                                        double openingBalance = openingBalancesMap[id] ?? 0;
                                        String category = acc['category'] ?? '';
                                        String subCategory = acc['sub_category'] ?? '';
                                        bool isNegative = _isAccountNegative(id);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 4,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      acc['name'] ?? 'Tanpa Nama',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (category == 'Bank' && subCategory.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        margin: const EdgeInsets.only(top: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          subCategory,
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.w500,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Rp ${_formatIdr(openingBalance)}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 10,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: primaryBlue.withOpacity(0.06),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Rp ${_formatIdr(systemBalance)}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 11,
                                                        color: primaryBlue,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: 36,
                                                        child: TextField(
                                                          controller: closingControllers[id],
                                                          keyboardType: TextInputType.number,
                                                          inputFormatters: [CurrencyInputFormatter()],
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 12,
                                                            color: isNegative ? Colors.red : Colors.black87,
                                                          ),
                                                          decoration: InputDecoration(
                                                            prefixText: "Rp ",
                                                            isDense: true,
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(6),
                                                              borderSide: BorderSide(
                                                                color: isNegative ? Colors.red : Colors.grey.shade300,
                                                              ),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(6),
                                                              borderSide: BorderSide(
                                                                color: isNegative ? Colors.red : const Color(0xFF00529C),
                                                                width: 2,
                                                              ),
                                                            ),
                                                            filled: true,
                                                            fillColor: isNegative ? Colors.red.shade50 : Colors.grey.shade50,
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {});
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    if (isNegative)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 4),
                                                        child: Icon(
                                                          Icons.warning_rounded,
                                                          color: Colors.red,
                                                          size: 14,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: _buildSelisihWidget(
                                                    systemBalance,
                                                    closingControllers[id]?.text ?? '',
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: SizedBox(
                                                    height: 36,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: keteranganControllers[id]?.text.isNotEmpty == true 
                                                            ? primaryBlue 
                                                            : Colors.grey.shade200,
                                                        foregroundColor: keteranganControllers[id]?.text.isNotEmpty == true 
                                                            ? Colors.white 
                                                            : Colors.grey.shade600,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                                        elevation: keteranganControllers[id]?.text.isNotEmpty == true ? 2 : 0,
                                                        shadowColor: keteranganControllers[id]?.text.isNotEmpty == true 
                                                            ? primaryBlue.withOpacity(0.3) 
                                                            : Colors.transparent,
                                                      ),
                                                      onPressed: () {
                                                        _showKeteranganDialog(
                                                          acc['name'] ?? 'Akun', 
                                                          keteranganControllers[id]!
                                                        );
                                                      },
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            keteranganControllers[id]?.text.isNotEmpty == true 
                                                                ? Icons.edit_note_rounded 
                                                                : Icons.note_add_rounded,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            keteranganControllers[id]?.text.isNotEmpty == true 
                                                                ? 'Edit' 
                                                                : 'Keterangan',
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    // TOTAL SELISIH
                                    const Divider(height: 2, color: Colors.grey),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            flex: 4,
                                            child: Text(
                                              "TOTAL SELISIH",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          const Expanded(flex: 2, child: SizedBox()),
                                          const Expanded(flex: 2, child: SizedBox()),
                                          const Expanded(flex: 2, child: SizedBox()),
                                          const Expanded(flex: 2, child: SizedBox()),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _buildTotalSelisihWidget(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (!isDataComplete && !isSubmitting) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Harap isi semua nilai fisik (Uang Kas dan semua akun) sebelum menutup sesi",
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
                              ],

                              if (hasNegative && isDataComplete && !isSubmitting) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.shade300, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.warning_rounded,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '⚠️ PERINGATAN DATA NEGATIF!',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Terdapat nilai negatif pada salah satu kolom fisik. '
                                              'Klik tombol di bawah untuk melanjutkan dengan konfirmasi.',
                                              style: TextStyle(
                                                color: Colors.red.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasNegative && isDataComplete 
                                        ? Colors.orange 
                                        : primaryOrange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: hasNegative && isDataComplete ? 6 : 4,
                                    shadowColor: (hasNegative && isDataComplete ? Colors.orange : primaryOrange).withOpacity(0.3),
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                  ),
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : hasNegative && isDataComplete
                                          ? const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            )
                                          : const Icon(
                                              Icons.cloud_upload_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                  label: isSubmitting
                                      ? const Text(
                                          "MENYIMPAN...",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        )
                                      : hasNegative && isDataComplete
                                          ? const Text(
                                              "ADA DATA NEGATIF - LANJUTKAN?",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 0.5,
                                              ),
                                            )
                                          : const Text(
                                              "AMANKAN & TUTUP SESI KASIR",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                  onPressed: (isSubmitting || !isDataComplete) ? null : submitCloseSession,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // GRID KANAN (Log Transaksi / Mutasi Rekening) - 45%
                      Expanded(
                        flex: 45,
                        child: Column(
                          children: [
                            // ============ TAB HEADER ============
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: primaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.grey.shade600,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                tabs: const [
                                  Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.receipt_long_rounded, size: 16),
                                        SizedBox(width: 6),
                                        Text("Log Transaksi"),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.account_balance_rounded, size: 16),
                                        SizedBox(width: 6),
                                        Text("Mutasi Rekening"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ============ TAB CONTENT ============
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Tab 0: Log Transaksi
                                  _LogTransaksiWidget(
                                    outletId: myOutletId,
                                    sessionId: widget.sessionId,
                                  ),
                                  
                                  // Tab 1: Mutasi Rekening
                                  _MutasiRekeningWidget(
                                    outletId: myOutletId,
                                    sessionId: widget.sessionId,
                                    baseUrl: baseUrl,
                                  ),
                                ],
                              ),
                            ),
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