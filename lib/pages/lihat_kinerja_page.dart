import 'dart:io' show File; // Mobile only
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart'; // Mobile only
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Web only

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
  List<Map<String, dynamic>> filteredData = [];
  String searchQuery = '';

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

  // 🔹 Ganti dua date picker jadi satu range picker
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.purple, // Warna utama
              onPrimary: Colors.white, // Teks tombol utama
              onSurface: Colors.black, // Warna teks tanggal
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  Future<void> fetchKinerja() async {
    if (userId == null || startDate == null || endDate == null) return;

    setState(() => isLoading = true);

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final start = dateFormat.format(startDate!);
      final end = dateFormat.format(endDate!);

      debugPrint('📅 Filter tanggal: $start → $end untuk user $userId');

      final response = await supabase
          .from('kinerja')
          .select(
              'tanggal, jam_mulai, jam_selesai, deskripsi, kategori_kinerja(nama)')
          .eq('user_id', userId!)
          .gte('tanggal', start)
          .lte('tanggal', end)
          .order('tanggal', ascending: true)
          .limit(10000);

      debugPrint('📦 Jumlah data: ${response.length}');

      setState(() {
        kinerjaData = List<Map<String, dynamic>>.from(response);
        _applySearchFilter();
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

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredData = kinerjaData;
    } else {
      filteredData = kinerjaData.where((item) {
        final kategori = item['kategori_kinerja']?['nama']?.toLowerCase() ?? '';
        final deskripsi = item['deskripsi']?.toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        return kategori.contains(query) || deskripsi.contains(query);
      }).toList();
    }
  }

  // 🔹 Export Excel biasa
  Future<void> exportToExcel() async {
    if (filteredData.isEmpty) return;

    final excel = ex.Excel.createExcel();
    final sheet = excel['Kinerja'];
    sheet.appendRow(
        ['Tanggal', 'Kategori', 'Deskripsi', 'Jam Mulai', 'Jam Selesai']);

    for (final item in filteredData) {
      sheet.appendRow([
        item['tanggal'] ?? '-',
        item['kategori_kinerja']?['nama'] ?? '-',
        item['deskripsi'] ?? '-',
        item['jam_mulai'] ?? '-',
        item['jam_selesai'] ?? '-',
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
            "download", "kinerja_${DateTime.now().millisecondsSinceEpoch}.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/kinerja_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File Excel berhasil dibuat: $filePath')),
        );
      }
    }
  }

  // 🔹 Export Excel per tanggal
  Future<void> exportPerTanggalExcel() async {
    if (filteredData.isEmpty) return;

    final excel = ex.Excel.createExcel();
    final sheet = excel['Kinerja Per Tanggal'];

    sheet.appendRow(
        ['Tanggal', 'Kategori', 'Deskripsi', 'Jam Mulai', 'Jam Selesai']);

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var d in filteredData) {
      final tgl = d['tanggal'] ?? '-';
      grouped.putIfAbsent(tgl, () => []);
      grouped[tgl]!.add(d);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(a).compareTo(DateTime.parse(b));
        } catch (_) {
          return a.compareTo(b);
        }
      });

    for (final tgl in sortedDates) {
      final dataList = grouped[tgl]!;

      for (final item in dataList) {
        sheet.appendRow([
          tgl,
          item['kategori_kinerja']?['nama'] ?? '-',
          item['deskripsi'] ?? '-',
          item['jam_mulai'] ?? '-',
          item['jam_selesai'] ?? '-',
        ]);
      }

      sheet.appendRow([]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "kinerja_per_tanggal_${DateTime.now().millisecondsSinceEpoch}.xlsx",
        )
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/kinerja_per_tanggal_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File Excel per tanggal disimpan: $filePath')),
        );
      }
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
                // 🔹 Tombol pilih rentang tanggal
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple),
                          ),
                          child: Text(
                            (startDate != null && endDate != null)
                                ? '${DateFormat('dd MMM yyyy').format(startDate!)} → ${DateFormat('dd MMM yyyy').format(endDate!)}'
                                : 'Pilih rentang tanggal',
                            style: const TextStyle(
                                color: Colors.purple, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: fetchKinerja,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 171, 107, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tampilkan'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 🔹 Kolom pencarian
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari kategori atau deskripsi',
                    fillColor: Colors.white.withOpacity(0.3),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.purple),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val;
                      _applySearchFilter();
                    });
                  },
                ),

                const SizedBox(height: 16),

                // 🔹 Tabel hasil
                Expanded(
                  child: _glassCard(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.purple))
                        : filteredData.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada kinerja',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: DataTable(
                                    headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                      fontSize: 12,
                                    ),
                                    dataTextStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Tanggal')),
                                      DataColumn(label: Text('Kategori')),
                                      DataColumn(label: Text('Deskripsi')),
                                      DataColumn(label: Text('Jam Mulai')),
                                      DataColumn(label: Text('Jam Selesai')),
                                    ],
                                    rows: filteredData.map((item) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              item['tanggal'] != null
                                                  ? DateFormat('dd MMM yyyy')
                                                      .format(DateTime.parse(
                                                          item['tanggal']))
                                                  : '-',
                                            ),
                                          ),
                                          DataCell(Text(item['kategori_kinerja']
                                                  ?['nama'] ??
                                              '-')),
                                          DataCell(Text(item['deskripsi'] ??
                                              '-')),
                                          DataCell(Text(
                                              item['jam_mulai'] ?? '-')),
                                          DataCell(Text(
                                              item['jam_selesai'] ?? '-')),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                  ),
                ),

                if (filteredData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Menampilkan ${filteredData.length} data',
                      style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: Colors.black54),
                    ),
                  ),

                const SizedBox(height: 16),

                // 🔹 Tombol export
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: exportToExcel,
                        icon: const Icon(Icons.download),
                        label: const Text('Download Biasa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 171, 107, 255),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: exportPerTanggalExcel,
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Per Tanggal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 140, 90, 220),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
