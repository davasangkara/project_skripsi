import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rekap_screen.dart';
import 'screens/pembagian_gaji_screen.dart';
import 'screens/bertanya_screen.dart';
import 'screens/setting_screen.dart';
import 'services/notification_service.dart'; // 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init(); // 
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Keuangan Anda',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SplashScreen(), // Tetap SplashScreen
    );
  }
}

// WIDGET HALAMAN UTAMA ANDA (TIDAK PERLU DIUBAH)
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    HistoryScreen(),
    RekapScreen(),
    PembagianGajiScreen(),
    BertanyaScreen(),
    SettingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: "Rekap"),
          BottomNavigationBarItem(icon: Icon(Icons.money), label: "Gaji"),
          BottomNavigationBarItem(icon: Icon(Icons.help), label: "Bertanya Ke AI"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Setting"),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
