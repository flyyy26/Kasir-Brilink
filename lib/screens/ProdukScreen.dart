import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  int? myKaryawanId;
  
  // ============ TAMBAHKAN TIPE OUTLET ============
  String outletType = 'pusat';
  // ==============================================
  
  List<dynamic> produkList = [];
  List<dynamic> filteredProdukList = [];
  List<dynamic> kategoriList = [];
  bool isLoading = false;
  bool isSubmitting = false;
  bool isDeleting = false;
  bool isLoadingKategori = false;

  // Controller untuk form produk
  String? selectedKategoriId;
  String? selectedKategoriName;
  
  final TextEditingController namaProdukController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController stokController = TextEditingController();
  final TextEditingController hargaHppController = TextEditingController();
  final TextEditingController hargaJualController = TextEditingController();

  // Controller untuk tambah kategori
  final TextEditingController kategoriBaruController = TextEditingController();
  final TextEditingController deskripsiKategoriController = TextEditingController();
  bool isAddingKategori = false;

  // Filter & Search
  String searchQuery = '';
  String? filterKategoriId;

  int editingId = 0;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    namaProdukController.dispose();
    skuController.dispose();
    stokController.dispose();
    hargaHppController.dispose();
    hargaJualController.dispose();
    kategoriBaruController.dispose();
    deskripsiKategoriController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id');
      // ============ AMBIL TIPE OUTLET ============
      outletType = prefs.getString('tipe_outlet') ?? 'pusat';
      // ===========================================
    });
    await fetchKategori();
    await fetchProduk();
  }

  Future<void> fetchKategori() async {
    setState(() => isLoadingKategori = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_kategori_produk.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          kategoriList = data['data'] ?? [];
          if (kategoriList.isNotEmpty && selectedKategoriId == null) {
            selectedKategoriId = kategoriList[0]['id'].toString();
            selectedKategoriName = kategoriList[0]['nama_kategori'].toString();
          }
        });
      }
    } catch (e) {
      print("Gagal mengambil kategori: $e");
    } finally {
      setState(() => isLoadingKategori = false);
    }
  }

  // ============ FETCH PRODUK (TETAP DARI OUTLET MASING-MASING) ============
  Future<void> fetchProduk() async {
    setState(() => isLoading = true);
    try {
      // ============ TETAP AMBIL DARI OUTLET SENDIRI ============
      String url = "$baseUrl/get_produk.php?outlet_id=$myOutletId";
      // ===========================================================
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          produkList = data['data'] ?? [];
          applyFilters();
        });
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat data produk");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void applyFilters() {
    var filtered = List.from(produkList);

    if (filterKategoriId != null) {
      filtered = filtered.where((p) {
        return p['kategori_id']?.toString() == filterKategoriId;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      String query = searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        String nama = p['nama_produk']?.toString().toLowerCase() ?? '';
        String sku = p['sku']?.toString().toLowerCase() ?? '';
        return nama.contains(query) || sku.contains(query);
      }).toList();
    }

    setState(() => filteredProdukList = filtered);
  }

  Future<void> addKategori(StateSetter dialogSetState) async {
    if (kategoriBaruController.text.trim().isEmpty) {
      showSnackBar("Masukkan nama kategori!");
      return;
    }

    String newNamaKategori = kategoriBaruController.text.trim();
    String newDeskripsiKategori = deskripsiKategoriController.text.trim();

    setState(() => isAddingKategori = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_kategori_produk.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"outlet_id": myOutletId, "nama_kategori": newNamaKategori, "deskripsi": newDeskripsiKategori}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar("Kategori berhasil ditambahkan!");        
        await fetchKategori();

        var newKategori = kategoriList.firstWhere((k) => k['nama_kategori'] == newNamaKategori, orElse: () => null);

        dialogSetState(() {
          if (newKategori != null) {
            selectedKategoriId = newKategori['id'].toString();
            selectedKategoriName = newKategori['nama_kategori'].toString();
          }
        });

        kategoriBaruController.clear();
        deskripsiKategoriController.clear();
        
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        showSnackBar(data['message'] ?? "Gagal menambah kategori");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isAddingKategori = false);
    }
  }

  void showAddKategoriDialog(StateSetter dialogSetState) {
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
            const Text("Tambah Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kategoriBaruController,
                decoration: InputDecoration(
                  labelText: "Nama Kategori",
                  hintText: "Contoh: Pulsa, Paket Data",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deskripsiKategoriController,
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
            onPressed: isAddingKategori ? null : () => addKategori(dialogSetState),
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

  // ============ SUBMIT PRODUK HANYA UNTUK PUSAT ============
  Future<void> submitProduk() async {
    // Cegah outlet cabang menambah produk
    if (outletType == 'cabang') {
      showSnackBar("Outlet cabang tidak dapat menambah produk!");
      return;
    }
    
    if (selectedKategoriId == null || selectedKategoriId!.isEmpty) {
      showSnackBar("Silakan pilih kategori!");
      return;
    }
    if (namaProdukController.text.trim().isEmpty) {
      showSnackBar("Nama produk wajib diisi!");
      return;
    }
    if (skuController.text.trim().isEmpty) {
      showSnackBar("SKU wajib diisi!");
      return;
    }

    setState(() => isSubmitting = true);

    String cleanStok = stokController.text.replaceAll('.', '');
    String cleanHpp = hargaHppController.text.replaceAll('.', '');
    String cleanJual = hargaJualController.text.replaceAll('.', '');

    var payload = {
      "outlet_id": myOutletId,
      "kategori": selectedKategoriName ?? '',
      "kategori_id": int.tryParse(selectedKategoriId!) ?? 0,
      "nama_produk": namaProdukController.text.trim(),
      "sku": skuController.text.trim(),
      "stok": int.tryParse(cleanStok) ?? 0,
      "harga_hpp": double.tryParse(cleanHpp) ?? 0,
      "harga_jual": double.tryParse(cleanJual) ?? 0,
      "karyawan_id": myKaryawanId,
    };

    String url = "$baseUrl/add_produk.php";
    if (editingId > 0) {
      url = "$baseUrl/update_produk.php";
      payload['id'] = editingId;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Berhasil!");
        resetForm();
        await fetchProduk();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan produk");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }
  // =========================================================

  // ============ DELETE PRODUK HANYA UNTUK PUSAT ============
  Future<void> deleteProduk(int id, String nama) async {
    // Cegah outlet cabang menghapus produk
    if (outletType == 'cabang') {
      showSnackBar("Outlet cabang tidak dapat menghapus produk!");
      return;
    }
    
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
            const Text("Hapus Produk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Apakah Anda yakin ingin menghapus produk?",
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
                  Icon(Icons.inventory_2_rounded, color: primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    nama,
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
              "⚠️ Produk yang dihapus tidak dapat dikembalikan.",
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

    setState(() => isDeleting = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_produk.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": id,
          "outlet_id": myOutletId,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Produk berhasil dihapus");
        await fetchProduk();
      } else {
        showSnackBar(data['message'] ?? "Gagal menghapus produk");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isDeleting = false);
    }
  }
  // =======================================================

  void resetForm() {
    namaProdukController.clear();
    skuController.clear();
    stokController.clear();
    hargaHppController.clear();
    hargaJualController.clear();
    setState(() {
      editingId = 0;
      if (kategoriList.isNotEmpty) {
        selectedKategoriId = kategoriList[0]['id'].toString();
        selectedKategoriName = kategoriList[0]['nama_kategori'].toString();
      }
    });
  }

  void editProduk(Map<String, dynamic> produk) {
    // ============ CEK: CABANG TIDAK BISA EDIT ============
    if (outletType == 'cabang') {
      showSnackBar("Outlet cabang tidak dapat mengedit produk!");
      return;
    }
    // ====================================================
    
    int id = 0;
    var idValue = produk['id'];
    if (idValue is int) {
      id = idValue;
    } else if (idValue is String) {
      id = int.tryParse(idValue) ?? 0;
    }
    
    if (id == 0) {
      showSnackBar("Error: ID produk tidak valid");
      return;
    }
    
    String kategoriName = produk['kategori']?.toString() ?? '';
    String? foundKategoriId;
    for (var k in kategoriList) {
      if (k['nama_kategori'].toString() == kategoriName) {
        foundKategoriId = k['id'].toString();
        break;
      }
    }
    
    double stokValue = 0;
    var stokData = produk['stok'];
    if (stokData is int) {
      stokValue = stokData.toDouble();
    } else if (stokData is double) {
      stokValue = stokData;
    } else if (stokData is String) {
      stokValue = double.tryParse(stokData) ?? 0;
    }
    
    double hppValue = 0;
    var hppData = produk['harga_hpp'];
    if (hppData is int) {
      hppValue = hppData.toDouble();
    } else if (hppData is double) {
      hppValue = hppData;
    } else if (hppData is String) {
      hppValue = double.tryParse(hppData) ?? 0;
    }
    
    double jualValue = 0;
    var jualData = produk['harga_jual'];
    if (jualData is int) {
      jualValue = jualData.toDouble();
    } else if (jualData is double) {
      jualValue = jualData;
    } else if (jualData is String) {
      jualValue = double.tryParse(jualData) ?? 0;
    }
    
    setState(() {
      editingId = id;
      if (foundKategoriId != null) {
        selectedKategoriId = foundKategoriId;
        selectedKategoriName = kategoriName;
      }
      namaProdukController.text = produk['nama_produk']?.toString() ?? '';
      skuController.text = produk['sku']?.toString() ?? '';
      stokController.text = _formatIdr(stokValue);
      hargaHppController.text = _formatIdr(hppValue);
      hargaJualController.text = _formatIdr(jualValue);
    });
    showAddEditDialog();
  }

  void showAddEditDialog() {
    // ============ CABANG TIDAK BISA BUKA DIALOG ============
    if (outletType == 'cabang') {
      showSnackBar("Outlet cabang tidak dapat menambah/mengedit produk!");
      return;
    }
    // ======================================================
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  editingId > 0 ? Icons.edit_rounded : Icons.add_rounded,
                  color: primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                editingId > 0 ? "Edit Produk" : "Tambah Produk",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: isLoadingKategori
                            ? Container(
                                height: 50,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: selectedKategoriId,
                                hint: const Text("Pilih Kategori", style: TextStyle(fontSize: 13)),
                                decoration: InputDecoration(
                                  labelText: "Kategori",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                items: kategoriList.map((k) {
                                  return DropdownMenuItem<String>(
                                    value: k['id'].toString(),
                                    child: Row(
                                      children: [
                                        Icon(Icons.category_rounded, size: 14, color: primaryBlue),
                                        const SizedBox(width: 8),
                                        Text(
                                          k['nama_kategori'].toString(),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    var selected = kategoriList.firstWhere((k) => k['id'].toString() == val);
                                    dialogSetState(() {
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
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          onPressed: () => showAddKategoriDialog(dialogSetState),
                          tooltip: "Tambah Kategori",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: namaProdukController,
                    decoration: InputDecoration(
                      labelText: "Nama Produk",
                      hintText: "Contoh: Pulsa 10.000",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: skuController,
                    decoration: InputDecoration(
                      labelText: "SKU",
                      hintText: "Contoh: PULSA-001",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stokController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: "Stok",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hargaHppController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: "Harga HPP (Modal)",
                      prefixText: "Rp ",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hargaJualController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: "Harga Jual",
                      prefixText: "Rp ",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                resetForm();
                Navigator.pop(context);
              },
              child: Text("BATAL", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : submitProduk,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      editingId > 0 ? "UPDATE" : "SIMPAN",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(Map<String, dynamic> produk) async {
    String namaProduk = produk['nama_produk'] ?? 'Produk';
    int produkId = produk['id'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.history_rounded, color: Colors.amber.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Histori - $namaProduk",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: _buildHistoryList(produkId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Tutup", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(int produkId) {
    return FutureBuilder(
      future: fetchProdukHistory(produkId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 8),
                Text(
                  "Gagal memuat histori",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        
        List<dynamic> histories = snapshot.data ?? [];
        
        if (histories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  "Belum ada histori perubahan",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        
        return ListView.separated(
          itemCount: histories.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100),
          itemBuilder: (context, index) {
            var log = histories[index];
            String fieldName = log['field_name'] ?? '';
            String oldValue = log['old_value'] ?? '';
            String newValue = log['new_value'] ?? '';
            String actionType = log['action_type'] ?? '';
            String karyawanName = log['karyawan_name'] ?? 'Sistem';
            String createdAt = log['created_at'] ?? '';
            
            String formattedDate = '';
            String formattedOldValue = oldValue;
            String formattedNewValue = newValue;

            // Format nilai jika berupa harga
            if (fieldName == 'harga_hpp' || fieldName == 'harga_jual') {
              if (oldValue.isNotEmpty) {
                formattedOldValue = "Rp ${_formatIdr(_parseToDouble(oldValue))}";
              }
              if (newValue.isNotEmpty) {
                formattedNewValue = "Rp ${_formatIdr(_parseToDouble(newValue))}";
              }
            }

            try {
              if (createdAt.isNotEmpty) {
                DateTime dateTime = DateTime.parse(createdAt);
                formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
              }
            } catch (e) {
              formattedDate = createdAt;
            }
            
            String fieldLabel = '';
            switch (fieldName) {
              case 'stok':
                fieldLabel = 'Stok';
                break;
              case 'harga_hpp':
                fieldLabel = 'Harga HPP';
                break;
              case 'harga_jual':
                fieldLabel = 'Harga Jual';
                break;
              case 'nama_produk':
                fieldLabel = 'Nama Produk';
                break;
              case 'sku':
                fieldLabel = 'SKU';
                break;
              case 'kategori':
                fieldLabel = 'Kategori';
                break;
              case 'produk':
                fieldLabel = 'Produk Baru';
                break;
              default:
                fieldLabel = fieldName;
            }
            
            String actionLabel = '';
            Color actionColor = Colors.grey;
            IconData actionIcon = Icons.edit_rounded;
            
            if (actionType == 'CREATE') {
              actionLabel = 'Dibuat';
              actionColor = Colors.green;
              actionIcon = Icons.add_circle_outline_rounded;
            } else if (actionType == 'DELETE') {
              actionLabel = 'Dihapus';
              actionColor = Colors.red;
              actionIcon = Icons.delete_outline_rounded;
            } else if (actionType == 'UPDATE') {
              actionLabel = 'Diubah';
              actionColor = Colors.blue;
              actionIcon = Icons.edit_rounded;
            }
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: actionColor.withOpacity(0.1),
                child: Icon(actionIcon, color: actionColor, size: 18),
              ),
              title: Row(
                children: [
                  Text(
                    fieldLabel,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: actionColor,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actionType == 'UPDATE') ...[
                    Row(
                      children: [
                        Text(
                          "Dari: ${oldValue.isEmpty ? '-' : formattedOldValue}",
                          style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          "Ke: $formattedNewValue",
                          style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ] else if (actionType == 'CREATE') ...[
                    Text(
                      "Produk: $newValue",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  Text(
                    "Oleh: $karyawanName • $formattedDate",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              isThreeLine: true,
              dense: true,
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> fetchProdukHistory(int produkId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_produk_log.php?produk_id=$produkId&outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print("Gagal mengambil histori produk: $e");
      return [];
    }
  }

  Widget _buildProdukCard(Map<String, dynamic> produk) {
    double stokValue = _parseToDouble(produk['stok']);
    double hppValue = _parseToDouble(produk['harga_hpp']);
    double jualValue = _parseToDouble(produk['harga_jual']);
    Color stokColor = stokValue <= 10 ? Colors.red.shade700 : (stokValue <= 25 ? Colors.orange.shade800 : Colors.green.shade700);

    // ============ TENTUKAN APAKAH BISA EDIT/HAPUS ============
    bool canEdit = outletType == 'pusat';
    // ========================================================

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          // Header: Nama, Kategori, Aksi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produk['nama_produk'] ?? 'Tanpa Nama',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            produk['kategori'] ?? '-',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: primaryBlue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "SKU: ${produk['sku'] ?? '-'}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ============ TAMPILKAN AKSI HANYA UNTUK PUSAT ============
              if (canEdit) ...[
                _buildActionButtons(produk),
              ],
              // =========================================================
            ],
          ),
          const Divider(height: 24),
          // Detail: Stok, HPP, Harga Jual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn("Stok", stokValue.toInt().toString(), color: stokColor),
              _buildInfoColumn("Harga HPP", "Rp ${_formatIdr(hppValue)}"),
              _buildInfoColumn("Harga Jual", "Rp ${_formatIdr(jualValue)}", isHighlight: true),
            ],
          ),
          // ============ TAMPILKAN LABEL "DARI PUSAT" UNTUK CABANG ============
          if (outletType == 'cabang') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "📦 Dari Outlet Pusat",
                style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
              ),
            ),
          ],
          // =================================================================
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> produk) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.history_rounded, size: 20, color: Colors.amber.shade700),
          onPressed: () => _showHistoryDialog(produk),
          tooltip: "Lihat Histori",
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 20, color: primaryBlue),
          onPressed: () => editProduk(produk),
          tooltip: "Edit Produk",
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red.shade400),
          onPressed: isDeleting
              ? null
              : () => deleteProduk(produk['id'], produk['nama_produk'] ?? 'Produk'),
          tooltip: "Hapus Produk",
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value, {Color? color, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isHighlight ? primaryOrange : Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  String _formatIdr(double number) {
    String str = number.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }
  
  double _parseToDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
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
          onPressed: () {
            Navigator.pop(context);
          },
          tooltip: "Kembali",
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Data Produk",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
            ),
            // ============ TAMPILKAN TIPE OUTLET ============
            Text(
              outletType.toUpperCase(),
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
            ),
            // =============================================
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
        // ============ TOMBOL TAMBAH HANYA UNTUK PUSAT ============
        actions: [
          if (outletType == 'pusat')
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              onPressed: () {
                resetForm();
                showAddEditDialog();
              },
              tooltip: "Tambah Produk",
            ),
        ],
        // ========================================================
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 450.0, vertical: 12.0),
              child: Column(
                children: [
                  // Filter & Search
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                    applyFilters();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Cari nama produk atau SKU...",
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: filterKategoriId,
                                hint: const Text("Semua Kategori", style: TextStyle(fontSize: 13)),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text("Semua Kategori", style: TextStyle(fontSize: 13)),
                                  ),
                                  ...kategoriList.map((k) {
                                    return DropdownMenuItem<String>(
                                      value: k['id'].toString(),
                                      child: Text(k['nama_kategori'].toString(), style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    filterKategoriId = val;
                                    applyFilters();
                                  });
                                },
                                isExpanded: true,
                                dropdownColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${filteredProdukList.length} dari ${produkList.length} produk ditampilkan",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            if (searchQuery.isNotEmpty || filterKategoriId != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    searchQuery = '';
                                    filterKategoriId = null;
                                    applyFilters();
                                  });
                                },
                                child: const Text("Reset Filter", style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // List Produk
                  Expanded(
                    child: filteredProdukList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  size: 56,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  outletType == 'cabang'
                                      ? "Belum ada produk dari pusat"
                                      : "Produk tidak ditemukan",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  outletType == 'cabang'
                                      ? "Tunggu kiriman produk dari outlet pusat"
                                      : "Coba kata kunci atau filter lain",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ))
                        : ListView.builder(
                            itemCount: filteredProdukList.length,
                            itemBuilder: (context, index) {
                              return _buildProdukCard(filteredProdukList[index]);
                            },
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