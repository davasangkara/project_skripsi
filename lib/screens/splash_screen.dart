import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'create_password_screen.dart';
import 'enter_password_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

// Tambahkan "with SingleTickerProviderStateMixin" untuk mengontrol animasi
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _storage = FlutterSecureStorage();

  // Controller dan variabel untuk animasi
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Inisialisasi AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Durasi total animasi
    );

    // Definisi animasi untuk logo (Scale & Fade)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Definisi animasi untuk teks (Slide & Fade)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 2), // Mulai dari bawah
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );

    // Mulai animasi
    _controller.forward();

    // Jalankan logika navigasi setelah jeda
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    // Selalu dispose controller untuk menghindari memory leak
    _controller.dispose();
    super.dispose();
  }

  void _checkPasswordStatus() async {
    // Total durasi splash screen (animasi + jeda tambahan)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    String? password = await _storage.read(key: 'user_password');

    // Gunakan transisi halaman yang lebih halus (Fade)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return (password == null || password.isEmpty)
              ? CreatePasswordScreen()
              : EnterPasswordScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Latar belakang gradien yang sama
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // Gunakan Stack untuk menumpuk elemen, termasuk elemen di bawah
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo yang dianimasikan
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Teks yang dianimasikan
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: const Text(
                        'Manajer Keuangan',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Elemen tambahan di bagian bawah
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation, // Menggunakan fade yang sama
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Memuat Aplikasi Anda...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
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
    );
  }
}
