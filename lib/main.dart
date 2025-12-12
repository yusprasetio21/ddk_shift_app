// lib/main.dart - GTS Shift DDK Optimized Version (Fixed Single File Output)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GtsApp());
}

class GtsApp extends StatefulWidget {
  const GtsApp({super.key});

  @override
  State<GtsApp> createState() => _GtsAppState();
}

class _GtsAppState extends State<GtsApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  
  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DDK Shift GTS',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: HomePage(
        toggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      fontFamily: 'Inter',
      useMaterial3: false,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2196F3),
        secondary: Color(0xFF9C27B0),
        background: Color(0xFFF5F5F5),
        surface: Color(0xFFFFFFFF),
        onBackground: Color(0xFF333333),
        onSurface: Color(0xFF333333),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFF333333),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      fontFamily: 'Inter',
      useMaterial3: false,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF2196F3),
        secondary: Color(0xFF9C27B0),
        background: Color(0xFF0A0A2A),
        surface: Color(0xFF1A1A3A),
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

/// History item model
class HistoryItem {
  String id;
  String content;
  String filename;
  String status;
  String note;
  String createdAt;
  
  HistoryItem({
    required this.id,
    required this.content,
    required this.filename,
    required this.status,
    required this.note,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'filename': filename,
    'status': status,
    'note': note,
    'createdAt': createdAt,
  };
  
  static HistoryItem fromJson(Map<String, dynamic> j) => HistoryItem(
    id: j['id'],
    content: j['content'],
    filename: j['filename'],
    status: j['status'],
    note: j['note'],
    createdAt: j['createdAt'],
  );
  
  Color get statusColor {
    switch (status) {
      case 'success': return const Color(0xFF00C853);
      case 'pending': return const Color(0xFFFF6D00);
      case 'duplicate': return const Color(0xFF9C27B0);
      case 'log': return const Color(0xFF757575);
      default: return const Color(0xFF2196F3);
    }
  }
  
  IconData get statusIcon {
    switch (status) {
      case 'success': return Icons.check_circle;
      case 'pending': return Icons.pending_actions;
      case 'duplicate': return Icons.content_copy;
      case 'log': return Icons.info;
      default: return Icons.circle;
    }
  }
}

// VPN Status Enum
enum VpnConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting
}

// VPN Type Enum
enum VpnType {
  simulated,
  openvpn,
  system
}

