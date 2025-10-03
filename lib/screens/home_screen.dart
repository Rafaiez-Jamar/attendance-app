import 'package:flutter/material.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _firebaseStatus = 'Initializing...';
  Color _firebaseStatusColor = Colors.orange;
  Map<String, dynamic> _syncStatus = {};
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initializes Firebase and other services when the screen loads.
  Future<void> _initializeServices() async {
    try {
      setState(() {
        _isLoading = true;
        _firebaseStatus = 'Initializing Firebase...';
        _firebaseStatusColor = Colors.orange;
      });

      // Initialize Firebase Service (handles offline mode gracefully)
      await FirebaseService.initialize();

      // Get detailed sync status
      _syncStatus = FirebaseService.getSyncStatus();

      setState(() {
        _isLoading = false;
        _updateFirebaseStatus();
      });

      // Test connection in background
      _testConnectionInBackground();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isLoading = false;
        _firebaseStatus = 'Initialization Error';
        _firebaseStatusColor = Colors.red;
      });
    }
  }

  /// Updates the status message and color based on Firebase connection state.
  void _updateFirebaseStatus() {
    if (FirebaseService.hasPermissionError) {
      _firebaseStatus = 'Permission Denied';
      _firebaseStatusColor = Colors.red;
    } else if (FirebaseService.isInitialized) {
      _firebaseStatus = 'Online';
      _firebaseStatusColor = Colors.green;
    } else if (FirebaseService.isOfflineMode) {
      _firebaseStatus = 'Offline Mode';
      _firebaseStatusColor = Colors.orange;
    } else {
      _firebaseStatus = 'Disconnected';
      _firebaseStatusColor = Colors.red;
    }
  }

  /// Attempts to test the network connection in the background.
  Future<void> _testConnectionInBackground() async {
    // Wait a bit for initialization to complete
    await Future.delayed(const Duration(seconds: 2));

    if (mounted && !FirebaseService.isInitialized) {
      bool connectionResult = await FirebaseService.testConnection();

      if (mounted) {
        setState(() {
          _syncStatus = FirebaseService.getSyncStatus();
          _updateFirebaseStatus();
        });

        if (connectionResult) {
          _showSnackBar('Connection restored!', Colors.green);
        }
      }
    }
  }

  /// Manually attempts to reconnect to Firebase.
  Future<void> _attemptReconnection() async {
    setState(() {
      _isReconnecting = true;
      _firebaseStatus = 'Reconnecting...';
      _firebaseStatusColor = Colors.blue; // Changed to blue for visibility
    });

    try {
      bool success = await FirebaseService.attemptReconnection();

      setState(() {
        _isReconnecting = false;
        _syncStatus = FirebaseService.getSyncStatus();
        _updateFirebaseStatus();
      });

      if (success) {
        _showSnackBar('Reconnection successful!', Colors.green);
      } else {
        _showSnackBar(
          'Reconnection failed. Check your internet connection.',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        _isReconnecting = false;
        _updateFirebaseStatus();
      });
      _showSnackBar('Reconnection error: $e', Colors.red);
    }
  }

  /// Shows a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Displays a dialog with detailed sync status information.
  void _showSyncStatusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[200], // Lightened dialog background
          title: const Text(
            'Sync Status Details',
            style: TextStyle(color: Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusRow(
                  'Initialized',
                  _syncStatus['initialized']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Offline Mode',
                  _syncStatus['offlineMode']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Permission Error',
                  _syncStatus['hasPermissionError']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Local Records',
                  _syncStatus['localRecordsCount']?.toString() ?? '0',
                ),
                _buildStatusRow(
                  'Firebase Apps',
                  _syncStatus['firebaseAppsCount']?.toString() ?? '0',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Local Records:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${_syncStatus['localRecordsCount'] ?? 0} records stored locally',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_syncStatus['localRecordsCount'] != null &&
                    _syncStatus['localRecordsCount'] > 0)
                  const Text(
                    'These will sync when connection is restored.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.black)),
            ),
            if (!FirebaseService.isInitialized)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _attemptReconnection();
                },
                child: const Text(
                  'Retry Connection',
                  style: TextStyle(color: Colors.black),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds a single row for the status dialog.
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ambil colorScheme dari Theme agar otomatis menyesuaikan light/dark mode
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // ✅ Background mengikuti tema
      backgroundColor: colorScheme.background,

      appBar: AppBar(
        // ✅ Title otomatis pakai style global (dari ThemeData)
        title: Text(
          'Attendance System',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        // ✅ AppBar otomatis pakai colorScheme, tidak perlu hardcode
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isReconnecting ? null : _attemptReconnection,
            tooltip: 'Retry Connection',
          ),
        ],
      ),

      body: _isLoading ? _buildLoadingScreen(context) : _buildMainContent(),
    );
  }

  /// Builds the loading screen UI.
  Widget _buildLoadingScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ CircularProgressIndicator otomatis ambil warna primary
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Initializing services...',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main content UI with the new professional white theme.
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ Greeting Section
          Text(
            'Hello 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to Face Attendance',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // ✅ Modern Welcome Card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Quick & Secure',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use facial recognition for attendance tracking',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.face_retouching_natural,
                  size: 64,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ✅ Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AttendanceScreen(mode: AttendanceMode.checkIn),
                    ),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.login, size: 36),
                      SizedBox(height: 8),
                      Text('Check In', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AttendanceScreen(mode: AttendanceMode.checkOut),
                    ),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.logout, size: 36),
                      SizedBox(height: 8),
                      Text('Check Out', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ✅ History Button (full width)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: BorderSide(color: Colors.blueGrey.shade500, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AttendanceHistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.history, color: Colors.black87),
            label: const Text('View History', style: TextStyle(fontSize: 16, color: Colors.black87)),
          ),
          const SizedBox(height: 28),

          // ✅ Status Card Modern
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'System Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: _showSyncStatusDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statusTile(
                    '🔥 Firebase',
                    _firebaseStatus,
                    _firebaseStatusColor,
                  ),
                  _statusTile('📱 Camera', 'Ready', Colors.green),
                  _statusTile('🤖 ML Kit', 'Ready', Colors.green),
                  if (_syncStatus['localRecordsCount'] != null &&
                      _syncStatus['localRecordsCount'] > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${_syncStatus['localRecordsCount']} records stored locally',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for status row
  Widget _statusTile(String label, String status, Color color) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Chip(
        label: Text(status, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  /// Builds a single row for the status card.
  Widget _buildStatusItem(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black)),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
