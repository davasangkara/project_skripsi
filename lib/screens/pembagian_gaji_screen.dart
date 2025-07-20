import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PembagianGajiScreen extends StatefulWidget {
  @override
  _PembagianGajiScreenState createState() => _PembagianGajiScreenState();
}

class _PembagianGajiScreenState extends State<PembagianGajiScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _gajiController = TextEditingController();
  String _kategori = "Gaji";

  List<Map<String, dynamic>> gajiList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<File> _getDataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/gaji_data.json');
  }

  Future<void> _loadData() async {
    final file = await _getDataFile();
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(contents);
      setState(() {
        gajiList = List<Map<String, dynamic>>.from(jsonData);
      });
    }
  }

  Future<void> _saveData() async {
    final file = await _getDataFile();
    await file.writeAsString(jsonEncode(gajiList));
  }

  void _tambahData() {
    if (_namaController.text.isNotEmpty && _gajiController.text.isNotEmpty) {
      String tanggal = DateFormat('dd MMMM yyyy').format(DateTime.now());

      setState(() {
        gajiList.add({
          "nama": _namaController.text,
          "gaji": double.parse(_gajiController.text),
          "kategori": _kategori,
          "tanggal": tanggal
        });
        _namaController.clear();
        _gajiController.clear();
      });

      _saveData();
    }
  }

  void _hapusData(int index) {
    setState(() {
      gajiList.removeAt(index);
    });
    _saveData();
  }

  Future<void> _cetakPDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Slip Gaji",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Container(height: 50, width: 50, child: pw.Placeholder()),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(width: 1),
                  children: [
                    _tableRow("Nama", data['nama']),
                    _tableRow("Jumlah Gaji", "Rp ${data['gaji'].toStringAsFixed(2)}"),
                    _tableRow("Kategori", data['kategori']),
                    _tableRow("Tanggal", data['tanggal']),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    children: [
                      pw.Text("TTD,", style: pw.TextStyle(fontSize: 16)),
                      pw.SizedBox(height: 40),
                      pw.Text("(_________________)", style: pw.TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/Slip_Gaji_${data['nama']}.pdf");
    await file.writeAsBytes(await pdf.save());

    OpenFilex.open(file.path);
  }

  pw.TableRow _tableRow(String title, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          color: PdfColors.grey300,
          child: pw.Text(title,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pembagian Gaji"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _namaController,
                      decoration: InputDecoration(
                        labelText: "Nama Penerima",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _gajiController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Jumlah Gaji",
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _kategori,
                      items: ["Gaji", "Bonus", "Lain-lain"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _kategori = val!),
                      decoration: InputDecoration(
                        labelText: "Kategori",
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _tambahData,
                      icon: Icon(Icons.add),
                      label: Text("Tambahkan"),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: gajiList.isEmpty
                  ? Center(
                      child: Text(
                        "Belum ada data",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: gajiList.length,
                      itemBuilder: (context, index) {
                        final data = gajiList[index];
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              data["nama"],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Rp ${data["gaji"].toStringAsFixed(2)} - ${data["kategori"]}\nTanggal: ${data['tanggal']}",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.print, color: Colors.green),
                                  onPressed: () => _cetakPDF(data),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _hapusData(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
