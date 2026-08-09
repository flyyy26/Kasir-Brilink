import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BukaKasScreen extends StatefulWidget {
  final VoidCallback? onSessionOpened;

  const BukaKasScreen({super.key, this.onSessionOpened});

  @override
  State<BukaKasScreen> createState() => _BukaKasScreenState();
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) cleanText = "0";

    double value = double.tryParse(cleanText) ?? 0;
    String str = value.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formatted = str.replaceAllMapped(reg, (Match match) => '${match[1]}.');

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _BukaKasScreenState extends State<BukaKasScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1; 

  int pusatOutletId = 1;
  bool isPusatOutlet = false;
  
  final TextEditingController cashOpeningController = TextEditingController();
  int? currentSessionId;
  bool isLoadingSessionData = false;
  bool hasActiveSession = false;
  
  // ============ TAMBAHAN KAS ============
  List<dynamic> tambahanKasList = [];
  double totalTambahanKas = 0;
  bool isLoadingTambahanKas = false;
  // =====================================

  // ============ TAMBAHAN SALDO ============
  List<dynamic> tambahanSaldoList = [];
  double totalTambahanSaldo = 0;
  bool isLoadingTambahanSaldo = false;
  // =====================================
  
  final TextEditingController accountNameController = TextEditingController();
  String? selectedCategory;
  String? selectedSubCategory;
  
  // ============ KATEGORI DAN SUB-KATEGORI ============
  final List<String> categories = ['Bank', 'E-Wallet', 'QRIS'];
  final List<String> subCategories = ['EDC', 'Penampung Outlet', 'Penampung Tarik Tunai'];
  // ===================================================

  List<dynamic> listAccountsTable = [];
  Map<int, TextEditingController> balanceControllers = {};
  Map<int, double> initialOpeningBalances = {};
  Map<int, bool> lockedAccounts = {};
  
  // ============ TRACK AKUN YANG SUDAH DI-SAVE ============
  Set<int> savedAccountIds = {};
  bool hasSavedBulk = false;
  // ======================================================

  bool isLoadingAccountsTable = false;
  bool isSubmittingSession = false;
  bool isSubmittingBulkBalances = false;
  bool isDeleting = false;
  bool isSubmitting = false; // <-- TAMBAHKAN INI
  
  bool hasLoadedLastClosing = false;
  bool _initialLoadDone = false;
  
  // ============ FLAG UNTUK MENCEGAH SETSTATE SETELAH DISPOSE ============
  bool _isMounted = false;
  // ====================================================================

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    loadOutletSession();
  }

  @override
  void dispose() {
    _isMounted = false;
    cashOpeningController.dispose();
    accountNameController.dispose();
    for (var controller in balanceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> loadOutletSession() async {
    final prefs = await SharedPreferences.getInstance();
    _safeSetState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
    });
    
    await fetchLastClosingCash();
    await fetchCurrentSession();
    await fetchTambahanKas();
    await fetchTambahanSaldo();
    await fetchAllAccountsWithOpeningStatus();
    
    // Jika tidak ada sesi aktif, tampilkan saldo dari sesi sebelumnya
    if (!hasActiveSession) {
      await fetchPreviousAccountBalances();
    }
  }

  // ============ FETCH ACCOUNT BALANCES DARI SESI SEBELUMNYA ============
  Future<void> fetchPreviousAccountBalances() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_previous_account_balances.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> previousBalances = data['data'] ?? [];
        
        // Update UI dengan saldo dari sesi sebelumnya
        for (var item in previousBalances) {
          int accountId = int.parse(item['account_id'].toString());
          double balance = double.tryParse(item['balance']?.toString() ?? '0') ?? 0;
          
          if (balanceControllers.containsKey(accountId)) {
            // Update nilai di controller
            balanceControllers[accountId]?.text = _formatIdr(balance);
            // Update initialOpeningBalances agar tidak dianggap berubah
            initialOpeningBalances[accountId] = balance;
            
            // Jika balance > 0, kunci akun
            if (balance > 0) {
              lockedAccounts[accountId] = true;
            }
          }
        }
        
        print("Previous account balances loaded: ${previousBalances.length} accounts");
        _safeSetState(() {});
      }
    } catch (e) {
      print("Gagal mengambil saldo sesi sebelumnya: $e");
    }
  }
  // ================================================================

  Future<bool> checkOpeningBalancesEmpty() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_opening_balances.php?outlet_id=$myOutletId&session_id=$currentSessionId"),
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        List<dynamic> balances = data['data'] ?? [];
        bool allZero = true;
        for (var item in balances) {
          double amount = double.tryParse(item['opening_balance']?.toString() ?? '0') ?? 0;
          if (amount > 0) {
            allZero = false;
            break;
          }
        }
        return allZero || balances.isEmpty;
      }
      return true;
    } catch (e) {
      print("Gagal cek opening balances: $e");
      return true;
    }
  }

  Future<void> fetchLastClosingCash() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_last_closing_balances.php?outlet_id=$myOutletId"),
      );
      
      final data = json.decode(response.body);
      
      if (data['status'] == true && data['cash_closing'] > 0) {
        double closingAmount = double.tryParse(data['cash_closing'].toString()) ?? 0;
        cashOpeningController.text = _formatIdr(closingAmount);
        hasLoadedLastClosing = true;
      } else {
        cashOpeningController.text = "0";
        hasLoadedLastClosing = true;
      }
    } catch (e) {
      print("Gagal mengambil data kas tutup terakhir: $e");
      cashOpeningController.text = "0";
      hasLoadedLastClosing = true;
    }
  }

  Future<void> fetchTambahanKas() async {
    if (currentSessionId == null) return;
    
    _safeSetState(() => isLoadingTambahanKas = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_tambahan_kas.php?session_id=$currentSessionId&outlet_id=$myOutletId"),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        _safeSetState(() {
          tambahanKasList = data['data'] ?? [];
          totalTambahanKas = tambahanKasList.fold(0.0, (sum, item) {
            return sum + (double.tryParse(item['nominal']?.toString() ?? '0') ?? 0);
          });
        });
      }
    } catch (e) {
      print("Gagal mengambil tambahan kas: $e");
    } finally {
      _safeSetState(() => isLoadingTambahanKas = false);
    }
  }

  Future<void> fetchTambahanSaldo() async {
    if (currentSessionId == null) return;
    
    _safeSetState(() => isLoadingTambahanSaldo = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_tambahan_saldo.php?session_id=$currentSessionId&outlet_id=$myOutletId"),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        _safeSetState(() {
          tambahanSaldoList = data['data'] ?? [];
          totalTambahanSaldo = tambahanSaldoList.fold(0.0, (sum, item) {
            return sum + (double.tryParse(item['nominal']?.toString() ?? '0') ?? 0);
          });
        });
      }
    } catch (e) {
      print("Gagal mengambil tambahan saldo: $e");
    } finally {
      _safeSetState(() => isLoadingTambahanSaldo = false);
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return "${now.day} ${months[now.month - 1]} ${now.year}";
  }

  Future<void> fetchCurrentSession() async {
    _safeSetState(() => isLoadingSessionData = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_current_session.php?outlet_id=$myOutletId"));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        if (data['has_session'] == true) {
          double cashOpening = double.tryParse(data['cash_opening'].toString()) ?? 0;
          String formattedCash = _formatIdr(cashOpening);
          int? parsedId = data['id'] != null ? int.tryParse(data['id'].toString()) : null;
          
          _safeSetState(() {
            currentSessionId = parsedId;
            cashOpeningController.text = formattedCash;
            hasActiveSession = true;
          });
          
          if (currentSessionId != null) {
            await fetchTambahanKas();
            await fetchTambahanSaldo();
          }
        } else {
          _safeSetState(() {
            currentSessionId = null;
            hasActiveSession = false;
            tambahanKasList = [];
            totalTambahanKas = 0;
            tambahanSaldoList = [];
            totalTambahanSaldo = 0;
            if (!hasLoadedLastClosing) {
              cashOpeningController.text = "0";
            }
          });
        }
      }
    } catch (e) {
      showSnackBar("Gagal mengambil sesi: $e");
    } finally {
      _safeSetState(() => isLoadingSessionData = false);
    }
  }

  Future<void> fetchAllAccountsWithOpeningStatus() async {
    _safeSetState(() => isLoadingAccountsTable = true);

    try {
      String url = "$baseUrl/get_accounts.php?outlet_id=$myOutletId";
      if (currentSessionId != null) {
        url += "&session_id=$currentSessionId";
      }
      
      print("Fetching URL: $url");
      
      final accResponse = await http.get(Uri.parse(url));

      print("Response status: ${accResponse.statusCode}");
      print("Response body: ${accResponse.body}");

      if (accResponse.body.isEmpty) {
        print("Response body kosong!");
        _safeSetState(() {
          listAccountsTable = [];
          hasSavedBulk = false;
        });
        return;
      }
      
      final accData = json.decode(accResponse.body);

      if (accResponse.statusCode == 200 && accData['status'] == true) {
        List<dynamic> allAccounts = accData['data'] ?? [];
        
        print("Total accounts from API: ${allAccounts.length}");
        
        if (accData['pusat_outlet_id'] != null) {
          pusatOutletId = int.tryParse(accData['pusat_outlet_id'].toString()) ?? 1;
        }
        isPusatOutlet = accData['is_pusat_outlet'] == true;
        
        print("Is Pusat Outlet: $isPusatOutlet");
        
        for (var controller in balanceControllers.values) {
          controller.dispose();
        }
        balanceControllers.clear();
        savedAccountIds.clear();
        hasSavedBulk = false;
        initialOpeningBalances.clear();
        lockedAccounts.clear();

        List<dynamic> filteredAccounts = allAccounts
            .where((acc) => acc['category'] != 'Cash')
            .toList();

        // ============ AMBIL DATA ACCOUNT BALANCES UNTUK CEK STATUS LOCK ============
        Map<int, double> accountBalancesMap = {};
        try {
          final abResponse = await http.get(
            Uri.parse("$baseUrl/get_account_balances.php?outlet_id=$myOutletId&session_id=$currentSessionId"),
          );
          final abData = json.decode(abResponse.body);
          if (abResponse.statusCode == 200 && abData['status'] == true) {
            for (var item in abData['data'] ?? []) {
              int accountId = int.parse(item['account_id'].toString());
              double balance = double.tryParse(item['balance']?.toString() ?? '0') ?? 0;
              accountBalancesMap[accountId] = balance;
            }
          }
        } catch (e) {
          print("Gagal mengambil account balances: $e");
        }

        for (var acc in filteredAccounts) {
          int accountId = int.parse(acc['id'].toString());
          double openingAmount = 0;
          double accountBalance = accountBalancesMap[accountId] ?? 0;
          
          if (acc['opening_balance'] != null) {
            openingAmount = double.tryParse(acc['opening_balance'].toString()) ?? 0;
          }
          
          // ============ TAMPILKAN OPENING BALANCES ============
          double displayAmount = openingAmount;
          
          initialOpeningBalances[accountId] = displayAmount;
          print("Akun: ${acc['name']}, Opening: $openingAmount, Account Balance: $accountBalance, Display: $displayAmount");
          
          bool isFromPusat = acc['is_from_pusat'] == true;
          bool isMBanking = acc['is_m_banking'] == true;
          
          // ============ LOGIKA LOCK ============
          bool shouldLock = false;
          bool isEditable = true;
          
          if (isFromPusat && isMBanking && !isPusatOutlet) {
            isEditable = false;
          }
          
          // Jika account_balance > 0, akun TETAP terkunci
          if (accountBalance > 0) {
            shouldLock = true;
            print("Akun ${acc['name']} terkunci karena account_balance > 0 ($accountBalance)");
          }
          // Jika opening_balance > 0, akun juga terkunci
          else if (openingAmount > 0) {
            shouldLock = true;
            print("Akun ${acc['name']} terkunci karena opening_balance > 0 ($openingAmount)");
          }
          // Jika tidak ada saldo (0), akun tidak terkunci
          else {
            shouldLock = false;
            print("Akun ${acc['name']} tidak terkunci (saldo 0)");
          }
          
          lockedAccounts[accountId] = shouldLock;
          
          // Track akun yang sudah di-save
          if (openingAmount > 0 || accountBalance > 0) {
            savedAccountIds.add(accountId);
          }
          
          balanceControllers[accountId] = TextEditingController(text: _formatIdr(displayAmount));
        }

        _safeSetState(() {
          listAccountsTable = filteredAccounts;
          hasSavedBulk = savedAccountIds.isNotEmpty;
        });
        
        print("Total akun di UI: ${filteredAccounts.length}");
        for (var acc in filteredAccounts) {
          int id = int.parse(acc['id'].toString());
          print("Akun: ${acc['name']}, Display: ${balanceControllers[id]?.text}, Locked: ${lockedAccounts[id] ?? false}");
        }
        
        _initialLoadDone = true;
      } else {
        print("Error from API: ${accData['message'] ?? 'Unknown error'}");
        _safeSetState(() {
          listAccountsTable = [];
          hasSavedBulk = false;
        });
      }
    } catch (e) {
      print("Gagal sinkronisasi data master tabel per outlet: $e");
      _safeSetState(() {
        listAccountsTable = [];
        hasSavedBulk = false;
      });
    } finally {
      _safeSetState(() => isLoadingAccountsTable = false);
    }
  }

  Future<Map<String, dynamic>> getLastClosingBalances() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_last_closing_balances.php?outlet_id=$myOutletId"),
      );
      return json.decode(response.body);
    } catch (e) {
      return {
        "status": false,
        "balances": [],
      };
    }
  }

  // ============ FUNGSI HAPUS AKUN ============
  Future<void> deleteAccount(int accountId, String accountName) async {
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
            const Text("Hapus Akun", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Apakah Anda yakin ingin menghapus akun?",
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
                  Icon(Icons.account_balance_rounded, color: const Color(0xFF00529C), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    accountName,
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
              "⚠️ Akun yang dihapus tidak dapat dikembalikan.",
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
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

    _safeSetState(() => isDeleting = true);
    
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_account.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "account_id": accountId,
          "outlet_id": myOutletId,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Akun berhasil dihapus");
        await fetchAllAccountsWithOpeningStatus();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus akun");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      _safeSetState(() => isDeleting = false);
    }
  }

  Future<void> submitOpenSession() async {
    if (cashOpeningController.text.isEmpty) {
      showSnackBar("Masukkan nominal modal awal laci!");
      return;
    }
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Buka Sesi Baru"),
        content: const Text("Anda yakin ingin membuka sesi kas baru?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF26A25)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Buka", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;

    _safeSetState(() => isSubmittingSession = true);
    String cleanNominal = cashOpeningController.text.replaceAll('.', '');
    
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/open_session.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "cash_opening": double.parse(cleanNominal),
          "outlet_id": myOutletId
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Sesi harian outlet berhasil dibuka!");
        
        // ============ PERBAIKAN: Refresh data ============
        await fetchCurrentSession();
        await fetchAllAccountsWithOpeningStatus();
        
        // ============ PERBAIKAN: Auto save saldo dari account_balances ke opening_balances ============
        // Setelah sesi dibuka, otomatis simpan semua account_balances ke opening_balances
        if (currentSessionId != null && listAccountsTable.isNotEmpty) {
          await autoSaveCurrentBalancesToOpening();
        }
        // ================================================================
        
        bool isEmpty = await checkOpeningBalancesEmpty();
        if (isEmpty && currentSessionId != null) {
          await autoSaveEmptyBalances();
        }
        
        if (widget.onSessionOpened != null) {
          widget.onSessionOpened!();
        }
      } else {
        showSnackBar(data['message'] ?? "Gagal membuka sesi");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      _safeSetState(() => isSubmittingSession = false);
    }
  }

  // ============ AUTO SAVE SALDO DARI ACCOUNT BALANCES KE OPENING BALANCES ============
  Future<void> autoSaveCurrentBalancesToOpening() async {
    if (listAccountsTable.isEmpty || currentSessionId == null) return;
    
    try {
      List<Map<String, dynamic>> balancesPayload = [];
      
      for (var acc in listAccountsTable) {
        int id = int.parse(acc['id'].toString());
        
        // Ambil nilai dari controller (sudah terisi dari account_balances sebelumnya)
        final controller = balanceControllers[id];
        String textValue = (controller == null || controller.text.isEmpty) ? "0" : controller.text;
        String cleanAmount = textValue.replaceAll('.', '');
        double amount = double.parse(cleanAmount);
        
        balancesPayload.add({
          "account_id": id,
          "amount": amount
        });
      }
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_bulk_opening_balances.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": currentSessionId,
          "outlet_id": myOutletId,
          "balances": balancesPayload,
          "partial_update": false
        }),
      );
      
      final data = json.decode(response.body);
      if (data['status'] == true) {
        print("Auto save saldo dari account_balances ke opening_balances berhasil!");
        await refreshOpeningBalances();
      }
    } catch (e) {
      print("Gagal auto save saldo: $e");
    }
  }
  // ================================================================

  Future<void> autoSaveEmptyBalances() async {
    if (listAccountsTable.isEmpty || currentSessionId == null) return;
    
    try {
      List<Map<String, dynamic>> balancesPayload = [];
      
      for (var acc in listAccountsTable) {
        int id = int.parse(acc['id'].toString());
        balancesPayload.add({
          "account_id": id,
          "amount": 0
        });
      }
      
      final response = await http.post(
        Uri.parse("$baseUrl/save_bulk_opening_balances.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": currentSessionId,
          "outlet_id": myOutletId,
          "balances": balancesPayload,
          "partial_update": false
        }),
      );
      
      final data = json.decode(response.body);
      if (data['status'] == true) {
        print("Auto save saldo awal berhasil (semua 0)");
        await refreshOpeningBalances();
      }
    } catch (e) {
      print("Gagal auto save saldo awal: $e");
    }
  }

  // ============ SAVE PER AKUN ============
  Future<bool> saveSingleAccount(int accountId, double amount) async {
    if (currentSessionId == null) {
      showSnackBar("Sesi tidak aktif!");
      return false;
    }

    var account = listAccountsTable.firstWhere(
      (acc) => int.parse(acc['id'].toString()) == accountId,
      orElse: () => null,
    );
    
    if (account != null && account['is_readonly'] == true) {
      showSnackBar("Akun ini tidak dapat diedit (readonly)!");
      return false;
    }
    
    // ============ CEK APAKAH AKUN TERKUNCI ============
    if (lockedAccounts[accountId] == true) {
      showSnackBar("Akun ini sudah terkunci dan tidak dapat diedit!");
      return false;
    }
    // ===================================================

    try {
      List<Map<String, dynamic>> balancesPayload = [
        {
          "account_id": accountId,
          "amount": amount
        }
      ];

      print("Saving account $accountId with amount $amount");

      final response = await http.post(
        Uri.parse("$baseUrl/save_bulk_opening_balances.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": currentSessionId,
          "outlet_id": myOutletId,
          "balances": balancesPayload,
          "partial_update": true
        }),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        _safeSetState(() {
          savedAccountIds.add(accountId);
          hasSavedBulk = true;
          initialOpeningBalances[accountId] = amount;
          
          // ============ KUNCI AKUN SETELAH DISAVE ============
          // Jika akun disave dengan nilai > 0, kunci
          if (amount > 0) {
            lockedAccounts[accountId] = true;
          }
          // ===================================================
          
          if (balanceControllers.containsKey(accountId)) {
            balanceControllers[accountId]?.text = _formatIdr(amount);
          }
        });
        
        return true;
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan saldo");
        return false;
      }
    } catch (e) {
      print("Error saving account: $e");
      showSnackBar("Koneksi bermasalah: $e");
      return false;
    }
  }
  // =========================================

  Future<void> saveNewAccount(BuildContext dialogContext) async {
    if (accountNameController.text.isEmpty || selectedCategory == null) {
      showSnackBar("Silakan lengkapi nama akun dan kategori!");
      return;
    }
    
    if (selectedCategory == 'Bank' && selectedSubCategory == null) {
      showSnackBar("Untuk kategori Bank, wajib pilih sub-kategori!");
      return;
    }
    
    // ============ VALIDASI SUB KATEGORI ============
    // Penampung Tarik Tunai: HANYA di outlet pusat
    // Penampung Outlet: Boleh di semua outlet (setiap outlet punya sendiri)
    // EDC: Boleh di semua outlet
    if (selectedCategory == 'Bank' && selectedSubCategory == 'Penampung Tarik Tunai') {
      // Cek apakah outlet ini adalah outlet pusat
      try {
        final prefs = await SharedPreferences.getInstance();
        int outletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
        
        final response = await http.get(
          Uri.parse("$baseUrl/check_outlet_type.php?outlet_id=$outletId"),
        );
        final data = json.decode(response.body);
        
        if (data['status'] == true && data['is_pusat'] != true) {
          showSnackBar("❌ Penampung Tarik Tunai hanya dapat didaftarkan di outlet pusat!");
          return;
        }
      } catch (e) {
        showSnackBar("❌ Gagal verifikasi outlet: $e");
        return;
      }
    }
    // Penampung Outlet: Bisa di semua outlet (tidak perlu validasi)
    // ============================================================================
    
    try {
      final payload = {
        "name": accountNameController.text,
        "category": selectedCategory,
        "outlet_id": myOutletId,
      };
      
      if (selectedCategory == 'Bank') {
        payload["sub_category"] = selectedSubCategory;
      }
      
      final response = await http.post(
        Uri.parse("$baseUrl/add_account.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("Akun ${accountNameController.text} berhasil didaftarkan!");
        
        final isPenampung = selectedSubCategory == 'Penampung Outlet' || selectedSubCategory == 'Penampung Tarik Tunai';
        
        accountNameController.clear();
        _safeSetState(() {
          selectedCategory = null;
          selectedSubCategory = null;
        });
        
        await fetchAllAccountsWithOpeningStatus();
        
        if (!isPenampung && currentSessionId != null && listAccountsTable.isNotEmpty) {
          var newAccount = listAccountsTable.lastWhere(
            (acc) => acc['name'] == accountNameController.text,
            orElse: () => null,
          );
          
          if (newAccount != null) {
            int newAccountId = int.parse(newAccount['id'].toString());
            await saveSingleAccount(newAccountId, 0);
            print("Auto save saldo awal 0 untuk akun baru: ${newAccount['name']}");
            
            _safeSetState(() {
              lockedAccounts[newAccountId] = false;
            });
          }
        }
        
        if (!mounted) return;
        Navigator.pop(dialogContext);
      } else {
        showSnackBar(data['message'] ?? "Gagal menambah akun");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    }
  }

  Future<void> submitBulkOpeningBalances() async {
    if (listAccountsTable.isEmpty) return;

    if (currentSessionId == null) {
      showSnackBar("Gagal menyimpan: Silakan lakukan 'PROSES BUKA KAS' modal laci awal terlebih dahulu!");
      return;
    }

    _safeSetState(() => isSubmittingBulkBalances = true);
    
    List<Map<String, dynamic>> balancesPayload = [];

    print("========== SUBMIT BULK OPENING BALANCES ==========");
    print("Is Pusat Outlet: $isPusatOutlet");
    print("Total accounts in table: ${listAccountsTable.length}");
    
    for (var acc in listAccountsTable) {
      int id = int.parse(acc['id'].toString());
      String name = acc['name'] ?? 'Unknown';
      bool isReadonly = acc['is_readonly'] == true;
      bool isFromPusat = acc['is_from_pusat'] == true;
      bool isMBanking = acc['is_m_banking'] == true;
      
      bool isLocked = lockedAccounts[id] ?? false;
      
      print("Account: $name, ID: $id, isReadonly: $isReadonly, isFromPusat: $isFromPusat, isMBanking: $isMBanking, isLocked: $isLocked");
      
      if (isReadonly) {
        print("  -> SKIP (readonly)");
        continue;
      }
      
      if (isLocked) {
        print("  -> SKIP (terkunci - saldo sudah terisi atau sudah ada transaksi)");
        continue;
      }
      
      if (isFromPusat && isMBanking && !isPusatOutlet) {
        print("  -> SKIP (penampung dari pusat, tapi bukan outlet pusat)");
        continue;
      }
      
      final controller = balanceControllers[id];
      String textValue = (controller == null || controller.text.isEmpty) ? "0" : controller.text;
      String cleanAmount = textValue.replaceAll('.', '');
      double amount = double.parse(cleanAmount);
      
      print("  -> Current Amount: $amount, Controller text: ${controller?.text}");
      
      double initialAmount = initialOpeningBalances[id] ?? 0;
      print("  -> Initial Amount: $initialAmount");
      
      if (amount != initialAmount) {
        balancesPayload.add({
          "account_id": id,
          "amount": amount
        });
        print("  -> ADDED to payload (berubah dari $initialAmount ke $amount)");
      } else {
        print("  -> SKIP (nilai sama dengan awal: $initialAmount)");
      }
    }
    
    print("Total accounts to save: ${balancesPayload.length}");
    print("Payload: ${json.encode(balancesPayload)}");
    print("==================================================");
    
    if (balancesPayload.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("$baseUrl/save_bulk_opening_balances.php"),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "session_id": currentSessionId,
            "outlet_id": myOutletId,
            "balances": balancesPayload,
            "partial_update": true
          }),
        );

        print("Response status: ${response.statusCode}");
        print("Response body: ${response.body}");

        final data = json.decode(response.body);
        
        if (response.statusCode == 200 && data['status'] == true) {
          showSnackBar("Saldo awal berhasil diupdate untuk ${balancesPayload.length} akun!");
          _safeSetState(() {
            for (var item in balancesPayload) {
              int accountId = item['account_id'];
              double amount = item['amount'];
              
              savedAccountIds.add(accountId);
              initialOpeningBalances[accountId] = amount;
              
              if (amount > 0) {
                lockedAccounts[accountId] = true;
              }
              
              if (balanceControllers.containsKey(accountId)) {
                balanceControllers[accountId]?.text = _formatIdr(amount);
              }
            }
            hasSavedBulk = true;
          });
        } else {
          showSnackBar(data['message'] ?? "Gagal menyimpan saldo");
        }
      } catch (e) {
        print("Error submitting: $e");
        showSnackBar("Koneksi bermasalah: $e");
      } finally {
        _safeSetState(() => isSubmittingBulkBalances = false);
      }
    } else {
      showSnackBar("Tidak ada perubahan saldo yang perlu disimpan.");
      _safeSetState(() => isSubmittingBulkBalances = false);
    }
  }

  Future<void> refreshOpeningBalances() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_opening_balances.php?outlet_id=$myOutletId&session_id=$currentSessionId"),
      );
      
      final data = json.decode(response.body);
      
      if (data['status'] == true && data['data'] != null) {
        List<dynamic> openingData = data['data'];
        
        Map<int, double> dbBalances = {};
        
        for (var item in openingData) {
          int accountId = int.parse(item['account_id'].toString());
          double amount = double.tryParse(item['opening_balance']?.toString() ?? item['balance']?.toString() ?? '0') ?? 0;
          dbBalances[accountId] = amount;
          savedAccountIds.add(accountId);
        }
        
        for (var acc in listAccountsTable) {
          int accountId = int.parse(acc['id'].toString());
          
          if (acc['is_from_pusat'] == true && acc['is_m_banking'] == true) {
            print("Skip refresh untuk akun penampung dari pusat: ${acc['name']}");
            continue;
          }
          
          if (balanceControllers.containsKey(accountId)) {
            double amount = dbBalances[accountId] ?? 0;
            balanceControllers[accountId]?.text = _formatIdr(amount);
          }
        }
        
        _safeSetState(() {
          hasSavedBulk = savedAccountIds.isNotEmpty;
        });
      }
    } catch (e) {
      print("Gagal refresh opening balances: $e");
    }
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String labelText, String? hintText, String? prefixText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,
      labelStyle: const TextStyle(color: Color(0xFF00529C), fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00529C), width: 2),
      ),
    );
  }

  void _showEditSaldoDialog(int accountId, String accountName, double currentBalance) async {
    // ============ CEK APAKAH AKUN TERKUNCI ============
    // Hanya akun yang terkunci (sudah memiliki saldo) yang bisa diedit
    if (!lockedAccounts[accountId]!) {
      showSnackBar("❌ Akun ini belum terkunci. Silakan isi saldo terlebih dahulu.");
      return;
    }
    // ===================================================
    
    final TextEditingController saldoController = TextEditingController(
      text: _formatIdr(currentBalance)
    );
    final TextEditingController keteranganController = TextEditingController();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF26A25).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFFF26A25), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text("Edit Saldo Awal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Akun: $accountName",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Saldo Saat Ini: Rp ${_formatIdr(currentBalance)}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Saldo Baru",
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: saldoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        hintText: "Masukkan saldo baru",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF26A25), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixText: "Rp ",
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Keterangan",
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keteranganController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Masukkan alasan perubahan saldo (wajib)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF26A25), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Batal", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26A25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    String cleanSaldo = saldoController.text.replaceAll('.', '');
                    double saldoBaru = double.tryParse(cleanSaldo) ?? 0;
                    String keterangan = keteranganController.text.trim();
                    
                    if (saldoBaru < 0) {
                      showSnackBar("❌ Saldo tidak boleh negatif");
                      return;
                    }
                    
                    if (keterangan.isEmpty) {
                      showSnackBar("❌ Keterangan wajib diisi");
                      return;
                    }
                    
                    if (saldoBaru == currentBalance) {
                      showSnackBar("❌ Saldo baru sama dengan saldo lama");
                      return;
                    }
                    
                    final prefs = await SharedPreferences.getInstance();
                    int karyawanId = prefs.getInt('karyawan_id') ?? 0;
                    
                    if (karyawanId <= 0) {
                      showSnackBar("❌ Data karyawan tidak ditemukan, silakan login ulang");
                      return;
                    }
                    
                    Navigator.pop(dialogContext);
                    _safeSetState(() => isSubmitting = true);
                    
                    try {
                      final response = await http.post(
                        Uri.parse("$baseUrl/request_edit_saldo.php"),
                        headers: {"Content-Type": "application/json"},
                        body: json.encode({
                          "karyawan_id": karyawanId,
                          "outlet_id": myOutletId,
                          "account_id": accountId,
                          "saldo_baru": saldoBaru,
                          "keterangan": keterangan,
                        }),
                      );
                      
                      final data = json.decode(response.body);
                      
                      if (response.statusCode == 200 && data['status'] == true) {
                        showSnackBar("✅ ${data['message']}");
                        await fetchAllAccountsWithOpeningStatus();
                      } else {
                        showSnackBar("❌ ${data['message'] ?? 'Gagal mengirim permintaan'}");
                      }
                    } catch (e) {
                      showSnackBar("❌ Error: $e");
                    } finally {
                      _safeSetState(() => isSubmitting = false);
                    }
                  },
                  child: const Text("Kirim Permintaan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAddAccountPopup() {
    selectedCategory = null;
    selectedSubCategory = null;
    accountNameController.clear();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00529C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00529C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text("Registrasi Akun Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: accountNameController,
                      decoration: _buildInputDecoration(labelText: "Nama Akun", hintText: "Contoh: QRIS Merchant Shopee"),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      hint: const Text("Pilih Kategori"),
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      decoration: _buildInputDecoration(labelText: "Kategori"),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCategory = val;
                          selectedSubCategory = null;
                        });
                      },
                    ),
                    if (selectedCategory == 'Bank') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedSubCategory,
                        hint: const Text("Pilih Sub-Kategori"),
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                        decoration: _buildInputDecoration(labelText: "Sub-Kategori"),
                        items: subCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedSubCategory = val);
                        },
                      ),
                      
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedCategory = null;
                      selectedSubCategory = null;
                      accountNameController.clear();
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Batal", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26A25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => saveNewAccount(dialogContext),
                  child: const Text(
                    "Daftarkan Akun",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildBulkSubmitButton() {
    if (listAccountsTable.isEmpty) return const SizedBox.shrink();
    
    String buttonText = hasSavedBulk ? "UPDATE PER AKUN" : "SIMPAN SEMUA";
    
    return SizedBox(
      width: 200,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSavedBulk ? const Color(0xFFF26A25) : const Color(0xFF00529C),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
        ),
        icon: Icon(
          hasSavedBulk ? Icons.edit_rounded : Icons.save_as_rounded, 
          color: Colors.white, 
          size: 18
        ),
        label: Text(
          buttonText,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
        ),
        onPressed: isSubmittingBulkBalances ? null : submitBulkOpeningBalances,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Buka Kas", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        elevation: 0,
        backgroundColor: const Color(0xFF00529C),
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          // ============ TOMBOL REFRESH ============
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () async {
              // Tampilkan loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text("Memuat ulang data..."),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
              
              // Refresh semua data
              await loadOutletSession();
              await fetchCurrentSession();
              await fetchAllAccountsWithOpeningStatus();
              await fetchTambahanKas();
              await fetchTambahanSaldo();
              
              // Jika tidak ada sesi aktif, ambil saldo dari sesi sebelumnya
              if (!hasActiveSession) {
                await fetchPreviousAccountBalances();
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Data berhasil diperbarui"),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: "Refresh Data",
          ),
          // =========================================
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text(_getFormattedDate(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: const Color(0xFFF26A25)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF26A25).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.money_rounded, color: Color(0xFFF26A25), size: 28),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Kas Awal Laci", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF00529C))),
                                const SizedBox(height: 4),
                                Text(
                                  hasActiveSession 
                                      ? "Sesi aktif sedang berjalan" 
                                      : "Isi dengan uang tunai fisik di laci (default dari kas tutup sebelumnya)",
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: isLoadingSessionData
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26A25)))
                                : TextField(
                                    controller: cashOpeningController,
                                    keyboardType: TextInputType.number,
                                    readOnly: hasActiveSession,
                                    inputFormatters: [CurrencyInputFormatter()],
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF00529C)),
                                    decoration: _buildInputDecoration(
                                      labelText: hasActiveSession ? "Sesi Aktif" : "Uang Kas Awal", 
                                      prefixText: "Rp ",
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        cashOpeningController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: cashOpeningController.text.length),
                                        );
                                      }
                                    },
                                  ),
                          ),
                          const SizedBox(width: 20),
                          if (!hasActiveSession)
                            SizedBox(
                              width: 150,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF26A25),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: isSubmittingSession ? null : submitOpenSession,
                                child: isSubmittingSession
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("BUKA KAS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text("SESI AKTIF", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      if (hasActiveSession && tambahanKasList.isNotEmpty) ...[
                        const Divider(height: 24, thickness: 1, color: Colors.grey),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 28),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tambahan Kas", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF00529C))),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Total tambahan kas dari outlet lain: ${tambahanKasList.length} transaksi",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Total Tambahan",
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      "Rp ${_formatIdr(totalTambahanKas)}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF1565C0),
                                size: 24,
                              ),
                              onPressed: () {
                                _showTambahanKasDetail();
                              },
                              tooltip: "Lihat detail tambahan kas",
                            )
                          ],
                        ),
                      ],

                      if (hasActiveSession && tambahanSaldoList.isNotEmpty) ...[
                        const Divider(height: 24, thickness: 1, color: Colors.grey),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.purple, size: 28),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tambahan Saldo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF00529C))),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Total tambahan saldo dari outlet lain: ${tambahanSaldoList.length} transaksi",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Total Tambahan",
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      "Rp ${_formatIdr(totalTambahanSaldo)}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.purple,
                                size: 24,
                              ),
                              onPressed: () {
                                _showTambahanSaldoDetail();
                              },
                              tooltip: "Lihat detail tambahan saldo",
                            )
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (!hasActiveSession && hasLoadedLastClosing)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Nilai kas awal default diambil dari kas tutup sesi sebelumnya.",
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Action Menu
                InkWell(
                  onTap: showAddAccountPopup,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00529C).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded, color: Color(0xFF00529C), size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Registrasi Akun Keuangan Baru", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00529C))),
                              Text("Tambah Bank, E-Wallet, atau QRIS untuk pengelolaan saldo", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF00529C), size: 24),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Table Section - Tambahkan info saldo dari sesi sebelumnya
                if (!hasActiveSession && !isLoadingAccountsTable) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Saldo awal di bawah ini diambil dari sesi sebelumnya.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Table Section
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00529C).withOpacity(0.08),
                            ),
                            child: const Icon(Icons.table_chart_rounded, color: Color(0xFF00529C), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text("Daftar Akun & Saldo Awal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00529C))),
                          const Spacer(),
                          if (isLoadingAccountsTable)
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          buildBulkSubmitButton(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(height: 2, color: const Color(0xFFF26A25)),
                      const SizedBox(height: 16),

                      listAccountsTable.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.account_balance_rounded, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text("Belum ada akun keuangan terdaftar", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                double availableWidth = constraints.maxWidth;
                                double noColumnWidth = 50;
                                double categoryColumnWidth = 100;
                                double subCategoryColumnWidth = 110;
                                double balanceColumnWidth = 180;
                                double actionColumnWidth = 50;
                                double nameColumnWidth = availableWidth - (noColumnWidth + categoryColumnWidth + subCategoryColumnWidth + balanceColumnWidth + actionColumnWidth + 40); 
                                
                                if (nameColumnWidth < 150) nameColumnWidth = 150;

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: availableWidth < 750 ? 750 : availableWidth,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                                      dataRowHeight: 64,
                                      columnSpacing: 6,
                                      horizontalMargin: 8,
                                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF00529C)),
                                      columns: [
                                        const DataColumn(label: SizedBox(width: 50, child: Text('No', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                                        DataColumn(label: SizedBox(width: nameColumnWidth, child: Text('Nama Akun', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        const DataColumn(label: SizedBox(width: 100, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        const DataColumn(label: SizedBox(width: 110, child: Text('Sub-Kategori', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        const DataColumn(label: SizedBox(width: 180, child: Text('Saldo Awal', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        const DataColumn(label: SizedBox(width: 50, child: Text('', style: TextStyle(fontWeight: FontWeight.bold)))),
                                      ],
                                      rows: listAccountsTable.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        var item = entry.value;
                                        int id = int.parse(item['id'].toString());
                                        String itemCategory = item['category'] ?? '-';
                                        String itemSubCategory = item['sub_category'] ?? '-';
                                        
                                        bool isMBanking = item['is_m_banking'] == true;
                                        bool isReadonly = item['is_readonly'] == true;
                                        bool isFromPusat = item['is_from_pusat'] == true;
                                        bool isLocked = lockedAccounts[id] ?? false;
                                        String sourceOutletName = item['source_outlet_name'] ?? '';
                                        
                                        Color badgeBgColor = const Color(0xFF00529C).withOpacity(0.08); 
                                        Color badgeTextColor = const Color(0xFF00529C);

                                        if (itemCategory == 'E-Wallet') {
                                          badgeBgColor = const Color(0xFFF26A25).withOpacity(0.08); 
                                          badgeTextColor = const Color(0xFFF26A25);
                                        } else if (itemCategory == 'QRIS') {
                                          badgeBgColor = const Color(0xFF7B1FA2).withOpacity(0.08); 
                                          badgeTextColor = const Color(0xFF7B1FA2);
                                        } else if (itemCategory == 'Bank' && itemSubCategory == 'Penampung') {
                                          badgeBgColor = const Color(0xFFFF6F00).withOpacity(0.08);
                                          badgeTextColor = const Color(0xFFFF6F00);
                                        }

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              SizedBox(
                                                width: 50,
                                                child: Center(
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: nameColumnWidth,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['name'] ?? '-',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 100,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: badgeBgColor,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    itemCategory,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeTextColor),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 110,
                                                child: itemCategory == 'Bank' && itemSubCategory != '-'
                                                    ? Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          itemSubCategory,
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      )
                                                    : Text(
                                                        '-',
                                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                                        textAlign: TextAlign.center,
                                                      ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 180,
                                                child: isReadonly || isLocked
                                                    ? Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                        decoration: BoxDecoration(
                                                          color: isLocked ? Colors.grey.shade200 : Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: isLocked ? Colors.grey.shade400 : Colors.grey.shade300),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                "Rp ${balanceControllers[id]?.text ?? '0'}",
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 13,
                                                                  color: isLocked ? Colors.grey.shade600 : Colors.grey.shade600,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (isFromPusat && !isLocked)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.blue.shade50,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: Colors.blue.shade200),
                                                                ),
                                                                child: Text(
                                                                  "PUSAT",
                                                                  style: TextStyle(
                                                                    fontSize: 7,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.blue.shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                            if (isLocked)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.orange.shade50,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: Colors.orange.shade200),
                                                                ),
                                                                child: Text(
                                                                  "TERKUNCI",
                                                                  style: TextStyle(
                                                                    fontSize: 7,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.orange.shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      )
                                                    : TextField(
                                                        controller: balanceControllers[id],
                                                        keyboardType: TextInputType.number,
                                                        inputFormatters: [CurrencyInputFormatter()],
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: Color(0xFF00529C),
                                                        ),
                                                        decoration: InputDecoration(
                                                          prefixText: "Rp ",
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                            borderSide: const BorderSide(color: Color(0xFF00529C), width: 1.5),
                                                          ),
                                                          fillColor: Colors.grey.shade50,
                                                          filled: true,
                                                          hintText: "0",
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 70,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // ============ TOMBOL EDIT - HANYA UNTUK AKUN TERKUNCI ============
                                                    if (!isReadonly && isLocked && hasActiveSession)
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.edit_rounded,
                                                          color: const Color(0xFFF26A25),
                                                          size: 18,
                                                        ),
                                                        onPressed: () => _showEditSaldoDialog(
                                                          id,
                                                          item['name'] ?? 'Akun',
                                                          double.tryParse(balanceControllers[id]?.text?.replaceAll('.', '') ?? '0') ?? 0
                                                        ),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        tooltip: "Edit Saldo Awal",
                                                      ),
                                                    if (isReadonly)
                                                      Icon(
                                                        Icons.lock_outline_rounded,
                                                        color: Colors.grey.shade400,
                                                        size: 18,
                                                      )
                                                    else
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.delete_outline_rounded,
                                                          color: Colors.red.shade400,
                                                          size: 18,
                                                        ),
                                                        onPressed: isDeleting 
                                                            ? null 
                                                            : () => deleteAccount(id, item['name'] ?? 'Akun'),
                                                        tooltip: "Hapus akun",
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Akun: ${listAccountsTable.length}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    if (isDeleting)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red.shade400,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ DIALOG DETAIL TAMBAHAN KAS ============
  void _showTambahanKasDetail() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Detail Tambahan Kas",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: tambahanKasList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Belum ada tambahan kas",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: tambahanKasList.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var item = tambahanKasList[index];
                    double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                    String sourceOutlet = item['source_outlet_name'] ?? 'Outlet Lain';
                    String createdAt = item['created_at'] ?? '';
                    String keterangan = item['keterangan'] ?? '';
                    
                    String formattedDate = '';
                    try {
                      if (createdAt.isNotEmpty) {
                        DateTime dateTime = DateTime.parse(createdAt);
                        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
                      }
                    } catch (e) {
                      formattedDate = createdAt;
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: const Icon(Icons.attach_money, color: Colors.green, size: 18),
                      ),
                      title: Text(
                        "Rp ${_formatIdr(nominal)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dari: $sourceOutlet",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          if (keterangan.isNotEmpty)
                            Text(
                              keterangan,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ============ DIALOG DETAIL TAMBAHAN SALDO ============
  void _showTambahanSaldoDetail() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Detail Tambahan Saldo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: tambahanSaldoList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Belum ada tambahan saldo",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: tambahanSaldoList.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var item = tambahanSaldoList[index];
                    double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                    String sourceOutlet = item['source_outlet_name'] ?? 'Outlet Lain';
                    String accountName = item['account_name'] ?? 'Akun Tujuan';
                    String createdAt = item['created_at'] ?? '';
                    String keterangan = item['keterangan'] ?? '';
                    
                    String formattedDate = '';
                    try {
                      if (createdAt.isNotEmpty) {
                        DateTime dateTime = DateTime.parse(createdAt);
                        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
                      }
                    } catch (e) {
                        formattedDate = createdAt;
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        child: const Icon(Icons.account_balance, color: Colors.purple, size: 18),
                      ),
                      title: Text(
                        "Rp ${_formatIdr(nominal)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dari: $sourceOutlet → $accountName",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          if (keterangan.isNotEmpty)
                            Text(
                              keterangan,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}