class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  
  const HomePage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // CONFIG
  final String ftpHost = '172.19.0.202';
  final int ftpPort = 21;
  final String ftpUser = 'rasonftp';
  final String ftpPass = 'rasonftp_1672';
  final String duplicateBase = 'https://bmkgsatu.bmkg.go.id/db/bmkgsatu//@search';
  final String metadataParam = '_metadata=type_message,timestamp_data,timestamp_sent_data,station_wmo_id,sandi_gts,ttaaii,cccc,need_ftp';
  
  // VPN Configuration
  final String vpnServer = 'vpn.bmkg.go.id';
  final String vpnUsername = 'sbdm';
  final String vpnPassword = 'D4t4ba53';
  final int vpnPort = 443;
  
  String petugasName = 'Operator BMKG';
  
  final TextEditingController _textController = TextEditingController();
  bool working = false;
  List<HistoryItem> history = [];
  File? historyFile;
  
  // VPN Variables
  VpnConnectionStatus vpnStatus = VpnConnectionStatus.disconnected;
  String vpnLog = '';
  DateTime? vpnConnectedAt;
  bool isVpnConnecting = false;
  VpnType selectedVpnType = VpnType.simulated;
  
  // UI Variables
  late TabController _mainTabController;
  final ScrollController _inputScrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  
  // Data Variables
  bool _isRefreshing = false;
  File? _pendingLocalFile;
  List<HistoryItem> _pendingLocalItems = [];
  
  // Loading state
  bool _isInitializing = true;
  
  // Theme colors
  Color get _backgroundColor => widget.isDarkMode 
      ? const Color(0xFF0A0A2A) 
      : const Color(0xFFF5F5F5);
  
  Color get _surfaceColor => widget.isDarkMode
      ? const Color(0xFF1A1A3A)
      : Colors.white;
  
  Color get _textColor => widget.isDarkMode
      ? Colors.white
      : const Color(0xFF333333);
  
  Color get _hintTextColor => widget.isDarkMode
      ? Colors.white.withOpacity(0.5)
      : Colors.grey.shade600;
  
  Color get _borderColor => widget.isDarkMode
      ? Colors.white.withOpacity(0.15)
      : Colors.grey.shade300;
  
  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    
    // Load data setelah UI siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }
  
  @override
  void dispose() {
    _mainTabController.dispose();
    _textController.dispose();
    _inputScrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _initializeApp() async {
    setState(() => _isInitializing = true);
    
    await Future.wait([
      _loadInitialData(),
      Future.delayed(const Duration(milliseconds: 300)), // Minimal loading time
    ]);
    
    setState(() => _isInitializing = false);
  }
  
  Future<void> _loadInitialData() async {
    await Future.wait([
      _initHistory(),
      _loadPendingLocalData(),
    ], eagerError: false);
  }
  
  Future<void> _checkAndRequestPermissions() async {
    try {
      final permissions = await [
        Permission.storage,
      ].request();
      
      for (var permission in permissions.entries) {
        if (permission.value.isGranted) {
          print('Permission ${permission.key} granted');
        }
      }
    } catch (e) {
      print('Permission error: $e');
    }
  }
  
  Future<void> _initHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      historyFile = File('${dir.path}/gts_history.json');
      if (!await historyFile!.exists()) {
        await historyFile!.writeAsString(jsonEncode([]));
      }
      final content = await historyFile!.readAsString();
      final arr = jsonDecode(content) as List;
      setState(() {
        history = arr.map((e) => HistoryItem.fromJson(e)).toList();
      });
    } catch (_) {
      setState(() {
        history = [];
      });
    }
  }
  
  Future<void> _loadPendingLocalData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _pendingLocalFile = File('${dir.path}/pending_local.json');
      if (!await _pendingLocalFile!.exists()) {
        await _pendingLocalFile!.writeAsString(jsonEncode([]));
      }
      final content = await _pendingLocalFile!.readAsString();
      final arr = jsonDecode(content) as List;
      setState(() {
        _pendingLocalItems = arr.map((e) => HistoryItem.fromJson(e)).toList();
      });
    } catch (_) {
      setState(() {
        _pendingLocalItems = [];
      });
    }
  }
  
  Future<void> _saveHistory() async {
    if (historyFile == null) return;
    final arr = history.map((h) => h.toJson()).toList();
    await historyFile!.writeAsString(jsonEncode(arr), flush: true);
  }
  
  Future<void> _savePendingLocalData() async {
    if (_pendingLocalFile == null) return;
    final arr = _pendingLocalItems.map((h) => h.toJson()).toList();
    await _pendingLocalFile!.writeAsString(jsonEncode(arr), flush: true);
  }
  
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    await _initHistory();
    await _loadPendingLocalData();
    
    setState(() {
      _isRefreshing = false;
    });
  }
  
  // ========== VPN FUNCTIONS ==========
  Future<void> _connectVPN() async {
    if (isVpnConnecting) return;
    
    if (vpnStatus == VpnConnectionStatus.connected) {
      await _disconnectVPN();
      return;
    }
    
    setState(() {
      isVpnConnecting = true;
      vpnStatus = VpnConnectionStatus.connecting;
      vpnLog = 'Starting VPN connection...\n';
    });
    
    try {
      switch (selectedVpnType) {
        case VpnType.simulated:
          await _connectSimulatedVPN();
          break;
        case VpnType.openvpn:
          await _connectOpenVPN();
          break;
        case VpnType.system:
          await _connectSystemVPN();
          break;
      }
    } catch (e) {
      setState(() {
        isVpnConnecting = false;
        vpnStatus = VpnConnectionStatus.disconnected;
        vpnLog += 'VPN Error: $e\n';
      });
      
      _showSnackBar('VPN Failed: ${e.toString()}', Colors.red);
    }
  }
  
  Future<void> _connectSimulatedVPN() async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() {
      vpnStatus = VpnConnectionStatus.connected;
      isVpnConnecting = false;
      vpnConnectedAt = DateTime.now();
      vpnLog += 'Simulated VPN Connected!\n';
    });
    
    _appendLog('Simulated VPN connected');
    _showSnackBar('Simulated VPN Connected', Colors.green);
  }
  
  Future<void> _connectOpenVPN() async {
    setState(() {
      isVpnConnecting = true;
      vpnStatus = VpnConnectionStatus.connecting;
      vpnLog = 'Starting OpenVPN connection...\n';
    });
    
    try {
      final configContent = '''
client
dev tun
proto tcp
remote $vpnServer $vpnPort
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
cipher AES-256-CBC
auth SHA256
verb 3
route 172.19.0.0 255.255.0.0
''';
      
      final dir = await getApplicationDocumentsDirectory();
      final configFile = File('${dir.path}/bmkg_vpn.ovpn');
      await configFile.writeAsString(configContent);
      
      final uris = [
        Uri.parse('openvpn://import-config?url=${Uri.encodeComponent(configFile.path)}&title=BMKG_VPN'),
        Uri.parse('openvpn://import?url=${Uri.encodeComponent(configFile.path)}'),
        Uri.parse('file://${configFile.path}'),
      ];
      
      bool launched = false;
      
      for (final uri in uris) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          vpnLog += 'Failed with URI $uri: $e\n';
        }
      }
      
      if (launched) {
        setState(() {
          vpnStatus = VpnConnectionStatus.connected;
          isVpnConnecting = false;
          vpnConnectedAt = DateTime.now();
          vpnLog += 'OpenVPN launched successfully\n';
        });
        
        _showSnackBar('OpenVPN launched. Please connect in OpenVPN Connect app.', Colors.orange, duration: 4);
      } else {
        await _showOpenVPNInstallDialog();
      }
      
    } catch (e) {
      setState(() {
        isVpnConnecting = false;
        vpnStatus = VpnConnectionStatus.disconnected;
        vpnLog += 'OpenVPN Error: $e\n';
      });
      
      _showSnackBar('OpenVPN Error: ${e.toString()}', Colors.red);
    }
  }
  
  Future<void> _showOpenVPNInstallDialog() async {
    final playStoreUri = Uri.parse('market://details?id=net.openvpn.openvpn');
    final playStoreWebUri = Uri.parse('https://play.google.com/store/apps/details?id=net.openvpn.openvpn');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenVPN Required'),
        content: const Text(
          'Please install OpenVPN Connect from Play Store first.\n\n'
          'After installation, import the config file manually from:\n'
          'Internal storage/Android/data/[app_name]/files/bmkg_vpn.ovpn',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (await canLaunchUrl(playStoreUri)) {
                  await launchUrl(playStoreUri);
                } else if (await canLaunchUrl(playStoreWebUri)) {
                  await launchUrl(playStoreWebUri);
                }
              } catch (e) {
                _showSnackBar('Cannot open Play Store: $e', Colors.red);
              }
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _connectSystemVPN() async {
    setState(() {
      isVpnConnecting = true;
      vpnStatus = VpnConnectionStatus.connecting;
      vpnLog = 'Opening system VPN settings...\n';
    });
    
    try {
      final uris = [
        Uri.parse('intent:#Intent;action=android.settings.VPN_SETTINGS;end'),
        Uri.parse('intent:#Intent;action=android.settings.SETTINGS;end'),
        Uri.parse('intent:#Intent;action=android.settings.WIRELESS_SETTINGS;end'),
      ];
      
      bool launched = false;
      
      for (final uri in uris) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          vpnLog += 'Failed with URI $uri: $e\n';
        }
      }
      
      if (launched) {
        setState(() {
          vpnStatus = VpnConnectionStatus.connected;
          isVpnConnecting = false;
          vpnConnectedAt = DateTime.now();
          vpnLog += 'VPN settings opened\n';
        });
        
        _showSnackBar('Please connect VPN in system settings', Colors.orange, duration: 4);
      } else {
        _showVPNInstructionsDialog();
      }
      
    } catch (e) {
      setState(() {
        isVpnConnecting = false;
        vpnStatus = VpnConnectionStatus.disconnected;
        vpnLog += 'System VPN Error: $e\n';
      });
      
      _showSnackBar('System VPN Error: ${e.toString()}', Colors.red);
    }
  }
  
  void _showVPNInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VPN Setup Instructions'),
        content: const Text(
          'Please setup VPN manually:\n\n'
          '1. Go to Settings → Network & internet → VPN\n'
          '2. Add new VPN configuration\n'
          '3. Use these settings:\n'
          '   • Type: PPTP or L2TP/IPSec\n'
          '   • Server: vpn.bmkg.go.id\n'
          '   • Username: sbdm\n'
          '   • Password: D4t4ba53\n'
          '4. Save and connect',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _disconnectVPN() async {
    setState(() {
      vpnStatus = VpnConnectionStatus.disconnecting;
    });
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    setState(() {
      vpnStatus = VpnConnectionStatus.disconnected;
      vpnConnectedAt = null;
      isVpnConnecting = false;
      vpnLog += 'VPN Disconnected\n';
    });
    
    _appendLog('VPN disconnected');
    _showSnackBar('VPN Disconnected', Colors.red);
  }
  
  // ========== PENDING RETRY FUNCTION ==========
  Future<void> _retryPendingItems() async {
    if (_pendingLocalItems.isEmpty) {
      _showSnackBar('Tidak ada data pending', Colors.orange);
      return;
    }
    
    if (working) return;
    
    setState(() => working = true);
    _appendLog('Retrying ${_pendingLocalItems.length} pending items...');
    
    int successCount = 0;
    int failedCount = 0;
    final itemsToRetry = List<HistoryItem>.from(_pendingLocalItems);
    
    for (var item in itemsToRetry) {
      try {
        final fname = item.filename.isNotEmpty ? item.filename : _createFileNameUtc();
        final tempFile = await _writeTempFile(fname, item.content);
        final ok = await _uploadFileToFtp(tempFile, fname);
        
        if (ok) {
          final index = history.indexWhere((h) => h.id == item.id);
          if (index != -1) {
            setState(() {
              history[index] = HistoryItem(
                id: item.id,
                content: item.content,
                filename: fname,
                status: 'success',
                note: 'retry_success',
                createdAt: item.createdAt,
              );
            });
          }
          
          setState(() {
            _pendingLocalItems.removeWhere((h) => h.id == item.id);
          });
          
          successCount++;
        } else {
          failedCount++;
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        _appendLog('Retry error: $e');
        failedCount++;
      }
    }
    
    await _saveHistory();
    await _savePendingLocalData();
    setState(() => working = false);
    
    _showSnackBar(
      'Retry selesai: $successCount berhasil, $failedCount gagal',
      successCount > 0 ? Colors.green : Colors.orange,
      duration: 3,
    );
  }
  
  void _showSnackBar(String message, Color color, {int duration = 2}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
      ),
    );
  }
  
  // ========== FUNGSI PEMBERSIHAN WHATSAPP YANG DIPERBAIKI ==========

