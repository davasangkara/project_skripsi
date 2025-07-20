import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class PDFService {
  Future<String> generatePDF(List<Transaction> transactions) async {
    final pdf = pw.Document();
    
    // Pisahkan transaksi masuk dan keluar
    List<Transaction> incomeTransactions = transactions.where((t) => t.amount > 0).toList();
    List<Transaction> expenseTransactions = transactions.where((t) => t.amount < 0).toList();

    double totalIncome = incomeTransactions.fold(0, (sum, item) => sum + item.amount);
    double totalExpense = expenseTransactions.fold(0, (sum, item) => sum + item.amount.abs());

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Laporan Keuangan Toko Cahaya Elektronik", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Tanggal: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}"),
              pw.SizedBox(height: 20),
              
              // Tabel Pemasukan
              pw.Text("Pemasukan", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
              _buildTransactionTable(incomeTransactions),

              pw.SizedBox(height: 10),

              // Tabel Pengeluaran
              pw.Text("Pengeluaran", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              _buildTransactionTable(expenseTransactions),

              pw.SizedBox(height: 20),

              // Akumulasi Total
              pw.Text("Total Pemasukan: Rp ${totalIncome.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
              pw.Text("Total Pengeluaran: Rp ${totalExpense.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              pw.Text("Saldo Akhir: Rp ${(totalIncome - totalExpense).toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/Rekap_Keuangan.pdf");
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  pw.Widget _buildTransactionTable(List<Transaction> transactions) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(child: pw.Text("Tanggal", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(5)),
            pw.Padding(child: pw.Text("Keterangan", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(5)),
            pw.Padding(child: pw.Text("Jumlah", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(5)),
          ],
        ),
        ...transactions.map((t) => pw.TableRow(
          children: [
            pw.Padding(child: pw.Text(DateFormat('dd/MM/yyyy').format(t.date)), padding: pw.EdgeInsets.all(5)),
            pw.Padding(child: pw.Text(t.title), padding: pw.EdgeInsets.all(5)),
            pw.Padding(child: pw.Text("Rp ${t.amount.abs().toStringAsFixed(2)}"), padding: pw.EdgeInsets.all(5)),
          ],
        )),
      ],
    );
  }
}
