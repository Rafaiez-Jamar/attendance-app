import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/firebase_service.dart';
import '../widgets/export_report_widget.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All'; // All, Check In, Check Out

  @override
  void initState() {
    super.initState();
    _loadAttendanceRecords();
  }

  Future<void> _loadAttendanceRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await FirebaseService.getAttendanceRecords(_selectedDate);
      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load attendance records: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendanceRecords();
    }
  }

  List<AttendanceRecord> _getFilteredRecords() {
    if (_selectedFilter == 'All') return _attendanceRecords;
    final type = _selectedFilter == 'Check In'
        ? AttendanceType.checkIn
        : AttendanceType.checkOut;
    return _attendanceRecords.where((r) => r.type == type).toList();
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Attendance Data'),
        content: const SizedBox(width: double.maxFinite, child: ExportReportWidget()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showRecordDetails(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              record.type == AttendanceType.checkIn ? Icons.login : Icons.logout,
              color: record.type == AttendanceType.checkIn ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(record.type == AttendanceType.checkIn
                ? 'Check In Details'
                : 'Check Out Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('User', record.userName),
              _buildDetailRow('Time', DateFormat('HH:mm:ss').format(record.timestamp)),
              _buildDetailRow('Date', DateFormat('EEEE, dd MMM yyyy').format(record.timestamp)),
              if (record.confidence != null)
                _buildDetailRow('Confidence', '${(record.confidence! * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
              if (record.photoPath != null && File(record.photoPath!).existsSync())
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Captured Photo:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(record.photoPath!), height: 200, fit: BoxFit.cover),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  String _summaryText() {
    final filtered = _getFilteredRecords();
    final inCount = filtered.where((r) => r.type == AttendanceType.checkIn).length;
    final outCount = filtered.where((r) => r.type == AttendanceType.checkOut).length;
    return 'Check In: $inCount, Check Out: $outCount';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredRecords();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAttendanceRecords),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'export' ? _showExportDialog() : null,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(children: [Icon(Icons.file_download), SizedBox(width: 8), Text('Export Data')]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔹 Filter Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outline.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('EEEE, dd MMM yyyy').format(_selectedDate)),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.filter_list),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedFilter,
                            borderRadius: BorderRadius.circular(12),
                            items: ['All', 'Check In', 'Check Out']
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedFilter = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_summaryText(), style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildList(filtered, theme, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text('No attendance records', style: theme.textTheme.titleMedium),
          Text(DateFormat('dd MMM yyyy').format(_selectedDate),
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAttendanceRecords,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AttendanceRecord> records, ThemeData theme, ColorScheme cs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final r = records[i];
        final isIn = r.type == AttendanceType.checkIn;
        final color = isIn ? Colors.green : Colors.red;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(isIn ? Icons.login : Icons.logout, color: color),
            ),
            title: Text(isIn ? 'Check In' : 'Check Out',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(r.userName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM yyyy, HH:mm:ss').format(r.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                if (r.confidence != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Confidence: ${(r.confidence! * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRecordDetails(r),
          ),
        );
      },
    );
  }
}
