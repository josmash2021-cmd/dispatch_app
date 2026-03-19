import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Displays upcoming scheduled rides (airport pickups, scheduled trips)
/// from the Firestore `scheduled_rides` collection.
/// Dispatchers can view, assign drivers, or cancel scheduled rides.
class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  final _db = FirebaseFirestore.instance;
  String _filter = 'all'; // all, scheduled, assigned, completed, cancelled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Scheduled Rides',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: AppColors.primary),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'scheduled', child: Text('Scheduled')),
              const PopupMenuItem(value: 'assigned', child: Text('Assigned')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No scheduled rides',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) => _buildCard(docs[i]),
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query q = _db
        .collection('scheduled_rides')
        .orderBy('scheduledAt', descending: false);
    if (_filter != 'all') {
      q = q.where('status', isEqualTo: _filter);
    }
    return q.snapshots();
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'scheduled';
    final flightNum = data['flight_number'] ?? '';
    final airline = data['airline'] ?? '';
    final airport = data['airport_code'] ?? '';
    final vehicleType = data['vehicle_type'] ?? '';
    final meetInside = data['meet_inside'] == true;
    final notes = data['notes'] ?? '';
    final dropoff = data['dropoff_address'] ?? '';
    final type = data['type'] ?? 'scheduled';

    DateTime? scheduledAt;
    if (data['scheduledAt'] is Timestamp) {
      scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
    } else if (data['scheduled_at'] is String) {
      scheduledAt = DateTime.tryParse(data['scheduled_at']);
    }

    final statusColor = _statusColor(status);
    final isUpcoming =
        scheduledAt != null && scheduledAt.isAfter(DateTime.now());

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  type == 'airport' ? Icons.flight_land : Icons.schedule,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type == 'airport'
                        ? 'Airport Pickup${flightNum.isNotEmpty ? ' · $flightNum' : ''}'
                        : 'Scheduled Ride',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date/Time
            if (scheduledAt != null) ...[
              _infoRow(Icons.calendar_today, _formatDate(scheduledAt)),
              const SizedBox(height: 6),
            ],

            // Airline/Airport
            if (airline.isNotEmpty || airport.isNotEmpty) ...[
              _infoRow(
                Icons.airlines,
                '$airline${airport.isNotEmpty ? ' ($airport)' : ''}',
              ),
              const SizedBox(height: 6),
            ],

            // Vehicle
            if (vehicleType.isNotEmpty) ...[
              _infoRow(Icons.directions_car, vehicleType),
              const SizedBox(height: 6),
            ],

            // Meet inside
            if (meetInside) ...[
              _infoRow(Icons.meeting_room, 'Meet inside terminal'),
              const SizedBox(height: 6),
            ],

            // Dropoff
            if (dropoff.isNotEmpty) ...[
              _infoRow(Icons.location_on, dropoff),
              const SizedBox(height: 6),
            ],

            // Notes
            if (notes.isNotEmpty) ...[
              _infoRow(Icons.note, notes),
              const SizedBox(height: 6),
            ],

            const SizedBox(height: 8),

            // Actions
            if (status == 'scheduled' && isUpcoming)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Assign Driver'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => _assignDriver(doc.id),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () => _cancelRide(doc.id),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return AppColors.accepted;
      case 'completed':
        return AppColors.completed;
      case 'cancelled':
        return AppColors.error;
      case 'scheduled':
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _assignDriver(String docId) async {
    // Fetch online drivers to pick from
    final driversSnap = await _db
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .get();
    final drivers = driversSnap.docs;

    if (!mounted) return;

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No online drivers available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show driver picker dialog
    final selected = await showDialog<QueryDocumentSnapshot>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
          title: const Text(
            'Assign Driver',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drivers.length,
            itemBuilder: (_, i) {
              final d = drivers[i].data();
              final name =
                  '${d['firstName'] ?? d['first_name'] ?? ''} ${d['lastName'] ?? d['last_name'] ?? ''}'
                      .trim();
              final vehicle = d['vehicleType'] ?? d['vehicle_type'] ?? '';
              return ListTile(
                leading: const Icon(Icons.person, color: AppColors.primary),
                title: Text(
                  name,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  vehicle,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () => Navigator.pop(ctx, drivers[i]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    try {
      final driverData = selected.data() as Map<String, dynamic>;
      final driverName =
          '${driverData['firstName'] ?? driverData['first_name'] ?? ''} ${driverData['lastName'] ?? driverData['last_name'] ?? ''}'
              .trim();
      final driverPhone = driverData['phone'] as String? ?? '';

      await _db.collection('scheduled_rides').doc(docId).update({
        'status': 'assigned',
        'driverId': selected.id,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned to $driverName'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelRide(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Cancel Ride?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will cancel the scheduled ride. The rider will be notified.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Ride',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.collection('scheduled_rides').doc(docId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
