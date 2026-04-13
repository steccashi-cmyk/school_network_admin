import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_icmp_ping/flutter_icmp_ping.dart';
import '../../reports/screens/device_detail_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> devices = [];
  bool _isLoading = true;
  bool _simulationMode = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('devices')
          .select()
          .order('name', ascending: true);

      setState(() {
        devices = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      devices = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _startPingAll();
      }
    }
  }

  void _startPingAll() {
    for (var device in devices) {
      _pingDevice(device);
    }
  }

  Future<void> _pingDevice(Map<String, dynamic> device) async {
    if (!mounted) return;
    setState(() => device['status'] = 'checking');

    await Future.delayed(const Duration(milliseconds: 800));

    if (_simulationMode) {
      final isOnline = device['id'] % 3 != 0;
      if (mounted) setState(() => device['status'] = isOnline ? 'online' : 'offline');
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
      if (mounted) setState(() => device['status'] = 'offline');
    }
  }

  Color _getStatusColor(String? status) {
    if (status == 'online') return Colors.green;
    if (status == 'offline') return Colors.red;
    return Colors.grey;
  }

  IconData _getDeviceIcon(String? type) {
    switch (type) {
      case 'router': return Icons.router;
      case 'server': return Icons.storage;
      case 'ap': return Icons.wifi;
      case 'switch': return Icons.settings_ethernet;
      default: return Icons.device_hub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Устройства'),
        actions: [
          IconButton(
            icon: Icon(_simulationMode ? Icons.science : Icons.network_check),
            tooltip: _simulationMode ? 'Симуляция включена' : 'Реальный пинг',
            onPressed: () {
              setState(() => _simulationMode = !_simulationMode);
              _startPingAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startPingAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? const Center(
                  child: Text(
                    'Нет устройств в базе\nДобавьте записи в таблицу "devices"',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          _getDeviceIcon(device['type']),
                          size: 40,
                          color: _getStatusColor(device['status']),
                        ),
                        title: Text(device['name'] ?? 'Устройство'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IP: ${device['ip'] ?? '-'}'),
                            Text('Кабинет: ${device['cabinet'] ?? '-'}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (device['status'] == 'checking')
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(
                                device['status'] == 'online' ? Icons.check_circle : Icons.cancel,
                                color: _getStatusColor(device['status']),
                                size: 28,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              device['status'] == 'online' ? 'Онлайн' : 'Оффлайн',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(device['status']),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeviceDetailScreen(device: device),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}