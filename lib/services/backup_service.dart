// lib/services/backup_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart'; // Pastikan path ini benar

class BackupService {
  // Prefix untuk membedakan data backup di SharedPreferences
  static String backupKeyPrefix(String accountName, String backupName) => "bkp_${accountName}_${backupName}";
  static const String _backupIndexKeyPrefix = "bkp_idx_";

  // Membuat backup baru
  Future<bool> createBackup(String accountName, String backupName, List<Transaction> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String key = backupKeyPrefix(accountName, backupName);
      List<String> jsonList = transactions.map((tx) => jsonEncode(tx.toJson())).toList();
      await prefs.setStringList(key, jsonList);

      String indexKey = _backupIndexKeyPrefix + accountName;
      List<String> backupNames = prefs.getStringList(indexKey) ?? [];
      if (!backupNames.contains(backupName)) {
        backupNames.add(backupName);
        await prefs.setStringList(indexKey, backupNames);
      }
      return true;
    } catch (e) {
      print("Error creating backup: $e");
      return false;
    }
  }

  // Mendapatkan daftar nama backup yang tersedia untuk sebuah akun
  Future<List<String>> getAvailableBackups(String accountName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String indexKey = _backupIndexKeyPrefix + accountName;
      List<String> backupNames = prefs.getStringList(indexKey) ?? [];
      backupNames.sort((a, b) => b.compareTo(a));
      return backupNames;
    } catch (e) {
      print("Error getting available backups: $e");
      return [];
    }
  }

  // Merestore transaksi dari nama backup yang dipilih untuk sebuah akun
  Future<List<Transaction>?> restoreFromBackup(String accountName, String backupName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String key = backupKeyPrefix(accountName, backupName);
      List<String>? jsonList = prefs.getStringList(key);

      if (jsonList == null) return null;
      return jsonList.map((tx) => Transaction.fromJson(jsonDecode(tx))).toList();
    } catch (e) {
      print("Error restoring from backup: $e");
      return null;
    }
  }

  // (Opsional) Fungsi untuk menghapus backup tertentu jika diperlukan
  Future<void> deleteBackup(String accountName, String backupName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String key = backupKeyPrefix(accountName, backupName);
      await prefs.remove(key);

      String indexKey = _backupIndexKeyPrefix + accountName;
      List<String> backupNames = prefs.getStringList(indexKey) ?? [];
      backupNames.remove(backupName);
      await prefs.setStringList(indexKey, backupNames);
    } catch (e) {
      print("Error deleting backup: $e");
    }
  }
}