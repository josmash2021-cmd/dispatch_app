import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  bool _isLoading = true;

  // Summary data
  double _totalPending = 0;
  double _payoutsThisWeek = 0;
  int _failedCount = 0;

  // Pending drivers
  List<Map<String, dynamic>> _pendingDrivers = [];

  // Payout history
  List<Map<String, dynamic>> _payoutHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadPendingDrivers(),
        _loadPayoutHistory(),
        _loadFailedCount(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingDrivers() async {
    final snapshot = await _firestore
        .collection('drivers')
        .where('balance', isGreaterThan: 0)
        .get();

    double pending = 0;
    final drivers = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      final balance = (data['balance'] as num?)?.toDouble() ?? 0;
      pending += balance;
      drivers.add(data);
    }

    // Sort by balance descending
    drivers.sort((a, b) =>
        ((b['balance'] as num?) ?? 0).compareTo((a['balance'] as num?) ?? 0));

    if (mounted) {
      setState(() {
        _pendingDrivers = drivers;
        _totalPending = pending;
      });
    }
  }

  Future<void> _loadPayoutHistory() async {
    final snapshot = await _firestore
        .collection('payouts')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final history = <Map<String, dynamic>>[];
    double weekTotal = 0;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      history.add(data);

      // Sum completed payouts this week
      if (data['status'] == 'completed' && data['completedAt'] != null) {
        final completedAt = (data['completedAt'] as Timestamp).toDate();
        if (completedAt.isAfter(weekStartDate)) {
          weekTotal += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    if (mounted) {
      setState(() {
        _payoutHistory = history;
        _payoutsThisWeek = weekTotal;
      });
    }
  }

  Future<void> _loadFailedCount() async {
    final snapshot = await _firestore
        .collection('payouts')
        .where('status', isEqualTo: 'failed')
        .count()
        .get();

    if (mounted) {
      setState(() {
        _failedCount = snapshot.count ?? 0;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPendingDrivers {
    if (_searchQuery.isEmpty) return _pendingDrivers;
    return _pendingDrivers.where((d) {
      final name = (d['fullName'] ?? d['driverName'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_searchQuery.isEmpty) return _payoutHistory;
    return _payoutHistory.where((p) {
      final name = (p['driverName'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payouts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryCards(),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by driver name...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF08090C),
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'History'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ─────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Pending',
              value: '\$${_totalPending.toStringAsFixed(2)}',
              icon: Icons.pending_actions_rounded,
              color: AppColors.primary,
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'This Week',
              value: '\$${_payoutsThisWeek.toStringAsFixed(2)}',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.primary,
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Failed',
              value: '$_failedCount',
              icon: Icons.error_outline_rounded,
              color: Colors.redAccent,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pending Tab ───────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final drivers = _filteredPendingDrivers;

    if (drivers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: _searchQuery.isNotEmpty
            ? 'No drivers match your search'
            : 'No pending payouts',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadData,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                return _AnimatedCardEntry(
                  index: index,
                  child: _PendingDriverCard(
                    driver: drivers[index],
                    onPayNow: () => _showPayDialog(drivers[index]),
                  ),
                );
              },
            ),
          ),
          // Pay All button
          if (drivers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: () => _showPayAllDialog(),
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  'Pay All (${drivers.length} drivers)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF08090C),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── History Tab ───────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final history = _filteredHistory;

    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        message: _searchQuery.isNotEmpty
            ? 'No payouts match your search'
            : 'No payout history yet',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: history.length,
        itemBuilder: (context, index) {
          return _AnimatedCardEntry(
            index: index,
            child: _PayoutHistoryCard(payout: history[index]),
          );
        },
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textHint, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─── Pay Now Dialog ────────────────────────────────────────────────────

  Future<void> _showPayDialog(Map<String, dynamic> driver) async {
    String selectedMethod = 'bank_transfer';
    final driverName = driver['fullName'] ?? driver['driverName'] ?? 'Unknown';
    final balance = (driver['balance'] as num?)?.toDouble() ?? 0;
    final driverId = driver['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Confirm Payout',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            _initials(driverName),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Method selector
                  const Text(
                    'Payout Method',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMethodOption(
                    label: 'Bank Transfer',
                    subtitle: '1-3 business days',
                    icon: Icons.account_balance_rounded,
                    value: 'bank_transfer',
                    selected: selectedMethod,
                    onTap: () {
                      setDialogState(() => selectedMethod = 'bank_transfer');
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMethodOption(
                    label: 'Instant',
                    subtitle: 'Within minutes',
                    icon: Icons.flash_on_rounded,
                    value: 'instant',
                    selected: selectedMethod,
                    onTap: () {
                      setDialogState(() => selectedMethod = 'instant');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF08090C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      await _processPayout(driverId, driverName, balance, selectedMethod);
    }
  }

  Widget _buildMethodOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pay All Dialog ────────────────────────────────────────────────────

  Future<void> _showPayAllDialog() async {
    final drivers = _filteredPendingDrivers;
    final total = drivers.fold<double>(
        0, (sum, d) => sum + ((d['balance'] as num?)?.toDouble() ?? 0));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Pay All Drivers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payments_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                '${drivers.length} drivers',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will process bank transfers for all pending driver balances.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF08090C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Pay All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      for (final driver in drivers) {
        final driverId = driver['id'] as String;
        final driverName =
            driver['fullName'] ?? driver['driverName'] ?? 'Unknown';
        final balance = (driver['balance'] as num?)?.toDouble() ?? 0;
        await _processPayout(driverId, driverName.toString(), balance, 'bank_transfer');
      }
    }
  }

  // ─── Process Payout ────────────────────────────────────────────────────

  Future<void> _processPayout(
    String driverId,
    String driverName,
    double amount,
    String method,
  ) async {
    try {
      final batch = _firestore.batch();

      // Create payout record
      final payoutRef = _firestore.collection('payouts').doc();
      batch.set(payoutRef, {
        'driverId': driverId,
        'driverName': driverName,
        'amount': amount,
        'status': 'processing',
        'method': method,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      });

      // Reset driver balance
      final driverRef = _firestore.collection('drivers').doc(driverId);
      batch.update(driverRef, {'balance': 0});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout of \$${amount.toStringAsFixed(2)} initiated for $driverName'),
            backgroundColor: AppColors.surfaceHigh,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout failed: $e'),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private Widgets
// ═════════════════════════════════════════════════════════════════════════════

// ─── Summary Card ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          isLoading
              ? Container(
                  height: 20,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ─── Pending Driver Card ─────────────────────────────────────────────────

class _PendingDriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onPayNow;

  const _PendingDriverCard({required this.driver, required this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final name = (driver['fullName'] ?? driver['driverName'] ?? 'Unknown').toString();
    final balance = (driver['balance'] as num?)?.toDouble() ?? 0;
    final totalTrips = (driver['totalTrips'] as num?)?.toInt() ?? 0;
    final rating = (driver['rating'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar with gold border
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surfaceHigh,
              backgroundImage: driver['photoUrl'] != null &&
                      (driver['photoUrl'] as String).isNotEmpty
                  ? NetworkImage(driver['photoUrl'] as String)
                  : null,
              child: driver['photoUrl'] == null ||
                      (driver['photoUrl'] as String).isEmpty
                  ? Text(
                      _initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.route_rounded,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalTrips trips',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 14),
                    ...List.generate(5, (i) {
                      return Icon(
                        i < rating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: i < rating.round()
                            ? AppColors.primary
                            : AppColors.textHint,
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Pay Now button
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF08090C),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              child: const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ─── Payout History Card ─────────────────────────────────────────────────

class _PayoutHistoryCard extends StatelessWidget {
  final Map<String, dynamic> payout;

  const _PayoutHistoryCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    final name = (payout['driverName'] ?? 'Unknown').toString();
    final amount = (payout['amount'] as num?)?.toDouble() ?? 0;
    final status = (payout['status'] ?? 'pending').toString();
    final createdAt = payout['createdAt'] is Timestamp
        ? (payout['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final method = (payout['method'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              method == 'instant'
                  ? Icons.flash_on_rounded
                  : Icons.account_balance_rounded,
              color: _statusColor(status),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(createdAt),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              _StatusChip(status: status),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.primary;
      case 'failed':
        return Colors.redAccent;
      case 'processing':
        return Colors.white;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color bgColor;

    switch (status) {
      case 'completed':
        textColor = AppColors.primary;
        bgColor = AppColors.primary.withValues(alpha: 0.12);
      case 'failed':
        textColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.12);
      case 'processing':
        textColor = Colors.white;
        bgColor = Colors.white.withValues(alpha: 0.08);
      default:
        textColor = AppColors.textSecondary;
        bgColor = AppColors.surfaceHigh;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Animated Card Entry ─────────────────────────────────────────────────

class _AnimatedCardEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedCardEntry({required this.index, required this.child});

  @override
  State<_AnimatedCardEntry> createState() => _AnimatedCardEntryState();
}

class _AnimatedCardEntryState extends State<_AnimatedCardEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);

    // Stagger based on index, capped so later items don't wait too long
    final delay = Duration(milliseconds: (widget.index * 50).clamp(0, 300));
    Future.delayed(delay, () {
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
