import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart'; 

class SharedPrefsService {
  static const String _accountsKey = "accounts_list_v1";
  static const String _currentAccountKey = "current_account_v1";
  static const String _transactionMasterPrefix = "transactions_for_";
  static String transactionKeyPrefix(String account) =>
      "${_transactionMasterPrefix}${account}_v1";


  Future<List<String>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_accountsKey) ?? ["Guest"];
  }

  Future<String> getCurrentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentAccountKey) ?? "Guest";
  }

  Future<void> setCurrentAccount(String account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAccountKey, account);
  }

  Future<void> addAccount(String account) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = await getAccounts();
    if (!accounts.contains(account)) {
      accounts.add(account);
      await prefs.setStringList(_accountsKey, accounts);
    }
  }


  Future<List<Transaction>> getTransactionsForAccount(String account) async {
    final prefs = await SharedPreferences.getInstance();
    String key = transactionKeyPrefix(account);
    List<String>? jsonList = prefs.getStringList(key);

    if (jsonList == null) return [];

    try {
      return jsonList
          .map((tx) => Transaction.fromJson(jsonDecode(tx)))
          .toList();
    } catch (e) {
      print("Error decoding transactions for account $account (key: $key): $e");
      await prefs.remove(key);
      return [];
    }
  }

  Future<void> saveTransactionsForAccount(
    String account,
    List<Transaction> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String key = transactionKeyPrefix(account);
    List<String> jsonList =
        transactions.map((tx) => jsonEncode(tx.toJson())).toList();
    await prefs.setStringList(key, jsonList);
  }

  Future<void> deleteAccount(String accountName) async {
  final prefs = await SharedPreferences.getInstance();

  List<String> accounts = prefs.getStringList('accounts') ?? [];
  accounts.remove(accountName);
  await prefs.setStringList('accounts', accounts);

  await prefs.remove('transactions_$accountName');
}


  Future<void> addTransactionToCurrentAccount(Transaction transaction) async {
    String currentAccount = await getCurrentAccount();
    List<Transaction> transactions = await getTransactionsForAccount(
      currentAccount,
    );
    transactions.insert(0, transaction);
    await saveTransactionsForAccount(currentAccount, transactions);
  }

  Future<List<Transaction>> getTransactions() async {
    String currentAccount = await getCurrentAccount();
    return await getTransactionsForAccount(currentAccount);
  }

  Future<void> clearTransactionsForAccount(String account) async {
    final prefs = await SharedPreferences.getInstance();
    String key = transactionKeyPrefix(account);
    await prefs.remove(key);
  }

  Future<void> clearTransactions() async {
    String currentAccount = await getCurrentAccount();
    await clearTransactionsForAccount(currentAccount);
  }


  Future<void> clearAllData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    int count = 0;

    for (String key in allKeys) {
      if (key == _accountsKey ||
          key == _currentAccountKey ||
          key.startsWith(_transactionMasterPrefix)) {
        await prefs.remove(key);
        count++;
      }
    }
    print(
      "Peringatan: $count entri data aktif telah dihapus. Data backup aman.",
    );
  }
}
