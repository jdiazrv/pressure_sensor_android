import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String uiVersion = 'v1';
const String prefsDeviceHost = 'device_host';
const String prefsShowRssiDbm = 'show_rssi_dbm';
const double compactLayoutBreakpoint = 390;
const int defaultUdpPort = 4210;
const Duration statePollInterval = Duration(seconds: 5);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WakelockPlus.enable();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PressureSensorApp());
}

class AppColors {
  static const bg = Color(0xFF07111B);
  static const bg2 = Color(0xFF0D1A2E);
  static const panel = Color(0xFF102031);
  static const panelSoft = Color(0xFF16283B);
  static const line = Color(0x1FFFFFFF);
  static const text = Color(0xFFF3F7FB);
  static const muted = Color(0xFF93A4B8);
  static const ok = Color(0xFF22C55E);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const accent = Color(0xFF53C6FF);
}

class DeviceState {
  const DeviceState({
    required this.device,
    required this.firmwareVersion,
    required this.hostname,
    required this.wifiConnected,
    required this.localIp,
    required this.apIp,
    required this.rssi,
    required this.sensorMode,
    required this.adsFound,
    required this.dataValid,
    required this.systemRunning,
    required this.deviceError,
    required this.pressure1,
    required this.pressure2,
    required this.voltage1,
    required this.voltage2,
    required this.signalkIp,
    required this.signalkAlive,
    required this.signalkServicePort,
    required this.udpPort,
    required this.udpEnabled,
    required this.partialRuntimeMs,
    required this.totalRuntimeMs,
    required this.uptimeMs,
  });

  final String device;
  final String firmwareVersion;
  final String hostname;
  final bool wifiConnected;
  final String localIp;
  final String apIp;
  final int rssi;
  final String sensorMode;
  final bool adsFound;
  final bool dataValid;
  final bool systemRunning;
  final String deviceError;
  final double pressure1;
  final double pressure2;
  final double voltage1;
  final double voltage2;
  final String signalkIp;
  final bool signalkAlive;
  final int signalkServicePort;
  final int udpPort;
  final bool udpEnabled;
  final int partialRuntimeMs;
  final int totalRuntimeMs;
  final int uptimeMs;

  factory DeviceState.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DeviceState(
      device: json['device']?.toString() ?? 'pressure-sensor-esp32',
      firmwareVersion: json['firmwareVersion']?.toString() ?? '--',
      hostname: json['hostname']?.toString() ?? 'watermaker',
      wifiConnected: json['wifiConnected'] == true,
      localIp: json['localIp']?.toString() ?? '0.0.0.0',
      apIp: json['apIp']?.toString() ?? '0.0.0.0',
      rssi: readInt('rssi'),
      sensorMode: json['sensorMode']?.toString() ?? 'real',
      adsFound: json['adsFound'] == true,
      dataValid: json['dataValid'] == true,
      systemRunning: json['systemRunning'] == true,
      deviceError: json['deviceError']?.toString() ?? '',
      pressure1: readDouble('pressure1'),
      pressure2: readDouble('pressure2'),
      voltage1: readDouble('voltage1'),
      voltage2: readDouble('voltage2'),
      signalkIp: json['signalkIp']?.toString() ?? '0.0.0.0',
      signalkAlive: json['signalkAlive'] == true,
      signalkServicePort: readInt('signalkServicePort'),
      udpPort: readInt('udpPort'),
      udpEnabled: json['udpEnabled'] == true,
      partialRuntimeMs: readInt('partialRuntimeMs'),
      totalRuntimeMs: readInt('totalRuntimeMs'),
      uptimeMs: readInt('uptimeMs'),
    );
  }
}

class DeviceDiagnostics {
  const DeviceDiagnostics({required this.values});

  final Map<String, dynamic> values;

  factory DeviceDiagnostics.fromJson(Map<String, dynamic> json) {
    return DeviceDiagnostics(values: json);
  }

  dynamic operator [](String key) => values[key];
}

class DeviceSettings {
  const DeviceSettings({
    required this.maxPressure1,
    required this.minPressure1,
    required this.minVdc1,
    required this.maxVdc1,
    required this.maxPressure2,
    required this.minPressure2,
    required this.minVdc2,
    required this.maxVdc2,
    required this.modo,
    required this.sensorMode,
    required this.signalkMaxAttempts,
    required this.outPort,
    required this.signalkIp,
    required this.apPassword,
    required this.adminPassword,
    required this.totalRuntimeMs,
  });

  final double maxPressure1;
  final double minPressure1;
  final double minVdc1;
  final double maxVdc1;
  final double maxPressure2;
  final double minPressure2;
  final double minVdc2;
  final double maxVdc2;
  final int modo;
  final int sensorMode;
  final int signalkMaxAttempts;
  final int outPort;
  final String signalkIp;
  final String apPassword;
  final String adminPassword;
  final int totalRuntimeMs;

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return DeviceSettings(
      maxPressure1: readDouble('maxPressure1'),
      minPressure1: readDouble('minPressure1'),
      minVdc1: readDouble('minVdc1'),
      maxVdc1: readDouble('maxVdc1'),
      maxPressure2: readDouble('maxPressure2'),
      minPressure2: readDouble('minPressure2'),
      minVdc2: readDouble('minVdc2'),
      maxVdc2: readDouble('maxVdc2'),
      modo: readInt('modo'),
      sensorMode: readInt('sensorMode'),
      signalkMaxAttempts: readInt('signalkMaxAttempts'),
      outPort: readInt('outPort'),
      signalkIp: json['signalkIp']?.toString() ?? '0.0.0.0',
      apPassword: json['APpassword']?.toString() ?? '',
      adminPassword: json['adminPassword']?.toString() ?? '',
      totalRuntimeMs: readInt('totalRuntimeMs'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maxPressure1': maxPressure1,
      'minPressure1': minPressure1,
      'minVdc1': minVdc1,
      'maxVdc1': maxVdc1,
      'maxPressure2': maxPressure2,
      'minPressure2': minPressure2,
      'minVdc2': minVdc2,
      'maxVdc2': maxVdc2,
      'modo': modo,
      'sensorMode': sensorMode,
      'signalkMaxAttempts': signalkMaxAttempts,
      'outPort': outPort,
      'signalkIp': signalkIp,
      'APpassword': apPassword,
      'adminPassword': adminPassword,
      'totalRuntimeMs': totalRuntimeMs,
    };
  }
}

