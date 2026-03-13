import 'dart:async';
import 'package:bluez/bluez.dart';

/// BLE Service supporting both:
///   1. Scanning   — discover nearby devices (central role)
///   2. Advertising — make this device discoverable & accept connections (peripheral role)
class BleService {
  BlueZClient? _client;
  BlueZAdapter? _adapter;

  // ── Scan streams ──────────────────────────────────────────────────────────
  final _scannedDevicesController =
      StreamController<List<BlueZDevice>>.broadcast();
  Stream<List<BlueZDevice>> get scannedDevicesStream =>
      _scannedDevicesController.stream;

  final _scanningController = StreamController<bool>.broadcast();
  Stream<bool> get scanningStream => _scanningController.stream;

  // ── Advertise streams ─────────────────────────────────────────────────────
  final _connectedDevicesController =
      StreamController<List<BlueZDevice>>.broadcast();
  Stream<List<BlueZDevice>> get connectedDevicesStream =>
      _connectedDevicesController.stream;

  final _advertisingController = StreamController<bool>.broadcast();
  Stream<bool> get advertisingStream => _advertisingController.stream;

  // ── Shared status stream ──────────────────────────────────────────────────
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // ── Internal state ────────────────────────────────────────────────────────
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  final List<BlueZDevice> _connectedDevices = [];
  final Map<String, StreamSubscription> _deviceSubs = {};
  StreamSubscription? _deviceAddedSub;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _client = BlueZClient();
    await _client!.connect();

    if (_client!.adapters.isEmpty) {
      throw Exception(
          'No Bluetooth adapter found.\nRun: sudo systemctl start bluetooth');
    }

    _adapter = _client!.adapters.first;

    if (!_adapter!.powered) {
      await _adapter!.setPowered(true);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _statusController.add('Adapter: ${_adapter!.alias} (${_adapter!.address})');

    // Watch for incoming connections (for advertising mode)
    _client!.deviceAdded.listen(_onDeviceAdded);
    _client!.deviceRemoved.listen(_onDeviceRemoved);

    // Track already-connected devices
    for (final d in _client!.devices) {
      if (d.connected) _trackConnectedDevice(d);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SCAN — discover nearby devices
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_client == null) await init();
    if (_isScanning) await stopScan();

    // Emit devices BlueZ already knows about
    _emitScannedDevices();

    // Listen for newly found devices
    _deviceAddedSub = _client!.deviceAdded.listen((_) => _emitScannedDevices());

    await _adapter!.startDiscovery();
    _isScanning = true;
    _scanningController.add(true);
    _statusController.add('Scanning for devices…');

    // Auto-stop after timeout
    Future.delayed(timeout, () {
      if (_isScanning) stopScan();
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
    _statusController.add('Scan stopped.');
  }

  void _emitScannedDevices() {
    if (_client == null) return;
    final devices = List<BlueZDevice>.from(_client!.devices)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _scannedDevicesController.add(List.unmodifiable(devices));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ADVERTISE — make this device discoverable and accept connections
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> startAdvertising() async {
    if (_client == null) await init();

    await _adapter!.setDiscoverable(true);
    await _adapter!.setPairable(true);
    await _adapter!.setDiscoverableTimeout(0); // never expire
    await _adapter!.setPairableTimeout(0);

    _isAdvertising = true;
    _advertisingController.add(true);
    _statusController.add(
        'Advertising as "${_adapter!.alias}" — waiting for connections…');
  }

  Future<void> stopAdvertising() async {
    await _adapter?.setDiscoverable(false);
    await _adapter?.setPairable(false);

    _isAdvertising = false;
    _advertisingController.add(false);
    _statusController.add('Advertising stopped.');
  }

  // ── Track incoming connections ────────────────────────────────────────────
  void _trackConnectedDevice(BlueZDevice device) {
    if (_deviceSubs.containsKey(device.address)) return;

    if (!_connectedDevices.any((d) => d.address == device.address)) {
      _connectedDevices.add(device);
      _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
      _statusController.add(
          '✅ Connected: ${device.name.isEmpty ? device.address : device.name}');
    }

    final sub = device.propertiesChanged.listen((props) {
      if (props.contains('Connected') && !device.connected) {
        _connectedDevices.removeWhere((d) => d.address == device.address);
        _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
        _statusController.add(
            '❌ Disconnected: ${device.name.isEmpty ? device.address : device.name}');
        _deviceSubs[device.address]?.cancel();
        _deviceSubs.remove(device.address);
      }
    });
    _deviceSubs[device.address] = sub;
  }

  void _onDeviceAdded(BlueZDevice device) {
    if (device.connected) {
      _trackConnectedDevice(device);
    } else {
      late StreamSubscription sub;
      sub = device.propertiesChanged.listen((props) {
        if (props.contains('Connected') && device.connected) {
          _trackConnectedDevice(device);
          sub.cancel();
        }
      });
    }
    // Also refresh scan list if scanning
    if (_isScanning) _emitScannedDevices();
  }

  void _onDeviceRemoved(BlueZDevice device) {
    _connectedDevices.removeWhere((d) => d.address == device.address);
    _connectedDevicesController.add(List.unmodifiable(_connectedDevices));
    _deviceSubs[device.address]?.cancel();
    _deviceSubs.remove(device.address);
    if (_isScanning) _emitScannedDevices();
  }

  Future<void> disconnectDevice(BlueZDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  String get adapterName => _adapter?.alias ?? _adapter?.name ?? 'Unknown';
  String get adapterAddress => _adapter?.address ?? '';

  // ── Dispose ───────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await stopScan();
    await stopAdvertising();
    for (final sub in _deviceSubs.values) {
      await sub.cancel();
    }
    _deviceSubs.clear();
    await _client?.close();
    await _scannedDevicesController.close();
    await _connectedDevicesController.close();
    await _scanningController.close();
    await _advertisingController.close();
    await _statusController.close();
  }
}