String _cleanMultiWhatsAppMessages(String rawText) {
  final lines = rawText.split('\n');
  final cleanedLines = <String>[];
  
  for (var line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) continue;
    
    // Pattern untuk timestamp WhatsApp: [HH:MM, DD/MM/YYYY] Nama:
    final waTimestampRegex = RegExp(r'^\[\d{1,2}[:.]\d{1,2},? \d{1,2}\/\d{1,2}\/\d{4}\][^:]*:');
    
    // Pattern untuk timestamp WhatsApp tanpa tanda kurung siku penuh
    final waPartialTimestampRegex = RegExp(r'^\d{1,2}[:.]\d{1,2},? \d{1,2}\/\d{1,2}\/\d{4}\][^:]*:');
    
    // Jika baris dimulai dengan timestamp WhatsApp, 
    // hapus SEMUA bagian timestamp dan nama
    if (waTimestampRegex.hasMatch(trimmedLine) || waPartialTimestampRegex.hasMatch(trimmedLine)) {
      // Cari posisi titik dua terakhir (setelah nama pengirim)
      final lastColonIndex = trimmedLine.lastIndexOf(':');
      if (lastColonIndex != -1 && lastColonIndex < trimmedLine.length - 1) {
        // Ambil konten setelah titik dua terakhir
        final contentAfterColon = trimmedLine.substring(lastColonIndex + 1).trim();
        if (contentAfterColon.isNotEmpty) {
          cleanedLines.add(contentAfterColon);
        }
      }
      continue;
    }
    
    // Skip baris metadata WhatsApp lainnya
    if (trimmedLine.toLowerCase().startsWith('forwarded')) continue;
    if (trimmedLine.toLowerCase().startsWith('from:')) continue;
    
    // Tambahkan baris yang valid
    cleanedLines.add(trimmedLine);
  }
  
  // Gabungkan semua baris yang tersisa
  var result = cleanedLines.join('\n').trim();
  
  // Hapus baris kosong berlebihan
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  
  // Pastikan ada satu baris kosong antara blok GTS
  result = result.replaceAll('=\n', '=\n\n');
  
  return result;
}