class SaveSettingsResult {
  const SaveSettingsResult({
    required this.restartRequired,
    required this.settings,
  });

  final bool restartRequired;
  final DeviceSettings settings;

  factory SaveSettingsResult.fromJson(Map<String, dynamic> json) {
    return SaveSettingsResult(
      restartRequired: json['restartRequired'] == true,
      settings: DeviceSettings.fromJson(
        (json['settings'] as Map<String, dynamic>?) ?? json,
      ),
    );
  }
}

class _PressureSample {
  const _PressureSample({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final double value;
}

class _UdpTelemetryPacket {
  const _UdpTelemetryPacket({
    this.pressure1,
    this.pressure2,
  });

  final double? pressure1;
  final double? pressure2;
}

class DeviceService {
  DeviceService();

  static const Duration timeout = Duration(milliseconds: 3000);
  static const Duration probeTimeout = Duration(milliseconds: 2200);
  final http.Client _client = http.Client();
  String host = '';
  String _adminSessionCookie = '';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString(prefsDeviceHost) ?? '';
  }

  Future<void> saveHost(String value) async {
    host = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsDeviceHost, host);
  }

  Future<DeviceState?> fetchState() async {
    final data = await _fetchJson('/api/state');
    return data == null ? null : DeviceState.fromJson(data);
  }

  Future<DeviceDiagnostics?> fetchDiagnostics() async {
    final data = await _fetchJson('/api/diagnostics');
    return data == null ? null : DeviceDiagnostics.fromJson(data);
  }

  Future<DeviceSettings?> fetchSettings() async {
    final data = await _fetchJson('/api/settings');
    return data == null ? null : DeviceSettings.fromJson(data);
  }

  Future<SaveSettingsResult> saveSettings(DeviceSettings settings) async {
    if (host.isEmpty) {
      throw Exception('Device host is empty');
    }
    if (settings.adminPassword.trim().isEmpty) {
      throw Exception('Admin password is required');
    }

    await _ensureAdminSession(settings.adminPassword.trim());
    var response = await _postSettings(settings);

    if (response.statusCode == 401) {
      _adminSessionCookie = '';
      await _ensureAdminSession(settings.adminPassword.trim());
      response = await _postSettings(settings);
    }

    final jsonBody = _tryDecodeJsonMap(response.body);

    if (response.statusCode != 200 || jsonBody['ok'] == false) {
      throw Exception(
        jsonBody['error']?.toString() ??
            _settingsErrorMessage(response, response.body.trim()),
      );
    }

    return SaveSettingsResult.fromJson(jsonBody);
  }

  Future<http.Response> _postSettings(DeviceSettings settings) {
    return _client
        .post(
          Uri.parse('http://$host/api/settings'),
          headers: _jsonHeaders(),
          body: jsonEncode(settings.toJson()),
        )
        .timeout(timeout);
  }

