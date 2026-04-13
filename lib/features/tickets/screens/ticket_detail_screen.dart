import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> comments = [];
  List<Map<String, dynamic>> attachments = [];
  bool _isLoading = true;
  final _commentController = TextEditingController();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadData();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      setState(() {
        _isAdmin = data['role'] == 'admin';
      });
    } catch (e) {
      _isAdmin = false;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final commentsData = await supabase
          .from('comments')
          .select()
          .eq('ticket_id', widget.ticket['id'])
          .order('created_at', ascending: true);

      final attachmentsData = await supabase
          .from('ticket_attachments')
          .select()
          .eq('ticket_id', widget.ticket['id'])
          .order('created_at', ascending: true);

      setState(() {
        comments = List<Map<String, dynamic>>.from(commentsData);
        attachments = List<Map<String, dynamic>>.from(attachmentsData);
      });
    }
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (!_isAdmin) {
      if (newStatus != 'in_progress' && newStatus != 'checking') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Оператор может переводить заявку только в "В работе" или "На проверке"'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    try {
      await supabase.from('tickets').update({'status': newStatus}).eq('id', widget.ticket['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Статус изменён на ${_getStatusText(newStatus)}')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка изменения статуса')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final filePath = 'tickets/${widget.ticket['id']}/$fileName';

      await supabase.storage.from('ticket_attachments').uploadBinary(filePath, bytes);
      final fileUrl = supabase.storage.from('ticket_attachments').getPublicUrl(filePath);

      await supabase.from('ticket_attachments').insert({
        'ticket_id': widget.ticket['id'],
        'file_name': fileName,
        'file_path': filePath,
        'file_url': fileUrl,
        'uploaded_by': supabase.auth.currentUser?.id,
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото успешно загружено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAttachment(String attachmentId, String filePath) async {
    try {
      await supabase.storage.from('ticket_attachments').remove([filePath]);
      await supabase.from('ticket_attachments').delete().eq('id', attachmentId);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото удалено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления фото')),
        );
      }
    }
  }

  Future<void> _deleteTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заявку?'),
        content: const Text('Это действие нельзя отменить.\nВсе комментарии и фото также будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('tickets').delete().eq('id', widget.ticket['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка удалена')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'ticket_id': widget.ticket['id'],
        'user_id': supabase.auth.currentUser?.id,
        'comment_text': _commentController.text.trim(),
      });

      _commentController.clear();
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка добавления комментария')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заявка №${ticket['ticket_number']}'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteTicket,
            ),

          PopupMenuButton<String>(
            onSelected: _updateStatus,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new', child: Text('Новая')),
              const PopupMenuItem(value: 'in_progress', child: Text('В работе')),
              const PopupMenuItem(value: 'checking', child: Text('На проверке')),
              if (_isAdmin)
                const PopupMenuItem(value: 'closed', child: Text('Закрыта')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text('Кабинет: ${ticket['cabinet'] ?? '-'}'),
                          Text('Приоритет: ${_getPriorityText(ticket['priority'] ?? 'medium')}'),
                          Text('Статус: ${_getStatusText(ticket['status'] ?? 'new')}'),
                          Text('Создано: ${ticket['created_at']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? ''}'),
                          const SizedBox(height: 12),
                          const Text('Описание:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(ticket['description'] ?? '—'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Прикреплённые фото', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ElevatedButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Добавить'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (attachments.isEmpty)
                    const Text('Фото пока нет', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: attachments.map((att) {
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Image.network(att['file_url'], fit: BoxFit.contain),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  att['file_url'],
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                  onPressed: () => _deleteAttachment(att['id'], att['file_path']),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  const Text('Комментарии', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  if (comments.isEmpty)
                    const Text('Комментариев пока нет')
                  else
                    Column(
                      children: comments.map((comment) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(comment['comment_text'] ?? ''),
                              subtitle: Text(
                                comment['created_at']?.toString().replaceFirst('T', ' ').substring(0, 16) ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          )).toList(),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Напишите комментарий...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _addComment,
                        icon: const Icon(Icons.send, color: Colors.blue, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
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

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high': return 'Высокий';
      case 'medium': return 'Средний';
      case 'low': return 'Низкий';
      default: return priority;
    }
  }
}