import 'package:flutter/material.dart';
import 'package:flutter_icmp_ping/flutter_icmp_ping.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  String _status = 'checking';
  final TextEditingController _sshController = TextEditingController();
  String _sshOutput = '';
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _pingDevice();
  }

  Future<void> _pingDevice() async {
    setState(() => _status = 'checking');

    await Future.delayed(const Duration(milliseconds: 800));

    final isOnline = widget.device['id'] % 3 != 0;
    setState(() => _status = isOnline ? 'online' : 'offline');
  }

  Future<void> _executeSSHCommand() async {
    final command = _sshController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _isExecuting = true;
      _sshOutput += '→ $command\n';
    });

    await Future.delayed(const Duration(seconds: 1));

    String result;
    if (command.toLowerCase().contains('reboot') || command.toLowerCase().contains('restart')) {
      result = 'Устройство перезагружается... (симуляция)';
    } else if (command.toLowerCase().contains('ping')) {
      result = 'PING 8.8.8.8 (симуляция): 64 bytes, time=12ms';
    } else if (command.toLowerCase().contains('status')) {
      result = 'Статус устройства: ${_status.toUpperCase()}';
    } else {
      result = 'Команда выполнена успешно (симуляция)';
    }

    setState(() {
      _sshOutput += '$result\n\n';
      _isExecuting = false;
    });

    _sshController.clear();
  }

  Color _getStatusColor() {
    return _status == 'online' ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Scaffold(
      appBar: AppBar(
        title: Text(device['name'] ?? 'Устройство'),
      ),
      body: SingleChildScrollView(
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
                    Row(
                      children: [
                        Icon(Icons.device_hub, size: 40, color: _getStatusColor()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('IP: ${device['ip'] ?? '-'}'),
                              Text('Кабинет: ${device['cabinet'] ?? '-'}'),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text(_status.toUpperCase(),
                                style: TextStyle(fontSize: 16, color: _getStatusColor(), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Icon(
                              _status == 'online' ? Icons.check_circle : Icons.cancel,
                              color: _getStatusColor(),
                              size: 32,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Быстрые действия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton('Ping', Icons.network_ping, Colors.blue, () => _pingDevice()),
                _buildActionButton('Перезагрузить', Icons.restart_alt, Colors.orange, () {
                  _sshController.text = 'reboot';
                  _executeSSHCommand();
                }),
                _buildActionButton('Сброс порта', Icons.power_settings_new, Colors.red, () {
                  _sshController.text = 'port reset 1';
                  _executeSSHCommand();
                }),
                _buildActionButton('Показать статус', Icons.info, Colors.purple, () {
                  _sshController.text = 'status';
                  _executeSSHCommand();
                }),
              ],
            ),

            const SizedBox(height: 32),

            const Text('SSH Команды', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _sshController,
                      decoration: const InputDecoration(
                        hintText: 'Введите команду (например: reboot, status)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _executeSSHCommand(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isExecuting ? null : _executeSSHCommand,
                      icon: _isExecuting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: const Text('Выполнить'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_sshOutput.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: Text(
                        _sshOutput,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
      ),
    );
  }
}