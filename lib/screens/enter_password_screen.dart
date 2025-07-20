import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart'; // Import main.dart untuk akses ke MainScreen

class EnterPasswordScreen extends StatefulWidget {
  @override
  _EnterPasswordScreenState createState() => _EnterPasswordScreenState();
}

// Gunakan SingleTickerProviderStateMixin untuk mengontrol animasi
class _EnterPasswordScreenState extends State<EnterPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _storage = FlutterSecureStorage();
  String? _errorMessage;

  // Controller untuk animasi "getar"
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller animasi
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    // Definisikan animasi "getar"
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_animationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Fungsi untuk memicu getaran
  void _triggerShakeAnimation() {
    _animationController.forward(from: 0);
  }

  void _checkPassword() async {
    final storedPassword = await _storage.read(key: 'user_password');
    if (!mounted) return;

    if (_passwordController.text == storedPassword) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MainScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
      // Jika salah, tampilkan pesan error dan getarkan form
      setState(() {
        _errorMessage = 'Kata sandi salah. Coba lagi.';
      });
      _passwordController.clear();
      _triggerShakeAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mendapatkan warna tema untuk gradien
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      // Latar belakang dengan gradien
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.grey.shade900, Colors.black]
                : [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          // AnimatedBuilder untuk menerapkan animasi getar
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                // Menggerakkan widget ke kiri dan kanan sesuai nilai animasi
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildLoginForm(theme, isDarkMode),
            ),
          ),
        ),
      ),
    );
  }

  // Widget untuk Form Login yang dibungkus dalam kartu
  Widget _buildLoginForm(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.8) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 60, color: theme.colorScheme.primary),
          SizedBox(height: 16),
          Text(
            'Selamat Datang Kembali',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Masukkan kunci untuk mengakses data Anda.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: '● ● ● ● ● ●',
              filled: true,
              fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _checkPassword(),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _checkPassword,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(
                'Buka Aplikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}