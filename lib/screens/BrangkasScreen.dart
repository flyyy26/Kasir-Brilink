import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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

class BrangkasScreen extends StatefulWidget {
  final int? sessionId;

  const BrangkasScreen({super.key, this.sessionId});

  @override
  State<BrangkasScreen> createState() => _BrangkasScreenState();
}

class _BrangkasScreenState extends State<BrangkasScreen> {
  final String baseUrl = "https://barokahsport.com/brilink";
  
  int myOutletId = 1;
  int? myKaryawanId;
  
  double saldoBrangkas = 0;
  List<dynamic> riwayatHariIni = [];
  
  bool isLoading = false;
  bool isSaving = false;
  bool _isDataChanged = false;
  
  // Form Controllers
  final TextEditingController nominalController = TextEditingController();
  final TextEditingController keteranganController = TextEditingController();
  
  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    nominalController.dispose();
    keteranganController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myOutletId = prefs.getInt('outlet_id') ?? 1;
      myKaryawanId = prefs.getInt('karyawan_id');
    });
    await fetchBrangkas();
    await fetchRiwayatHariIni();
  }

  Future<void> fetchBrangkas() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_brangkas.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          saldoBrangkas = double.tryParse(data['data']['saldo']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (e) {
      print("Error fetch brangkas: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ============ AMBIL RIWAYAT HARI INI SAJA ============
  Future<void> fetchRiwayatHariIni() async {
    try {
      String tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await http.get(
        Uri.parse("$baseUrl/get_brangkas_daily_detail.php?outlet_id=$myOutletId&tanggal=$tanggal"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          riwayatHariIni = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetch riwayat: $e");
    }
  }

  // ============ FUNGSI TAMBAH SALDO BRANGKAS ============
  Future<void> tambahBrangkas(BuildContext dialogContext) async {
    String nominalText = nominalController.text.replaceAll('.', '').replaceAll(',', '');
    double nominal = double.tryParse(nominalText) ?? 0;
    
    if (nominal <= 0 || nominalController.text.isEmpty) {
      showSnackBar("Masukkan nominal!");
      return;
    }

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/save_brangkas.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "outlet_id": myOutletId,
          "jenis": "masuk",
          "nominal": nominal,
          "keterangan": keteranganController.text.trim(),
          "karyawan_id": myKaryawanId,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Saldo brangkas berhasil ditambahkan!");
        nominalController.clear();
        keteranganController.clear();
        if (!mounted) return;
        Navigator.pop(dialogContext);
        await fetchBrangkas();
        await fetchRiwayatHariIni();
        setState(() => _isDataChanged = true);
      } else {
        showSnackBar(data['message'] ?? "Gagal menambah saldo");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ============ FUNGSI TRANSFER KE KAS ============
  Future<void> transferToKas(BuildContext dialogContext) async {
    if (widget.sessionId == null) {
      showSnackBar("Sesi kas tidak aktif! Buka kas terlebih dahulu.");
      return;
    }

    String nominalText = nominalController.text.replaceAll('.', '').replaceAll(',', '');
    double nominal = double.tryParse(nominalText) ?? 0;
    
    if (nominal <= 0 || nominalController.text.isEmpty) {
      showSnackBar("Masukkan nominal!");
      return;
    }

    if (nominal > saldoBrangkas) {
      showSnackBar("Saldo brangkas tidak cukup! Saldo: Rp ${_formatIdr(saldoBrangkas)}");
      return;
    }

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/transfer_brangkas_to_kas.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "outlet_id": myOutletId,
          "session_id": widget.sessionId,
          "nominal": nominal,
          "keterangan": keteranganController.text.trim(),
          "karyawan_id": myKaryawanId,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        showSnackBar(data['message'] ?? "Transfer ke kas berhasil!");
        nominalController.clear();
        keteranganController.clear();
        if (!mounted) return;
        Navigator.pop(dialogContext);
        await fetchBrangkas();
        await fetchRiwayatHariIni();
        setState(() => _isDataChanged = true);
      } else {
        showSnackBar(data['message'] ?? "Gagal transfer");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      setState(() => isSaving = false);
    }
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

  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // ============ DIALOG UNTUK TAMBAH BRANGKAS ============
  void _showTambahBrangkasDialog() {
    nominalController.clear();
    keteranganController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_circle_outline_rounded, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Text("Tambah Saldo Brangkas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nominalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: "Nominal",
                    prefixText: "Rp ",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keteranganController,
                  decoration: InputDecoration(
                    labelText: "Keterangan (opsional)",
                    hintText: "Contoh: Setoran harian",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isSaving ? null : () => tambahBrangkas(dialogContext),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text("Tambah", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ============ DIALOG UNTUK TRANSFER KE KAS ============
  void _showTransferKeKasDialog() {
    nominalController.clear();
    keteranganController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_forward_rounded, color: primaryOrange, size: 24),
              ),
              const SizedBox(width: 12),
              const Text("Transfer ke Kas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nominalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: "Nominal Transfer",
                    prefixText: "Rp ",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keteranganController,
                  decoration: InputDecoration(
                    labelText: "Keterangan (opsional)",
                    hintText: "Contoh: Modal tambahan kasir",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "⚠️ Saldo brangkas akan berkurang dan saldo kas laci akan bertambah.",
                  style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Batal"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isSaving ? null : () => transferToKas(dialogContext),
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              label: const Text("Transfer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSessionActive = widget.sessionId != null;
    
    // Hitung total hari ini
    double totalMasukHariIni = 0;
    double totalKeluarHariIni = 0;
    for (var item in riwayatHariIni) {
      if (item['jenis'] == 'masuk') {
        totalMasukHariIni += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
      } else {
        totalKeluarHariIni += double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, _isDataChanged),
        ),
        title: const Text(
          "Brangkas",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
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
              fetchBrangkas();
              fetchRiwayatHariIni();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // Saldo Brangkas
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Saldo Brangkas",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Rp ${_formatIdr(saldoBrangkas)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Outlet Pusat",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ringkasan Hari Ini
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hari Ini",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Masuk",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      "Rp ${_formatIdr(totalMasukHariIni)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Keluar",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      "Rp ${_formatIdr(totalKeluarHariIni)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
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
                      const SizedBox(height: 12),

                      // Tombol Aksi
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _showTambahBrangkasDialog,
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                                label: const Text("Tambah Saldo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSessionActive ? primaryOrange : Colors.grey.shade300,
                                  foregroundColor: isSessionActive ? Colors.white : Colors.grey.shade500,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: isSessionActive ? _showTransferKeKasDialog : null,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text("Transfer ke Kas", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Riwayat Hari Ini
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
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.history_rounded,
                                      size: 18,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Riwayat Hari Ini",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${riwayatHariIni.length} transaksi",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, thickness: 1),
                              
                              Expanded(
                                child: riwayatHariIni.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                                            SizedBox(height: 12),
                                            Text(
                                              "Belum ada aktivitas hari ini",
                                              style: TextStyle(color: Colors.grey, fontSize: 14),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "Tambahkan saldo atau transfer ke kas",
                                              style: TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: riwayatHariIni.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          var log = riwayatHariIni[index];
                                          String jenis = log['jenis'] ?? 'masuk';
                                          double nominal = double.tryParse(log['nominal']?.toString() ?? '0') ?? 0;
                                          double saldoSebelum = double.tryParse(log['saldo_sebelum']?.toString() ?? '0') ?? 0;
                                          double saldoSesudah = double.tryParse(log['saldo_sesudah']?.toString() ?? '0') ?? 0;
                                          String keterangan = log['keterangan'] ?? '';
                                          String namaKaryawan = log['nama_karyawan'] ?? '';
                                          String createdAt = log['created_at'] ?? '';
                                          
                                          bool isMasuk = jenis == 'masuk';
                                          
                                          String label = isMasuk ? "TAMBAH" : "TRANSFER KE KAS";
                                          Color labelColor = isMasuk ? Colors.green.shade700 : primaryOrange;
                                          Color bgColor = isMasuk ? Colors.green.shade50 : primaryOrange.withOpacity(0.1);
                                          
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: bgColor,
                                              child: Icon(
                                                isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                                                color: labelColor,
                                                size: 20,
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: labelColor,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  "Rp ${_formatIdr(nominal)}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: labelColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (keterangan.isNotEmpty)
                                                  Text(
                                                    keterangan,
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "Saldo: Rp ${_formatIdr(saldoSebelum)} → Rp ${_formatIdr(saldoSesudah)}",
                                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    if (namaKaryawan.isNotEmpty)
                                                      Text(
                                                        "Oleh: $namaKaryawan",
                                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                      ),
                                                  ],
                                                ),
                                                Text(
                                                  _formatDate(createdAt),
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                                ),
                                              ],
                                            ),
                                            dense: true,
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
              ),
            ),
    );
  }
}