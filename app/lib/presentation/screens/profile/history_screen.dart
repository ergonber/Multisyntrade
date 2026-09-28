import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tx = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'deriv-history',
        body: {'limit': 300},
      );
      final data = res.data as Map<String, dynamic>?;
      final list = (data?['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() { _tx = list; _loading = false; });
    } catch (e) {
      setState(() { _error = 'No se pudo cargar el historial de Deriv'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial (Deriv)')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Text(_error!, style: const TextStyle(color: AppColors.negative))),
                  ])
                : _tx.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Sin operaciones registradas en Deriv.', style: TextStyle(color: Colors.grey))),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tx.length,
                        separatorBuilder: (_, __) => const Divider(height: 8, color: Colors.black12),
                        itemBuilder: (_, i) => _row(_tx[i]),
                      ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final profit = (t['profit'] as num?)?.toDouble() ?? 0;
    final win = profit >= 0;
    final symbol = (t['symbol'] ?? '').toString();
    final type = (t['type'] ?? '').toString();
    final sell = t['sell_time'];
    DateTime? dt;
    if (sell is int) dt = DateTime.fromMillisecondsSinceEpoch(sell * 1000);
    final when = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$type  ·  $when', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Text(
        '${win ? '+' : ''}\$${profit.toStringAsFixed(2)}',
        style: TextStyle(color: win ? AppColors.positive : AppColors.negative, fontWeight: FontWeight.bold),
      ),
    );
  }
}
