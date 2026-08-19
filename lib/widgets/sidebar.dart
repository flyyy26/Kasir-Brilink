import 'package:flutter/material.dart';
import 'package:kasir_brilink/screens/GantiShiftScreen.dart';
import 'package:kasir_brilink/screens/laporan_mutasi_rekening_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/login_screen.dart';
import '../screens/buka_kas_screen.dart';
import '../screens/tutup_kas_screen.dart';
import '../screens/saldo_screen.dart';
import '../screens/FeeBrilinkDailyScreen.dart';
import '../screens/AllLogTransaksiScreen.dart';
import '../screens/ProdukScreen.dart';
import '../screens/KirimProdukScreen.dart';
import '../screens/BrangkasScreen.dart';

class Sidebar extends StatefulWidget {
  final String sessionStatus;
  final int? sessionId;
  final VoidCallback? onRefresh;

  const Sidebar({
    super.key,
    required this.sessionStatus,
    this.sessionId,
    this.onRefresh,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final String baseUrl = "https://barokahsport.com/brilink";

  String namaKaryawan = "Kasir";
  String namaOutlet = "Outlet BRILink";
  String tipeOutlet = "cabang";
  int myOutletId = 1;
  
  bool hasProduk = false;
  bool isLoadingProduk = false;
  
  // ============ NOTIFIKASI PRODUK MASUK ============
  int pendingKirimCount = 0;
  bool isLoadingNotif = false;
  // ================================================

  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      namaKaryawan = prefs.getString('nama_karyawan') ?? "Kasir";
      namaOutlet = prefs.getString('nama_outlet') ?? "Outlet BRILink";
      tipeOutlet = prefs.getString('tipe_outlet') ?? "cabang";
      myOutletId = prefs.getInt('outlet_id') ?? 1;
    });
    
