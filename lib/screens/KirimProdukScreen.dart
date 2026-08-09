import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class KirimProdukScreen extends StatefulWidget {
  const KirimProdukScreen({super.key});

  @override
  State<KirimProdukScreen> createState() => _KirimProdukScreenState();
}

class _KirimProdukScreenState extends State<KirimProdukScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  int? myKaryawanId;
  String outletType = 'pusat';
  
  List<dynamic> produkList = [];
  List<dynamic> outletCabangList = [];
  List<Map<String, dynamic>> selectedItems = [];
  List<dynamic> kirimProdukList = [];
  
  int? selectedOutletCabangId;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isLoadingOutlets = false;
  
  // ============ FILTER TANGGAL ============
  DateTime? selectedDate = DateTime.now();
  bool hasDateFilter = false;
  // ========================================
  
  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  
  String filterStatus = 'semua';
  final List<String> statusOptions = ['semua', 'pending', 'dikirim', 'diterima', 'ditolak'];
  
  @override
  void initState() {
    super.initState();
    loadData();
  }
  
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id');
      outletType = prefs.getString('tipe_outlet') ?? 'pusat';
    });
    
    await fetchOutletCabang();
    await fetchProduk();
    await fetchKirimProduk();
  }
  
  Future<void> fetchOutletCabang() async {
    setState(() => isLoadingOutlets = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_outlets_by_type.php?type=cabang&outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          outletCabangList = data['data'] ?? [];
          if (outletCabangList.isNotEmpty) {
            selectedOutletCabangId = outletCabangList[0]['id'];
          }
        });
      }
    } catch (e) {
      print("Gagal mengambil outlet cabang: $e");
    } finally {
      setState(() => isLoadingOutlets = false);
    }
  }
  
  Future<void> fetchProduk() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_produk.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          produkList = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Gagal mengambil produk: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  // ============ FETCH KIRIM PRODUK DENGAN FILTER TANGGAL ============
  Future<void> fetchKirimProduk() async {
    setState(() => isLoading = true);
    try {
      String url = "$baseUrl/get_kirim_produk.php?outlet_id=$myOutletId";
      
      // ============ FILTER TANGGAL ============
      // Default selalu gunakan selectedDate (default hari ini)
      if (selectedDate != null) {
        String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
        url += "&tanggal=$dateStr";
      } else {
        // Fallback: gunakan hari ini
        String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        url += "&tanggal=$dateStr";
      }
      // ========================================
      
      if (filterStatus != 'semua') {
        url += "&status=$filterStatus";
      }
      
      print("🔍 URL fetchKirimProduk: $url");
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      print("📦 Response: ${data['total']} data untuk tanggal ${data['tanggal_filter'] ?? '-'}");
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          kirimProdukList = data['data'] ?? [];
          hasDateFilter = true;
        });
      } else {
        setState(() {
          kirimProdukList = [];
        });
        if (data['message'] != null) {
          showSnackBar(data['message']);
        }
      }
    } catch (e) {
      print("Gagal mengambil data kirim produk: $e");
      setState(() => kirimProdukList = []);
    } finally {
      setState(() => isLoading = false);
    }
  }
  // ============================================================================
  
  void addToSelected(produk) {
    setState(() {
      int existingIndex = selectedItems.indexWhere((item) => item['produk_id'] == produk['id']);
      if (existingIndex != -1) {
        selectedItems[existingIndex]['quantity'] = (selectedItems[existingIndex]['quantity'] ?? 1) + 1;
      } else {
        selectedItems.add({
          'produk_id': produk['id'],
          'nama_produk': produk['nama_produk'],
          'sku': produk['sku'],
          'kategori': produk['kategori'],
          'kategori_id': produk['kategori_id'],
          'harga_hpp': produk['harga_hpp'],
          'harga_jual': produk['harga_jual'],
          'stok': produk['stok'],
          'quantity': 1,
        });
      }
    });
  }
  
  void removeFromSelected(int index) {
    setState(() {
      selectedItems.removeAt(index);
    });
  }
  
  void updateQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        selectedItems.removeAt(index);
      } else {
        selectedItems[index]['quantity'] = newQuantity;
      }
    });
  }
  
  Future<void> kirimProduk() async {
    if (selectedOutletCabangId == null) {
      showSnackBar("Pilih outlet cabang tujuan!");
      return;
    }
    
    if (selectedItems.isEmpty) {
      showSnackBar("Pilih produk yang akan dikirim!");
      return;
    }
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Kirim Produk"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Kirim ${selectedItems.length} produk ke:"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                outletCabangList.firstWhere((o) => o['id'] == selectedOutletCabangId)['nama_outlet'] ?? 'Outlet',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            ...selectedItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  "• ${item['nama_produk']} × ${item['quantity']}",
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("KIRIM", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => isSubmitting = true);
    
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/kirim_produk.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "outlet_pusat_id": myOutletId,
          "outlet_cabang_id": selectedOutletCabangId,
          "karyawan_id": myKaryawanId,
          "items": selectedItems.map((item) {
            return {
              "produk_id": item['produk_id'],
              "nama_produk": item['nama_produk'],
              "sku": item['sku'],
              "kategori": item['kategori'],
              "kategori_id": item['kategori_id'],
              "harga_hpp": item['harga_hpp'],
              "harga_jual": item['harga_jual'],
              "quantity": item['quantity'],
            };
          }).toList(),
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Produk berhasil dikirim!");
        setState(() {
          selectedItems.clear();
        });
        await fetchProduk();
        await fetchKirimProduk();
      } else {
        showSnackBar(data['message'] ?? "Gagal mengirim produk");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }
  
  Future<void> terimaProduk(int kirimId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Terima Produk"),
        content: const Text("Apakah Anda yakin ingin menerima produk ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("TERIMA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => isSubmitting = true);
    
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/terima_produk.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "kirim_produk_id": kirimId,
          "outlet_cabang_id": myOutletId,
          "karyawan_id": myKaryawanId,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Produk berhasil diterima!");
        await fetchKirimProduk();
        await fetchProduk();
      } else {
        showSnackBar(data['message'] ?? "Gagal menerima produk");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  // ============ FUNGSI TERIMA SEMUA PRODUK ============
  Future<void> terimaSemuaProduk() async {
    // Ambil semua kiriman dengan status 'dikirim' atau 'pending'
    var pendingItems = kirimProdukList.where((item) {
      String status = item['status'] ?? '';
      return status == 'dikirim' || status == 'pending';
    }).toList();
    
    if (pendingItems.isEmpty) {
      showSnackBar("Tidak ada produk yang perlu diterima");
      return;
    }
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Terima Semua"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Terima semua ${pendingItems.length} produk yang masuk?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pendingItems.take(5).map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      "• ${item['nama_produk'] ?? 'Produk'} × ${item['quantity']}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (pendingItems.length > 5)
              Text(
                "... dan ${pendingItems.length - 5} produk lainnya",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("TERIMA SEMUA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => isSubmitting = true);
    
    int successCount = 0;
    int failCount = 0;
    
    try {
      for (var item in pendingItems) {
        int kirimId = item['id'];
        
        final response = await http.post(
          Uri.parse("$baseUrl/terima_produk.php"),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "kirim_produk_id": kirimId,
            "outlet_cabang_id": myOutletId,
            "karyawan_id": myKaryawanId,
          }),
        );
        
        final data = json.decode(response.body);
        
        if (response.statusCode == 200 && data['status'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      // Refresh data
      await fetchKirimProduk();
      await fetchProduk();
      
      if (failCount == 0) {
        showSnackBar("✅ Semua $successCount produk berhasil diterima!");
      } else {
        showSnackBar("⚠️ $successCount berhasil diterima, $failCount gagal");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }
  // ================================================
  
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
  
  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // ============ TENTUKAN JUDUL APPBAR ============
    String appBarTitle = outletType == 'pusat' ? 'Kirim Produk' : 'Terima Produk';
    // ===============================================
    
    // ============ CEK APAKAH ADA DATA YANG PERLU DITERIMA ============
    bool hasPending = kirimProdukList.any((item) {
      String status = item['status'] ?? '';
      return status == 'dikirim' || status == 'pending';
    });
    // =================================================================
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              fetchKirimProduk();
              fetchProduk();
              fetchOutletCabang();
            },
          ),
          // ============ TOMBOL TERIMA SEMUA (HANYA UNTUK CABANG) ============
          if (outletType == 'cabang' && hasPending)
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: Colors.white),
              onPressed: isSubmitting ? null : terimaSemuaProduk,
              tooltip: "Terima Semua",
            ),
          // ================================================================
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 300, vertical: 16),
              child: Column(
                children: [
                  // ============ FILTER TANGGAL ============
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Filter Tanggal:",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_left_rounded),
                                onPressed: () {
                                  setState(() {
                                    selectedDate = selectedDate?.subtract(const Duration(days: 1));
                                  });
                                  fetchKirimProduk();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 20,
                              ),
                              InkWell(
                                onTap: () async {
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
                                    });
                                    await fetchKirimProduk();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    selectedDate != null
                                        ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                        : "Pilih Tanggal",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_right_rounded),
                                onPressed: () {
                                  setState(() {
                                    selectedDate = selectedDate?.add(const Duration(days: 1));
                                  });
                                  fetchKirimProduk();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.today_rounded),
                          onPressed: () {
                            setState(() {
                              selectedDate = DateTime.now();
                            });
                            fetchKirimProduk();
                          },
                          tooltip: "Hari ini",
                          iconSize: 20,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<String>(
                            value: filterStatus,
                            items: statusOptions.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                filterStatus = val ?? 'semua';
                              });
                              fetchKirimProduk();
                            },
                            underline: const SizedBox(),
                            iconSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // ============ FORM KIRIM PRODUK (HANYA UNTUK PUSAT) ============
                  if (outletType == 'pusat') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: selectedOutletCabangId,
                                  hint: const Text("Pilih Outlet Cabang"),
                                  decoration: InputDecoration(
                                    labelText: "Outlet Tujuan",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  items: outletCabangList.map((outlet) {
                                    return DropdownMenuItem<int>(
                                      value: outlet['id'],
                                      child: Text(outlet['nama_outlet'] ?? 'Outlet'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      selectedOutletCabangId = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryOrange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: isSubmitting ? null : kirimProduk,
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded, color: Colors.white),
                                  label: Text(
                                    isSubmitting ? "MENGIRIM..." : "KIRIM",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (selectedItems.isNotEmpty) ...[
                            const Text(
                              "Produk yang akan dikirim:",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: selectedItems.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var item = entry.value;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['nama_produk'] ?? 'Produk',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.remove_rounded, size: 16),
                                              onPressed: () => updateQuantity(idx, (item['quantity'] ?? 1) - 1),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            SizedBox(
                                              width: 30,
                                              child: Text(
                                                '${item['quantity'] ?? 1}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.add_rounded, size: 16),
                                              onPressed: () => updateQuantity(idx, (item['quantity'] ?? 1) + 1),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                              onPressed: () => removeFromSelected(idx),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Total: ${selectedItems.length} produk, ${selectedItems.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))} pcs",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // ============ DAFTAR PRODUK (HANYA UNTUK PUSAT) ============
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Daftar Produk",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.35,
                              minHeight: 100,
                            ),
                            child: produkList.isEmpty
                                ? const Center(child: Text("Tidak ada produk"))
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: produkList.length,
                                    itemBuilder: (context, index) {
                                      var produk = produkList[index];
                                      int stok = int.tryParse(produk['stok']?.toString() ?? '0') ?? 0;
                                      bool isSelected = selectedItems.any((item) => item['produk_id'] == produk['id']);
                                      
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.inventory_2_rounded,
                                          color: stok > 0 ? primaryBlue : Colors.grey.shade400,
                                        ),
                                        title: Text(
                                          produk['nama_produk'] ?? 'Produk',
                                          style: TextStyle(
                                            color: stok > 0 ? Colors.black87 : Colors.grey.shade400,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "Stok: $stok | ${produk['sku'] ?? '-'}",
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                        trailing: isSelected
                                            ? Chip(
                                                label: const Text("Dipilih", style: TextStyle(fontSize: 10)),
                                                backgroundColor: Colors.green.shade100,
                                                labelStyle: TextStyle(color: Colors.green.shade700),
                                              )
                                            : (stok > 0
                                                ? IconButton(
                                                    icon: Icon(Icons.add_circle_outline, color: primaryBlue),
                                                    onPressed: () => addToSelected(produk),
                                                  )
                                                : null),
                                        onTap: stok > 0 ? () => addToSelected(produk) : null,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // ============ RIWAYAT KIRIM PRODUK ============
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "Riwayat",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  // ============ TAMPILKAN TANGGAL FILTER ============
                                  if (selectedDate != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy').format(selectedDate!),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                  // ==================================================
                                  Text(
                                    "(${kirimProdukList.length})",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              // ============ TOMBOL TERIMA SEMUA (HANYA UNTUK CABANG & ADA DATA) ============
                              if (outletType == 'cabang' && kirimProdukList.isNotEmpty && hasPending)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: isSubmitting ? null : terimaSemuaProduk,
                                  icon: Icon(Icons.checklist_rounded, size: 16, color: Colors.white),
                                  label: const Text(
                                    "TERIMA SEMUA",
                                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              // ==============================================================
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // ============ TAMPILKAN PESAN JIKA TIDAK ADA DATA ============
                          kirimProdukList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text(
                                          selectedDate != null && selectedDate != DateTime.now()
                                              ? "Tidak ada kiriman pada ${DateFormat('dd/MM/yyyy').format(selectedDate!)}"
                                              : "Belum ada kiriman hari ini",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          outletType == 'pusat' 
                                              ? "Kirim produk ke outlet cabang"
                                              : "Tunggu kiriman dari outlet pusat",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Expanded(
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: kirimProdukList.length,
                                    separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100),
                                    itemBuilder: (context, index) {
                                      var item = kirimProdukList[index];
                                      String status = item['status'] ?? 'pending';
                                      Color statusColor = status == 'diterima'
                                          ? Colors.green
                                          : (status == 'dikirim' ? Colors.orange : Colors.grey);
                                      
                                      // ============ TAMPILKAN NAMA OUTLET SESUAI POV ============
                                      String outletName = '';
                                      if (outletType == 'pusat') {
                                        outletName = item['outlet_cabang_name'] ?? '-';
                                      } else {
                                        outletName = item['outlet_pusat_name'] ?? '-';
                                      }
                                      // ========================================================
                                      
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: statusColor.withOpacity(0.1),
                                          child: Icon(
                                            status == 'diterima' ? Icons.check_rounded : Icons.send_rounded,
                                            color: statusColor,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          item['nama_produk'] ?? 'Produk',
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${item['quantity']} pcs | ${outletType == 'pusat' ? 'Ke: ' : 'Dari: '}$outletName",
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                            Text(
                                              _formatDate(item['created_at'] ?? ''),
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            if (outletType == 'cabang' && status == 'dikirim')
                                              const SizedBox(width: 8),
                                            if (outletType == 'cabang' && status == 'dikirim')
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                ),
                                                onPressed: isSubmitting ? null : () => terimaProduk(item['id']),
                                                child: const Text(
                                                  "TERIMA",
                                                  style: TextStyle(fontSize: 10, color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          // ==============================================================
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