  Map<String, String> _jsonHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_adminSessionCookie.isNotEmpty) {
      headers['Cookie'] = _adminSessionCookie;
    }
    return headers;
  }

  Future<void> _ensureAdminSession(String password) async {
    if (_adminSessionCookie.isNotEmpty) return;

    final request = http.Request(
      'POST',
      Uri.parse('http://$host/auth/login'),
    );
    request.followRedirects = false;
    request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    request.bodyFields = <String, String>{
      'password': password,
      'next': '/device-settings',
    };

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 302) {
      final rawCookie = response.headers['set-cookie'] ?? '';
      final match = RegExp(r'wm_admin_session=[^;]+').firstMatch(rawCookie);
      if (match != null) {
        _adminSessionCookie = match.group(0) ?? '';
        return;
      }
      throw Exception('Login succeeded but no admin session cookie was returned');
    }

    if (response.statusCode == 403) {
      throw Exception('Invalid admin password');
    }

    throw Exception('Admin login failed (${response.statusCode})');
  }

  Future<List<String>> fetchMonitor(int since) async {
    if (host.isEmpty) return const <String>[];
    try {
      final response = await http
          .get(Uri.parse('http://$host/api/monitor?since=$since'))
          .timeout(timeout);
      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        return const <String>[];
      }
      return response.body
          .trim()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<bool> discover() async {
    final mdns = await _discoverByMdns();
    if (mdns != null) {
      await saveHost(mdns);
      return true;
    }

    final lookup = await _lookupLocalHost();
    if (lookup != null) {
      await saveHost(lookup);
      return true;
    }

    final direct = await _probeHost('watermaker.local');
    if (direct != null) {
      await saveHost(direct);
      return true;
    }

    final prefix = _subnetPrefixFromHint(host);
    if (prefix != null) {
      final scanned = await _scanSubnet(prefix);
      if (scanned != null) {
        await saveHost(scanned);
        return true;
      }
    }

    return false;
  }

  Future<Map<String, dynamic>?> _fetchJson(String path) async {
    if (host.isEmpty) return null;
    try {
      final response =
          await http.get(Uri.parse('http://$host$path')).timeout(timeout);
      if (response.statusCode != 200) return null;
      return _decodeJsonMap(response.body);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final text = body.trim();
    if (text.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  Map<String, dynamic> _tryDecodeJsonMap(String body) {
    try {
      return _decodeJsonMap(body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _settingsErrorMessage(http.Response response, String body) {
    if (response.statusCode == 401) {
      return 'Admin session expired or was rejected by the ESP32';
    }
    if (response.statusCode == 403) {
      return 'Invalid admin password';
    }
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      return 'The ESP32 returned an HTML page instead of JSON';
    }
    if (body.isNotEmpty) {
      return 'Unexpected response from the ESP32';
    }
    return 'Error saving settings';
  }

  Future<String?> _discoverByMdns() async {
    try {
      final client = MDnsClient(
        rawDatagramSocketFactory: (
          dynamic host,
          int port, {
          bool? reuseAddress,
          bool? reusePort,
          int? ttl,
        }) {
          return RawDatagramSocket.bind(
            host,
            port,
            reuseAddress: reuseAddress ?? true,
            reusePort: reusePort ?? false,
            ttl: ttl ?? 255,
          );
        },
      );
      await client.start();

      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_http._tcp.local'),
        timeout: const Duration(seconds: 4),
      )) {
        if (!ptr.domainName.toLowerCase().contains('watermaker')) continue;

        final hostname =
            '${ptr.domainName.replaceAll(RegExp(r'\._http\._tcp\.local\.?$', caseSensitive: false), '')}.local';

        await for (final IPAddressResourceRecord ip
            in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(hostname),
          timeout: const Duration(seconds: 3),
        )) {
          client.stop();
          return ip.address.address;
        }
      }

      client.stop();
    } catch (_) {}
    return null;
  }

  Future<String?> _scanSubnet(String prefix) async {
    const int batchSize = 16;
    for (int start = 1; start < 255; start += batchSize) {
      final end = math.min(start + batchSize, 255);
      final futures = <Future<String?>>[];
      for (int i = start; i < end; i++) {
        futures.add(_probeHost('$prefix.$i'));
      }
      final results = await Future.wait(futures);
      for (final hit in results) {
        if (hit != null) return hit;
      }
    }
    return null;
  }

  Future<String?> _lookupLocalHost() async {
    try {
      final addrs = await InternetAddress.lookup('watermaker.local')
          .timeout(const Duration(seconds: 4));
      if (addrs.isNotEmpty) {
        return addrs.first.address;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _probeHost(String candidate) async {
    try {
      final response = await http
          .get(Uri.parse('http://$candidate/api/state'))
          .timeout(probeTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if ((data['device']?.toString() ?? '').contains('pressure-sensor')) {
        return candidate;
      }
    } catch (_) {}
    return null;
  }

  bool _isIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    return parts.every((part) => int.tryParse(part) != null);
  }

  String? _subnetPrefixFromHint(String hint) {
    if (!_isIpv4(hint)) return null;
    final parts = hint.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}

class PressureSensorApp extends StatelessWidget {
  const PressureSensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pressure Sensor',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.panel,
        ),
        useMaterial3: true,
      ),
      home: const PressureHome(),
    );
  }
}

class PressureHome extends StatefulWidget {
  const PressureHome({super.key});

  @override
  State<PressureHome> createState() => _PressureHomeState();
}

class _PressureHomeState extends State<PressureHome> {
  final DeviceService _service = DeviceService();
  final List<_PressureSample> _lowHistory = <_PressureSample>[];
  final List<_PressureSample> _highHistory = <_PressureSample>[];
  Timer? _pollTimer;
  RawDatagramSocket? _udpSocket;
  StreamSubscription<RawSocketEvent>? _udpSubscription;
  DeviceState? _state;
  bool _discovering = false;
  bool _bootstrapping = true;
  bool _refreshing = false;
  bool _online = false;
  bool _showRssiDbm = false;
  bool _useHttpFallback = false;
  DateTime? _lastValidReadingAt;
  DateTime? _lastUdpAt;
  int _udpPort = defaultUdpPort;
  String _lastKnownDeviceIp = '';
  double? _udpPressure1;
  double? _udpPressure2;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _udpSubscription?.cancel();
    _udpSocket?.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _showRssiDbm = prefs.getBool(prefsShowRssiDbm) ?? false;
    await _service.load();

    if (_service.host.isEmpty) {
      await _rediscover();
    } else {
      await _refresh();
    }

    _pollTimer = Timer.periodic(
      statePollInterval,
      (_) => _checkUdpAndFallback(),
    );

    if (!mounted) return;
    setState(() {
      _bootstrapping = false;
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final state = await _service.fetchState();
    if (!mounted) {
      _refreshing = false;
      return;
    }

    if (state == null) {
      setState(() {
        _state = null;
        _online = false;
        _udpPressure1 = null;
        _udpPressure2 = null;
        _useHttpFallback = false;
      });
      _refreshing = false;
      return;
    }

    _lastKnownDeviceIp = state.localIp;
    await _ensureUdpListener(state.udpPort);
    if (!mounted) {
      _refreshing = false;
      return;
    }

    if (_udpPressure1 == null || _udpPressure2 == null) {
      _recordPressureHistoryValues(state.pressure1, state.pressure2);
    }

    setState(() {
      _state = state;
      _online = true;
      _useHttpFallback = true;
      if (state.dataValid) {
        _lastValidReadingAt = DateTime.now();
        _lastUdpAt = DateTime.now();
      }
    });
    _refreshing = false;
  }

  Future<void> _ensureUdpListener(int port) async {
    if (_udpSocket != null && _udpPort == port) return;

    await _udpSubscription?.cancel();
    _udpSocket?.close();

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: true,
    );

    _udpSocket = socket;
    _udpPort = port;
    _udpSubscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      _handleUdpDatagram(datagram);
    });
  }

  void _handleUdpDatagram(Datagram datagram) {
    if (!mounted) return;
    if (_lastKnownDeviceIp.isNotEmpty &&
        datagram.address.address != _lastKnownDeviceIp) {
      return;
    }

    final packet = _parseUdpPacket(datagram.data);
    if (packet == null) return;

    final low = packet.pressure1 ?? _udpPressure1;
    final high = packet.pressure2 ?? _udpPressure2;
    if (low == null || high == null) return;

    _recordPressureHistoryValues(low, high);

    setState(() {
      _udpPressure1 = low;
      _udpPressure2 = high;
      _lastUdpAt = DateTime.now();
      _useHttpFallback = false;
      if (_state != null) {
        _online = true;
      }
      if (_state?.dataValid == true) {
        _lastValidReadingAt = DateTime.now();
      }
    });
  }

  void _checkUdpAndFallback() {
    if (_lastUdpAt == null) {
      _refresh();
      return;
    }
    final sinceLastUdp = DateTime.now().difference(_lastUdpAt!);
    if (sinceLastUdp > statePollInterval) {
      _refresh();
    }
  }

  _UdpTelemetryPacket? _parseUdpPacket(List<int> data) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map<String, dynamic>) return null;
      final updates = decoded['updates'];
      if (updates is! List) return null;

      double? low;
      double? high;
      for (final update in updates) {
        if (update is! Map<String, dynamic>) continue;
        final values = update['values'];
        if (values is! List) continue;
        for (final value in values) {
          if (value is! Map<String, dynamic>) continue;
          final path = value['path']?.toString() ?? '';
          final numeric = (value['value'] as num?)?.toDouble();
          if (numeric == null) continue;
          if (path == 'environment.watermaker.pressure.low') {
            low = numeric;
          } else if (path == 'environment.watermaker.pressure.high') {
            high = numeric;
          }
        }
      }

      if (low == null && high == null) return null;
      return _UdpTelemetryPacket(pressure1: low, pressure2: high);
    } catch (_) {
      return null;
    }
  }

  void _recordPressureHistoryValues(double low, double high) {
    final now = DateTime.now();
    if (low > 0) {
      _lowHistory.add(_PressureSample(timestamp: now, value: low));
    }
    if (high > 0) {
      _highHistory.add(_PressureSample(timestamp: now, value: high));
    }
    _prunePressureHistory(_lowHistory, now);
    _prunePressureHistory(_highHistory, now);
  }

  void _prunePressureHistory(List<_PressureSample> history, DateTime now) {
    final cutoff = now.subtract(const Duration(minutes: 5));
    while (history.isNotEmpty && history.first.timestamp.isBefore(cutoff)) {
      history.removeAt(0);
    }
  }

  ({double min, double max})? _historyRange(
    List<_PressureSample> history,
    double rangeMin,
    double rangeMax,
  ) {
    if (history.isEmpty) return null;
    var minValue = history.first.value;
    var maxValue = history.first.value;
    for (final sample in history.skip(1)) {
      if (sample.value < minValue) minValue = sample.value;
      if (sample.value > maxValue) maxValue = sample.value;
    }
    return (
      min: minValue.clamp(rangeMin, rangeMax).toDouble(),
      max: maxValue.clamp(rangeMin, rangeMax).toDouble(),
    );
  }

  Future<void> _rediscover() async {
    if (_discovering) return;
    setState(() {
      _discovering = true;
    });
    final found = await _service.discover();
    if (!mounted) return;
    setState(() {
      _discovering = false;
    });
    if (found) {
      await _refresh();
    }
  }

  Future<void> _promptHost() async {
    final controller = TextEditingController(
      text: _service.host.isEmpty ? 'watermaker.local' : _service.host,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Device address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: '192.168.x.x or watermaker.local',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await _service.saveHost(result);
    await _refresh();
  }

  Future<void> _openDevicePath(String path) async {
    if (_service.host.isEmpty) return;
    final uri = Uri.parse('http://${_service.host}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleRssiDisplay() async {
    final next = !_showRssiDbm;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsShowRssiDbm, next);
    if (!mounted) return;
    setState(() {
      _showRssiDbm = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2336), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: _bootstrapping
              ? const _StartupScreen()
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _TopBar(
                        connected: _online,
                        signalkAlive: state?.signalkAlive ?? false,
                        signalkKnown: (state?.signalkIp ?? '0.0.0.0') != '0.0.0.0',
                        rssi: state?.rssi,
                        showRssiValue: _showRssiDbm,
                        useHttpFallback: _useHttpFallback,
                        onStatusTap: _showStatusDetails,
                        onWifiTap: _toggleRssiDisplay,
                        onSettingsTap: _showToolsSheet,
                      ),
                      const SizedBox(height: 8),
                      _HeroCard(
                        online: _online,
                        running: state?.systemRunning ?? false,
                        title: _heroTitle(state),
                        sessionRuntime: _formatDuration(state?.partialRuntimeMs ?? 0),
                        totalRuntime: _formatHours(state?.totalRuntimeMs ?? 0),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: state == null
                            ? _EmptyState(
                                discovering: _discovering,
                                onDiscover: _rediscover,
                                onSetHost: _promptHost,
                              )
                            : RefreshIndicator(
                                color: AppColors.accent,
                                onRefresh: _refresh,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    PressureCard.low(
                                      state: _stateWithDisplayedPressures(state),
                                      historyRange: _historyRange(_lowHistory, 0, 4),
                                    ),
                                    const SizedBox(height: 8),
                                    PressureCard.high(
                                      state: _stateWithDisplayedPressures(state),
                                      historyRange: _historyRange(_highHistory, 0, 70),
                                    ),
                                    const SizedBox(height: 8),
                                    _InfoStrip(
                                      detail: _formatLastReading(_lastValidReadingAt),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _heroTitle(DeviceState? state) {
    if (state == null || !_online) return 'Waiting for pressure';
    if (!state.dataValid && state.deviceError.isNotEmpty) return state.deviceError;
    if (!state.dataValid) return 'System idle';
    if (state.systemRunning && _displayPressure2(state) >= 60) {
      return 'High pressure out of range';
    }
    if (state.systemRunning) return 'System active';
    return 'System idle';
  }

  Future<void> _showToolsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panelSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tools',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Diagnostics and live monitor for this ESP32.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  _sheetButton(
                    'Device diagnostics',
                    _service.host.isEmpty
                        ? null
                        : () => _openNativePage(
                              DiagnosticsPage(service: _service),
                            ),
                  ),
                  _sheetButton(
                    'SignalK monitor',
                    _service.host.isEmpty
                        ? null
                        : () => _openNativePage(
                              MonitorPage(service: _service),
                            ),
                  ),
                  _sheetButton(
                    'Device settings',
                    _service.host.isEmpty
                        ? null
                        : () => _openNativePage(
                              SettingsPage(service: _service),
                            ),
                  ),
                  _sheetButton(
                    'Settings menu (web)',
                    _service.host.isEmpty ? null : () => _openDevicePath('/config'),
                  ),
                  _sheetButton(
                    'Firmware update',
                    _service.host.isEmpty ? null : () => _openDevicePath('/update'),
                  ),
                  _sheetButton(
                    'Filesystem update',
                    _service.host.isEmpty ? null : () => _openDevicePath('/updatefs'),
                  ),
                  _sheetButton(
                    'Factory reset',
                    _service.host.isEmpty ? null : () => _openDevicePath('/factory'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connection',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sheetButton(
                    'Set device address',
                    () async {
                      Navigator.of(context).pop();
                      await _promptHost();
                    },
                  ),
                  _sheetButton(
                    _discovering ? 'Discovering...' : 'Rediscover device',
                    _discovering
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _rediscover();
                          },
                  ),
                  _sheetButton(
                    'Open web dashboard',
                    _service.host.isEmpty ? null : () => _openDevicePath('/'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNativePage(Widget page) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await _refresh();
  }

  Widget _sheetButton(String label, Future<void> Function()? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap == null
              ? null
              : () async {
                  await onTap();
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bg2,
            foregroundColor: AppColors.text,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  void _showStatusDetails() {
    final state = _state;
    final lines = <String>[
      'FW: ${state?.firmwareVersion ?? '--'}',
      'UI: $uiVersion',
      'Host: ${_service.host.isEmpty ? '--' : _service.host}',
      'UDP telemetry: ${(state?.udpEnabled ?? false) ? 'ready' : 'stopped'}',
      'SignalK: ${(state != null && state.signalkAlive) ? 'active' : 'no response'}',
    ];
    if (state != null && state.deviceError.isNotEmpty) {
      lines.add('Device: ${state.deviceError}');
    } else if (_online) {
      lines.add('No device errors detected');
    } else {
      lines.add('No valid device data');
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Status'),
        content: Text(lines.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSec = math.max(0, ms ~/ 1000);
    if (totalSec < 60) return '${totalSec}s';
    final totalMin = totalSec ~/ 60;
    if (totalMin < 60) return '$totalMin min';
    final totalHr = totalMin ~/ 60;
    if (totalHr < 24) return '$totalHr h';
    return '${totalHr ~/ 24} d';
  }

  String _formatHours(int ms) => '${(ms / 3600000).toStringAsFixed(1)} h';

  String _formatLastReading(DateTime? value) {
    if (value == null) return '--:--:--';
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    final ss = value.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  DeviceState _stateWithDisplayedPressures(DeviceState state) {
    final low = _displayPressure1(state);
    final high = _displayPressure2(state);
    return DeviceState(
      device: state.device,
      firmwareVersion: state.firmwareVersion,
      hostname: state.hostname,
      wifiConnected: state.wifiConnected,
      localIp: state.localIp,
      apIp: state.apIp,
      rssi: state.rssi,
      sensorMode: state.sensorMode,
      adsFound: state.adsFound,
      dataValid: state.dataValid,
      systemRunning: state.systemRunning,
      deviceError: state.deviceError,
      pressure1: low,
      pressure2: high,
      voltage1: state.voltage1,
      voltage2: state.voltage2,
      signalkIp: state.signalkIp,
      signalkAlive: state.signalkAlive,
      signalkServicePort: state.signalkServicePort,
      udpPort: state.udpPort,
      udpEnabled: state.udpEnabled,
      partialRuntimeMs: state.partialRuntimeMs,
      totalRuntimeMs: state.totalRuntimeMs,
      uptimeMs: state.uptimeMs,
    );
  }

  double _displayPressure1(DeviceState state) => _udpPressure1 ?? state.pressure1;

  double _displayPressure2(DeviceState state) => _udpPressure2 ?? state.pressure2;
}

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.service});

  final DeviceService service;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Timer? _timer;
  DeviceDiagnostics? _data;
  bool _loading = true;

  static const List<MapEntry<String, String>> _fields = [
    MapEntry('Firmware', 'firmwareVersion'),
    MapEntry('Mode', 'sensorMode'),
    MapEntry('Device error', 'deviceError'),
    MapEntry('WiFi connected', 'wifiConnected'),
    MapEntry('SSID', 'ssid'),
    MapEntry('Hostname', 'hostname'),
    MapEntry('Local IP', 'localIp'),
    MapEntry('AP IP', 'apIp'),
    MapEntry('MAC', 'mac'),
    MapEntry('RSSI', 'rssi'),
    MapEntry('SignalK diagnostic IP', 'signalkIp'),
    MapEntry('SignalK alive', 'signalkAlive'),
    MapEntry('SignalK HTTP port', 'signalkServicePort'),
    MapEntry('UDP broadcast port', 'udpPort'),
    MapEntry('ADS1115', 'adsFound'),
    MapEntry('Voltage 1', 'voltage1'),
    MapEntry('Voltage 2', 'voltage2'),
    MapEntry('Pressure 1', 'pressure1'),
    MapEntry('Pressure 2', 'pressure2'),
    MapEntry('Heap free', 'heapFree'),
    MapEntry('Heap min', 'heapMin'),
    MapEntry('CPU', 'cpuMHz'),
    MapEntry('Chip model', 'chipModel'),
    MapEntry('Chip revision', 'chipRevision'),
    MapEntry('Chip cores', 'chipCores'),
    MapEntry('Flash size', 'flashSize'),
    MapEntry('Sketch size', 'sketchSize'),
    MapEntry('Free sketch', 'freeSketchSpace'),
    MapEntry('Uptime', 'uptimeMs'),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await widget.service.fetchDiagnostics();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        title: const Text('Device diagnostics'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2336), AppColors.bg],
          ),
        ),
        child: _loading && _data == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 980
                        ? 4
                        : width >= 720
                        ? 3
                        : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 92,
                      ),
                      itemCount: _fields.length,
                      itemBuilder: (context, index) {
                        final field = _fields[index];
                        return _DiagTile(
                          label: field.key,
                          value: _formatDiagnosticsValue(
                            field.value,
                            _data?[field.value],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _formatDiagnosticsValue(String key, dynamic value) {
    if (value == null || value.toString().isEmpty) return '--';
    if (key == 'uptimeMs') return _formatDuration((value as num).toInt());
    if (['heapFree', 'heapMin', 'flashSize', 'sketchSize', 'freeSketchSpace']
        .contains(key)) {
      return '${((value as num).toDouble() / 1024).round()} KB';
    }
    if (key == 'rssi') return '$value dBm';
    if (key == 'cpuMHz') return '$value MHz';
    if (key == 'voltage1' || key == 'voltage2') {
      return '${(value as num).toDouble().toStringAsFixed(3)} V';
    }
    if (key == 'pressure1' || key == 'pressure2') {
      return '${(value as num).toDouble().toStringAsFixed(1)} bar';
    }
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString();
  }

  String _formatDuration(int ms) {
    final totalSec = math.max(0, ms ~/ 1000);
    if (totalSec < 60) return '${totalSec}s';
    final totalMin = totalSec ~/ 60;
    if (totalMin < 60) return '$totalMin min';
    final totalHr = totalMin ~/ 60;
    if (totalHr < 24) return '$totalHr h';
    return '${totalHr ~/ 24} d';
  }
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key, required this.service});

  final DeviceService service;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final List<String> _lines = <String>[];
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  int _since = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final lines = await widget.service.fetchMonitor(_since);
    if (!mounted) return;
    if (lines.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    for (final line in lines) {
      final split = line.indexOf('\t');
      if (split <= 0) continue;
      final seq = int.tryParse(line.substring(0, split));
      if (seq != null) {
        _since = seq + 1;
      }
      _lines.add(line.substring(split + 1));
    }

    if (_lines.length > 400) {
      _lines.removeRange(0, _lines.length - 400);
    }

    setState(() {
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031508),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07210F),
        title: const Text('SignalK monitor'),
      ),
      body: _loading && _lines.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _lines[index],
                    style: const TextStyle(
                      color: Color(0xFF5DFF83),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.service});

  final DeviceService service;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _maxPressure1Controller = TextEditingController();
  final _minPressure1Controller = TextEditingController();
  final _minVdc1Controller = TextEditingController();
  final _maxVdc1Controller = TextEditingController();
  final _maxPressure2Controller = TextEditingController();
  final _minPressure2Controller = TextEditingController();
  final _minVdc2Controller = TextEditingController();
  final _maxVdc2Controller = TextEditingController();
  final _signalkMaxAttemptsController = TextEditingController();
  final _outPortController = TextEditingController();
  final _totalRuntimeHoursController = TextEditingController();
  final _signalkIpController = TextEditingController();
  final _apPasswordController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int _modo = 1;
  int _sensorMode = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maxPressure1Controller.dispose();
    _minPressure1Controller.dispose();
    _minVdc1Controller.dispose();
    _maxVdc1Controller.dispose();
    _maxPressure2Controller.dispose();
    _minPressure2Controller.dispose();
    _minVdc2Controller.dispose();
    _maxVdc2Controller.dispose();
    _signalkMaxAttemptsController.dispose();
    _outPortController.dispose();
    _totalRuntimeHoursController.dispose();
    _signalkIpController.dispose();
    _apPasswordController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.service.fetchSettings();
    if (!mounted) return;
    if (settings == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    _maxPressure1Controller.text = _formatDecimal(settings.maxPressure1);
    _minPressure1Controller.text = _formatDecimal(settings.minPressure1);
    _minVdc1Controller.text = _formatDecimal(settings.minVdc1);
    _maxVdc1Controller.text = _formatDecimal(settings.maxVdc1);
    _maxPressure2Controller.text = _formatDecimal(settings.maxPressure2);
    _minPressure2Controller.text = _formatDecimal(settings.minPressure2);
    _minVdc2Controller.text = _formatDecimal(settings.minVdc2);
    _maxVdc2Controller.text = _formatDecimal(settings.maxVdc2);
    _signalkMaxAttemptsController.text = settings.signalkMaxAttempts.toString();
    _outPortController.text = settings.outPort.toString();
    _totalRuntimeHoursController.text =
        (settings.totalRuntimeMs / 3600000).toStringAsFixed(1);
    _signalkIpController.text = settings.signalkIp;
    _apPasswordController.text = settings.apPassword;
    _adminPasswordController.text = settings.adminPassword;

    setState(() {
      _modo = settings.modo;
      _sensorMode = settings.sensorMode;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final result = await widget.service.saveSettings(
        DeviceSettings(
          maxPressure1: _readDouble(_maxPressure1Controller),
          minPressure1: _readDouble(_minPressure1Controller),
          minVdc1: _readDouble(_minVdc1Controller),
          maxVdc1: _readDouble(_maxVdc1Controller),
          maxPressure2: _readDouble(_maxPressure2Controller),
          minPressure2: _readDouble(_minPressure2Controller),
          minVdc2: _readDouble(_minVdc2Controller),
          maxVdc2: _readDouble(_maxVdc2Controller),
          modo: _modo,
          sensorMode: _sensorMode,
          signalkMaxAttempts: _readInt(_signalkMaxAttemptsController),
          outPort: _readInt(_outPortController),
          signalkIp: _signalkIpController.text.trim(),
          apPassword: _apPasswordController.text.trim(),
          adminPassword: _adminPasswordController.text.trim(),
          totalRuntimeMs: (_readDouble(_totalRuntimeHoursController) * 3600000)
              .round(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.restartRequired
                ? 'Settings saved. The ESP32 will restart.'
                : 'Settings saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        title: const Text('Device settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2336), AppColors.bg],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _SettingsSection(
                      title: 'Sensor 1',
                      child: Column(
                        children: [
                          _settingsField(
                            controller: _minPressure1Controller,
                            label: 'Min pressure',
                          ),
                          _settingsField(
                            controller: _maxPressure1Controller,
                            label: 'Max pressure',
                          ),
                          _settingsField(
                            controller: _minVdc1Controller,
                            label: 'Min Vdc',
                          ),
                          _settingsField(
                            controller: _maxVdc1Controller,
                            label: 'Max Vdc',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSection(
                      title: 'Sensor 2',
                      child: Column(
                        children: [
                          _settingsField(
                            controller: _minPressure2Controller,
                            label: 'Min pressure',
                          ),
                          _settingsField(
                            controller: _maxPressure2Controller,
                            label: 'Max pressure',
                          ),
                          _settingsField(
                            controller: _minVdc2Controller,
                            label: 'Min Vdc',
                          ),
                          _settingsField(
                            controller: _maxVdc2Controller,
                            label: 'Max Vdc',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSection(
                      title: 'System',
                      child: Column(
                        children: [
                          _settingsDropdown(
                            label: 'WiFi mode',
                            value: _modo,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('AP')),
                              DropdownMenuItem(value: 1, child: Text('AP + STA')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _modo = value;
                              });
                            },
                          ),
                          _settingsDropdown(
                            label: 'Sensor mode',
                            value: _sensorMode,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Real')),
                              DropdownMenuItem(value: 1, child: Text('Demo')),
                              DropdownMenuItem(
                                value: 2,
                                child: Text('Demo + UDP'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _sensorMode = value;
                              });
                            },
                          ),
                          _settingsField(
                            controller: _signalkMaxAttemptsController,
                            label: 'SignalK max attempts',
                            isInteger: true,
                          ),
                          _settingsField(
                            controller: _outPortController,
                            label: 'UDP broadcast port',
                            isInteger: true,
                          ),
                          _settingsField(
                            controller: _totalRuntimeHoursController,
                            label: 'Total runtime (h)',
                          ),
                          _settingsField(
                            controller: _signalkIpController,
                            label: 'SignalK diagnostic IP',
                            keyboardType: TextInputType.text,
                            allowEmpty: true,
                            validator: _validateIp,
                          ),
                          _settingsField(
                            controller: _apPasswordController,
                            label: 'AP password',
                            keyboardType: TextInputType.text,
                            allowEmpty: true,
                            validator: (_) => null,
                          ),
                          _settingsField(
                            controller: _adminPasswordController,
                            label: 'Admin password',
                            keyboardType: TextInputType.text,
                            validator: _validateAdminPassword,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(_saving ? 'Saving...' : 'Save settings'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app now uses HTTP for settings and diagnostics, while pressure telemetry can arrive by UDP broadcast.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _settingsField({
    required TextEditingController controller,
    required String label,
    bool isInteger = false,
    TextInputType? keyboardType,
    bool allowEmpty = false,
    String? Function(String text)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType:
            keyboardType ??
            TextInputType.numberWithOptions(
              decimal: !isInteger,
              signed: false,
            ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return allowEmpty ? null : 'Required';
          if (validator != null) return validator(text);
          return isInteger ? _validateInt(text) : _validateDouble(text);
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _settingsDropdown({
    required String label,
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  String? _validateDouble(String text) =>
      double.tryParse(text.replaceAll(',', '.')) == null ? 'Invalid number' : null;

  String? _validateInt(String text) =>
      int.tryParse(text) == null ? 'Invalid number' : null;

  String? _validateIp(String text) {
    if (text == '0.0.0.0') return null;
    final parts = text.split('.');
    if (parts.length != 4) return 'Invalid IP';
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return 'Invalid IP';
      }
    }
    return null;
  }

  String? _validateAdminPassword(String text) {
    if (text.length < 8) return 'Minimum 8 characters';
    if (text.length > 20) return 'Maximum 20 characters';
    return null;
  }

  double _readDouble(TextEditingController controller) {
    return double.parse(controller.text.trim().replaceAll(',', '.'));
  }

  int _readInt(TextEditingController controller) {
    return int.parse(controller.text.trim());
  }

  String _formatDecimal(double value) => value.toStringAsFixed(3);
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.connected,
    required this.signalkAlive,
    required this.signalkKnown,
    required this.rssi,
    required this.showRssiValue,
    required this.useHttpFallback,
    required this.onStatusTap,
    required this.onWifiTap,
    required this.onSettingsTap,
  });

  final bool connected;
  final bool signalkAlive;
  final bool signalkKnown;
  final int? rssi;
  final bool showRssiValue;
  final bool useHttpFallback;
  final VoidCallback onStatusTap;
  final VoidCallback onWifiTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactLayoutBreakpoint;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MAB Systems',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF89B2CC),
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: compact ? 1.2 : 1.8,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'WaterMaker',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );

        final settingsButton = InkWell(
          onTap: onSettingsTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.text),
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 9 : 10,
          ),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              if (useHttpFallback)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.warn.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'HTTP',
                    style: TextStyle(
                      color: AppColors.warn,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (useHttpFallback) const SizedBox(width: 6),
              _StatusPill(
                connected: connected,
                onTap: onStatusTap,
                compact: compact,
              ),
              const SizedBox(width: 6),
              _SkPill(active: signalkKnown && signalkAlive, compact: compact),
              const SizedBox(width: 6),
              _WifiPill(
                rssi: rssi,
                showValue: showRssiValue,
                onTap: onWifiTap,
                compact: compact,
              ),
              const SizedBox(width: 6),
              settingsButton,
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.online,
    required this.running,
    required this.title,
    required this.sessionRuntime,
    required this.totalRuntime,
  });

  final bool online;
  final bool running;
  final String title;
  final String sessionRuntime;
  final String totalRuntime;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactLayoutBreakpoint;
        final metricGap = compact ? 6.0 : 8.0;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Partial runtime',
                      value: sessionRuntime,
                      sub: running ? 'System running' : 'System stopped',
                      compact: compact,
                    ),
                  ),
                  SizedBox(width: metricGap),
                  Expanded(
                    child: _MetricCard(
                      label: 'Total runtime',
                      value: totalRuntime,
                      sub: 'Accumulated on device',
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    this.compact = false,
  });

  final String label;
  final String value;
  final String sub;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Ultima lectura',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            detail,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3C57), AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.28),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.text,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'WaterMaker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preparing diagnostics and pressure telemetry...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0x1FFFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PressureCard extends StatelessWidget {
  const PressureCard({
    super.key,
    required this.title,
    required this.value,
    required this.rangeMin,
    required this.rangeMax,
    required this.zones,
    required this.status,
    required this.stateText,
    this.historyRange,
  });

  factory PressureCard.low({
    required DeviceState state,
    ({double min, double max})? historyRange,
  }) {
    final bounded = state.pressure1.clamp(0.0, 4.0);
    final zone = _zoneForValue(
      bounded,
      const [
        ZoneSpec(0, 1, AppColors.warn),
        ZoneSpec(1, 3, AppColors.ok),
        ZoneSpec(3, 4, AppColors.danger),
      ],
    );
    return PressureCard(
      title: 'Presion de entrada',
      value: bounded.toDouble(),
      rangeMin: 0,
      rangeMax: 4,
      zones: const [
        ZoneSpec(0, 1, AppColors.warn),
        ZoneSpec(1, 3, AppColors.ok),
        ZoneSpec(3, 4, AppColors.danger),
      ],
      status: zone.label,
      stateText: zone.state,
      historyRange: historyRange,
    );
  }

  factory PressureCard.high({
    required DeviceState state,
    ({double min, double max})? historyRange,
  }) {
    final bounded = state.pressure2.clamp(0.0, 70.0);
    final zone = _zoneForValue(
      bounded,
      const [
        ZoneSpec(0, 50, AppColors.warn),
        ZoneSpec(50, 57, AppColors.ok),
        ZoneSpec(57, 60, AppColors.warn),
        ZoneSpec(60, 70, AppColors.danger),
      ],
    );
    return PressureCard(
      title: 'Presion principal',
      value: bounded.toDouble(),
      rangeMin: 0,
      rangeMax: 70,
      zones: const [
        ZoneSpec(0, 50, AppColors.warn),
        ZoneSpec(50, 57, AppColors.ok),
        ZoneSpec(57, 60, AppColors.warn),
        ZoneSpec(60, 70, AppColors.danger),
      ],
      status: zone.label,
      stateText: zone.state,
      historyRange: historyRange,
    );
  }

  final String title;
  final double value;
  final double rangeMin;
  final double rangeMax;
  final List<ZoneSpec> zones;
  final String status;
  final String stateText;
  final ({double min, double max})? historyRange;

  @override
  Widget build(BuildContext context) {
    final progress =
        ((value - rangeMin) / (rangeMax - rangeMin)).clamp(0.0, 1.0);
    final historyMin = historyRange?.min;
    final historyMax = historyRange?.max;
    final statusColor = _statusColor(status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactLayoutBreakpoint;
        final valueFontSize = compact ? 44.0 : 58.0;
        final unitFontSize = compact ? 16.0 : 20.0;
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  badge,
                ],
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: valueFontSize,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    TextSpan(
                      text: ' BAR',
                      style: TextStyle(
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(color: AppColors.line),
                ),
                child: Stack(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(999),
                            bottomLeft: Radius.circular(999),
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.75),
                              statusColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (historyMin != null)
                      _RangeMarker(
                        leftFactor: ((historyMin - rangeMin) / (rangeMax - rangeMin))
                            .clamp(0.0, 1.0),
                      ),
                    if (historyMax != null)
                      _RangeMarker(
                        leftFactor: ((historyMax - rangeMin) / (rangeMax - rangeMin))
                            .clamp(0.0, 1.0),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  children: zones
                      .map(
                        (zone) => Expanded(
                          flex: math.max(1, ((zone.to - zone.from) * 100).round()),
                          child: Container(
                            height: 4,
                            color: zone.color.withValues(alpha: 0.8),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: $stateText',
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeMarker extends StatelessWidget {
  const _RangeMarker({required this.leftFactor});

  final double leftFactor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment((leftFactor * 2) - 1, 0),
        child: Container(
          width: 2,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.26),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagTile extends StatelessWidget {
  const _DiagTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.discovering,
    required this.onDiscover,
    required this.onSetHost,
  });

  final bool discovering;
  final Future<void> Function() onDiscover;
  final Future<void> Function() onSetHost;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_rounded, color: AppColors.accent, size: 42),
            const SizedBox(height: 14),
            const Text(
              'No device connected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Discover your Watermaker on the local network or set the device address manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: discovering ? null : onDiscover,
              child: Text(discovering ? 'Discovering...' : 'Discover device'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onSetHost,
              child: const Text('Set address manually'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.connected,
    required this.onTap,
    this.compact = false,
  });

  final bool connected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.ok : AppColors.danger;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: compact ? 34 : 42,
        height: compact ? 34 : 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 14),
          ],
        ),
        child: Container(
          width: compact ? 10 : 12,
          height: compact ? 10 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkPill extends StatelessWidget {
  const _SkPill({required this.active, this.compact = false});

  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ok : AppColors.danger;
    return Container(
      width: compact ? 34 : 42,
      height: compact ? 34 : 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 14),
        ],
      ),
      child: Text(
        'SK',
        style: TextStyle(
          color: active ? const Color(0xFFD9FFE7) : const Color(0xFFFFD3D3),
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WifiPill extends StatelessWidget {
  const _WifiPill({
    required this.rssi,
    required this.showValue,
    required this.onTap,
    this.compact = false,
  });

  final int? rssi;
  final bool showValue;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final level = _wifiLevel(rssi);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: compact ? 34 : 42,
        padding: EdgeInsets.symmetric(
          horizontal: showValue ? (compact ? 8 : 10) : (compact ? 10 : 12),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showValue)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (index) {
                  final active = index < level;
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Container(
                      width: compact ? 3.5 : 4,
                      height: compact ? [4.0, 7.0, 10.0, 12.0][index] : [5.0, 8.0, 11.0, 14.0][index],
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: active
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  );
                }),
              ),
            if (showValue)
              Text(
                rssi == null ? '--' : '$rssi dBm',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: compact ? 11 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _wifiLevel(int? value) {
    if (value == null) return 0;
    if (value >= -55) return 4;
    if (value >= -67) return 3;
    if (value >= -75) return 2;
    if (value >= -85) return 1;
    return 0;
  }
}

class ZoneSpec {
  const ZoneSpec(this.from, this.to, this.color);

  final double from;
  final double to;
  final Color color;
}

class ZoneState {
  const ZoneState(this.label, this.state);

  final String label;
  final String state;
}

ZoneState _zoneForValue(double value, List<ZoneSpec> zones) {
  for (final zone in zones) {
    if (value >= zone.from && value <= zone.to) {
      if (zone.color == AppColors.ok) {
        return const ZoneState('Normal', 'Stable');
      }
      if (zone.color == AppColors.danger) {
        return const ZoneState('Alarm', 'High');
      }
      return const ZoneState('Warning', 'Caution');
    }
  }
  return const ZoneState('Idle', 'No range');
}

Color _statusColor(String status) {
  switch (status) {
    case 'Normal':
      return AppColors.ok;
    case 'Alarm':
      return AppColors.danger;
    default:
      return AppColors.warn;
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    color: AppColors.panel.withValues(alpha: 0.94),
    border: Border.all(color: AppColors.line),
    boxShadow: const [
      BoxShadow(
        color: Color(0x44000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
  );
}
