import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/shared_prefs_service.dart';
import '../widgets/transaction_list.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final SharedPrefsService _prefsService = SharedPrefsService();
  List<Transaction> _transactions = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    List<Transaction> transactions = await _prefsService.getTransactions();
    setState(() {
      _transactions = transactions;
    });
  }

  void _showFinancialChart() {
    double totalIncome = _transactions
        .where((tx) => tx.amount > 0)
        .fold(0, (sum, tx) => sum + tx.amount);
    double totalExpense = _transactions
        .where((tx) => tx.amount < 0)
        .fold(0, (sum, tx) => sum + tx.amount.abs());
    double total = totalIncome + totalExpense;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Grafik Keuangan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: totalIncome,
                        title:
                            total > 0
                                ? "${((totalIncome / total) * 100).toStringAsFixed(1)}%"
                                : "0%",
                        radius: 60,
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.red,
                        value: totalExpense,
                        title:
                            total > 0
                                ? "${((totalExpense / total) * 100).toStringAsFixed(1)}%"
                                : "0%",
                        radius: 60,
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    sectionsSpace: 5,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 14),
                  SizedBox(width: 5),
                  Text(
                    "Pemasukan: Rp${totalIncome.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(width: 20),
                  Icon(Icons.circle, color: Colors.red, size: 14),
                  SizedBox(width: 5),
                  Text(
                    "Pengeluaran: Rp${totalExpense.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Transaction> incomeTransactions =
        _transactions.where((tx) => tx.amount > 0).toList();
    List<Transaction> expenseTransactions =
        _transactions.where((tx) => tx.amount < 0).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("History"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.arrow_downward, color: Colors.green),
              text: "Uang Masuk",
            ),
            Tab(
              icon: Icon(Icons.arrow_upward, color: Colors.red),
              text: "Uang Keluar",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TransactionList(incomeTransactions),
          TransactionList(expenseTransactions),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFinancialChart,
        child: Icon(Icons.pie_chart),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
