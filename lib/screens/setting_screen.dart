// lib/screens/setting_screen.dart
// VERSI FINAL: Reset password tidak menghapus file backup, sekarang juga mendukung hapus akun permanen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/shared_prefs_service.dart';
import '../services/theme_provider.dart';
import '../services/backup_service.dart';
import '../models/transaction.dart';

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final SharedPrefsService _prefsService = SharedPrefsService();
  final BackupService _backupService = BackupService();
  final _secureStorage = FlutterSecureStorage();

  List<String> _accounts = [];
  String _currentAccount = "Guest";

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    List<String> accounts = await _prefsService.getAccounts();
    String current = await _prefsService.getCurrentAccount();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _currentAccount = current;
      });
    }
  }

  Future<void> _switchAccount(String newAccount) async {
    await _prefsService.setCurrentAccount(newAccount);
    if (mounted) {
      setState(() {
        _currentAccount = newAccount;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Beralih ke akun: $newAccount")),
    );
  }

  void _addAccount() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Tambah Akun Baru"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Nama akun"),
        ),
        actions: [
          TextButton(
            child: Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Tambah"),
            onPressed: () async {
              String newAccountName = controller.text.trim();
              if (newAccountName.isNotEmpty && !_accounts.contains(newAccountName)) {
                await _prefsService.addAccount(newAccountName);
                _loadAccounts();
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackup() async {
    List<Transaction> currentTransactions = await _prefsService.getTransactionsForAccount(_currentAccount);

    if (currentTransactions.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak ada catatan untuk di-backup.")),
      );
      return;
    }

    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String backupName = "backup_${_currentAccount}_$timestamp";

    bool success = await _backupService.createBackup(_currentAccount, backupName, currentTransactions);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backup '$backupName' berhasil!")),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backup gagal.")),
      );
    }
  }

  Future<void> _showRestoreDialog() async {
    List<String> availableBackups = await _backupService.getAvailableBackups(_currentAccount);

    if (availableBackups.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak ada data backup untuk akun $_currentAccount.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Pilih Data untuk Restore"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableBackups.length,
              itemBuilder: (BuildContext context, int index) {
                String backupName = availableBackups[index];
                String displayBackupName = backupName
                    .replaceFirst("backup_${_currentAccount}_", "")
                    .replaceFirst("_", " jam ");
                return ListTile(
                  title: Text(displayBackupName),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await _handleRestore(backupName);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Batal"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRestore(String backupName) async {
    List<Transaction>? restoredTransactions = await _backupService.restoreFromBackup(_currentAccount, backupName);

    if (restoredTransactions != null) {
      await _prefsService.saveTransactionsForAccount(_currentAccount, restoredTransactions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Restore dari '$backupName' berhasil!")),
        );
      }
      _loadAccounts();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restore gagal.")),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Konfirmasi Hapus"),
          content: Text("Hapus semua catatan untuk akun '$_currentAccount'?"),
          actions: [
            TextButton(
              child: Text("Batal"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text("Hapus", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await _prefsService.clearTransactionsForAccount(_currentAccount);
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Catatan untuk '$_currentAccount' telah dihapus.")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.delete_forever_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text("Hapus Akun Permanen"),
          ]),
          content: Text(
            "Akun '${_currentAccount}' akan dihapus PERMANEN.\n\n"
            "• Semua data transaksi akan dihapus\n"
            "• Backup TIDAK akan dihapus\n\n"
            "Lanjutkan?",
          ),
          actions: [
            TextButton(
              child: Text("Batal"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Hapus Akun"),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteCurrentAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCurrentAccount() async {
    if (_currentAccount == 'Guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Akun 'Guest' tidak bisa dihapus.")),
      );
      return;
    }

    await _prefsService.deleteAccount(_currentAccount);
    await _prefsService.clearTransactionsForAccount(_currentAccount);

    List<String> updatedAccounts = await _prefsService.getAccounts();
    String newCurrent = updatedAccounts.contains("Guest")
        ? "Guest"
        : (updatedAccounts.isNotEmpty ? updatedAccounts.first : "Guest");

    await _prefsService.setCurrentAccount(newCurrent);

    if (mounted) {
      setState(() {
        _currentAccount = newCurrent;
        _accounts = updatedAccounts;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Akun telah dihapus.")),
      );
    }
  }

  void _showAccountSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pilih Akun"),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _accounts.length,
            itemBuilder: (BuildContext context, int index) {
              String account = _accounts[index];
              return ListTile(
                title: Text(account),
                selected: account == _currentAccount,
                onTap: () {
                  Navigator.pop(context);
                  if (account != _currentAccount) {
                    _switchAccount(account);
                  }
                },
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text("Tambah Akun Baru"),
            onPressed: () {
              Navigator.pop(context);
              _addAccount();
            },
          ),
        ],
      ),
    );
  }

  void _showResetAppConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Reset Aplikasi")
          ]),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Anda akan mereset data aplikasi.", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text(
                  "• Password aplikasi akan dihapus.\n"
                  "• SEMUA data akun dan transaksi aktif akan hilang.\n\n"
                  "Data backup Anda TIDAK AKAN DIHAPUS.\n\n"
                  "Anda yakin?",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Batal"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: Text("Ya, Reset Sekarang"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _handleResetApp();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleResetApp() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Mereset aplikasi...")
            ]),
          ),
        ),
      );

      await _secureStorage.delete(key: 'user_password');
      await _prefsService.clearAllData();

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Aplikasi berhasil di-reset. Data backup Anda aman.")),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      SystemNavigator.pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal mereset aplikasi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text("Pengaturan")),
      body: ListView(
        padding: EdgeInsets.all(8.0),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.primary, size: 30),
              title: Text("Akun Saat Ini"),
              subtitle: Text(_currentAccount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              trailing: Icon(Icons.arrow_drop_down_circle_outlined),
              onTap: _showAccountSelectionDialog,
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.person_add_alt_1_outlined, color: Colors.green, size: 30),
              title: Text("Tambah Akun Baru"),
              onTap: _addAccount,
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: SwitchListTile(
              title: Text("Tema Gelap"),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(),
              secondary: Icon(Icons.brightness_6_outlined, color: themeProvider.isDarkMode ? Colors.yellowAccent : Colors.blueGrey, size: 30),
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.backup_outlined, color: Colors.blueAccent, size: 30),
              title: Text("Backup Catatan Akun Ini"),
              subtitle: Text("Menyimpan catatan dari akun '${_currentAccount}'"),
              onTap: _handleBackup,
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.restore_page_outlined, color: Colors.teal, size: 30),
              title: Text("Restore Catatan ke Akun Ini"),
              subtitle: Text("Memulihkan catatan ke akun '${_currentAccount}'"),
              onTap: _showRestoreDialog,
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 30),
              title: Text("Hapus Semua Catatan Akun Ini"),
              subtitle: Text("Menghapus semua catatan dari akun '${_currentAccount}'"),
              onTap: () => _showDeleteConfirmationDialog(context),
            ),
          ),
          Divider(height: 16),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Colors.red, size: 30),
              title: Text("Hapus Akun Ini Secara Permanen"),
              subtitle: Text("Menghapus akun dan seluruh transaksinya"),
              onTap: _showDeleteAccountDialog,
            ),
          ),
          Divider(height: 24, thickness: 1, indent: 20, endIndent: 20),
          Card(
            elevation: 2,
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              title: Text("Lupa Password / Reset Aplikasi", style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
              subtitle: Text("Hapus data aktif, pertahankan backup"),
              onTap: _showResetAppConfirmationDialog,
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