String _cleanBlock(String block) {
  final raw = block.replaceAll('\r', '\n');
  final lines = raw.split('\n');
  final kept = <String>[];
  
  for (var line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) continue;
    
    // Skip semua jenis timestamp WhatsApp
    if (trimmedLine.contains(']') && trimmedLine.contains(':') && 
        (trimmedLine.contains('/') || RegExp(r'\d{1,2}[:.]\d{1,2}').hasMatch(trimmedLine))) {
      // Cek jika ini format timestamp WhatsApp
      if (RegExp(r'^(\[?\d{1,2}[:.]\d{1,2},? \d{1,2}\/\d{1,2}\/\d{4}\]?[^:]*:|[^:]* \d{1,2}\/\d{1,2}\/\d{4}[^:]*:)').hasMatch(trimmedLine)) {
        // Ambil konten setelah titik dua terakhir
        final lastColonIndex = trimmedLine.lastIndexOf(':');
        if (lastColonIndex != -1 && lastColonIndex < trimmedLine.length - 1) {
          final content = trimmedLine.substring(lastColonIndex + 1).trim();
          if (content.isNotEmpty) {
            kept.add(content);
          }
        }
        continue;
      }
    }
    
    // Skip metadata WhatsApp lainnya
    if (trimmedLine.toLowerCase().startsWith('forwarded')) continue;
    if (trimmedLine.toLowerCase().startsWith('from:')) continue;
    
    // Skip baris yang hanya berisi nomor telepon dengan titik dua
    final phoneRegex = RegExp(r'^\+\d{2,4}[-\s]?\d+[-\s]?\d+[-\s]?\d+[:]?$');
    if (phoneRegex.hasMatch(trimmedLine)) continue;
    
    kept.add(trimmedLine);
  }
  
  var out = kept.join('\n').trim();
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  if (!out.endsWith('=')) out = '$out=';
  
  return out;
}
  
  // ========== GTS PROCESSING FUNCTIONS ==========
  String _createFileNameUtc() {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'DDK_SHIFT_${y}${m}${d}_${hh}${mm}.X';
  }
  
  Future<bool> _checkDuplicateOnServer(String cleanedBlock) async {
    try {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day, 0, 0, 0);
      final end = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);
      
      String fmt(DateTime t) =>
          '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}T${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      
      final query = '?type_name=GTSMessage&$metadataParam&_size=10000&timestamp_data__gte=${Uri.encodeComponent(fmt(start))}&timestamp_data__lte=${Uri.encodeComponent(fmt(end))}';
      final url = '$duplicateBase$query';
      
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return false;
      }
      
      dynamic jsonBody;
      try {
        jsonBody = json.decode(resp.body);
      } catch (_) {
        return resp.body.toLowerCase().contains(cleanedBlock.toLowerCase());
      }
      
      List<dynamic> rows = [];
      if (jsonBody is List) rows = jsonBody;
      else if (jsonBody is Map) {
        if (jsonBody.containsKey('rows') && jsonBody['rows'] is List) rows = List.from(jsonBody['rows']);
        else if (jsonBody.containsKey('data') && jsonBody['data'] is List) rows = List.from(jsonBody['data']);
        else {
          for (var v in jsonBody.values) {
            if (v is List) {
              rows = v;
              break;
            }
          }
        }
      }
      
      final lower = cleanedBlock.toLowerCase();
      for (var r in rows) {
        if (r is Map) {
          final sandi = (r['sandi_gts'] ?? '').toString();
          final ttaaii = (r['ttaaii'] ?? '').toString();
          final cccc = (r['cccc'] ?? '').toString();
          if (sandi.isNotEmpty && lower.contains(sandi.toLowerCase())) return true;
          if (ttaaii.isNotEmpty && lower.contains(ttaaii.toLowerCase())) return true;
          if (cccc.isNotEmpty && lower.contains(cccc.toLowerCase())) return true;
        }
      }
      return false;
    } catch (e) {
      _appendLog('Duplicate check error: $e');
      return false;
    }
  }
  
  Future<File> _writeTempFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true, encoding: utf8);
    return file;
  }
  
  Future<bool> _uploadFileToFtp(File file, String remoteName) async {
    try {
      final ftp = FTPConnect(
        ftpHost, 
        user: ftpUser, 
        pass: ftpPass, 
        port: ftpPort, 
        timeout: 15
      );
      await ftp.connect();
      final ok = await ftp.uploadFile(
        file, 
        sRemoteName: remoteName,
      );
      await ftp.disconnect();
      return ok;
    } catch (e) {
      if (!e.toString().contains('timeout')) {
        _appendLog('FTP error: $e');
      }
      return false;
    }
  }
  
  void _appendLog(String s) {
    final now = DateTime.now().toUtc();
    setState(() {
      history.insert(0, HistoryItem(
        id: now.microsecondsSinceEpoch.toString(),
        content: '[LOG] $s',
        filename: '',
        status: 'log',
        note: '',
        createdAt: now.toIso8601String(),
      ));
    });
    _saveHistory();
  }
  
  // ========== OPTIMIZED PROCESS AND SEND ==========
  Future<void> _processAndSend() async {
    if (selectedVpnType == VpnType.simulated && vpnStatus != VpnConnectionStatus.connected) {
      _showSnackBar('Harap konek VPN terlebih dahulu', Colors.red);
      return;
    }
    
    final raw = _textController.text;
    if (raw.trim().isEmpty) {
      _showSnackBar('Masukkan teks terlebih dahulu', Colors.orange);
      return;
    }
    
    _textFieldFocusNode.unfocus();
    setState(() => working = true);
    
    final processedData = await _processTextInBackground(raw);
    
    if (processedData['cleanedText'] == null || (processedData['cleanedText'] as String).isEmpty) {
      setState(() => working = false);
      _showSnackBar('Tidak ada data valid untuk diproses', Colors.orange);
      return;
    }
    
    final cleanedText = processedData['cleanedText'] as String;
    
    _appendLog('Memproses data GTS...');
    
    final result = await _processSingleFile(cleanedText);
    
    setState(() => working = false);
    
    if (result['status'] == 'success') {
      _showSnackBar('Data berhasil dikirim!', Colors.green, duration: 3);
      _textController.clear();
    } else if (result['status'] == 'duplicate') {
      _showSnackBar('Data duplikat ditemukan', Colors.orange, duration: 3);
    } else if (result['status'] == 'failed') {
      _showSnackBar('Gagal mengirim data (disimpan lokal)', Colors.red, duration: 3);
    }
    
    await _saveHistory();
  }
  
  Future<Map<String, dynamic>> _processTextInBackground(String rawText) async {
    final cleanedMultiMessage = _cleanMultiWhatsAppMessages(rawText);
    return {
      'cleanedText': cleanedMultiMessage,
    };
  }
  
  Future<Map<String, dynamic>> _processSingleFile(String cleanedText) async {
    try {
      // Periksa duplikat di server untuk seluruh konten
      bool isDup = false;
      try {
        isDup = await _checkDuplicateOnServer(cleanedText)
            .timeout(const Duration(seconds: 5), onTimeout: () {
          _appendLog('Duplicate check timeout, skip check');
          return false;
        });
      } catch (e) {
        _appendLog('Server duplicate check error, skip check: $e');
      }
      
      if (isDup) {
        final dupItem = HistoryItem(
          id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
          content: cleanedText,
          filename: '',
          status: 'duplicate',
          note: 'duplicate_server',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );
        
        setState(() {
          history.insert(0, dupItem);
        });
        
        return {'status': 'duplicate'};
      }
      
      // Buat file dan upload
      final fname = _createFileNameUtc();
      final f = await _writeTempFile(fname, cleanedText);
      
      bool ok = false;
      try {
        ok = await _uploadFileToFtp(f, fname)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          _appendLog('FTP upload timeout for $fname');
          return false;
        });
      } catch (e) {
        _appendLog('FTP upload failed: $e');
        ok = false;
      }
      
      if (ok) {
        final successItem = HistoryItem(
          id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
          content: cleanedText,
          filename: fname,
          status: 'success',
          note: 'uploaded',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );
        
        setState(() {
          history.insert(0, successItem);
        });
        
        return {'status': 'success'};
      } else {
        final pendingItem = HistoryItem(
          id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
          content: cleanedText,
          filename: fname,
          status: 'pending',
          note: 'ftp_failed_saved_local',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );
        
        setState(() {
          history.insert(0, pendingItem);
          _pendingLocalItems.insert(0, pendingItem);
        });
        
        await _savePendingLocalData();
        return {'status': 'failed'};
      }
    } catch (e) {
      _appendLog('File processing error: $e');
      return {'status': 'failed', 'error': e.toString()};
    }
  }
  
  // ========== HELPER FUNCTIONS ==========
  String _getVpnStatusText() {
    switch (vpnStatus) {
      case VpnConnectionStatus.connected:
        return 'CONNECTED';
      case VpnConnectionStatus.disconnected:
        return 'DISCONNECTED';
      case VpnConnectionStatus.connecting:
        return 'CONNECTING';
      case VpnConnectionStatus.disconnecting:
        return 'DISCONNECTING';
      default:
        return 'DISCONNECTED';
    }
  }
  
  Color _getVpnStatusColor() {
    switch (vpnStatus) {
      case VpnConnectionStatus.connected:
        return const Color(0xFF00C853);
      case VpnConnectionStatus.connecting:
        return const Color(0xFFFF6D00);
      case VpnConnectionStatus.disconnected:
        return const Color(0xFFD32F2F);
      case VpnConnectionStatus.disconnecting:
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFF757575);
    }
  }
  
  IconData _getVpnStatusIcon() {
    switch (vpnStatus) {
      case VpnConnectionStatus.connected:
        return Icons.vpn_lock;
      case VpnConnectionStatus.connecting:
        return Icons.vpn_key;
      case VpnConnectionStatus.disconnected:
        return Icons.vpn_key_off;
      default:
        return Icons.vpn_lock;
    }
  }
  
  String _getVpnTypeText() {
    switch (selectedVpnType) {
      case VpnType.simulated:
        return 'Simulated';
      case VpnType.openvpn:
        return 'OpenVPN';
      case VpnType.system:
        return 'System';
      default:
        return 'Simulated';
    }
  }
  
  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoString;
    }
  }
  
  Future<void> _exportHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportFile = File('${dir.path}/gts_history_export_${DateTime.now().millisecondsSinceEpoch}.json');
      
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_items': history.length,
        'items': history.map((h) => h.toJson()).toList(),
      };
      
      await exportFile.writeAsString(jsonEncode(exportData), flush: true);
      
      _showSnackBar('History exported to ${exportFile.path}', Colors.green);
      _appendLog('History exported: ${exportFile.path}');
    } catch (e) {
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }
  
  Future<void> _clearHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A3A) : Colors.white,
        title: Text('Clear History?', style: TextStyle(color: _textColor)),
        content: Text(
          'This will delete all history items. This action cannot be undone.',
          style: TextStyle(color: _hintTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                history.clear();
                _pendingLocalItems.clear();
              });
              await _saveHistory();
              await _savePendingLocalData();
              _showSnackBar('History cleared', Colors.orange);
              _appendLog('History cleared by user');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // ========== UI BUILDERS ==========
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Memuat aplikasi...',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _buildCustomScrollView(),
      ),
    );
  }
  
  Widget _buildCustomScrollView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          snap: true,
          elevation: 0,
          backgroundColor: _backgroundColor,
          expandedHeight: 0,
          collapsedHeight: 56,
          flexibleSpace: _buildHeader(),
        ),
        
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildStatusCard(),
          ),
        ),
        
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, width: 1),
                boxShadow: widget.isDarkMode ? null : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _mainTabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: _hintTextColor,
                tabs: const [
                  Tab(icon: Icon(Icons.edit, size: 14), text: 'INPUT'),
                  Tab(icon: Icon(Icons.history, size: 14), text: 'HISTORY'),
                  Tab(icon: Icon(Icons.assessment, size: 14), text: 'REPORT'),
                ],
              ),
            ),
            backgroundColor: _backgroundColor,
          ),
        ),
        
        SliverFillRemaining(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: _surfaceColor,
            displacement: 40,
            child: TabBarView(
              controller: _mainTabController,
              children: [
                _buildInputTab(),
                _buildHistoryTab(),
                _buildReportTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload, 
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'DDK SHIFT GTS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                'GTS Transmission',
                style: TextStyle(
                  fontSize: 10,
                  color: _hintTextColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: _textColor.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: widget.toggleTheme,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, 
                    color: _textColor.withOpacity(0.7), size: 20),
                onPressed: _showVPNDetails,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard() {
    final pending = history.where((h) => h.status == 'pending').length;
    final success = history.where((h) => h.status == 'success').length;
    final duplicate = history.where((h) => h.status == 'duplicate').length;
    final pendingLocal = _pendingLocalItems.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _surfaceColor,
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: widget.isDarkMode ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM STATUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getVpnStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getVpnStatusColor().withOpacity(0.3)),
                ),
                child: Text(
                  _getVpnTypeText(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getVpnStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge('VPN', _getVpnStatusText(), _getVpnStatusColor()),
              _buildStatusBadge('PENDING', '$pending', const Color(0xFFFF6D00)),
              _buildStatusBadge('SUCCESS', '$success', const Color(0xFF00C853)),
              _buildStatusBadge('DUPLICATE', '$duplicate', const Color(0xFF9C27B0)),
            ],
          ),
          if (pendingLocal > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage, color: const Color(0xFFFF6D00), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$pendingLocal lokal',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFFFF6D00),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _retryPendingItems,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6D00),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'RETRY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Monospace',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _hintTextColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, 
      {Color color = Colors.blue, bool isLoading = false, double width = double.infinity}) {
    return Container(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isLoading
                    ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)]
                    : [
                        color.withOpacity(widget.isDarkMode ? 0.8 : 0.9),
                        color.withOpacity(widget.isDarkMode ? 0.5 : 0.7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: widget.isDarkMode ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] : [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.9)),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildVPNButton() {
  final isConnected = vpnStatus == VpnConnectionStatus.connected;
  final isConnecting = isVpnConnecting;
  
  return PopupMenuButton<VpnType>(
    onSelected: (VpnType value) {
      setState(() {
        selectedVpnType = value;
        if (isConnected) {
          _disconnectVPN();
        }
      });
    },
    itemBuilder: (BuildContext context) => <PopupMenuEntry<VpnType>>[
      PopupMenuItem<VpnType>(
        value: VpnType.simulated,
        child: Row(
          children: [
            Icon(
              selectedVpnType == VpnType.simulated 
                ? Icons.check_circle 
                : Icons.circle_outlined,
              color: selectedVpnType == VpnType.simulated 
                ? Colors.blue 
                : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text('Simulated VPN'),
          ],
        ),
      ),
      PopupMenuItem<VpnType>(
        value: VpnType.openvpn,
        child: Row(
          children: [
            Icon(
              selectedVpnType == VpnType.openvpn 
                ? Icons.check_circle 
                : Icons.circle_outlined,
              color: selectedVpnType == VpnType.openvpn 
                ? Colors.blue 
                : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text('OpenVPN Connect'),
          ],
        ),
      ),
      PopupMenuItem<VpnType>(
        value: VpnType.system,
        child: Row(
          children: [
            Icon(
              selectedVpnType == VpnType.system 
                ? Icons.check_circle 
                : Icons.circle_outlined,
              color: selectedVpnType == VpnType.system 
                ? Colors.blue 
                : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text('System VPN'),
          ],
        ),
      ),
    ],
    child: Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isConnecting
              ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)]
              : isConnected
                  ? [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.5)]
                  : [
                      _getVpnStatusColor().withOpacity(widget.isDarkMode ? 0.8 : 0.9),
                      _getVpnStatusColor().withOpacity(widget.isDarkMode ? 0.5 : 0.7),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isConnected 
              ? Colors.red.withOpacity(0.3)
              : _getVpnStatusColor().withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? Colors.red : _getVpnStatusColor())
                .withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnecting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.9)),
              ),
            )
          else
            Icon(
              isConnected ? Icons.vpn_lock : _getVpnStatusIcon(),
              color: Colors.white,
              size: 16,
            ),
          const SizedBox(width: 8),
          Text(
            isConnecting 
                ? 'CONNECTING...' 
                : (isConnected ? 'DISCONNECT VPN' : 'CONNECT VPN'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (!isConnecting && !isConnected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ],
        ],
      ),
    ),
  );
}
  
  void _showVPNDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A3A) : Colors.white,
        title: Text(
          'VPN Configuration',
          style: TextStyle(color: _textColor),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfigItem('Server:', vpnServer, Icons.dns),
              _buildConfigItem('Port:', vpnPort.toString(), Icons.numbers),
              _buildConfigItem('Username:', vpnUsername, Icons.person),
              _buildConfigItem('Password:', '••••••••', Icons.lock),
              const SizedBox(height: 16),
              Text(
                'Current Type: ${_getVpnTypeText()}',
                style: TextStyle(
                  color: _getVpnStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${_getVpnStatusText()}',
                style: TextStyle(
                  color: _getVpnStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Untuk akses jaringan 172.19.x.x:',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• OpenVPN: Install OpenVPN Connect dari Play Store\n'
                '• Sistem: Aktifkan VPN di pengaturan sistem\n'
                '• Pastikan route ke 172.19.0.0/16 aktif',
                style: TextStyle(
                  color: _hintTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isVpnConnecting && vpnStatus != VpnConnectionStatus.connected)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _connectVPN();
              },
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildConfigItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _hintTextColor, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: _hintTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInputTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _surfaceColor,
              border: Border.all(color: _borderColor, width: 1),
              boxShadow: widget.isDarkMode ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  focusNode: _textFieldFocusNode,
                  controller: _textController,
                  maxLines: null,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontFamily: 'Monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste WhatsApp messages here...\n\n• Auto-clean WhatsApp timestamps\n• Support multiple messages\n• File will contain all GTS blocks',
                    hintStyle: TextStyle(
                      color: _hintTextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3,
                children: [
                  _buildVPNButton(),
                  _buildActionButton(
                    Icons.clear_all,
                    'CLEAR',
                    () => _textController.clear(),
                    color: const Color(0xFF757575),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              _buildActionButton(
                working ? Icons.refresh : Icons.send_and_archive,
                working ? 'PROCESSING...' : 'SEND DATA',
                _processAndSend,
                color: working 
                    ? const Color(0xFFFF6D00)
                    : Theme.of(context).colorScheme.primary,
                isLoading: working,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHistoryTab() {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: _hintTextColor, size: 64),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(
                color: _hintTextColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your processed data will appear here',
              style: TextStyle(
                color: _hintTextColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History (${history.length})',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Updated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                    style: TextStyle(
                      color: _hintTextColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...history.map((item) => _buildHistoryItem(item)).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildHistoryItem(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _surfaceColor,
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: widget.isDarkMode ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(item.statusIcon, color: item.statusColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: item.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(
                    color: _hintTextColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.filename.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'File: ${item.filename}',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 11,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
            Text(
              item.content.length > 100 
                  ? '${item.content.substring(0, 100)}...' 
                  : item.content,
              style: TextStyle(
                color: _textColor.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'Monospace',
              ),
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${item.note}',
                style: TextStyle(
                  color: _hintTextColor,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportTab() {
    final total = history.length;
    final success = history.where((h) => h.status == 'success').length;
    final pending = history.where((h) => h.status == 'pending').length;
    final duplicate = history.where((h) => h.status == 'duplicate').length;
    final log = history.where((h) => h.status == 'log').length;
    
    final today = DateTime.now();
    final todayItems = history.where((h) {
      try {
        final itemDate = DateTime.parse(h.createdAt).toLocal();
        return itemDate.year == today.year && 
               itemDate.month == today.month && 
               itemDate.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();
    
    final todaySuccess = todayItems.where((h) => h.status == 'success').length;
    final todayPending = todayItems.where((h) => h.status == 'pending').length;
    final todayDuplicate = todayItems.where((h) => h.status == 'duplicate').length;
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _surfaceColor,
              border: Border.all(color: _borderColor, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATISTICS',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow('Total Processed', '$total', Colors.blue),
                _buildStatRow('Success', '$success', const Color(0xFF00C853)),
                _buildStatRow('Pending', '$pending', const Color(0xFFFF6D00)),
                _buildStatRow('Duplicate', '$duplicate', const Color(0xFF9C27B0)),
                _buildStatRow('Log Entries', '$log', const Color(0xFF757575)),
                const SizedBox(height: 16),
                Divider(color: _borderColor),
                const SizedBox(height: 8),
                Text(
                  'Today (${_formatDate(today.toIso8601String())})',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatRow('Today Success', '$todaySuccess', const Color(0xFF00C853)),
                _buildStatRow('Today Pending', '$todayPending', const Color(0xFFFF6D00)),
                _buildStatRow('Today Duplicate', '$todayDuplicate', const Color(0xFF9C27B0)),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_pendingLocalItems.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFFF6D00).withOpacity(0.1),
                border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3), width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: const Color(0xFFFF6D00)),
                      const SizedBox(width: 8),
                      Text(
                        '${_pendingLocalItems.length} PENDING ITEMS',
                        style: TextStyle(
                          color: const Color(0xFFFF6D00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These items failed to upload and are saved locally. Click RETRY button in status card to retry.',
                    style: TextStyle(
                      color: _textColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          _buildActionButton(
            Icons.file_download,
            'EXPORT HISTORY',
            _exportHistory,
            color: Colors.blue,
          ),
          
          const SizedBox(height: 12),
          
          _buildActionButton(
            Icons.delete_sweep,
            'CLEAR HISTORY',
            _clearHistory,
            color: Colors.red,
          ),
          
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.shade100,
            ),
            child: Column(
              children: [
                Text(
                  'GTS Shift DDK v1.1',
                  style: TextStyle(
                    color: _hintTextColor,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last sync: ${DateTime.now().toLocal().toString().substring(0, 19)}',
                  style: TextStyle(
                    color: _hintTextColor.withOpacity(0.7),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textColor.withOpacity(0.8),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;
  
  _TabBarDelegate({required this.child, required this.backgroundColor});
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }
  
  @override
  double get maxExtent => 52;
  
  @override
  double get minExtent => 52;
  
  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return child != oldDelegate.child || backgroundColor != oldDelegate.backgroundColor;
  }
}