import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/notification_provider.dart';

/// Dialog to send push notification to a user
class SendNotificationDialog extends StatefulWidget {
  final int userId;
  final String userName;

  const SendNotificationDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send Notification',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'To: ${widget.userName}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Quick templates
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _templateChip('Account Verified', 'Your account has been verified successfully!'),
                  const SizedBox(width: 8),
                  _templateChip('Trip Update', 'Your driver is on the way. ETA: 5 min'),
                  const SizedBox(width: 8),
                  _templateChip('Promo Code', 'Use code CRUISE20 for 20% off your next ride!'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Title field
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notification Title',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'e.g., Trip Update',
                hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Body field
            TextField(
              controller: _bodyCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'Enter your message here...',
                hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Send',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _templateChip(String label, String templateBody) {
    return GestureDetector(
      onTap: () {
        _titleCtrl.text = label;
        _bodyCtrl.text = templateBody;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please enter both title and message'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<NotificationProvider>();
    final success = await provider.sendNotificationToUser(
      userId: widget.userId,
      title: title,
      body: body,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Notification sent successfully!'),
        ),
      );
    }
  }
}

/// Extension to easily show the notification dialog
extension SendNotificationDialogExtension on BuildContext {
  Future<void> showSendNotificationDialog({
    required int userId,
    required String userName,
  }) async {
    return showDialog(
      context: this,
      builder: (context) => SendNotificationDialog(
        userId: userId,
        userName: userName,
      ),
    );
  }
}
