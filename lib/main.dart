import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definisikan tema dasar
    final ThemeData base = ThemeData.light();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kasir BRILink',
      // Terapkan font ke seluruh tema aplikasi
      theme: base.copyWith(
        textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
      ),
      home: SplashScreen(),
    );
  }
}