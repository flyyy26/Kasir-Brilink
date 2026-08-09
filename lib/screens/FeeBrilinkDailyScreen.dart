import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ============ CURRENCY INPUT FORMATTER ============
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
// =====================================================

class FeeBrilinkHarianScreen extends StatefulWidget {
  final int sessionId;

  const FeeBrilinkHarianScreen({super.key, required this.sessionId});

  @override
  State<FeeBrilinkHarianScreen> createState() => _FeeBrilinkHarianScreenState();
}

class _FeeBrilinkHarianScreenState extends State<FeeBrilinkHarianScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  List<dynamic> feeList = [];
  List<dynamic> accountOptions = [];
  bool isLoading = true;
  bool isSaving = false;
  bool isLoadingAccounts = false;
  double totalFee = 0;
  bool _isDataChanged = false;
  int myOutletId = 1;
  int? myKaryawanId;
  
  // Filter
  DateTime selectedDate = DateTime.now();
  
  // Form
  final TextEditingController nominalController = TextEditingController();
  final TextEditingController keteranganController = TextEditingController();
  
  // ============ AKUN TUJUAN ============
  int? selectedAccountId;
  String? selectedAccountName;
  bool _hasSelectedAccount = false;
  
  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  @override
  void initState() {
    super.initState();
    loadOutletIdAndAccount();
  }

  @override
  void dispose() {
    nominalController.dispose();
    keteranganController.dispose();
    super.dispose();
  }

  Future<void> loadOutletIdAndAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id');
      
      // ============ LOAD ACCOUNT YANG TERSIMPAN ============
      selectedAccountId = prefs.getInt('fee_account_id');
      selectedAccountName = prefs.getString('fee_account_name');
      _hasSelectedAccount = selectedAccountId != null && selectedAccountId! > 0;
    });
    
    await fetchAccounts();
    await fetchFeeData();
  }

  // ============ FETCH ACCOUNT ============
  Future<void> fetchAccounts() async {
    setState(() => isLoadingAccounts = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_accounts_by_outlet.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> accounts = data['data'] ?? [];
        // Filter hanya akun Bank atau E-Wallet
        accounts = accounts.where((a) {
          String category = a['category']?.toString().toLowerCase() ?? '';
          return category == 'bank' || category == 'e-wallet' || category == 'ewallet' || category == 'qris';
        }).toList();
        
        setState(() {
          accountOptions = accounts;
        });
        
        // Jika sudah ada account tersimpan, cek apakah masih valid
        if (_hasSelectedAccount) {
          bool valid = accountOptions.any((a) => a['id'] == selectedAccountId);
          if (!valid) {
            setState(() {
              selectedAccountId = null;
              selectedAccountName = null;
              _hasSelectedAccount = false;
            });
            final prefs = await SharedPreferences.getInstance();
            prefs.remove('fee_account_id');
            prefs.remove('fee_account_name');
          }
        }
      }
    } catch (e) {
      print("Error fetch accounts: $e");
      showSnackBar("Gagal memuat daftar akun");
    } finally {
      setState(() => isLoadingAccounts = false);
    }
  }

  // ============ SIMPAN ACCOUNT KE SHARED PREFERENCES ============
  Future<void> saveAccountSelection(int accountId, String accountName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fee_account_id', accountId);
    await prefs.setString('fee_account_name', accountName);
    setState(() {
      selectedAccountId = accountId;
      selectedAccountName = accountName;
      _hasSelectedAccount = true;
    });
    showSnackBar("✅ Akun tujuan disimpan: $accountName");
  }

  // ============ TAMPILKAN DIALOG PILIH AKUN ============
  void _showSelectAccountDialog() {
    // Buat local variable untuk selected account di dalam dialog
    int? tempSelectedAccountId = selectedAccountId;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  minWidth: 350,
                  maxHeight: 550,
                ),
                padding: const EdgeInsets.all(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ============ HEADER ============
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
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
                                  "Pilih Akun Tujuan Fee",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "KMC (Kredit Merchant) akan masuk ke akun ini",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    
                    // ============ BODY ============
                    Expanded(
                      child: isLoadingAccounts
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text("Memuat daftar akun...", style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          : accountOptions.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.account_balance_wallet_rounded, size: 48, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text(
                                          "Tidak ada akun Bank/E-Wallet",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Silakan tambahkan akun terlebih dahulu",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: accountOptions.length,
                                  itemBuilder: (context, index) {
                                    var account = accountOptions[index];
                                    int id = int.parse(account['id'].toString());
                                    String name = account['name'] ?? 'Unknown';
                                    String category = account['category'] ?? 'Bank';
                                    String subCategory = account['sub_category'] ?? '';
                                    String displayName = subCategory.isNotEmpty && subCategory != '-'
                                        ? "$name ($subCategory)"
                                        : name;
                                    
                                    bool isSelected = tempSelectedAccountId == id;
                                    bool isBRI = name.toLowerCase().contains('bri');
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? primaryBlue.withOpacity(0.08) 
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? primaryBlue 
                                              : Colors.grey.shade200,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isBRI 
                                                ? Colors.blue.shade50 
                                                : primaryBlue.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            category.toLowerCase() == 'e-wallet' || category.toLowerCase() == 'ewallet'
                                                ? Icons.phone_android_rounded
                                                : Icons.account_balance_rounded,
                                            color: isBRI ? Colors.blue.shade700 : primaryBlue,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Text(
                                          category ?? 'Bank',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: primaryBlue,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              )
                                            : null,
                                        onTap: () {
                                          // ============ UPDATE STATE DIALOG ============
                                          setDialogState(() {
                                            tempSelectedAccountId = id;
                                          });
                                        },
                                        selected: isSelected,
                                      ),
                                    );
                                  },
                                ),
                    ),
                    
                    // ============ FOOTER ============
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
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
                                backgroundColor: tempSelectedAccountId == null 
                                    ? Colors.grey.shade300 
                                    : primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: tempSelectedAccountId == null ? 0 : 2,
                                shadowColor: tempSelectedAccountId == null 
                                    ? Colors.transparent 
                                    : primaryBlue.withOpacity(0.3),
                              ),
                              onPressed: tempSelectedAccountId == null
                                  ? null
                                  : () async {
                                      final selected = accountOptions.firstWhere(
                                        (a) => a['id'] == tempSelectedAccountId,
                                      );
                                      String name = selected['name'] ?? 'Unknown';
                                      String subCategory = selected['sub_category'] ?? '';
                                      String displayName = subCategory.isNotEmpty && subCategory != '-'
                                          ? "$name ($subCategory)"
                                          : name;
                                      await saveAccountSelection(tempSelectedAccountId!, displayName);
                                      if (mounted) {
                                        setState(() {});
                                        Navigator.pop(context);
                                      }
                                    },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Simpan & Gunakan",
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> fetchFeeData() async {
    setState(() => isLoading = true);
    
    try {
      String url = "$baseUrl/get_fee_brilink_harian.php?outlet_id=$myOutletId&tanggal=${_formatDateForAPI(selectedDate)}";
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          feeList = data['data'] ?? [];
          totalFee = double.tryParse(data['total_fee']?.toString() ?? '0') ?? 0;
        });
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat data fee");
      }
    } catch (e) {
      print("Error fetch fee: $e");
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveFee() async {
    String nominalText = nominalController.text.replaceAll('.', '').replaceAll(',', '');
    double nominal = double.tryParse(nominalText) ?? 0;
    
    if (nominal <= 0) {
      showSnackBar("Masukkan nominal fee!");
      return;
    }

    if (!_hasSelectedAccount || selectedAccountId == null) {
      _showSelectAccountDialog();
      return;
    }

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save_fee_brilink_harian.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "outlet_id": myOutletId,
          "session_id": widget.sessionId,
          "tanggal": _formatDateForAPI(selectedDate),
          "nominal": nominal,
          "keterangan": keteranganController.text.trim(),
          "karyawan_id": myKaryawanId,
          "destination_account_id": selectedAccountId, // Kirim akun tujuan
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("✅ Fee berhasil ditambahkan!");
        nominalController.clear();
        keteranganController.clear();
        setState(() => _isDataChanged = true);
        await fetchFeeData(); // Refresh data
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan fee");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteFee(int id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Fee"),
        content: const Text("Apakah Anda yakin ingin menghapus fee ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_fee_brilink_harian.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": id,
          "outlet_id": myOutletId,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("✅ Fee berhasil dihapus");
        setState(() => _isDataChanged = true);
        await fetchFeeData();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus fee");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    }
  }

  Future<void> _changeDate(DateTime newDate) async {
    setState(() {
      selectedDate = newDate;
    });
    await fetchFeeData();
  }

  String _formatDateForAPI(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDateDisplay(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    
    String dayName = days[date.weekday - 1];
    String monthName = months[date.month - 1];
    
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, _isDataChanged),
        ),
        title: const Text(
          "Kredit Merchant (Harian)",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: primaryOrange),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchFeeData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Memuat data...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 450.0, vertical: 12.0),
              child: Column(
                children: [
                  // ============ ACCOUNT SELECTOR ============
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasSelectedAccount ? Colors.white : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasSelectedAccount ? Colors.grey.shade200 : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _hasSelectedAccount 
                                ? primaryBlue.withOpacity(0.08) 
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: _hasSelectedAccount ? primaryBlue : Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasSelectedAccount 
                                    ? "Akun Tujuan Fee" 
                                    : "⚠️ Pilih Akun Tujuan",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _hasSelectedAccount ? Colors.grey.shade500 : Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                _hasSelectedAccount 
                                    ? selectedAccountName ?? '-' 
                                    : "Klik tombol di samping untuk memilih",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _hasSelectedAccount ? Colors.black87 : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSelectedAccount ? primaryBlue : Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _showSelectAccountDialog,
                          icon: Icon(
                            _hasSelectedAccount ? Icons.edit_rounded : Icons.add_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _hasSelectedAccount ? "Ganti" : "Pilih",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date Selector
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Tanggal:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_left_rounded),
                                onPressed: () {
                                  _changeDate(selectedDate.subtract(const Duration(days: 1)));
                                },
                                padding: const EdgeInsets.all(4),
                              ),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
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
                                    await _changeDate(picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Text(
                                    _formatDateDisplay(selectedDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_right_rounded),
                                onPressed: () {
                                  _changeDate(selectedDate.add(const Duration(days: 1)));
                                },
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.today_rounded),
                          onPressed: () => _changeDate(DateTime.now()),
                          tooltip: "Hari ini",
                        ),
                      ],
                    ),
                  ),

                  // Summary Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.attach_money_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Fee",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "Hari ini / tanggal dipilih",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Rp ${_formatIdr(totalFee)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            Text(
                              "${feeList.length} kali input",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Input Form
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: nominalController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            decoration: InputDecoration(
                              labelText: "Nominal Fee",
                              prefixText: "Rp ",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: keteranganController,
                            decoration: InputDecoration(
                              labelText: "Keterangan (opsional)",
                              hintText: "Contoh: Komisi Brilink",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: !_hasSelectedAccount || isSaving
                                ? null
                                : saveFee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_hasSelectedAccount ? Colors.grey.shade400 : primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    !_hasSelectedAccount ? "Pilih Akun" : "TAMBAH",
                                    style: TextStyle(color: !_hasSelectedAccount ? Colors.grey.shade600 : Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List Fee
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.monetization_on_rounded,
                                        size: 18,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${feeList.length} Data",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_hasSelectedAccount)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Akun: ${selectedAccountName ?? ''}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          
                          Expanded(
                            child: feeList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.monetization_on_rounded,
                                          size: 64,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "Belum ada fee",
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Tambahkan fee BRILink di atas",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: feeList.length,
                                    itemBuilder: (context, index) {
                                      var item = feeList[index];
                                      double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                                      String keterangan = item['keterangan'] ?? '';
                                      String namaKaryawan = item['nama_karyawan'] ?? '';
                                      String accountName = item['account_name'] ?? '';
                                      String subCategory = item['account_sub_category'] ?? '';
                                      String accountDisplay = subCategory.isNotEmpty && subCategory != '-'
                                          ? "$accountName ($subCategory)"
                                          : accountName;
                                      String createdAt = item['created_at'] ?? '';
                                      
                                      // Format waktu
                                      String waktu = '';
                                      if (createdAt.isNotEmpty) {
                                        try {
                                          DateTime dateTime = DateTime.parse(createdAt);
                                          waktu = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
                                        } catch (e) {
                                          waktu = createdAt;
                                        }
                                      }
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: primaryOrange,
                                                borderRadius: BorderRadius.circular(2),
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
                                                        "Rp ${_formatIdr(nominal)}",
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (accountDisplay.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: primaryBlue.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            accountDisplay,
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              color: primaryBlue,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      if (keterangan.isNotEmpty) ...[
                                                        Text(
                                                          keterangan,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                      ],
                                                      if (namaKaryawan.isNotEmpty) ...[
                                                        Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          namaKaryawan,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey.shade500,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                      ],
                                                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        waktu,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.red.shade400,
                                                size: 20,
                                              ),
                                              onPressed: () => deleteFee(item['id']),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}