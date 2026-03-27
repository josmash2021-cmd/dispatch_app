import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/audit_log_provider.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedAction;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _actionTypes = [
    {'value': null, 'label': 'All Actions', 'icon': Icons.all_inclusive},
    {'value': 'ADMIN_STATUS_CHANGE', 'label': 'Status Changes', 'icon': Icons.toggle_on},
    {'value': 'ADMIN_TRIP_CREATED', 'label': 'Trip Created', 'icon': Icons.add_circle},
    {'value': 'ADMIN_TRIP_UPDATED', 'label': 'Trip Updated', 'icon': Icons.edit},
    {'value': 'ADMIN_TRIP_DELETED', 'label': 'Trip Deleted', 'icon': Icons.delete},
    {'value': 'ADMIN_USER_EDIT', 'label': 'User Edited', 'icon': Icons.edit},
    {'value': 'ADMIN_USER_DELETED', 'label': 'User Deleted', 'icon': Icons.person_remove},
    {'value': 'ADMIN_VERIFICATION', 'label': 'Verification', 'icon': Icons.verified_user},
    {'value': 'ADMIN_DISPATCH', 'label': 'Dispatch', 'icon': Icons.local_taxi},
    {'value': 'dispatch_owner_login', 'label': 'Admin Login', 'icon': Icons.login},
    {'value': 'dispatch_owner_logout', 'label': 'Admin Logout', 'icon': Icons.logout},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditLogProvider>().loadLogs(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<AuditLogProvider>().loadMore(
        action: _selectedAction,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );
    }
  }

  Future<void> _refresh() async {
    await context.read<AuditLogProvider>().refresh(
      action: _selectedAction,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.background,
            ),
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        title: const Text(
          'Audit Logs',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: AppColors.primary),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterSection(),
          // Logs list
          Expanded(
            child: Consumer<AuditLogProvider>(
              builder: (context, provider, _) {
                if (provider.isInitialLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (provider.errorMessage != null && provider.logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No audit logs found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Logs will appear here when admin actions are performed',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.logs.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.logs.length) {
                        // Loading indicator at bottom
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      final log = provider.logs[index];
                      return _buildLogCard(log);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range display
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                        : _startDate != null
                            ? 'From ${DateFormat('MMM d, yyyy').format(_startDate!)}'
                            : 'Until ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _refresh();
                    },
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.error.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          // Action type selector
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _actionTypes.length,
              itemBuilder: (context, index) {
                final action = _actionTypes[index];
                final isSelected = _selectedAction == action['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedAction = selected ? action['value'] : null;
                      });
                      _refresh();
                    },
                    label: Text(action['label']),
                    avatar: Icon(
                      action['icon'],
                      size: 16,
                      color: isSelected ? Colors.black : AppColors.textSecondary,
                    ),
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    backgroundColor: AppColors.surfaceHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? 'UNKNOWN';
    final timestamp = log['timestamp'] as String?;
    final actor = log['actor'] as String? ?? 'system';
    final details = log['details'] as String? ?? '';
    final ip = log['ip'] as String?;

    final actionConfig = _actionTypes.firstWhere(
      (a) => a['value'] == action,
      orElse: () => {'icon': Icons.help, 'label': action, 'color': AppColors.textHint},
    );

    Color actionColor;
    switch (action) {
      case 'ADMIN_USER_DELETED':
      case 'ADMIN_TRIP_DELETED':
      case 'ADMIN_DELETE_ALL_USERS':
        actionColor = AppColors.error;
        break;
      case 'ADMIN_STATUS_CHANGE':
      case 'ADMIN_USER_EDIT':
      case 'ADMIN_TRIP_UPDATED':
        actionColor = AppColors.warning;
        break;
      case 'ADMIN_VERIFICATION':
        actionColor = AppColors.success;
        break;
      case 'ADMIN_DISPATCH':
        actionColor = AppColors.primary;
        break;
      default:
        actionColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    actionConfig['icon'],
                    size: 18,
                    color: actionColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionConfig['label'],
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          DateFormat('MMM d, yyyy • HH:mm').format(
                            DateTime.parse(timestamp),
                          ),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  actor,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
                if (ip != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.computer,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ip,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
