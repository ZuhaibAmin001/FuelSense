import 'package:flutter/material.dart';
import '../services/api_service.dart';


class EmployeeScreen extends StatefulWidget {
  final int stationId;
  const EmployeeScreen({super.key, required this.stationId});
  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ApiService.getEmployees(widget.stationId);
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _employees = List<Map<String, dynamic>>.from(r.data['employees'] ?? []);
        _loading = false;
        _err = null;
      });
    } else {
      setState(() { _loading = false; _err = r.error; });
    }
  }

  Future<void> _deleteEmployee(int id) async {
    final r = await ApiService.deleteEmployee(widget.stationId, id);
    if (!mounted) return;
    if (r.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'Failed to delete')));
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'Pump Attendant';
    String shift = 'MORNING';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1425),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Employee', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                dropdownColor: const Color(0xFF0D1425),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Role', labelStyle: TextStyle(color: Colors.white54)),
                items: ['Pump Attendant', 'Cashier', 'Manager', 'Security']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setDialogState(() => role = v ?? role),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: shift,
                dropdownColor: const Color(0xFF0D1425),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Shift', labelStyle: TextStyle(color: Colors.white54)),
                items: ['MORNING', 'EVENING', 'NIGHT']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setDialogState(() => shift = v ?? shift),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final r = await ApiService.addEmployee(
                  widget.stationId,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: role,
                  shift: shift,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (r.success) {
                  _load();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? 'Failed to add')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1425),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Text('Employees', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            GestureDetector(
              onTap: _showAddDialog,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 18),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : _err != null
                  ? Center(child: Text(_err!, style: const TextStyle(color: Colors.white54)))
                  : _employees.isEmpty
                      ? Center(child: Text('No employees yet.\nTap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.4))))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _employees.length,
                          itemBuilder: (_, i) {
                            final e = _employees[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1425),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
                                  child: Text(e['name'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(e['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${e['role']} · ${e['shift']}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                  ]),
                                ),
                                IconButton(
                                  onPressed: () => _deleteEmployee(e['id']),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                ),
                              ]),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}