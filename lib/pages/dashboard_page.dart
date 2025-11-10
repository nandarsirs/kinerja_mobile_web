import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final ScrollController _monthScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedMonth());
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
      final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      final response = await supabase
          .from('kinerja')
          .select('kategori_id, kategori_kinerja(nama, target)')
          .eq('user_id', userId!)
          .gte('tanggal', startDate.toIso8601String())
          .lte('tanggal', endDate.toIso8601String());

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

      final data = grouped.values.map((e) {
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

      setState(() => rekapKategori = data);
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  void _scrollToSelectedMonth() {
    final index = selectedMonth.month - 1;
    const itemWidth = 88.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = index * itemWidth - (screenWidth / 2) + (itemWidth / 2);
    _monthScrollController.animateTo(
      offset.clamp(
        _monthScrollController.position.minScrollExtent,
        _monthScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Widget _glassMonthSelector() {
    final months =
        List.generate(12, (index) => DateTime(selectedMonth.year, index + 1, 1));
    return SizedBox(
      height: 50,
      child: ListView.builder(
        controller: _monthScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected = month.month == selectedMonth.month;
          final monthName = DateFormat.MMM().format(month);

          return GestureDetector(
            onTap: () {
              setState(() => selectedMonth = month);
              fetchRekapKategori();
              _scrollToSelectedMonth();
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFAA73E0), Color(0xFF7B4BFF)],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.purple.withOpacity(isSelected ? 0 : 0.5)),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                monthName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

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
            padding:
                EdgeInsets.symmetric(horizontal: w * 0.04, vertical: h * 0.015),
            child: Column(
              children: [
                // ------------------ HEADER ------------------
                Row(
                  children: [
                    CircleAvatar(
                      radius: w * 0.07,
                      backgroundColor: Colors.white.withOpacity(0.6),
                      child: Icon(Icons.person,
                          color: Colors.purple, size: w * 0.07),
                    ),
                    SizedBox(width: w * 0.03),
                    Expanded(
                      child: Text(
                        userName,
                        style: TextStyle(
                            fontSize: w * 0.05, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.purple),
                      onPressed: fetchRekapKategori,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: _logout,
                    ),
                  ],
                ),

                SizedBox(height: h * 0.02),

                // ------------------ CARD ISI UTAMA ------------------
                Expanded(
                  child: _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pilih Bulan
                        Text(
                          'Pilih Bulan',
                          style: TextStyle(
                              fontSize: w * 0.04, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _glassMonthSelector(),
                        const SizedBox(height: 12),

                        // Data Kinerja
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.purple),
                                )
                              : rekapKategori.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Belum ada kinerja',
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.black54),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: rekapKategori.length,
                                      itemBuilder: (context, index) {
                                        final item = rekapKategori[index];
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: Colors.white24),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['kategori'] ?? '-',
                                                style: TextStyle(
                                                  fontSize: w * 0.045,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple[800],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text('Jumlah: ${item['jumlah']}'),
                                                  Text('Target: ${item['target']}'),
                                                  Text('Nilai: ${item['persentase']}'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: h * 0.015),

                // ------------------ TOMBOL BAWAH ------------------
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await context.push('/input-kinerja');
                          fetchRekapKategori();
                        },
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(vertical: h * 0.015),
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
                          child: Text(
                            "Tambah Kinerja",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: w * 0.045),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: w * 0.03),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/lihat-kinerja'),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(vertical: h * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.purple),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Lihat Kinerja",
                            style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: w * 0.045),
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
