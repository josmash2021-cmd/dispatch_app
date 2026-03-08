import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/app_theme.dart';
import '../providers/verification_provider.dart';
import '../services/dispatch_api_service.dart';
import '../services/verification_service.dart';

class VerificationReviewScreen extends StatefulWidget {
  const VerificationReviewScreen({super.key});
  @override
  State<VerificationReviewScreen> createState() =>
      _VerificationReviewScreenState();
}

class _VerificationReviewScreenState extends State<VerificationReviewScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerificationProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<VerificationProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            const Text('Verification Review'),
            if (prov.pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${prov.pendingCount}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: prov.startListening,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: prov.setSearchQuery,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textHint,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textHint,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          prov.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip(
                  prov,
                  'all',
                  'All',
                  prov.totalCount,
                  AppColors.primary,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  prov,
                  'pending',
                  'Pending',
                  prov.pendingTotal,
                  AppColors.warning,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  prov,
                  'approved',
                  'Approved',
                  prov.approvedTotal,
                  AppColors.success,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  prov,
                  'rejected',
                  'Rejected',
                  prov.rejectedTotal,
                  AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Body
          Expanded(child: _buildBody(prov)),
        ],
      ),
    );
  }

  Widget _filterChip(
    VerificationProvider prov,
    String value,
    String label,
    int count,
    Color color,
  ) {
    final selected = prov.filter == value;
    return GestureDetector(
      onTap: () => prov.setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.20)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: color.withValues(alpha: 0.40))
              : null,
        ),
        child: Text(
          '$label: $count',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(VerificationProvider prov) {
    if (prov.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (prov.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              prov.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: prov.startListening,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (prov.verifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              prov.filter == 'pending'
                  ? 'No pending verifications'
                  : 'No verification requests',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async => prov.startListening(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: prov.verifications.length,
        itemBuilder: (_, i) =>
            _VerificationCard(request: prov.verifications[i]),
      ),
    );
  }
}

// ─── Verification Card ──────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  final VerificationRequest request;
  const _VerificationCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: request.isPending
              ? AppColors.warning.withValues(alpha: 0.25)
              : AppColors.cardBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: request.profilePhotoUrl != null
                      ? NetworkImage(
                          DispatchApiService.fullUrl(request.profilePhotoUrl!),
                        )
                      : request.userId > 0
                      ? NetworkImage(
                          DispatchApiService.photoUrl(request.userId),
                        )
                      : null,
                  onBackgroundImageError:
                      request.profilePhotoUrl != null || request.userId > 0
                      ? (_, _) {}
                      : null,
                  child: request.profilePhotoUrl == null && request.userId <= 0
                      ? Text(
                          request.fullName.isNotEmpty
                              ? request.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.fullName.isNotEmpty
                                  ? request.fullName
                                  : 'Unknown',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon(request.status),
                                  color: statusColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel(request.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _docTypeLabel(request.idDocumentType),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.role.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.submittedAt != null
                            ? timeago.format(request.submittedAt!)
                            : 'Unknown time',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.isPending)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    // Pending requests open a full-screen page for better document review
    if (request.isPending) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PendingVerificationDetailPage(request: request),
        ),
      );
      return;
    }

    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');
    final statusColor = _statusColor(request.status);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ListView(
            controller: scrollCtrl,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Avatar + name
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: request.profilePhotoUrl != null
                      ? NetworkImage(
                          DispatchApiService.fullUrl(request.profilePhotoUrl!),
                        )
                      : request.userId > 0
                      ? NetworkImage(
                          DispatchApiService.photoUrl(request.userId),
                        )
                      : null,
                  onBackgroundImageError:
                      request.profilePhotoUrl != null || request.userId > 0
                      ? (_, _) {}
                      : null,
                  child: request.profilePhotoUrl == null && request.userId <= 0
                      ? Text(
                          request.fullName.isNotEmpty
                              ? request.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  request.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Status + role badges
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(request.status),
                            color: statusColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel(request.status),
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        request.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader('Contact'),
              _detailRow(
                Icons.phone_outlined,
                'Phone',
                request.phone.isNotEmpty ? request.phone : 'Not set',
              ),
              _detailRow(
                Icons.email_outlined,
                'Email',
                request.email ?? 'Not set',
              ),

              const SizedBox(height: 16),
              _sectionHeader('Verification Info'),
              _detailRow(
                Icons.badge_outlined,
                'Document Type',
                _docTypeLabel(request.idDocumentType),
              ),
              _detailRow(
                Icons.perm_identity_rounded,
                'User ID',
                'sql_${request.userId}',
              ),
              if (request.submittedAt != null)
                _detailRow(
                  Icons.calendar_today_rounded,
                  'Submitted',
                  dateFmt.format(request.submittedAt!),
                ),
              if (request.reviewedAt != null)
                _detailRow(
                  Icons.check_circle_outline_rounded,
                  'Reviewed',
                  dateFmt.format(request.reviewedAt!),
                ),
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.reason!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── SSN ──
              const SizedBox(height: 20),
              _sectionHeader('Social Security Number'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: request.ssnProvided
                        ? AppColors.success.withValues(alpha: 0.35)
                        : AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 20,
                      color: request.ssnProvided
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.ssnProvided
                                ? 'SSN Provided'
                                : 'SSN Not Provided',
                            style: TextStyle(
                              color: request.ssnProvided
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (request.ssnProvided) ...[
                            const SizedBox(height: 2),
                            Text(
                              request.ssnMasked ??
                                  '***-**-${request.ssnLast4 ?? "????"}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (request.ssnLast4 != null)
                              Text(
                                'Last 4: ${request.ssnLast4}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      request.ssnProvided
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      color: request.ssnProvided
                          ? AppColors.success
                          : AppColors.warning,
                      size: 22,
                    ),
                  ],
                ),
              ),

              // ── Verification Photos ──
              const SizedBox(height: 20),
              _sectionHeader('Verification Photos'),
              if (request.profilePhotoUrl != null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Profile Photo',
                  DispatchApiService.fullUrl(request.profilePhotoUrl!),
                ),
              ] else if (request.userId > 0) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Profile Photo',
                  DispatchApiService.photoUrl(request.userId),
                ),
              ],
              if (request.licenseFrontUrl != null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Driver License — Front',
                  DispatchApiService.fullUrl(request.licenseFrontUrl!),
                ),
              ],
              if (request.licenseBackUrl != null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Driver License — Back',
                  DispatchApiService.fullUrl(request.licenseBackUrl!),
                ),
              ],
              if (request.insuranceUrl != null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Car Insurance',
                  DispatchApiService.fullUrl(request.insuranceUrl!),
                ),
              ],
              if (request.idPhotoUrl != null &&
                  request.licenseFrontUrl == null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'ID Document (${_docTypeLabel(request.idDocumentType)})',
                  DispatchApiService.fullUrl(request.idPhotoUrl!),
                ),
              ],
              if (request.selfieUrl != null) ...[
                const SizedBox(height: 8),
                _photoCard(
                  context,
                  'Biometric Selfie',
                  DispatchApiService.fullUrl(request.selfieUrl!),
                ),
              ],
              if (request.vehicle != null) ...[
                const SizedBox(height: 16),
                _sectionHeader('Vehicle'),
                _detailRow(
                  Icons.directions_car_rounded,
                  'Car',
                  [
                    request.vehicle!['year'],
                    request.vehicle!['make'],
                    request.vehicle!['model'],
                  ].where((v) => v != null && '$v'.isNotEmpty).join(' '),
                ),
                if (request.vehicle!['color'] != null)
                  _detailRow(
                    Icons.palette_outlined,
                    'Color',
                    '${request.vehicle!['color']}',
                  ),
                if (request.vehicle!['plate'] != null)
                  _detailRow(
                    Icons.pin_outlined,
                    'Plate',
                    '${request.vehicle!['plate']}',
                  ),
              ],
              if (request.idPhotoUrl == null &&
                  request.selfieUrl == null &&
                  request.profilePhotoUrl == null &&
                  request.licenseFrontUrl == null &&
                  request.userId <= 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No photos available yet',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ),

              // ── Account Details from Backend ──
              if (request.userId > 0) ...[
                const SizedBox(height: 20),
                _sectionHeader('Account Details'),
                _UserDetailWidget(userId: request.userId),
              ],

              // Action buttons
              if (request.isPending) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectDialog(ctx),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveConfirm(ctx),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _approveConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text(
              'Approve Verification',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Approve identity verification for ${request.fullName}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx); // close dialog
              Navigator.pop(context); // close bottom sheet
              context.read<VerificationProvider>().approve(request.docId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${request.fullName} approved',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text(
              'Approve',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _rejectDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Reject Verification',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject verification for ${request.fullName}?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogCtx); // close dialog
              Navigator.pop(context); // close bottom sheet
              context.read<VerificationProvider>().reject(
                request.docId,
                reason,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${request.fullName} rejected',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text(
              'Reject',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard(BuildContext context, String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showFullPhoto(context, label, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textHint,
                      size: 36,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Photo not available',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  width: double.infinity,
                  color: AppColors.surfaceHigh,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showFullPhoto(BuildContext context, String label, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pending Verification Detail Page ────────────────────────────────────────

class _PendingVerificationDetailPage extends StatefulWidget {
  final VerificationRequest request;
  const _PendingVerificationDetailPage({required this.request});

  @override
  State<_PendingVerificationDetailPage> createState() =>
      _PendingVerificationDetailPageState();
}

class _PendingVerificationDetailPageState
    extends State<_PendingVerificationDetailPage> {
  Map<String, dynamic>? _backendUser;

  VerificationRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    _loadBackendUser();
  }

  Future<void> _loadBackendUser() async {
    if (request.userId <= 0) return;
    try {
      final data = await DispatchApiService.getUserDetail(request.userId);
      if (mounted) setState(() => _backendUser = data);
    } catch (_) {}
  }

  /// Pick first non-null non-empty URL: Firestore first, then backend.
  String? _pickUrl(String? firestoreUrl, String backendKey) {
    if (firestoreUrl != null && firestoreUrl.isNotEmpty) return firestoreUrl;
    final be = _backendUser?[backendKey] as String?;
    if (be != null && be.isNotEmpty) return be;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');

    // Merge photo URLs: Firestore → backend fallback
    final profileUrl = _pickUrl(request.profilePhotoUrl, 'photo_url');
    final licenseFrontUrl = _pickUrl(
      request.licenseFrontUrl,
      'license_front_url',
    );
    final licenseBackUrl = _pickUrl(request.licenseBackUrl, 'license_back_url');
    final insuranceUrl = _pickUrl(request.insuranceUrl, 'insurance_url');
    final idPhotoUrl = _pickUrl(request.idPhotoUrl, 'id_photo_url');
    final selfieUrl = _pickUrl(request.selfieUrl, 'selfie_url');

    // SSN: Firestore → backend fallback
    final ssnProvided =
        request.ssnProvided ||
        (_backendUser?['ssn_provided'] as bool? ?? false);
    final ssnFull = _backendUser?['ssn_full'] as String?;
    final ssnMasked =
        request.ssnMasked ?? _backendUser?['ssn_masked'] as String?;
    final ssnLast4 = request.ssnLast4 ?? _backendUser?['ssn_last4'] as String?;

    // Vehicle: Firestore → backend fallback
    final vehicle =
        request.vehicle ??
        (_backendUser?['vehicle_type'] != null
            ? {'type': _backendUser!['vehicle_type']}
            : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Solicitud de Verificación',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: AppColors.warning,
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  'PENDIENTE',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          // ── Profile header ──
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: request.profilePhotoUrl != null
                  ? NetworkImage(
                      DispatchApiService.fullUrl(request.profilePhotoUrl!),
                    )
                  : request.userId > 0
                  ? NetworkImage(DispatchApiService.photoUrl(request.userId))
                  : null,
              onBackgroundImageError:
                  request.profilePhotoUrl != null || request.userId > 0
                  ? (_, _) {}
                  : null,
              child: request.profilePhotoUrl == null && request.userId <= 0
                  ? Text(
                      request.fullName.isNotEmpty
                          ? request.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              request.fullName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _docTypeLabel(request.idDocumentType),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Contact ──
          const SizedBox(height: 28),
          _sectionHeader('Contacto'),
          _detailRow(
            Icons.phone_outlined,
            'Teléfono',
            request.phone.isNotEmpty ? request.phone : 'No registrado',
          ),
          _detailRow(
            Icons.email_outlined,
            'Email',
            request.email ?? 'No registrado',
          ),

          // ── Verification info ──
          const SizedBox(height: 20),
          _sectionHeader('Información de Verificación'),
          _detailRow(
            Icons.badge_outlined,
            'Tipo de Documento',
            _docTypeLabel(request.idDocumentType),
          ),
          _detailRow(
            Icons.perm_identity_rounded,
            'User ID',
            'sql_${request.userId}',
          ),
          if (request.submittedAt != null)
            _detailRow(
              Icons.calendar_today_rounded,
              'Enviado',
              dateFmt.format(request.submittedAt!),
            ),

          // ── SSN ──
          const SizedBox(height: 20),
          _sectionHeader('Número de Seguro Social'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ssnProvided
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 20,
                  color: ssnProvided ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ssnProvided
                            ? 'SSN Proporcionado'
                            : 'SSN No Proporcionado',
                        style: TextStyle(
                          color: ssnProvided
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (ssnProvided) ...[
                        const SizedBox(height: 2),
                        Text(
                          ssnFull ??
                              ssnMasked ??
                              '***-**-${ssnLast4 ?? "????"}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (ssnLast4 != null)
                          Text(
                            'Últimos 4: $ssnLast4',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  ssnProvided
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: ssnProvided ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
              ],
            ),
          ),

          // ── Verification Photos ──
          const SizedBox(height: 28),
          _sectionHeader('Fotos de Verificación'),

          // Profile photo
          if (profileUrl != null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Foto de Perfil',
              DispatchApiService.fullUrl(profileUrl),
            ),
          ] else if (request.userId > 0) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Foto de Perfil',
              DispatchApiService.photoUrl(request.userId),
            ),
          ],

          // Driver license front
          if (licenseFrontUrl != null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Licencia de Conducir — Frente',
              DispatchApiService.fullUrl(licenseFrontUrl),
            ),
          ],

          // Driver license back
          if (licenseBackUrl != null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Licencia de Conducir — Dorso',
              DispatchApiService.fullUrl(licenseBackUrl),
            ),
          ],

          // Insurance
          if (insuranceUrl != null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Seguro del Vehículo',
              DispatchApiService.fullUrl(insuranceUrl),
            ),
          ],

          // Fallback: id_photo (for riders using identity_verification_screen)
          if (idPhotoUrl != null && licenseFrontUrl == null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Documento ID (${_docTypeLabel(request.idDocumentType)})',
              DispatchApiService.fullUrl(idPhotoUrl),
            ),
          ],

          // Selfie / biometrics
          if (selfieUrl != null) ...[
            const SizedBox(height: 10),
            _photoCard(
              context,
              'Selfie Biométrico',
              DispatchApiService.fullUrl(selfieUrl),
            ),
          ],

          // Vehicle info (drivers)
          if (vehicle != null) ...[
            const SizedBox(height: 20),
            _sectionHeader('Vehículo'),
            _detailRow(
              Icons.directions_car_rounded,
              'Auto',
              [
                vehicle['year'],
                vehicle['make'],
                vehicle['model'],
              ].where((v) => v != null && '$v'.isNotEmpty).join(' '),
            ),
            if (vehicle['color'] != null)
              _detailRow(
                Icons.palette_outlined,
                'Color',
                '${vehicle['color']}',
              ),
            if (vehicle['plate'] != null)
              _detailRow(Icons.pin_outlined, 'Placa', '${vehicle['plate']}'),
          ],

          if (idPhotoUrl == null &&
              selfieUrl == null &&
              profileUrl == null &&
              licenseFrontUrl == null &&
              request.userId <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay fotos disponibles todavía',
                style: TextStyle(color: AppColors.textHint, fontSize: 13),
              ),
            ),

          // ── Account Details from Backend ──
          if (request.userId > 0) ...[
            const SizedBox(height: 28),
            _sectionHeader('Detalles de la Cuenta'),
            _UserDetailWidget(userId: request.userId),
          ],
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.cardBorder, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectDialog(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'Rechazar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveConfirm(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Aprobar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard(BuildContext context, String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showFullPhoto(context, label, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textHint,
                      size: 36,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Foto no disponible',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: AppColors.surfaceHigh,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showFullPhoto(BuildContext context, String label, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approveConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text(
              'Aprobar Verificación',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          '¿Aprobar la verificación de identidad de ${request.fullName}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final prov = context.read<VerificationProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              prov.approve(request.docId);
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${request.fullName} aprobado',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text(
              'Aprobar',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _rejectDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Rechazar Verificación',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Rechazar la verificación de ${request.fullName}?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Motivo del rechazo...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              final prov = context.read<VerificationProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              prov.reject(request.docId, reason);
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${request.fullName} rechazado',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text(
              'Rechazar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User Detail Widget (fetches from backend API) ──────────────────────────

class _UserDetailWidget extends StatefulWidget {
  final int userId;
  const _UserDetailWidget({required this.userId});
  @override
  State<_UserDetailWidget> createState() => _UserDetailWidgetState();
}

class _UserDetailWidgetState extends State<_UserDetailWidget> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _ssnRevealed = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await DispatchApiService.getUserDetail(widget.userId);
      if (mounted) {
        setState(() {
          _user = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Could not load: $_error',
          style: const TextStyle(color: AppColors.textHint, fontSize: 13),
        ),
      );
    }
    if (_user == null) return const SizedBox.shrink();

    final password = _user!['password_plain'] as String?;
    final hasPassword = _user!['has_password'] as bool? ?? false;
    final createdAt = _user!['created_at'] as String?;
    final verStatus = _user!['verification_status'] as String? ?? 'none';
    final docs =
        (_user!['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // SSN from backend
    final ssnProvided = _user!['ssn_provided'] as bool? ?? false;
    final ssnMasked = _user!['ssn_masked'] as String?;
    final ssnLast4 = _user!['ssn_last4'] as String?;
    final ssnFull = _user!['ssn_full'] as String?;
    // Fallback photos from backend user model
    final backendIdPhoto = _user!['id_photo_url'] as String?;
    final backendSelfie = _user!['selfie_url'] as String?;
    final vehicleType = _user!['vehicle_type'] as String?;
    final username = _user!['username'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Account info ──
        _infoRow(
          Icons.lock_open_rounded,
          'Password',
          password != null && password.isNotEmpty
              ? password
              : hasPassword
              ? '(set but not stored in plaintext)'
              : 'No password',
        ),
        if (username != null && username.isNotEmpty)
          _infoRow(Icons.account_circle_outlined, 'Username', username),
        _infoRow(Icons.verified_user_outlined, 'Verification', verStatus),
        if (vehicleType != null && vehicleType.isNotEmpty)
          _infoRow(Icons.directions_car_outlined, 'Vehicle Type', vehicleType),
        if (createdAt != null)
          _infoRow(
            Icons.calendar_today_rounded,
            'Registered',
            _formatDate(createdAt),
          ),

        // ── SSN from backend ──
        const SizedBox(height: 10),
        GestureDetector(
          onTap: ssnProvided && ssnFull != null
              ? () => setState(() => _ssnRevealed = !_ssnRevealed)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ssnProvided
                  ? AppColors.success.withValues(alpha: 0.07)
                  : AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ssnProvided
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 17,
                  color: ssnProvided ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'SSN',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ssnProvided && ssnFull != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _ssnRevealed ? 'Tap to hide' : 'Tap to reveal',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        ssnProvided
                            ? (_ssnRevealed && ssnFull != null
                                  ? ssnFull
                                  : (ssnMasked ??
                                        '***-**-${ssnLast4 ?? "????"}'))
                            : 'No proporcionado',
                        style: TextStyle(
                          color: ssnProvided
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ssnProvided ? 'Verified' : 'Missing',
                  style: TextStyle(
                    color: ssnProvided ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Backend verification photos (fallback if Firestore photos missing) ──
        if (backendIdPhoto != null || backendSelfie != null) ...[
          const SizedBox(height: 12),
          const Text(
            'ID Photos (Server)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (backendIdPhoto != null)
            _buildPhotoCard(context, 'ID Document', backendIdPhoto),
          if (backendSelfie != null)
            _buildPhotoCard(context, 'Selfie', backendSelfie),
        ],

        // ── Documents from server ──
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Server Documents',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...docs.map((doc) => _buildDocCard(context, doc)),
        ],
      ],
    );
  }

  Widget _buildPhotoCard(BuildContext context, String label, String rawPath) {
    final url = rawPath.startsWith('http')
        ? rawPath
        : DispatchApiService.fullUrl(rawPath);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullPhoto(context, label, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildDocCard(BuildContext context, Map<String, dynamic> doc) {
    final docType = (doc['doc_type'] as String? ?? 'unknown').replaceAll(
      '_',
      ' ',
    );
    final status = doc['status'] as String? ?? 'pending';
    final filePath = doc['file_path'] as String?;
    final statusColor = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
        ? AppColors.error
        : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  docType.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (filePath != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showFullPhoto(
                context,
                docType.toUpperCase(),
                DispatchApiService.documentUrl(filePath),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  DispatchApiService.documentUrl(filePath),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textHint,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullPhoto(BuildContext context, String label, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warning;
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.textHint;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.hourglass_top_rounded;
    case 'approved':
      return Icons.verified_rounded;
    case 'rejected':
      return Icons.block_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return status;
  }
}

String _docTypeLabel(String type) {
  switch (type) {
    case 'license':
      return "Driver's License";
    case 'passport':
      return 'Passport';
    case 'id_card':
      return 'Government ID';
    default:
      return type;
  }
}
