import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MasterAccountScreen extends StatefulWidget {
  const MasterAccountScreen({super.key});

  @override
  State<MasterAccountScreen> createState() => _MasterAccountScreenState();
}

class _MasterAccountScreenState extends State<MasterAccountScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  List<dynamic> accounts = [];
  List<String> categories = ['Bank', 'E-Wallet', 'QRIS'];
  bool isLoading = true;
  bool isDeleting = false;
  bool isAddingCategory = false;
  
  final TextEditingController nameController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  String? selectedCategory;
  bool isRekeningUtama = false;
  int? editingId;

  @override
  void initState() {
    super.initState();
    fetchAccounts();
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  Future<void> fetchAccounts({String? category}) async {
    setState(() => isLoading = true);
    try {
      String url = "$baseUrl/get_master_account.php";
      if (category != null && category.isNotEmpty) {
        url += "?category=$category";
      }
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          accounts = data['data'] ?? [];
        });
      }
    } catch (e) {
      showSnackBar("Gagal memuat data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveAccount() async {
    if (nameController.text.isEmpty) {
      showSnackBar("Nama akun wajib diisi!");
      return;
    }
    
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      showSnackBar("Kategori wajib dipilih!");
      return;
    }

    final url = editingId == null 
        ? "$baseUrl/add_master_account.php"
        : "$baseUrl/update_master_account.php";

    final payload = {
      "name": nameController.text.trim(),
      "category": selectedCategory,
      "is_rekening_utama": isRekeningUtama ? 1 : 0,
    };
    
    if (editingId != null) {
      payload["id"] = editingId;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Akun berhasil disimpan");
        Navigator.pop(context);
        await fetchAccounts();
        resetForm();
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan akun");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    }
  }

  Future<void> saveNewCategory() async {
    if (categoryController.text.isEmpty) {
      showSnackBar("Nama kategori wajib diisi!");
      return;
    }
    
    String newCategory = categoryController.text.trim();
    if (categories.contains(newCategory)) {
      showSnackBar("Kategori '$newCategory' sudah ada!");
      return;
    }
    
    setState(() {
      categories.add(newCategory);
      selectedCategory = newCategory;
      isAddingCategory = false;
      categoryController.clear();
    });
    
    showSnackBar("Kategori '$newCategory' berhasil ditambahkan");
  }

  Future<void> deleteAccount(int id, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun"),
        content: Text("Apakah Anda yakin ingin menghapus akun '$name'?"),
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
        Uri.parse("$baseUrl/delete_master_account.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Akun berhasil dihapus");
        await fetchAccounts();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus akun");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isDeleting = false);
    }
  }

  void resetForm() {
    nameController.clear();
    categoryController.clear();
    setState(() {
      isRekeningUtama = false;
      editingId = null;
      selectedCategory = null;
      isAddingCategory = false;
    });
  }

  void editAccount(Map<String, dynamic> account) {
    nameController.text = account['name'] ?? '';
    setState(() {
      selectedCategory = account['category'] ?? '';
      isRekeningUtama = account['is_rekening_utama'] == 1;
      editingId = account['id'];
    });
    showAddAccountDialog();
  }

  void showAddAccountDialog() {
    // Reset form jika bukan edit
    if (editingId == null) {
      resetForm();
    }
    
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
                  editingId == null ? "Tambah Akun" : "Edit Akun",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nama Akun
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Nama Akun",
                      hintText: "Contoh: BRI, DANA, QRIS BCA",
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Kategori dengan fitur tambah kategori
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          hint: const Text("Pilih Kategori"),
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: "Kategori",
                            prefixIcon: const Icon(Icons.category_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedCategory = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol tambah kategori
                      Tooltip(
                        message: "Tambah Kategori Baru",
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              isAddingCategory = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF26A25).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF26A25).withOpacity(0.3)),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFFF26A25),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Input tambah kategori
                  if (isAddingCategory) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: categoryController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: "Nama kategori baru",
                              prefixIcon: const Icon(Icons.add_rounded, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (_) => saveNewCategory(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00529C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: saveNewCategory,
                          child: const Text("Tambah", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 20),
                          onPressed: () {
                            setDialogState(() {
                              isAddingCategory = false;
                              categoryController.clear();
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Checkbox Rekening Utama
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
                              "Rekening Utama akan ditampilkan terlebih dahulu dan memiliki sub-kategori (EDC/Penampung) saat registrasi akun",
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
                onPressed: saveAccount,
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Bank':
        return const Color(0xFF00529C);
      case 'E-Wallet':
        return const Color(0xFFF26A25);
      case 'QRIS':
        return const Color(0xFF7B1FA2);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bank':
        return Icons.account_balance_rounded;
      case 'E-Wallet':
        return Icons.phone_android_rounded;
      case 'QRIS':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Master Akun", style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: const Color(0xFF00529C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              resetForm();
              showAddAccountDialog();
            },
            tooltip: "Tambah Akun",
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchAccounts,
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
          : accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        "Belum ada akun terdaftar",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Klik tombol + untuk menambah akun",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final bool isUtama = account['is_rekening_utama'] == 1;
                    final String category = account['category'] ?? 'Unknown';
                    final Color categoryColor = _getCategoryColor(category);
                    final IconData categoryIcon = _getCategoryIcon(category);
                    
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
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(categoryIcon, color: categoryColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      account['name'] ?? 'Unknown',
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
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: categoryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_rounded, color: Colors.grey.shade600, size: 20),
                                onPressed: () => editAccount(account),
                                tooltip: "Edit Akun",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                                onPressed: isDeleting ? null : () => deleteAccount(account['id'], account['name'] ?? 'Akun'),
                                tooltip: "Hapus Akun",
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