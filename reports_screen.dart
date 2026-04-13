import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allTickets = [];
  bool _isLoading = true;

  String _selectedPeriod = 'all';

  int totalTickets = 0;
  int newTickets = 0;
  int inProgressTickets = 0;
  int closedTickets = 0;
  int highPriority = 0;
  int mediumPriority = 0;
  int lowPriority = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      // Простой и надёжный запрос
      var query = supabase.from('tickets').select();

      // Фильтр по периоду
      final now = DateTime.now();

      if (_selectedPeriod == 'today') {
        final start = DateTime(now.year, now.month, now.day).toIso8601String();
        query = query.gte('created_at', start);
      } else if (_selectedPeriod == 'week') {
        final start = now.subtract(const Duration(days: 7)).toIso8601String();
        query = query.gte('created_at', start);
      } else if (_selectedPeriod == 'month') {
        final start = DateTime(now.year, now.month - 1, now.day).toIso8601String();
        query = query.gte('created_at', start);
      }

      // Сортировка
      final data = await query.order('created_at', ascending: false);

      allTickets = List<Map<String, dynamic>>.from(data);
      _calculateStats();
    } catch (e) {
      allTickets = [];
      debugPrint('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    totalTickets = allTickets.length;
    newTickets = allTickets.where((t) => t['status'] == 'new').length;
    inProgressTickets = allTickets.where((t) => t['status'] == 'in_progress').length;
    closedTickets = allTickets.where((t) => t['status'] == 'closed').length;

    highPriority = allTickets.where((t) => t['priority'] == 'high').length;
    mediumPriority = allTickets.where((t) => t['priority'] == 'medium').length;
    lowPriority = allTickets.where((t) => t['priority'] == 'low').length;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new': return 'Новая';
      case 'in_progress': return 'В работе';
      case 'checking': return 'На проверке';
      case 'closed': return 'Закрыта';
      default: return status;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high': return 'Высокий';
      case 'medium': return 'Средний';
      case 'low': return 'Низкий';
      default: return priority;
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Отчет по заявкам'];

      sheet.appendRow(['№ заявки', 'Название', 'Кабинет', 'Приоритет', 'Статус', 'Дата создания']);

      for (var ticket in allTickets) {
        sheet.appendRow([
          ticket['ticket_number'] ?? '',
          ticket['title'] ?? '',
          ticket['cabinet'] ?? '',
          _getPriorityText(ticket['priority'] ?? ''),
          _getStatusText(ticket['status'] ?? ''),
          ticket['created_at']?.toString().substring(0, 16) ?? '',
        ]);
      }

      final fileBytes = excel.encode();
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/отчет_заявок_${DateTime.now().toIso8601String().substring(0,10)}.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(filePath)], text: 'Отчет по заявкам');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отчёт экспортирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(   // ← Добавили scroll для всего экрана
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фильтр по периоду
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Все')),
                        ButtonSegment(value: 'today', label: Text('Сегодня')),
                        ButtonSegment(value: 'week', label: Text('Неделя')),
                        ButtonSegment(value: 'month', label: Text('Месяц')),
                      ],
                      selected: {_selectedPeriod},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => _selectedPeriod = selection.first);
                        _loadReports();
                      },
                    ),

                    const SizedBox(height: 24),

                    const Text('Статистика', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _buildStatCard('Всего', totalTickets.toString(), Colors.blue),
                        const SizedBox(width: 12),
                        _buildStatCard('Новые', newTickets.toString(), Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard('В работе', inProgressTickets.toString(), Colors.blue),
                        const SizedBox(width: 12),
                        _buildStatCard('Закрыто', closedTickets.toString(), Colors.green),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text('По приоритету', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard('Высокий', highPriority.toString(), Colors.red),
                        const SizedBox(width: 12),
                        _buildStatCard('Средний', mediumPriority.toString(), Colors.orange),
                        const SizedBox(width: 12),
                        _buildStatCard('Низкий', lowPriority.toString(), Colors.green),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Последние заявки
                    const Text('Последние заявки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    SizedBox(   // ← Фиксированная высота для списка
                      height: 320,   // подбери значение под свой экран (300-380 обычно хорошо)
                      child: allTickets.isEmpty
                          ? const Center(child: Text('Нет данных за выбранный период'))
                          : ListView.builder(
                              itemCount: allTickets.length > 10 ? 10 : allTickets.length,
                              itemBuilder: (context, index) {
                                final ticket = allTickets[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(ticket['title'] ?? ''),
                                    subtitle: Text('Каб. ${ticket['cabinet'] ?? '-'} • ${_getStatusText(ticket['status'] ?? '')}'),
                                    trailing: Text(_getPriorityText(ticket['priority'] ?? '')),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}