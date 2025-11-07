import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> rekapKategori = [];
  bool isLoading = false;
  String userName = '';
  String? userId;
  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
      userName = prefs.getString('nama') ?? 'User';
    });
    fetchRekapKategori();
  }

  Future<void> fetchRekapKategori() async {
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      // Filter berdasarkan bulan terpilih
      final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endDate =
          DateTime(selectedMonth.year, selectedMonth.month + 1, 0); // last day

      final response = await supabase
          .from('kinerja')
          .select('kategori_id, kategori_kinerja(nama, target)')
          .eq('user_id', userId!)
          .gte('tanggal', startDate.toIso8601String())
          .lte('tanggal', endDate.toIso8601String());

      // Group by kategori
      final Map<int, Map<String, dynamic>> grouped = {};
      for (final item in response) {
        final kategoriId = item['kategori_id'] as int;
        final kategoriNama = item['kategori_kinerja']['nama'] ?? 'Lainnya';
        final target = (item['kategori_kinerja']['target'] ?? 0).toDouble();

        if (grouped.containsKey(kategoriId)) {
          grouped[kategoriId]!['jumlah'] += 1;
        } else {
          grouped[kategoriId] = {
            'kategori': kategoriNama,
            'jumlah': 1,
            'target': target,
          };
        }
      }

      // Hitung persentase
      final List<Map<String, dynamic>> data = grouped.values.map((e) {
        final target = e['target'] as double;
        final jumlah = e['jumlah'] as int;
        final persentase =
            target > 0 ? ((jumlah / target) * 100).toStringAsFixed(1) + '%' : '-';
        return {
          'kategori': e['kategori'],
          'jumlah': jumlah,
          'target': target,
          'persentase': persentase,
        };
      }).toList();

      setState(() {
        rekapKategori = data;
      });

      debugPrint('Rekap kategori: $rekapKategori');
    } catch (e) {
      debugPrint('❌ Gagal memuat kinerja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat kinerja: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) context.go('/login');
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

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null && picked != selectedMonth) {
      setState(() => selectedMonth = picked);
      fetchRekapKategori();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthText = DateFormat.yMMMM().format(selectedMonth);

    return Scaffold(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.6),
                      child:
                          const Icon(Icons.person, color: Colors.purple, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.purple),
                      tooltip: 'Refresh',
                      onPressed: fetchRekapKategori,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      tooltip: 'Logout',
                      onPressed: _logout,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter bulan
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.purple),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickMonth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple),
                        ),
                        child: Text(
                          monthText,
                          style: const TextStyle(
                              color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Glass card dengan tabel rekap
                Expanded(
                  child: _glassCard(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.purple),
                          )
                        : rekapKategori.isEmpty
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
                                    DataColumn(label: Text('Kategori')),
                                    DataColumn(label: Text('Jumlah')),
                                    DataColumn(label: Text('Target')),
                                    DataColumn(label: Text('Nilai')),
                                  ],
                                  rows: rekapKategori.map((item) {
                                    return DataRow(cells: [
                                      DataCell(Text(item['kategori'] ?? '-')),
                                      DataCell(Text(item['jumlah'].toString())),
                                      DataCell(Text(item['target'].toString())),
                                      DataCell(Text(item['persentase'] ?? '-')),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bagian bawah tombol
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Tombol Tambah Kinerja
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await context.push('/input-kinerja');
                            fetchRekapKategori();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFAA73E0), Color(0xFF7B4BFF)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "Tambah Kinerja",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Tombol Lihat Kinerja
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.push('/lihat-kinerja'); // nanti buat halaman ini
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.purple),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "Lihat Kinerja",
                              style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
