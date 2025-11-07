import 'dart:io' show File; // Hanya untuk Mobile
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart'; // Mobile only

// Flutter Web import
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LihatKinerjaPage extends StatefulWidget {
  const LihatKinerjaPage({super.key});

  @override
  State<LihatKinerjaPage> createState() => _LihatKinerjaPageState();
}

class _LihatKinerjaPageState extends State<LihatKinerjaPage> {
  final supabase = Supabase.instance.client;

  DateTime? startDate;
  DateTime? endDate;
  String? userId;

  bool isLoading = false;
  List<Map<String, dynamic>> kinerjaData = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => endDate = picked);
  }

  Future<void> fetchKinerja() async {
    if (userId == null || startDate == null || endDate == null) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('kinerja')
          .select('tanggal, jam_mulai, jam_selesai, deskripsi, kategori_kinerja(nama)')
          .eq('user_id', userId!)
          .gte('tanggal', startDate!.toIso8601String())
          .lte('tanggal', endDate!.toIso8601String());

      setState(() {
        kinerjaData = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('❌ Gagal mengambil data kinerja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data kinerja: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> exportToExcel() async {
    if (kinerjaData.isEmpty) return;

    final excel = ex.Excel.createExcel();
    final sheet = excel['Kinerja'];
    sheet.appendRow(['Tanggal', 'Kategori', 'Deskripsi', 'Jam Mulai', 'Jam Selesai']);

    for (final item in kinerjaData) {
      sheet.appendRow([
        item['tanggal'] ?? '-',
        item['kategori_kinerja']?['nama'] ?? '-',
        item['deskripsi'] ?? '-',
        item['jam_mulai'] ?? '-',
        item['jam_selesai'] ?? '-',
      ]);
    }

    if (kIsWeb) {
      // Flutter Web
      final bytes = excel.encode();
      if (bytes == null) return;

      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "kinerja_${DateTime.now().millisecondsSinceEpoch}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/kinerja_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileBytes = excel.encode();
      if (fileBytes == null) return;

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File Excel berhasil dibuat: $filePath')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lihat Kinerja'),
        backgroundColor: Colors.purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 253, 253, 253),
              Color.fromARGB(255, 170, 115, 224),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Pilihan range tanggal
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple),
                          ),
                          child: Text(
                            startDate != null
                                ? 'Mulai: ${startDate!.toLocal().toString().split(' ')[0]}'
                                : 'Pilih tanggal mulai',
                            style: const TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickEndDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple),
                          ),
                          child: Text(
                            endDate != null
                                ? 'Selesai: ${endDate!.toLocal().toString().split(' ')[0]}'
                                : 'Pilih tanggal selesai',
                            style: const TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: fetchKinerja,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 171, 107, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tampilkan'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Tabel kinerja
                Expanded(
                  child: _glassCard(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                        : kinerjaData.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada kinerja',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingTextStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                  dataTextStyle: const TextStyle(
                                    color: Colors.black87,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Tanggal')),
                                    DataColumn(label: Text('Kategori')),
                                    DataColumn(label: Text('Deskripsi')),
                                    DataColumn(label: Text('Jam Mulai')),
                                    DataColumn(label: Text('Jam Selesai')),
                                  ],
                                  rows: kinerjaData.map((item) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item['tanggal'] ?? '-')),
                                        DataCell(Text(item['kategori_kinerja']?['nama'] ?? '-')),
                                        DataCell(Text(item['deskripsi'] ?? '-')),
                                        DataCell(Text(item['jam_mulai'] ?? '-')),
                                        DataCell(Text(item['jam_selesai'] ?? '-')),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                  ),
                ),

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: exportToExcel,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 171, 107, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
