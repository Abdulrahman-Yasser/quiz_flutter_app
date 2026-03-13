import 'dart:async';
import 'package:bluez/bluez.dart';

/// BLE Service using BlueZ (Linux/AGL) via the `bluez` Dart package.
/// Communicates with bluetoothd over D-Bus — no Android/iOS needed.
class BleService {
  BlueZClient? _client;
  BlueZAdapter? _adapter;

  // ── Streams exposed to the UI ─────────────────────────────────────────────
  final _devicesController =
      StreamController<List<BlueZDevice>>.broadcast();
  Stream<List<BlueZDevice>> get devicesStream => _devicesController.stream;

  final _connectedController =
      StreamController<BlueZDevice?>.broadcast();
  Stream<BlueZDevice?> get connectedStream => _connectedController.stream;

  final _scanningController = StreamController<bool>.broadcast();
  Stream<bool> get scanningStream => _scanningController.stream;

  // ── Internal state ────────────────────────────────────────────────────────
  BlueZDevice? _connectedDevice;
  bool _isScanning = false;
  StreamSubscription? _deviceAddedSub;

  bool get isScanning => _isScanning;

  // ── Initialise BlueZ client & grab first adapter ──────────────────────────
  Future<void> init() async {
    _client = BlueZClient();
    await _client!.connect();

    if (_client!.adapters.isEmpty) {
      throw Exception('No Bluetooth adapter found. Is bluetoothd running?');
    }
    _adapter = _client!.adapters.first;
  }

  // ── 1. Scan for nearby BLE devices ───────────────────────────────────────
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_client == null) await init();
    if (_isScanning) await stopScan();

    // Emit any devices BlueZ already knows about
    _emitDevices();

    // Listen for newly discovered devices during this scan
    _deviceAddedSub = _client!.deviceAdded.listen((_) => _emitDevices());

    await _adapter!.startDiscovery();
    _isScanning = true;
    _scanningController.add(true);

    // Auto-stop after timeout
    Future.delayed(timeout, () async {
      if (_isScanning) await stopScan();
    });
  }

  Future<void> stopScan() async {
    try {
      await _adapter?.stopDiscovery();
    } catch (_) {}
    await _deviceAddedSub?.cancel();
    _deviceAddedSub = null;
    _isScanning = false;
    _scanningController.add(false);
  }

  void _emitDevices() {
    if (_client == null) return;
    final devices = List<BlueZDevice>.from(_client!.devices)
      ..sort((a, b) => b.rssi.compareTo(a.rssi)); // strongest signal first
    _devicesController.add(List.unmodifiable(devices));
  }

  // ── 2. Connect to a device ────────────────────────────────────────────────
  Future<void> connectToDevice(BlueZDevice device) async {
    await disconnectDevice(); // drop any existing connection first

    await device.connect();
    _connectedDevice = device;
    _connectedController.add(device);

    // Watch for unexpected disconnection via property changes
    device.propertiesChanged.listen((props) {
      if (props.contains('Connected') && !device.connected) {
        _connectedDevice = null;
        _connectedController.add(null);
      }
    });
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
      _connectedController.add(null);
    }
  }

  // ── Clean-up ──────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await stopScan();
    await disconnectDevice();
    await _client?.close();
    await _devicesController.close();
    await _connectedController.close();
    await _scanningController.close();
  }
}
