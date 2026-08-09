import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MasterBankScreen extends StatefulWidget {
  const MasterBankScreen({super.key});

  @override
  State<MasterBankScreen> createState() => _MasterBankScreenState();
}

class _MasterBankScreenState extends State<MasterBankScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  List<dynamic> banks = [];
  bool isLoading = true;
  bool isDeleting = false;
  
  final TextEditingController nameController = TextEditingController();
  final TextEditingController kodeBankController = TextEditingController();
  bool isRekeningUtama = false;
  int? editingId;

  @override
  void initState() {
    super.initState();
    fetchBanks();
  }

  @override
  void dispose() {
    nameController.dispose();
    kodeBankController.dispose();
    super.dispose();
  }

  Future<void> fetchBanks() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_master_bank.php"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          banks = data['data'] ?? [];
        });
      }
    } catch (e) {
      showSnackBar("Gagal memuat data bank: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveBank() async {
    if (nameController.text.isEmpty) {
      showSnackBar("Nama bank wajib diisi!");
      return;
    }

    final url = editingId == null 
        ? "$baseUrl/add_master_bank.php"
        : "$baseUrl/update_master_bank.php";

    final payload = {
      "name": nameController.text.trim(),
      "kode_bank": kodeBankController.text.trim(),
      "is_rekening_utama": isRekeningUtama ? 1 : 0,
    };
    
    if (editingId != null) {
      payload["id"] = editingId as Object;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Bank berhasil disimpan");
        Navigator.pop(context);
        await fetchBanks();
        resetForm();
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan bank");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    }
  }

  Future<void> deleteBank(int id, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Bank"),
        content: Text("Apakah Anda yakin ingin menghapus bank '$name'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_master_bank.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Bank berhasil dihapus");
        await fetchBanks();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus bank");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isDeleting = false);
    }
  }

  void resetForm() {
    nameController.clear();
    kodeBankController.clear();
    setState(() {
      isRekeningUtama = false;
      editingId = null;
    });
  }

  void editBank(Map<String, dynamic> bank) {
    nameController.text = bank['name'] ?? '';
    kodeBankController.text = bank['kode_bank'] ?? '';
    setState(() {
      isRekeningUtama = bank['is_rekening_utama'] == 1;
      editingId = bank['id'];
    });
    showAddBankDialog();
  }

  void showAddBankDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                  child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00529C), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  editingId == null ? "Tambah Bank" : "Edit Bank",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Nama Bank",
                      hintText: "Contoh: BRI, BCA, Mandiri",
                      prefixIcon: Icon(Icons.business_center_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isRekeningUtama,
                        onChanged: (val) {
                          setDialogState(() => isRekeningUtama = val ?? false);
                        },
                        activeColor: const Color(0xFFF26A25),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Rekening Utama",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                  if (isRekeningUtama)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Bank Rekening Utama akan menampilkan pilihan EDC/Penampung saat registrasi akun",
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  resetForm();
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
                onPressed: saveBank,
                child: const Text(
                  "Simpan",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Master Bank", style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: const Color(0xFF00529C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              resetForm();
              showAddBankDialog();
            },
            tooltip: "Tambah Bank",
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchBanks,
            tooltip: "Refresh",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: const Color(0xFFF26A25)),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26A25)))
          : banks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        "Belum ada bank terdaftar",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Klik tombol + untuk menambah bank",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: banks.length,
                  itemBuilder: (context, index) {
                    final bank = banks[index];
                    final bool isUtama = bank['is_rekening_utama'] == 1;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUtama ? const Color(0xFFF26A25).withOpacity(0.3) : Colors.grey.shade200,
                          width: isUtama ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isUtama 
                                  ? const Color(0xFFF26A25).withOpacity(0.1)
                                  : const Color(0xFF00529C).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_rounded,
                              color: isUtama ? const Color(0xFFF26A25) : const Color(0xFF00529C),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      bank['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isUtama)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF26A25).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFF26A25).withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          "Utama",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFF26A25),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (bank['kode_bank'] != null && bank['kode_bank'].isNotEmpty)
                                  Text(
                                    "Kode: ${bank['kode_bank']}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_rounded, color: Colors.grey.shade600, size: 20),
                                onPressed: () => editBank(bank),
                                tooltip: "Edit Bank",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                                onPressed: isDeleting ? null : () => deleteBank(bank['id'], bank['name'] ?? 'Bank'),
                                tooltip: "Hapus Bank",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}