import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputKinerjaPage extends StatefulWidget {
  const InputKinerjaPage({super.key});

  @override
  State<InputKinerjaPage> createState() => _InputKinerjaPageState();
}

class _InputKinerjaPageState extends State<InputKinerjaPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _deskripsiController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  int? _selectedKategori;
  bool _loading = false;

  List<Map<String, dynamic>> _kategoriList = [];

  @override
  void initState() {
    super.initState();
    _loadKategori();
  }

  Future<void> _loadKategori() async {
    try {
      final response = await supabase.from('kategori_kinerja').select();
      setState(() {
        _kategoriList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori: $e')),
      );
    }
  }

  Future<void> _simpanKinerja() async {
    if (_selectedDate == null || _jamMulai == null || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua kolom wajib')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User tidak ditemukan')),
        );
        return;
      }

      final jamMulaiStr =
          '${_jamMulai!.hour.toString().padLeft(2, '0')}:${_jamMulai!.minute.toString().padLeft(2, '0')}';
      final jamSelesaiStr = _jamSelesai != null
          ? '${_jamSelesai!.hour.toString().padLeft(2, '0')}:${_jamSelesai!.minute.toString().padLeft(2, '0')}'
          : null;

      await supabase.from('kinerja').insert({
        'user_id': userId,
        'kategori_id': _selectedKategori,
        'tanggal': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'jam_mulai': jamMulaiStr,
        'jam_selesai': jamSelesaiStr,
        'deskripsi': _deskripsiController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kinerja berhasil disimpan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _glassPickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black87)),
            Text(value, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: Colors.black54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Input Kinerja',
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _glassPickerTile(
                    label: 'Tanggal',
                    value: _selectedDate == null
                        ? 'Pilih tanggal'
                        : DateFormat('dd MMM yyyy').format(_selectedDate!),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  _glassPickerTile(
                    label: 'Jam Mulai',
                    value: _jamMulai == null
                        ? 'Pilih jam mulai'
                        : _jamMulai!.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _jamMulai = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  _glassPickerTile(
                    label: 'Jam Selesai',
                    value: _jamSelesai == null
                        ? 'Pilih jam selesai (opsional)'
                        : _jamSelesai!.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _jamSelesai = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    dropdownColor: Colors.white.withOpacity(0.2),
                    value: _selectedKategori,
                    decoration: _glassInputDecoration('Kategori Kinerja'),
                    items: _kategoriList.map((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          item['nama'],
                          style: const TextStyle(color: Colors.black87),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedKategori = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deskripsiController,
                    maxLines: 5,
                    decoration: _glassInputDecoration('Deskripsi Kegiatan'),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _simpanKinerja,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.purpleAccent,
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Simpan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
