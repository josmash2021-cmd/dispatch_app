import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with TickerProviderStateMixin {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<DocumentSnapshot> _alerts = [];
  String _selectedSeverity = 'all';
  int _unreadCount = 0;
  bool _loading = true;

  // Track which doc IDs have already been animated in
  final Set<String> _animatedIds = {};

  static const _severityFilters = ['all', 'critical', 'high', 'medium'];

  static const _severityColors = {
    'critical': Color(0xFFEF4444),
    'high': Color(0xFFF97316),
    'medium': Color(0xFFEAB308),
    'low': Color(0xFF22C55E),
  };

  static const _typeIcons = {
    'payment_failed': Icons.payment,
    'server_errors': Icons.dns,
    'security_ip_blocked': Icons.shield,
    'db_slow': Icons.storage,
    'high_error_rate': Icons.warning,
    'stripe_charge_failed': Icons.credit_card,
  };

  @override
  void initState() {
    super.initState();
    _listenToAlerts();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToAlerts() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('admin_alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _alerts = snapshot.docs;
          _unreadCount =
              _alerts.where((d) => (d.data() as Map)['read'] != true).length;
          _loading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _loading = false);
        debugPrint('AlertsScreen stream error: $error');
      },
    );
  }

  List<DocumentSnapshot> get _filteredAlerts {
    if (_selectedSeverity == 'all') return _alerts;
    return _alerts.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['severity'] == _selectedSeverity;
    }).toList();
  }

  Future<void> _markAsRead(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    if (data['read'] == true) return;
    try {
      await doc.reference.update({'read': true});
    } catch (e) {
      debugPrint('Failed to mark alert as read: $e');
    }
  }

  Future<void> _markAllRead() async {
    final unread = _alerts.where((d) => (d.data() as Map)['read'] != true);
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark all as read'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  IconData _iconForType(String? type) {
    return _typeIcons[type] ?? Icons.notifications;
  }

  Color _colorForSeverity(String? severity) {
    return _severityColors[severity] ?? const Color(0xFF22C55E);
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAlerts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Alerts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Color(0xFF08090C),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 18, color: AppColors.primary),
              label: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          // Alert list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildAlertCard(filtered[index], index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _severityFilters.map((filter) {
          final selected = _selectedSeverity == filter;
          final label =
              filter == 'all' ? 'All' : filter[0].toUpperCase() + filter.substring(1);

          // Count for each filter
          int count;
          if (filter == 'all') {
            count = _alerts.length;
          } else {
            count = _alerts
                .where(
                    (d) => (d.data() as Map<String, dynamic>)['severity'] == filter)
                .length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(
                '$label ($count)',
                style: TextStyle(
                  color: selected ? const Color(0xFF08090C) : AppColors.textSecondary,
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
                setState(() => _selectedSeverity = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String?;
    final title = data['title'] as String? ?? 'Alert';
    final message = data['message'] as String? ?? '';
    final severity = data['severity'] as String?;
    final isRead = data['read'] == true;
    final createdAt = data['createdAt'];

    final sevColor = _colorForSeverity(severity);
    final isNew = !_animatedIds.contains(doc.id);
    if (isNew) _animatedIds.add(doc.id);

    Widget card = Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.done, color: AppColors.primary, size: 28),
      ),
      onDismissed: (_) => _markAsRead(doc),
      child: GestureDetector(
        onTap: () => _markAsRead(doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Severity bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: sevColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconForType(type),
                            color: sevColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight:
                                            isRead ? FontWeight.w500 : FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _relativeTime(createdAt),
                                style: const TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                            ],
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
      ),
    );

    // Stagger fade-in for new items
    if (isNew) {
      final delay = Duration(milliseconds: (index * 50).clamp(0, 400));
      return _StaggerFadeIn(delay: delay, child: card);
    }

    return card;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedSeverity == 'all'
                ? 'No alerts yet'
                : 'No ${_selectedSeverity} alerts',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'System alerts will appear here',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stagger fade-in animation widget
class _StaggerFadeIn extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _StaggerFadeIn({required this.delay, required this.child});

  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
