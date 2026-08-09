import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; 
import 'home_screen.dart';  

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    initApp();
  }

  Future<void> initApp() async {
    // Mengambil data storage tanpa penundaan tambahan
    final prefs = await SharedPreferences.getInstance();
    bool isLogin = prefs.getBool('is_login') ?? false;

    if (!mounted) return;

    // Navigasi dieksekusi segera setelah pengecekan selesai
    if (isLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white, // Sesuaikan warna background kasir Anda
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 25),
            // Gunakan ukuran indicator yang agak kecil agar lebih rapi
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}