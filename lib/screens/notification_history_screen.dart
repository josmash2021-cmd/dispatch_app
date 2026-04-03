import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/dispatch_api_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<DocumentSnapshot> _notifications = [];
  bool _loading = true;
  String _selectedFilter = 'all';

  static const _filters = ['all', 'all_drivers', 'all_riders', 'user'];
  static const _filterLabels = {
    'all': 'All',
    'all_drivers': 'To Drivers',
    'all_riders': 'To Riders',
    'user': 'Individual',
  };

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ── Firestore listener ─────────────────────────────────

  void _listenToNotifications() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('notification_history')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _notifications = snapshot.docs;
          _loading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _loading = false);
        debugPrint('NotificationHistory stream error: $error');
      },
    );
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _listenToNotifications();
  }

  // ── Helpers ────────────────────────────────────────────

  List<DocumentSnapshot> get _filteredNotifications {
    if (_selectedFilter == 'all') return _notifications;
    return _notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_selectedFilter == 'user') {
        return data['targetType'] == 'user';
      }
      return data['targetType'] == _selectedFilter;
    }).toList();
  }

  int get _todayCount {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final sentAt = data['sentAt'];
      if (sentAt is Timestamp) {
        return sentAt.toDate().isAfter(startOfDay);
      }
      return false;
    }).length;
  }

  int get _weekCount {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final sentAt = data['sentAt'];
      if (sentAt is Timestamp) {
        return sentAt.toDate().isAfter(weekStart);
      }
      return false;
    }).length;
  }

  int get _broadcastCount {
    return _notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['targetType'] == 'broadcast';
    }).length;
  }

  IconData _iconForTargetType(String? targetType) {
    switch (targetType) {
      case 'all_drivers':
        return Icons.local_taxi;
      case 'all_riders':
        return Icons.person;
      case 'broadcast':
        return Icons.campaign;
      case 'user':
        return Icons.person_pin;
      default:
        return Icons.notifications;
    }
  }

  String _targetLabel(Map<String, dynamic> data) {
    switch (data['targetType']) {
      case 'all_drivers':
        return 'All Drivers';
      case 'all_riders':
        return 'All Riders';
      case 'broadcast':
        return 'Broadcast';
      case 'user':
        return data['targetName'] as String? ?? 'User';
      default:
        return 'Unknown';
    }
  }

  String _relativeTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  String get _currentAdminName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'Admin';
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notification History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSendSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF08090C),
        icon: const Icon(Icons.send),
        label: const Text(
          'Send',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Summary cards
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  // Filter chips
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  // Notification list
                  if (filtered.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildNotificationCard(filtered[index]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _summaryCard('Today', _todayCount, Icons.today),
          const SizedBox(width: 10),
          _summaryCard('This Week', _weekCount, Icons.date_range),
          const SizedBox(width: 10),
          _summaryCard('Broadcasts', _broadcastCount, Icons.campaign),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final selected = _selectedFilter == filter;
          final label = _filterLabels[filter] ?? filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF08090C)
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.cardBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Notification card ──────────────────────────────────

  Widget _buildNotificationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final targetType = data['targetType'] as String?;
    final sentBy = data['sentBy'] as String? ?? '';
    final sentAt = data['sentAt'];
    final template = data['template'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForTargetType(targetType),
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _relativeTime(sentAt),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Body
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Target badge + sent by
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _targetLabel(data),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (template != null && template.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            template,
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (sentBy.isNotEmpty)
                        Text(
                          'by $sentBy',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No notifications sent yet'
                : 'No ${_filterLabels[_selectedFilter]} notifications',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to send a new notification',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── Send notification bottom sheet ─────────────────────

  void _showSendSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SendNotificationSheet(
        adminName: _currentAdminName,
        onSent: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification sent'),
              backgroundColor: AppColors.surfaceHigh,
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Send Notification Bottom Sheet
// ═══════════════════════════════════════════════════════════

class _SendNotificationSheet extends StatefulWidget {
  final String adminName;
  final VoidCallback? onSent;

  const _SendNotificationSheet({
    required this.adminName,
    this.onSent,
  });

  @override
  State<_SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends State<_SendNotificationSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();

  String _targetType = 'all_drivers'; // all_drivers, all_riders, user
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedTemplate;
  bool _sending = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  static const _targetOptions = {
    'all_drivers': 'All Drivers',
    'all_riders': 'All Riders',
    'user': 'Individual User',
  };

  static const _templates = {
    'Account Verified': {
      'title': 'Account Verified',
      'body': 'Your account has been verified. You can now start using Cruise.',
    },
    'Trip Update': {
      'title': 'Trip Update',
      'body': 'There has been an update to your trip. Please check the app for details.',
    },
    'Promotion': {
      'title': 'Special Promotion',
      'body': 'Check out our latest promotion! Open the app for details.',
    },
    'System Maintenance': {
      'title': 'Scheduled Maintenance',
      'body':
          'We will be performing scheduled maintenance. Service may be temporarily unavailable.',
    },
  };

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _applyTemplate(String templateName) {
    final template = _templates[templateName];
    if (template == null) return;
    setState(() {
      _selectedTemplate = templateName;
      _titleController.text = template['title']!;
      _bodyController.text = template['body']!;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchUsers(query.trim());
    });
  }

  Future<void> _searchUsers(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      // Search across both drivers and clients collections
      final driversSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .limit(20)
          .get();
      final clientsSnap = await FirebaseFirestore.instance
          .collection('clients')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];

      for (final doc in [...driversSnap.docs, ...clientsSnap.docs]) {
        final data = doc.data();
        final firstName =
            (data['firstName'] ?? data['first_name'] ?? '').toString().toLowerCase();
        final lastName =
            (data['lastName'] ?? data['last_name'] ?? '').toString().toLowerCase();
        final fullName = '$firstName $lastName';
        final phone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();

        if (fullName.contains(lowerQuery) || phone.contains(lowerQuery)) {
          results.add({
            'id': doc.id,
            'name':
                '${data['firstName'] ?? data['first_name'] ?? ''} ${data['lastName'] ?? data['last_name'] ?? ''}'
                    .trim(),
            'phone': phone,
            'collection':
                driversSnap.docs.contains(doc) ? 'drivers' : 'clients',
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      debugPrint('User search error: $e');
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and body are required'),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
      return;
    }

    if (_targetType == 'user' && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user'),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      // Call appropriate API method
      if (_targetType == 'all_drivers') {
        await DispatchApiService.broadcastToDrivers(title: title, body: body);
      } else if (_targetType == 'all_riders') {
        await DispatchApiService.broadcastToRiders(title: title, body: body);
      } else if (_targetType == 'user' && _selectedUserId != null) {
        final userId = int.tryParse(_selectedUserId!);
        if (userId != null) {
          await DispatchApiService.sendNotification(
            userId: userId,
            title: title,
            body: body,
          );
        }
      }

      // Write to notification_history in Firestore
      await FirebaseFirestore.instance.collection('notification_history').add({
        'title': title,
        'body': body,
        'targetType': _targetType,
        'targetId': _targetType == 'user' ? _selectedUserId : null,
        'targetName': _targetType == 'user' ? _selectedUserName : null,
        'sentBy': widget.adminName,
        'sentAt': FieldValue.serverTimestamp(),
        'template': _selectedTemplate,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSent?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Send Notification',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),

              // Target selector
              const Text(
                'Target',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _targetOptions.entries.map((entry) {
                  final selected = _targetType == entry.key;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF08090C)
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceHigh,
                    selectedColor: AppColors.primary,
                    side: BorderSide(
                      color:
                          selected ? AppColors.primary : AppColors.cardBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _targetType = entry.key;
                        _selectedUserId = null;
                        _selectedUserName = null;
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // User search (only for individual)
              if (_targetType == 'user') ...[
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search user by name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_selectedUserName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedUserName!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUserId = null;
                              _selectedUserName = null;
                            });
                          },
                          child: const Icon(Icons.close,
                              color: AppColors.primary, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_searchResults.isNotEmpty &&
                    _selectedUserId == null) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppColors.cardBorder,
                      ),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            user['collection'] == 'drivers'
                                ? Icons.local_taxi
                                : Icons.person,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            user['name'] ?? '',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            user['phone'] ?? '',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedUserId = user['id'];
                              _selectedUserName = user['name'];
                              _searchResults = [];
                              _searchController.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Template quick-picks
              const Text(
                'Templates',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.keys.map((name) {
                  final selected = _selectedTemplate == name;
                  return GestureDetector(
                    onTap: () => _applyTemplate(name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Title field
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Notification title',
                  labelText: 'Title',
                ),
                onChanged: (_) {
                  if (_selectedTemplate != null) {
                    setState(() => _selectedTemplate = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Body field
              TextField(
                controller: _bodyController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notification body...',
                  labelText: 'Body',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) {
                  if (_selectedTemplate != null) {
                    setState(() => _selectedTemplate = null);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Send button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF08090C),
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF08090C),
                          ),
                        )
                      : const Text(
                          'Send Notification',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
