import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluez/bluez.dart';
import 'ble_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ── Existing state ────────────────────────────────────────────────────────
  String aglVersion = "Loading...";
  bool showImage = false;
  Process? player;

  // ── BLE state ─────────────────────────────────────────────────────────────
  final BleService _ble = BleService();
  List<BlueZDevice> _devices = [];
  BlueZDevice? _connectedDevice;
  bool _isScanning = false;
  String? _bleError;
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    readVersion();

    _ble.devicesStream.listen((list) {
      if (mounted) setState(() => _devices = list);
    });

    _ble.connectedStream.listen((device) {
      if (mounted) setState(() {
        _connectedDevice = device;
        _connectingAddress = null;
      });
    });

    _ble.scanningStream.listen((v) {
      if (mounted) setState(() => _isScanning = v);
    });
  }

  // ── Existing methods ──────────────────────────────────────────────────────
  Future<void> readVersion() async {
    try {
      final file = File('/etc/os-release');
      final content = await file.readAsString();
      for (var line in content.split('\n')) {
        if (line.startsWith('VERSION=')) {
          aglVersion = line.split('=')[1];
        }
      }
    } catch (e) {
      aglVersion = "Unknown";
    }
    setState(() {});
  }

  void playSound() async {
    player?.kill();
    try {
      final byteData = await rootBundle.load('assets/sound.mp3');
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/sound.mp3');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      player = await Process.start('gst-launch-1.0', [
        'playbin',
        'uri=file://${tempFile.path}',
      ]);
    } catch (e) {
      print("Error playing sound via GStreamer: $e");
    }
  }

  // ── BLE methods ───────────────────────────────────────────────────────────
  Future<void> _toggleScan() async {
    setState(() => _bleError = null);
    try {
      if (_isScanning) {
        await _ble.stopScan();
      } else {
        await _ble.startScan();
      }
    } catch (e) {
      setState(() => _bleError = e.toString());
    }
  }

  Future<void> _handleDeviceTap(BlueZDevice device) async {
    if (_connectedDevice?.address == device.address) {
      await _ble.disconnectDevice();
    } else {
      setState(() => _connectingAddress = device.address);
      try {
        await _ble.connectToDevice(device);
      } catch (e) {
        setState(() {
          _bleError = 'Connection failed: $e';
          _connectingAddress = null;
        });
      }
    }
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _ble.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("AGL Flutter Demo"),
          actions: [
            if (_connectedDevice != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: Chip(
                    avatar: const Icon(Icons.bluetooth_connected,
                        size: 14, color: Colors.white),
                    label: Text(
                      _connectedDevice!.name.isEmpty
                          ? 'Connected'
                          : _connectedDevice!.name,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    backgroundColor: Colors.green.shade600,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // ── Existing section ────────────────────────────────────────
              Text("AGL Version: $aglVersion"),
              const SizedBox(height: 10),
              const Text("Name: Abdulrahman Yasser - Quiz of AGL Flutter"),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => setState(() => showImage = true),
                child: const Text("Show Image"),
              ),
              ElevatedButton(
                onPressed: playSound,
                child: const Text("Play Sound"),
              ),
              const SizedBox(height: 10),
              if (showImage) Image.asset('assets/picture.png', width: 200),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),

              // ── BLE section ─────────────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Bluetooth Devices",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Scan button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _toggleScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(
                      _isScanning ? 'Stop Scanning…' : 'Scan for Devices'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning
                        ? Colors.red.shade600
                        : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              // Error banner
              if (_bleError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_bleError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 12),

              // Empty state
              if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isScanning
                        ? 'Searching for devices…'
                        : 'No devices found. Press Scan to start.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),

              // Device cards
              ..._devices.map((device) {
                final name =
                    device.name.isEmpty ? 'Unknown Device' : device.name;
                final isConnected =
                    _connectedDevice?.address == device.address;
                final isConnecting =
                    _connectingAddress == device.address;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isConnected
                        ? BorderSide(color: Colors.green.shade400, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isConnected
                          ? Colors.green.shade100
                          : Colors.blue.shade50,
                      child: Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        color: isConnected
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MAC address
                        Text(device.address,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                        const SizedBox(height: 3),
                        Row(children: [
                          // RSSI
                          Icon(Icons.signal_cellular_alt,
                              size: 13, color: _rssiColor(device.rssi)),
                          const SizedBox(width: 3),
                          Text('${device.rssi} dBm',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _rssiColor(device.rssi))),

                          if (isConnected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('CONNECTED',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                    trailing: isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : ElevatedButton(
                            onPressed: () => _handleDeviceTap(device),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isConnected
                                  ? Colors.red.shade50
                                  : Colors.blue.shade700,
                              foregroundColor:
                                  isConnected ? Colors.red : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                                isConnected ? 'Disconnect' : 'Connect',
                                style: const TextStyle(fontSize: 12)),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}