import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_icmp_ping/flutter_icmp_ping.dart';

import '../../devices/screens/devices_screen.dart';
import '../../tickets/screens/tickets_screen.dart';
import '../../reports/screens/reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  String userName = '';
  String userRole = 'operator';
  int _currentIndex = 0;

  bool _simulationMode = true;
  int _newTicketsCount = 0;

  List<Map<String, dynamic>> devices = [
    {'id': 1, 'name': 'Маршрутизатор', 'ip': '192.168.1.1', 'status': 'checking'},
    {'id': 2, 'name': 'Сервер', 'ip': '192.168.1.10', 'status': 'checking'},
    {'id': 3, 'name': 'Wi-Fi 1 этаж', 'ip': '192.168.1.20', 'status': 'checking'},
    {'id': 4, 'name': 'Wi-Fi 2 этаж', 'ip': '192.168.1.21', 'status': 'checking'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _startMonitoring();
    _listenToNewTickets();
  }

  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase.from('users').select().eq('email', user.email!).single();
        setState(() {
          userName = data['full_name'] ?? 'Пользователь';
          userRole = data['role'] ?? 'operator';
        });
      } catch (e) {}
    }
  }

  // ←←← НОВЫЙ МЕТОД ←←←
  void _listenToNewTickets() {
    supabase
        .from('tickets')
        .stream(primaryKey: ['id'])
        .listen((data) {
          final newCount = data.where((ticket) => ticket['status'] == 'new').length;

          if (newCount != _newTicketsCount) {
            setState(() => _newTicketsCount = newCount);

            if (newCount > 0 && _currentIndex != 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Новая заявка! Всего новых: $newCount'),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Открыть',
                    textColor: Colors.white,
                    onPressed: () => setState(() => _currentIndex = 2),
                  ),
                ),
              );
            }
          }
        });
  }

  void _startMonitoring() {
    for (var device in devices) {
      _pingDevice(device);
    }
  }

  Future<void> _pingDevice(Map<String, dynamic> device) async {
    setState(() => device['status'] = 'checking');

    await Future.delayed(const Duration(milliseconds: 800));

    if (_simulationMode) {
      final isOnline = device['id'] % 2 == 1;
      setState(() => device['status'] = isOnline ? 'online' : 'offline');
      return;
    }

    try {
      final ping = Ping(device['ip'], count: 2, timeout: 2.0);
      bool isOnline = false;

      await for (final PingData data in ping.stream) {
        if (data.summary != null && data.summary!.received != null && data.summary!.received! > 0) {
          isOnline = true;
          break;
        }
      }

      if (mounted) {
        setState(() => device['status'] = isOnline ? 'online' : 'offline');
      }
    } catch (e) {
      if (mounted) {
        setState(() => device['status'] = 'offline');
      }
    }
  }

  Color _getDeviceStatusColor(String status) {
    if (status == 'online') return Colors.green;
    if (status == 'offline') return Colors.red;
    return Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHome(),
      const DevicesScreen(),
      const TicketsScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Network Admin'),
        actions: [
          IconButton(
            icon: Icon(_simulationMode ? Icons.science : Icons.network_check),
            tooltip: _simulationMode ? 'Симуляция включена' : 'Реальный пинг',
            onPressed: () {
              setState(() => _simulationMode = !_simulationMode);
              _startMonitoring();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startMonitoring,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Устройства',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _newTicketsCount > 0,
              label: Text('$_newTicketsCount'),
              backgroundColor: Colors.red,
              child: const Icon(Icons.assignment),
            ),
            label: 'Заявки',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Отчёты',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Добро пожаловать, $userName',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            userRole == 'admin' ? 'Администратор' : 'Оператор',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Состояние сети', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              Text(
                _simulationMode ? '(Симуляция)' : '(Реальный пинг)',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        device['name'].contains('Wi-Fi') ? Icons.wifi : Icons.router,
                        color: _getDeviceStatusColor(device['status']),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          device['name'],
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (device['status'] == 'checking')
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(
                          device['status'] == 'online' ? Icons.check_circle : Icons.cancel,
                          color: _getDeviceStatusColor(device['status']),
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Активные заявки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 2),
                child: const Text('Все заявки'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('tickets')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Ошибка загрузки заявок'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Пока нет активных заявок\nСоздайте первую заявку'),
                  );
                }

                final activeTickets = snapshot.data!;

                return ListView.builder(
                  itemCount: activeTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = activeTickets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {},
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(ticket['priority'] ?? 'medium').withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getPriorityText(ticket['priority'] ?? 'medium'),
                                      style: TextStyle(
                                        color: _getPriorityColor(ticket['priority'] ?? 'medium'),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}