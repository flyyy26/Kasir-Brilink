import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class PosScreen extends StatefulWidget {
  final int sessionId;

  const PosScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  int myKaryawanId = 0;
  String myKaryawanName = "";
  String outletType = 'pusat';

  List<dynamic> produkList = [];
  List<dynamic> kategoriList = [];
  List<Map<String, dynamic>> cartItems = [];
  
  String? selectedKategoriId;
  String searchQuery = '';
  
  String selectedPaymentMethod = 'cash';
  final List<String> paymentMethods = ['cash', 'qris'];

  // ============ VARIABEL DISKON ============
  double diskonPersen = 0;
  double diskonNominal = 0;
  bool isDiskonActive = false;
  final TextEditingController diskonController = TextEditingController();
  // ========================================

  bool isLoading = false;
  bool isLoadingKategori = false;
  bool isSubmitting = false;

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  final TextEditingController customerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    diskonController.addListener(_onDiskonChanged);
  }

  @override
  void dispose() {
    customerController.dispose();
    diskonController.dispose();
    super.dispose();
  }

  void _onDiskonChanged() {
    String text = diskonController.text.trim();
    if (text.isEmpty) {
      setState(() {
        diskonPersen = 0;
        diskonNominal = 0;
        isDiskonActive = false;
      });
      return;
    }
    
    double? value = double.tryParse(text);
    if (value != null) {
      if (value > 100) {
        value = 100;
        diskonController.text = '100';
        diskonController.selection = TextSelection.fromPosition(
          TextPosition(offset: diskonController.text.length),
        );
      }
      setState(() {
        diskonPersen = value!;
        isDiskonActive = value > 0;
        _hitungDiskonNominal();
      });
    }
  }

  void _hitungDiskonNominal() {
    double total = getTotalPrice();
    if (total > 0) {
      diskonNominal = total * (diskonPersen / 100);
    } else {
      diskonNominal = 0;
    }
  }

  double getTotalPrice() {
    return cartItems.fold(0.0, (sum, item) {
      double price = item['harga_jual'] ?? 0;
      int qty = item['quantity'] ?? 0;
      return sum + (price * qty);
    });
  }

  double getTotalAfterDiscount() {
    double total = getTotalPrice();
    double diskon = diskonNominal;
    if (diskon > total) diskon = total;
    return total - diskon;
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? prefs.getInt('saved_outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id') ?? 0;
      myKaryawanName = prefs.getString('nama_karyawan') ?? "Kasir";
      outletType = prefs.getString('tipe_outlet') ?? 'pusat';
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
        });
      }
    } catch (e) {
      print("Gagal mengambil kategori: $e");
    } finally {
      setState(() => isLoadingKategori = false);
    }
  }

  Future<void> fetchProduk({String? kategoriId}) async {
    setState(() => isLoading = true);
    try {
      String url = "$baseUrl/get_produk.php?outlet_id=$myOutletId";
      if (kategoriId != null && kategoriId.isNotEmpty) {
        url += "&kategori=$kategoriId";
      }
      
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          produkList = data['data'] ?? [];
        });
      } else {
        showSnackBar(data['message'] ?? "Gagal memuat produk");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> getFilteredProduk() {
    if (searchQuery.isEmpty) {
      return produkList;
    }
    return produkList.where((p) {
      String nama = p['nama_produk']?.toString().toLowerCase() ?? '';
      String sku = p['sku']?.toString().toLowerCase() ?? '';
      String query = searchQuery.toLowerCase();
      return nama.contains(query) || sku.contains(query);
    }).toList();
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

  void addToCart(Map<String, dynamic> produk) {
    int stok = 0;
    var stokValue = produk['stok'];
    if (stokValue is int) {
      stok = stokValue;
    } else if (stokValue is String) {
      stok = int.tryParse(stokValue) ?? 0;
    }
    
    int existingIndex = cartItems.indexWhere((item) => item['id'] == produk['id']);
    int currentQty = existingIndex != -1 ? (cartItems[existingIndex]['quantity'] ?? 0) : 0;
    
    if (currentQty >= stok) {
      showSnackBar("Stok tidak mencukupi! Stok tersedia: $stok");
      return;
    }
    
    setState(() {
      if (existingIndex != -1) {
        cartItems[existingIndex]['quantity'] = (cartItems[existingIndex]['quantity'] ?? 1) + 1;
      } else {
        cartItems.add({
          'id': produk['id'],
          'nama_produk': produk['nama_produk'],
          'harga_jual': _parseToDouble(produk['harga_jual']),
          'stok': produk['stok'] ?? 0,
          'quantity': 1,
          'kategori': produk['kategori'] ?? '',
        });
      }
      _hitungDiskonNominal();
    });
  }

  void removeFromCart(int index) {
    setState(() {
      cartItems.removeAt(index);
      _hitungDiskonNominal();
    });
  }

  void updateQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        cartItems.removeAt(index);
        _hitungDiskonNominal();
        return;
      }
      
      int stok = 0;
      var stokValue = cartItems[index]['stok'];
      if (stokValue is int) {
        stok = stokValue;
      } else if (stokValue is String) {
        stok = int.tryParse(stokValue) ?? 0;
      }
      
      if (newQuantity > stok) {
        showSnackBar("Stok tidak mencukupi! Maksimal: $stok");
        return;
      }
      
      cartItems[index]['quantity'] = newQuantity;
      _hitungDiskonNominal();
    });
  }

  String getPaymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash (Uang Kas)';
      case 'qris':
        return 'QRIS Merchant';
      default:
        return method;
    }
  }

  IconData getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money_rounded;
      case 'qris':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Future<void> submitPosTransaction() async {
    if (cartItems.isEmpty) {
      showSnackBar("Keranjang belanja kosong!");
      return;
    }

    if (customerController.text.trim().isEmpty) {
      showSnackBar("Masukkan nama pelanggan!");
      return;
    }

    setState(() => isSubmitting = true);

    double total = getTotalPrice();
    double diskon = diskonNominal;
    double totalAfterDiscount = getTotalAfterDiscount();

    List<Map<String, dynamic>> items = cartItems.map((item) {
      double harga = item['harga_jual'] ?? 0;
      int qty = item['quantity'] ?? 0;
      return {
        'produk_id': item['id'],
        'nama_produk': item['nama_produk'],
        'harga': harga,
        'quantity': qty,
        'subtotal': harga * qty,
      };
    }).toList();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save_pos_transaction.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": widget.sessionId,
          "outlet_id": myOutletId,
          "karyawan_id": myKaryawanId,
          "customer_name": customerController.text.trim(),
          "items": items,
          "total": total,
          "total_after_discount": totalAfterDiscount,
          "diskon_persen": diskonPersen,
          "diskon_nominal": diskon,
          "payment_method": selectedPaymentMethod,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        String methodLabel = getPaymentMethodLabel(selectedPaymentMethod);
        String diskonInfo = diskonPersen > 0 ? " (Diskon ${diskonPersen.toStringAsFixed(0)}%)" : "";
        showSnackBar("Transaksi POS berhasil! Metode: $methodLabel$diskonInfo");
        setState(() {
          cartItems.clear();
          customerController.clear();
          diskonController.clear();
          diskonPersen = 0;
          diskonNominal = 0;
          isDiskonActive = false;
        });
        await fetchProduk(kategoriId: selectedKategoriId);
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        showSnackBar(data['message'] ?? "Gagal menyimpan transaksi");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredProduk = getFilteredProduk();
    double total = getTotalPrice();
    double totalAfterDiscount = getTotalAfterDiscount();
    double diskon = diskonNominal;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: "Kembali",
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Point of Sale",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
            ),
            Text(
              outletType.toUpperCase(),
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => fetchProduk(kategoriId: selectedKategoriId),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  // Filter & Search
                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            onChanged: (value) {
                              setState(() => searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText: "Cari produk...",
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
                          child: DropdownButtonFormField<String>(
                            value: selectedKategoriId,
                            hint: const Text("Semua", style: TextStyle(fontSize: 13)),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text("Semua", style: TextStyle(fontSize: 13)),
                              ),
                              ...kategoriList.map((k) {
                                String kategoriId = k['id'].toString();
                                String kategoriNama = k['nama_kategori'].toString();
                                return DropdownMenuItem<String>(
                                  value: kategoriId,
                                  child: Text(
                                    kategoriNama,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (val) {
                              setState(() {
                                selectedKategoriId = val;
                                fetchProduk(kategoriId: val);
                              });
                            },
                            isExpanded: true,
                            dropdownColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Body: Grid Produk & Cart
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grid Produk (60%)
                        Expanded(
                          flex: 6,
                          child: Container(
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
                            child: filteredProduk.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_rounded, size: 56, color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text(
                                          outletType == 'cabang' 
                                              ? "Belum ada produk dikirim"
                                              : "Tidak ada produk",
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          outletType == 'cabang'
                                              ? "Tunggu kiriman produk dari outlet pusat"
                                              : "Silakan tambahkan produk terlebih dahulu",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 5,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1.1,
                                    ),
                                    itemCount: filteredProduk.length,
                                    itemBuilder: (context, index) {
                                      var produk = filteredProduk[index];
                                      String nama = produk['nama_produk'] ?? 'Produk';
                                      double harga = _parseToDouble(produk['harga_jual']);
                                      int stok = 0;
                                      var stokValue = produk['stok'];
                                      if (stokValue is int) {
                                        stok = stokValue;
                                      } else if (stokValue is String) {
                                        stok = int.tryParse(stokValue) ?? 0;
                                      }
                                      bool isOutOfStock = stok <= 0;

                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: isOutOfStock ? Colors.red.shade200 : Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: isOutOfStock ? null : () => addToCart(produk),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: primaryBlue.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(
                                                    Icons.shopping_bag_rounded,
                                                    color: isOutOfStock ? Colors.grey.shade400 : primaryBlue,
                                                    size: 30,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  nama,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isOutOfStock ? Colors.grey.shade400 : Colors.grey.shade900,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Rp ${_formatIdr(harga)}",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryOrange,
                                                  ),
                                                ),
                                                Text(
                                                  "Stok: $stok",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isOutOfStock ? Colors.red.shade700 : Colors.grey.shade500,
                                                    fontWeight: isOutOfStock ? FontWeight.w600 : FontWeight.w400,
                                                  ),
                                                ),
                                                if (isOutOfStock)
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 4),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.red.shade200),
                                                    ),
                                                    child: Text(
                                                      "HABIS",
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Cart (40%)
                        Container(
                          width: 380,
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
                              // Header Cart
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primaryBlue,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Keranjang",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "${cartItems.length}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (cartItems.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            cartItems.clear();
                                            diskonController.clear();
                                            diskonPersen = 0;
                                            diskonNominal = 0;
                                            isDiskonActive = false;
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ),

                              // Customer Name & Diskon
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: customerController,
                                        decoration: InputDecoration(
                                          hintText: "Nama Pelanggan",
                                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                          prefixIcon: Icon(Icons.person_outline, size: 18, color: Colors.grey.shade400),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: primaryBlue, width: 1.5),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: diskonController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: "Diskon %",
                                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                          prefixIcon: Icon(Icons.discount_rounded, size: 18, color: Colors.grey.shade400),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.green.shade700, width: 1.5),
                                          ),
                                          filled: true,
                                          fillColor: Colors.green.shade50,
                                        ),
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Metode Pembayaran
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    const Text(
                                      "Bayar:",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SegmentedButton<String>(
                                        segments: paymentMethods.map((method) {
                                          return ButtonSegment<String>(
                                            value: method,
                                            label: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  getPaymentMethodIcon(method),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  method.toUpperCase(),
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        selected: {selectedPaymentMethod},
                                        onSelectionChanged: (Set<String> newSelection) {
                                          setState(() {
                                            selectedPaymentMethod = newSelection.first;
                                          });
                                        },
                                        style: SegmentedButton.styleFrom(
                                          selectedBackgroundColor: selectedPaymentMethod == 'cash' 
                                              ? Colors.green.shade100 
                                              : const Color(0xFF7B1FA2).withOpacity(0.2),
                                          selectedForegroundColor: selectedPaymentMethod == 'cash' 
                                              ? Colors.green.shade900 
                                              : const Color(0xFF7B1FA2),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Cart Items List
                              Expanded(
                                child: cartItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Keranjang kosong",
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
                                            ),
                                            Text(
                                              "Klik produk untuk menambah",
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: cartItems.length,
                                        itemBuilder: (context, index) {
                                          var item = cartItems[index];
                                          String nama = item['nama_produk'] ?? 'Produk';
                                          double harga = item['harga_jual'] ?? 0;
                                          int qty = item['quantity'] ?? 1;
                                          double subtotal = harga * qty;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        nama,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.grey.shade900,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        "Rp ${_formatIdr(harga)}",
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: primaryOrange,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(Icons.remove_rounded, size: 16, color: Colors.grey.shade700),
                                                      onPressed: () => updateQuantity(index, qty - 1),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        '$qty',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.add_rounded, size: 16, color: primaryBlue),
                                                      onPressed: () => updateQuantity(index, qty + 1),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade400),
                                                      onPressed: () => removeFromCart(index),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  "Rp ${_formatIdr(subtotal)}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              // Total & Checkout
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Diskon Info
                                    if (isDiskonActive && diskonPersen > 0) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Diskon ${diskonPersen.toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          Text(
                                            "- Rp ${_formatIdr(diskon)}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 8, thickness: 1),
                                    ],

                                    // Total Sebelum Diskon
                                    if (isDiskonActive && diskonPersen > 0) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Subtotal",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            "Rp ${_formatIdr(total)}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.grey.shade600,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],

                                    // Total Akhir
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Total",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          "Rp ${_formatIdr(totalAfterDiscount)}",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isDiskonActive && diskonPersen > 0 
                                                ? Colors.green.shade700 
                                                : primaryOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: ElevatedButton(
                                        onPressed: isSubmitting ? null : submitPosTransaction,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: selectedPaymentMethod == 'cash' 
                                              ? primaryOrange 
                                              : const Color(0xFF7B1FA2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isSubmitting
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    getPaymentMethodIcon(selectedPaymentMethod),
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    "BAYAR ${selectedPaymentMethod.toUpperCase()}",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}