    if (tipeOutlet == 'cabang') {
      await cekProdukCabang();
      await cekNotifikasiProdukMasuk();
    } else {
      setState(() => hasProduk = true);
    }
  }

  // ============ FUNGSI CEK PRODUK DI OUTLET CABANG ============
  Future<void> cekProdukCabang() async {
    setState(() => isLoadingProduk = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_produk.php?outlet_id=$myOutletId"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> produk = data['data'] ?? [];
        setState(() {
          hasProduk = produk.isNotEmpty;
        });
      }
    } catch (e) {
      print("Gagal cek produk cabang: $e");
      setState(() => hasProduk = false);
    } finally {
      setState(() => isLoadingProduk = false);
    }
  }
  // ============================================================

  // ============ FUNGSI CEK NOTIFIKASI PRODUK MASUK ============
  Future<void> cekNotifikasiProdukMasuk() async {
    if (tipeOutlet != 'cabang') return;
    
    setState(() => isLoadingNotif = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_kirim_produk.php?outlet_id=$myOutletId&status=dikirim"),
      );
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['status'] == true) {
        List<dynamic> list = data['data'] ?? [];
        setState(() {
          pendingKirimCount = list.length;
        });
      }
    } catch (e) {
      print("Gagal cek notifikasi produk: $e");
      setState(() => pendingKirimCount = 0);
    } finally {
      setState(() => isLoadingNotif = false);
    }
  }
  // ============================================================

  // ============ LOGOUT BIASA ============
  Future<void> actionLogout() async {
    // Tampilkan dialog konfirmasi logout
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
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Konfirmasi Logout",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah Anda yakin ingin logout?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Shift yang sedang aktif akan tetap aktif. Anda bisa login kembali nanti.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "BATAL",
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
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
              "LOGOUT",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Logout biasa - hanya clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
  // =====================================

  Widget _buildStatusChip() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (widget.sessionStatus == "open") {
      statusText = "AKTIF";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (widget.sessionStatus == "closed") {
      statusText = "TERTUTUP";
      statusColor = Colors.grey;
      statusIcon = Icons.lock_rounded;
    } else {
      statusText = "BELUM BUKA";
      statusColor = primaryOrange;
      statusIcon = Icons.warning_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool isEnabled = true,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isEnabled
              ? (iconColor ?? primaryBlue).withOpacity(0.1)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isEnabled
              ? (iconColor ?? primaryBlue)
              : Colors.grey.shade400,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isEnabled ? Colors.grey.shade900 : Colors.grey.shade400,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
          : null,
      trailing: isEnabled
          ? Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade400, size: 20)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                "LOCKED",
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5),
              ),
            ),
      onTap: isEnabled ? onTap : null,
      enabled: isEnabled,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showProdukMenu = false;
    
    if (tipeOutlet == 'pusat') {
      showProdukMenu = true;
    } else if (tipeOutlet == 'cabang' && hasProduk) {
      showProdukMenu = true;
    }

    String kirimProdukTitle = tipeOutlet == 'pusat' ? 'Kirim Produk' : 'Terima Produk';
    IconData kirimProdukIcon = tipeOutlet == 'pusat' ? Icons.local_shipping_rounded : Icons.inbox_rounded;
    
    Widget? badgeWidget;
    if (tipeOutlet == 'cabang' && pendingKirimCount > 0) {
      badgeWidget = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            pendingKirimCount > 9 ? '9+' : pendingKirimCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header Profile Sidebar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30)),
                        child: const CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person,
                              size: 32, color: Color(0xFF00529C)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              namaKaryawan,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              namaOutlet,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            _buildStatusChip(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.white.withOpacity(0.7), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "Sesi: ${widget.sessionStatus == "open" ? "Berjalan" : widget.sessionStatus == "closed" ? "Ditutup" : "Belum dibuka"}",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_rounded,
                    title: "Dashboard",
                    iconColor: primaryBlue,
                    onTap: () => Navigator.pop(context),
                  ),

                  const Divider(height: 4, thickness: 1, indent: 16, endIndent: 16),

                  _buildMenuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: "Buka Kas / Kelola Saldo",
                    iconColor: primaryOrange,
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BukaKasScreen(
                            onSessionOpened: widget.onRefresh,
                          ),
                        ),
                      );
                      if (widget.onRefresh != null) {
                        widget.onRefresh!();
                      }
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.lock_clock_rounded,
                    title: "Tutup Sesi Kas Harian",
                    iconColor: Colors.red.shade700,
                    isEnabled: widget.sessionStatus == "open",
                    onTap: () async {
                      Navigator.pop(context);
                      if (widget.sessionId == null || widget.sessionId == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                "Sesi belum aktif atau sedang disinkronkan"),
                            backgroundColor: primaryOrange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                        return;
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TutupKasScreen(sessionId: widget.sessionId!),
                        ),
                      );
                      if (result == true && widget.onRefresh != null) {
                        widget.onRefresh!();
                      }
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.account_balance_rounded,
                    title: "Informasi Saldo",
                    iconColor: Colors.teal.shade700,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SaldoScreen()),
                      );
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.assessment_rounded,
                    title: "Laporan Mutasi Rekening",
                    iconColor: const Color.fromARGB(255, 179, 0, 179),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LaporanMutasiRekeningScreen()),
                      );
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.monetization_on_rounded,
                    title: "Kredit Merchant",
                    iconColor: Colors.green.shade700,
                    isEnabled: widget.sessionStatus == "open",
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeeBrilinkHarianScreen(
                            sessionId: widget.sessionId ?? 0,
                          ),
                        ),
                      );
                      if (result == true && widget.onRefresh != null) {
                        widget.onRefresh!();
                      }
                    },
                  ),

                  if (tipeOutlet == 'pusat') ...[
                    _buildMenuItem(
                      icon: Icons.lock_rounded,
                      title: "Brangkas",
                      iconColor: Colors.amber.shade700,
                      onTap: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrangkasScreen(
                              sessionId: widget.sessionId,
                            ),
                          ),
                        );

                        if (result == true && widget.onRefresh != null) {
                          widget.onRefresh!();
                        }
                      },
                    ),
                  ],

                  const Divider(height: 4, thickness: 1, indent: 16, endIndent: 16),

                  if (showProdukMenu) ...[
                    _buildMenuItem(
                      icon: Icons.inventory_2_rounded,
                      title: "Data Produk",
                      iconColor: Colors.amber.shade700,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) => const ProdukScreen()));
                      },
                    ),
                  ] else if (tipeOutlet == 'cabang' && !isLoadingProduk) ...[
                    _buildMenuItem(
                      icon: Icons.inventory_2_rounded,
                      title: "Data Produk",
                      iconColor: Colors.grey.shade400,
                      isEnabled: false,
                      subtitle: "Belum ada produk",
                      onTap: () {},
                    ),
                  ],

                  _buildMenuItem(
                    icon: kirimProdukIcon,
                    title: kirimProdukTitle,
                    iconColor: tipeOutlet == 'pusat' ? Colors.brown.shade700 : Colors.green.shade700,
                    onTap: () {
                      Navigator.pop(context);
                      if (tipeOutlet == 'cabang') {
                        setState(() {
                          pendingKirimCount = 0;
                        });
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KirimProdukScreen(),
                        ),
                      ).then((_) {
                        if (tipeOutlet == 'cabang') {
                          cekNotifikasiProdukMasuk();
                        }
                      });
                    },
                    trailing: badgeWidget,
                  ),

                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: "Log Semua Transaksi",
                    iconColor: Colors.purple.shade700,
                    isEnabled: true,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllLogTransaksiScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 4, thickness: 1, indent: 16, endIndent: 16),

                  _buildMenuItem(
                    icon: Icons.swap_horiz_rounded,
                    title: "Ganti Shift",
                    iconColor: Colors.orange.shade700,
                    isEnabled: widget.sessionStatus == "open",
                    onTap: () async {
                      Navigator.pop(context);
                      if (widget.sessionId == null || widget.sessionId == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Sesi belum aktif"),
                            backgroundColor: primaryOrange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GantiShiftScreen(
                            sessionId: widget.sessionId!, karyawanName: '',
                          ),
                        ),
                      );
                      if (result == true) {
                        if (widget.onRefresh != null) {
                          widget.onRefresh!();
                        }
                      }
                    },
                  ),

                  const Divider(height: 4, thickness: 1, indent: 16, endIndent: 16),

                  // ============ LOGOUT BIASA ============
                  _buildMenuItem(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    iconColor: Colors.red.shade700,
                    onTap: actionLogout,
                  ),
                  // =======================================
                ],
              ),
            ),

            // Footer Version Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: primaryBlue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text("BRILink v1.0",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: primaryOrange,
                          borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}