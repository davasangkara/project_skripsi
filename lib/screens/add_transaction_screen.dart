import 'package:flutter/material.dart';
import '../models/transaction.dart';

class AddTransactionScreen extends StatefulWidget {
  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  void _submitData() {
    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text);

    if (title.isEmpty || amount == null || amount <= 0) return;

    final newTransaction = Transaction(
      id: Transaction.generateId(), // Gunakan UUID
      title: title,
      amount: amount,
      date: DateTime.now(),
    );

    Navigator.of(context).pop(newTransaction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tambah Transaksi")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Judul"),
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: "Jumlah"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text("Tambahkan"),
              onPressed: _submitData,
            ),
          ],
        ),
      ),
    );
  }
}
