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
  String ubuntuVersion = "Unknown";
  bool showImage = false;
  bool showUbuntuVersion = false;
  Process? player;

  // ── BLE state ─────────────────────────────────────────────────────────────
  final BleService _ble = BleService();
  List<BlueZDevice> _scannedDevices = [];
  List<BlueZDevice> _connectedDevices = [];
  bool _isScanning = false;
  bool _isAdvertising = false;
  String _bleStatus = 'Initializing…';
  String? _bleError;
  String? _connectingAddress;

  @override
  void initState() {
    super.initState();
    readVersion();
    _initBle();
  }

  Future<void> _initBle() async {
    try {
      await _ble.init();

      _ble.scannedDevicesStream
          .listen((d) { if (mounted) setState(() => _scannedDevices = d); });

      _ble.connectedDevicesStream
          .listen((d) { if (mounted) setState(() { _connectedDevices = d; _connectingAddress = null; }); });

      _ble.scanningStream
          .listen((v) { if (mounted) setState(() => _isScanning = v); });

      _ble.advertisingStream
          .listen((v) { if (mounted) setState(() => _isAdvertising = v); });

      _ble.statusStream
          .listen((s) { if (mounted) setState(() => _bleStatus = s); });

      setState(() => _bleStatus =
          'Adapter: ${_ble.adapterName} (${_ble.adapterAddress})');
    } catch (e) {
      setState(() => _bleError = e.toString());
    }
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

  Future<void> fetchUbuntuVersion() async {
    try {
      final file = File('/etc/os-release');
      final content = await file.readAsString();
      for (var line in content.split('\n')) {
        if (line.startsWith('PRETTY_NAME=')) {
          ubuntuVersion = line.split('=')[1].replaceAll('"', '');
          break;
        }
      }
    } catch (e) {
      ubuntuVersion = "Unknown";
    }
    setState(() {
      showUbuntuVersion = true;
    });
  }

  // ── BLE actions ───────────────────────────────────────────────────────────
  Future<void> _toggleScan() async {
    setState(() => _bleError = null);
    try {
      _isScanning ? await _ble.stopScan() : await _ble.startScan();
    } catch (e) {
      setState(() => _bleError = e.toString());
    }
  }

  Future<void> _toggleAdvertising() async {
    setState(() => _bleError = null);
    try {
      _isAdvertising
          ? await _ble.stopAdvertising()
          : await _ble.startAdvertising();
    } catch (e) {
      setState(() => _bleError = e.toString());
    }
  }

  Future<void> _handleScanDeviceTap(BlueZDevice device) async {
    setState(() => _connectingAddress = device.address);
    try {
      await device.connect();
    } catch (e) {
      setState(() {
        _bleError = 'Connection failed: $e';
        _connectingAddress = null;
      });
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
            if (_connectedDevices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: Chip(
                    avatar: const Icon(Icons.bluetooth_connected,
                        size: 14, color: Colors.white),
                    label: Text(
                      '${_connectedDevices.length} connected',
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

              // ── Existing section ──────────────────────────────────────
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
              ElevatedButton(
                onPressed: fetchUbuntuVersion,
                child: const Text("Show Ubuntu Version"),
              ),
              const SizedBox(height: 10),
              if (showUbuntuVersion)
                Text(
                  "Ubuntu Version: $ubuntuVersion",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              if (showImage) Image.asset('assets/picture.png', width: 200),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),

              // ── BLE Status ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.bluetooth, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_bleStatus,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Two BLE buttons side by side ──────────────────────────
              Row(
                children: [
                  // Button 1: Scan
                  Expanded(
                    child: SizedBox(
                      height: 56,
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
                          _isScanning ? 'Stop\nScan' : 'Scan\nDevices',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? Colors.red.shade600
                              : Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Button 2: Advertise
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _toggleAdvertising,
                        icon: _isAdvertising
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.broadcast_on_personal),
                        label: Text(
                          _isAdvertising ? 'Stop\nAdvertise' : 'Advertise\nDevice',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAdvertising
                              ? Colors.red.shade600
                              : Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Error banner ──────────────────────────────────────────
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

              const SizedBox(height: 20),

              // ── Scanned Devices ───────────────────────────────────────
              if (_isScanning || _scannedDevices.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nearby Devices',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                if (_scannedDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Searching…',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ..._scannedDevices.map((device) {
                  final name =
                      device.name.isEmpty ? 'Unknown Device' : device.name;
                  final isConnecting =
                      _connectingAddress == device.address;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.bluetooth,
                            color: Colors.blue.shade700),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Row(children: [
                        Icon(Icons.signal_cellular_alt,
                            size: 13, color: _rssiColor(device.rssi)),
                        const SizedBox(width: 3),
                        Text('${device.rssi} dBm',
                            style: TextStyle(
                                fontSize: 12,
                                color: _rssiColor(device.rssi))),
                        const SizedBox(width: 6),
                        Text(device.address,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                      trailing: isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : ElevatedButton(
                              onPressed: () => _handleScanDeviceTap(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Connect',
                                  style: TextStyle(fontSize: 12)),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              // ── Connected Devices (from advertising) ──────────────────
              if (_connectedDevices.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Connected Devices',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                ..._connectedDevices.map((device) {
                  final name =
                      device.name.isEmpty ? 'Unknown Device' : device.name;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.green.shade400, width: 2),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Icon(Icons.bluetooth_connected,
                            color: Colors.green.shade700),
                      ),
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(device.address,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => _ble.disconnectDevice(device),
                            child: const Text('Disconnect',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else if (_isAdvertising) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Waiting for a device to connect…\nOpen Bluetooth on your phone and select "${_ble.adapterName}"',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey.shade600, height: 1.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}