import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/transaction.dart';
import '../services/pdf_service.dart';
import '../services/shared_prefs_service.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class RekapScreen extends StatefulWidget {
  @override
  _RekapScreenState createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> with SingleTickerProviderStateMixin {
  final SharedPrefsService _prefsService = SharedPrefsService();
  final PDFService _pdfService = PDFService();
  List<Transaction> _transactions = [];
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  bool _isFabOpen = false;
  late AnimationController _animationController;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    List<Transaction> transactions = await _prefsService.getTransactions();
    double income = 0.0;
    double expense = 0.0;

    for (var item in transactions) {
      if (item.amount > 0) {
        income += item.amount;
      } else {
        expense += item.amount.abs();
      }
    }

    setState(() {
      _transactions = transactions;
      _totalIncome = income;
      _totalExpense = expense;
    });
  }

  Future<void> _generatePDF(BuildContext context, String type) async {
    if (_transactions.isEmpty) {
      _showSnackbar("Tidak ada transaksi untuk diekspor!");
      return;
    }

    List<Transaction> filteredTransactions = [];
    if (type == "income") {
      filteredTransactions = _transactions.where((t) => t.amount > 0).toList();
    } else if (type == "expense") {
      filteredTransactions = _transactions.where((t) => t.amount < 0).toList();
    } else if (type == "range") {
      if (_startDate == null || _endDate == null) {
        _showSnackbar("Pilih rentang tanggal terlebih dahulu!");
        return;
      }
      filteredTransactions = _transactions.where((t) =>
        t.date.isAfter(_startDate!.subtract(Duration(days: 1))) &&
        t.date.isBefore(_endDate!.add(Duration(days: 1)))
      ).toList();
    } else if (type == "month") {
      if (_selectedMonth == null) {
        _showSnackbar("Pilih bulan terlebih dahulu!");
        return;
      }
      filteredTransactions = _transactions.where((t) =>
        t.date.year == _selectedMonth!.year && t.date.month == _selectedMonth!.month
      ).toList();
    } else {
      filteredTransactions = _transactions;
    }

    if (filteredTransactions.isEmpty) {
      _showSnackbar("Tidak ada transaksi yang tersedia untuk diekspor!");
      return;
    }

    String filePath = await _pdfService.generatePDF(filteredTransactions);
    await OpenFilex.open(filePath);
    _showSnackbar("PDF berhasil dibuat dan dibuka!");
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      _isFabOpen ? _animationController.forward() : _animationController.reverse();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showMonthPicker(
      context: context,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(now.year, now.month),
      initialDate: _selectedMonth ?? now,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 243, 243),
      appBar: AppBar(
        title: Text("Rekap Keuangan"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(Icons.arrow_downward, "Pemasukan", _totalIncome, Colors.green),
            _buildSummaryItem(Icons.arrow_upward, "Pengeluaran", _totalExpense, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, double value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4),
        Text("Rp ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: tx.amount > 0 ? Colors.green : Colors.red,
              child: Icon(
                tx.amount > 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
              ),
            ),
            title: Text(tx.title, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date)),
            trailing: Text(
              "Rp ${tx.amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: tx.amount > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
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
              _fabOption("Ekspor Rentang", Icons.date_range, Colors.indigo, () async {
                await _selectDateRange(context);
                _generatePDF(context, "range");
              }),
              _fabOption("Ekspor Bulan", Icons.calendar_today, Colors.deepOrange, () async {
                await _selectMonth(context);
                _generatePDF(context, "month");
              }),
              SizedBox(height: 10),
            ],
          ),
        FloatingActionButton(
          onPressed: _toggleFab,
          child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _animationController),
          backgroundColor: Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _fabOption(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton.extended(
        heroTag: label,
        label: Text(label),
        icon: Icon(icon),
        backgroundColor: color,
        onPressed: onPressed,
      ),
    );
  }
}
