import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/transaction.dart';
import '../services/shared_prefs_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final SharedPrefsService _prefsService = SharedPrefsService();
  List<Transaction> _transactions = [];
  double _balance = 0.0;
  double _income = 0.0;
  double _expense = 0.0;
  bool _isFabOpen = false;
  bool _sortByNewest = true;

  late AnimationController _animationController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotification();
    _loadTransactions();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'keuangan_channel',
      'Notifikasi Keuangan',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Pemberitahuan Keuangan',
      message,
      platformChannelSpecifics,
    );
  }

  Future<void> _loadTransactions() async {
    List<Transaction> transactions = await _prefsService.getTransactions();
    double totalBalance = 0.0;
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var item in transactions) {
      totalBalance += item.amount;
      if (item.amount > 0) {
        totalIncome += item.amount;
      } else {
        totalExpense += item.amount.abs();
      }
    }

    setState(() {
      _transactions = transactions;
      _sortTransactions();
      _balance = totalBalance;
      _income = totalIncome;
      _expense = totalExpense;
    });
  }

  void _sortTransactions() {
    _transactions.sort((a, b) =>
        _sortByNewest ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
  }

  Future<void> _addTransaction(String title, double amount) async {
    if (title.isEmpty || amount == 0) return;

    final newTransaction = Transaction(
      id: Transaction.generateId(),
      title: title,
      amount: amount,
      date: DateTime.now(),
    );

    double newBalance = _balance + amount;
    _checkAndNotify(amount, newBalance);

    setState(() {
      _transactions.add(newTransaction);
      _sortTransactions();
      _balance = newBalance;
      if (amount > 0) {
        _income += amount;
      } else {
        _expense += amount.abs();
      }
    });

    await _prefsService.addTransactionToCurrentAccount(newTransaction);
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    _transactions.removeWhere((t) => t.id == transaction.id);
    await _prefsService.saveTransactionsForAccount(
      await _prefsService.getCurrentAccount(),
      _transactions,
    );
    await _loadTransactions();
  }

  Future<void> _editTransaction(
      Transaction oldTx, String newTitle, double newAmount) async {
    int index = _transactions.indexWhere((t) => t.id == oldTx.id);
    if (index != -1) {
      _transactions[index] = Transaction(
        id: oldTx.id,
        title: newTitle,
        amount: newAmount,
        date: oldTx.date,
      );
      await _prefsService.saveTransactionsForAccount(
        await _prefsService.getCurrentAccount(),
        _transactions,
      );
      await _loadTransactions();
    }
  }

  void _checkAndNotify(double amount, double balance) {
    if (amount < -100000) {
      _showNotification("Pengeluaran kamu besar hari ini, harap lebih hemat.");
    } else if (amount > 500000) {
      _showNotification("Pemasukan besar tercatat, tetap kelola dengan bijak!");
    }

    if (balance < 50000) {
      _showNotification("Saldo kamu hampir habis, periksa kembali pengeluaran.");
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Tambah Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Tambah Catatan",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: _fillSuggestedTransaction,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: "Deskripsi"),
              ),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: "Jumlah"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Batal"),
              onPressed: () {
                _titleController.clear();
                _amountController.clear();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Pemasukan"),
              onPressed: () {
                _addTransaction(
                  _titleController.text,
                  double.parse(_amountController.text),
                );
                _titleController.clear();
                _amountController.clear();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Pengeluaran", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _addTransaction(
                  _titleController.text,
                  -double.parse(_amountController.text),
                );
                _titleController.clear();
                _amountController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(Transaction transaction) {
    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Transaksi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: "Deskripsi"),
              ),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: "Jumlah"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Batal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Simpan"),
              onPressed: () {
                _editTransaction(
                  transaction,
                  _titleController.text,
                  double.tryParse(_amountController.text) ?? transaction.amount,
                );
                _titleController.clear();
                _amountController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _fillSuggestedTransaction() {
    _titleController.text = "Belanja Bulanan";
    _amountController.text = "500000";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortByNewest = value == "Terbaru";
                _sortTransactions();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: "Terbaru", child: Text("Urutkan: Terbaru")),
              PopupMenuItem(value: "Terlama", child: Text("Urutkan: Terlama")),
            ],
            icon: Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(),
          _buildIncomeExpenseCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Saldo Anda",
              style:
                  TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("Rp ${_balance.toStringAsFixed(2)}",
              style:
                  TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIncomeExpenseItem("Saldo Masuk", _income, Colors.green),
            _buildIncomeExpenseItem("Saldo Keluar", _expense, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseItem(String title, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4),
        Text("Rp ${amount.toStringAsFixed(2)}", style: TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildTransactionList() {
    List<Transaction> filteredTransactions = _transactions.where((tx) {
      return tx.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = filteredTransactions[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(transaction.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${transaction.date.day}/${transaction.date.month}/${transaction.date.year}"),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Rp ${transaction.amount.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: transaction.amount > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 20),
                      tooltip: "Edit",
                      onPressed: () => _showEditDialog(transaction),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: "Hapus",
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Konfirmasi"),
                          content: Text("Apakah Anda ingin menghapus transaksi ini?"),
                          actions: [
                            TextButton(
                              child: Text("Batal"),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: Text("Hapus"),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteTransaction(transaction);
                              },
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_isFabOpen)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: "transaksi",
                label: Text("Tambah Transaksi"),
                icon: Icon(Icons.add),
                onPressed: _showTransactionDialog,
              ),
              SizedBox(height: 10),
            ],
          ),
        FloatingActionButton(
          heroTag: "fab",
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _animationController,
          ),
          onPressed: _toggleFab,
        ),
      ],
    );
  }
}
