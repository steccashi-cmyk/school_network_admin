import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ticket_detail_screen.dart';   // ← Новый импорт

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('tickets')
          .select()
          .order('created_at', ascending: false);
      setState(() => tickets = List<Map<String, dynamic>>.from(data));
    }
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createTicket() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const NewTicketDialog(),
    );

    if (result != null && mounted) {
      try {
        final ticketNumber = 'T-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

        await supabase.from('tickets').insert({
          'ticket_number': ticketNumber,
          'title': result['title'],
          'description': result['description'],
          'cabinet': result['cabinet'],
          'priority': result['priority'],
          'status': 'new',
        });

        _loadTickets();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Заявка $ticketNumber создана')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка создания заявки')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createTicket),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : tickets.isEmpty
              ? const Center(
                  child: Text('Пока нет заявок\nНажмите "+" чтобы создать', textAlign: TextAlign.center),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TicketDetailScreen(ticket: ticket),
                            ),
                          ).then((_) => _loadTickets());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket['title'] ?? 'Заявка',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Кабинет: ${ticket['cabinet'] ?? '-'}'),
                                    Text(
                                      'Создано: ${ticket['created_at']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Chip(
                                    label: Text(_getStatusText(ticket['status'] ?? 'new')),
                                    backgroundColor: _getStatusColor(ticket['status'] ?? 'new').withOpacity(0.15),
                                    labelStyle: TextStyle(
                                      color: _getStatusColor(ticket['status'] ?? 'new'),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getPriorityText(ticket['priority'] ?? 'medium'),
                                    style: TextStyle(
                                      color: _getPriorityColor(ticket['priority'] ?? 'medium'),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTicket,
        child: const Icon(Icons.add),
      ),
    );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'checking': return Colors.purple;
      case 'closed': return Colors.green;
      default: return Colors.grey;
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }
}

class NewTicketDialog extends StatefulWidget {
  const NewTicketDialog({super.key});

  @override
  State<NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<NewTicketDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _cabinet = '';
  String _priority = 'medium';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая заявка'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название проблемы'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Кабинет'),
              onChanged: (value) => _cabinet = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Приоритет'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Низкий')),
                DropdownMenuItem(value: 'medium', child: Text('Средний')),
                DropdownMenuItem(value: 'high', child: Text('Высокий')),
              ],
              onChanged: (value) => setState(() => _priority = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty) return;
            Navigator.pop(context, {
              'title': _titleController.text,
              'description': _descriptionController.text,
              'cabinet': _cabinet,
              'priority': _priority,
            });
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}