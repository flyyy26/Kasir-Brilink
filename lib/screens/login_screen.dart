import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Base URL sesuai dengan hosting Anda
  final String baseUrl = "https://barokahsport.com/brilink";

  // Warna Brand
  final Color primaryBlue = const Color(0xFF00529C);
  final Color primaryOrange = const Color(0xFFF26A25);
  final Color primaryGreen = const Color(0xFF2E7D32);

  // List untuk menampung data dari API
  List outlets = [];
  List listKaryawan = [];

  // Variabel untuk menyimpan ID yang dipilih di Dropdown
  String? selectedOutletId;
  String? selectedKaryawanId;

  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    fetchOutlets();
  }

  // 1. Fungsi mengambil data Outlet
  Future<void> fetchOutlets() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_outlets.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          List outletData = data['data'] ?? [];
          outletData.sort((a, b) {
            int idA = int.parse(a['id'].toString());
            int idB = int.parse(b['id'].toString());
            return idA.compareTo(idB);
          });
          
          setState(() {
            outlets = outletData;
          });
        }
      }
    } catch (e) {
      showSnackBar("Gagal menyambung ke server: $e");
    }
  }

  // 2. Fungsi mengambil data Karyawan berdasarkan ID Outlet yang dipilih
  Future<void> fetchKaryawan(String outletId) async {
    setState(() {
      listKaryawan = [];
      selectedKaryawanId = null;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/get_karyawan.php?outlet_id=$outletId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            listKaryawan = data['data'];
          });
        }
      }
    } catch (e) {
      showSnackBar("Gagal mengambil data karyawan: $e");
    }
  }

  // ============ CEK SHIFT SEBELUM LOGIN ============
  Future<Map<String, dynamic>> _checkShiftStatus(int karyawanId, int outletId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_shift_start.php?karyawan_id=$karyawanId&outlet_id=$outletId"),
      );
      return json.decode(response.body);
    } catch (e) {
      return {
        "status": false,
        "message": "Gagal mengecek shift: $e"
      };
    }
  }
  // =================================================

  // 3. Fungsi untuk mengirim data Login (POST) ke server
  Future<void> login() async {
    if (selectedOutletId == null || selectedKaryawanId == null || passwordController.text.isEmpty) {
      showSnackBar("Silakan lengkapi semua data login");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "karyawan_id": int.tryParse(selectedKaryawanId!) ?? 0,
          "password": passwordController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        int karyawanId = int.tryParse(data['user_data']['id'].toString()) ?? 0;
        int outletId = int.tryParse(data['user_data']['outlet_id'].toString()) ?? 0;
        
        // ============ CEK SHIFT START ============
        final shiftData = await _checkShiftStatus(karyawanId, outletId);
        
        if (shiftData['status'] == true) {
          // ============ CEK APAKAH SHIFT CLOSED ============
          bool isShiftClosed = shiftData['is_shift_closed'] == true || shiftData['is_shift_closed'] == 1 || shiftData['is_shift_closed'] == '1';
          bool hasActiveShift = shiftData['has_active_shift'] == true || shiftData['has_active_shift'] == 1 || shiftData['has_active_shift'] == '1';
          
          // Jika shift sudah closed, TOLAK LOGIN
          if (isShiftClosed && !hasActiveShift) {
            setState(() {
              isLoading = false;
            });
            
            // Tampilkan dialog bahwa shift sudah closed
            if (!mounted) return;
            await showDialog(
              context: context,
              barrierDismissible: false,
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
                      child: const Icon(Icons.lock_clock_rounded, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Shift Telah Berakhir",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Shift karyawan ini sudah selesai (closed).",
                      style: TextStyle(fontSize: 14),
                    ),
                    if (shiftData['shift_end'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: Colors.grey.shade600, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "Shift selesai: ${shiftData['shift_end']}",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00529C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "OK",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
            return;
          }
          // =======================================================
          
          // Parsing nilai integer dengan aman agar tidak error String subtype
          int shiftId = int.tryParse(shiftData['shift_id']?.toString() ?? '0') ?? 0;
          int sessionId = int.tryParse(shiftData['session_id']?.toString() ?? '0') ?? 0;

          // ============ SIMPAN DATA LOGIN & SHIFT ============
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_login', true);
          await prefs.setInt('karyawan_id', karyawanId);
          await prefs.setString('nama_karyawan', data['user_data']['nama_karyawan']?.toString() ?? '');
          await prefs.setInt('outlet_id', outletId);

          await prefs.setString('shift_start', shiftData['shift_start']?.toString() ?? DateTime.now().toIso8601String());
          await prefs.setInt('shift_id', shiftId);
          await prefs.setInt('session_id', sessionId);
          await prefs.setString('shift_status', hasActiveShift ? 'active' : 'inactive');

          showSnackBar("Login Berhasil!");
          
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        } else {
          showSnackBar(shiftData['message'] ?? "Gagal memverifikasi shift");
        }
      } else {
        showSnackBar(data['message'] ?? "Login gagal");
      }
    } catch (e) {
      showSnackBar("Terjadi kesalahan: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.manrope(
        color: Colors.grey.shade600,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null 
          ? Icon(prefixIcon, color: Colors.grey.shade500, size: 20)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Deteksi apakah layar lebar (desktop)
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final double maxWidth = isDesktop ? 450 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade50,
              Colors.white,
              primaryBlue.withOpacity(0.05),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 20,
              vertical: 24,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: isDesktop ? 620 : double.infinity,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo & Title
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryBlue,
                            primaryBlue.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.account_balance_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      "BRILink",
                      style: GoogleFonts.manrope(
                        fontSize: isDesktop ? 32 : 28,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    Text(
                      "Sistem Kasir",
                      style: GoogleFonts.manrope(
                        fontSize: isDesktop ? 16 : 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryOrange, primaryOrange.withOpacity(0.5)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(
                        isDesktop ? 32 : 24,
                      ),
                      child: Column(
                        children: [
                          // Dropdown Outlet
                          DropdownButtonFormField<String>(
                            decoration: _buildInputDecoration(
                              labelText: "Pilih Outlet",
                              prefixIcon: Icons.storefront_rounded,
                            ),
                            value: selectedOutletId,
                            isExpanded: true,
                            hint: Text(
                              outlets.isEmpty ? "Memuat data..." : "Pilih outlet",
                              style: GoogleFonts.manrope(
                                color: outlets.isEmpty ? Colors.grey.shade400 : Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            style: GoogleFonts.manrope(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            items: outlets.isEmpty 
                                ? [] 
                                : outlets.map((outlet) {
                                    return DropdownMenuItem<String>(
                                      value: outlet['id'].toString(),
                                      child: Text(
                                        outlet['nama_outlet'] ?? '',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            onChanged: outlets.isEmpty 
                                ? null 
                                : (value) {
                                    setState(() {
                                      selectedOutletId = value;
                                    });
                                    if (value != null) {
                                      fetchKaryawan(value); 
                                    }
                                  },
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade500,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dropdown Karyawan
                          DropdownButtonFormField<String>(
                            decoration: _buildInputDecoration(
                              labelText: "Pilih Karyawan",
                              prefixIcon: Icons.person_rounded,
                            ),
                            value: selectedKaryawanId,
                            isExpanded: true,
                            hint: Text(
                              selectedOutletId == null 
                                  ? "Pilih outlet terlebih dahulu" 
                                  : listKaryawan.isEmpty 
                                      ? "Memuat data..." 
                                      : "Pilih karyawan",
                              style: GoogleFonts.manrope(
                                color: selectedOutletId == null 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            style: GoogleFonts.manrope(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            items: listKaryawan.isEmpty 
                                ? [] 
                                : listKaryawan.map((karyawan) {
                                    return DropdownMenuItem<String>(
                                      value: karyawan['id'].toString(),
                                      child: Text(
                                        karyawan['nama_karyawan'] ?? '',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            onChanged: listKaryawan.isEmpty || selectedOutletId == null
                                ? null 
                                : (value) {
                                    setState(() {
                                      selectedKaryawanId = value;
                                    });
                                  },
                            dropdownColor: Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade500,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextField(
                            controller: passwordController,
                            obscureText: !isPasswordVisible,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              labelText: "Password",
                              prefixIcon: Icons.lock_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isPasswordVisible 
                                      ? Icons.visibility_rounded 
                                      : Icons.visibility_off_rounded,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isPasswordVisible = !isPasswordVisible;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                              onPressed: isLoading ? null : login,
                              child: isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "MASUK",
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "© 2026 HM Barokah BRILink",
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: primaryOrange,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}