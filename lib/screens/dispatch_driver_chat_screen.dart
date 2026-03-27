import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Real-time chat between dispatch and a specific driver.
/// Firestore: dispatch_driver_chats/{driverId}/messages/{auto}
class DispatchDriverChatScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DispatchDriverChatScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DispatchDriverChatScreen> createState() =>
      _DispatchDriverChatScreenState();
}

class _DispatchDriverChatScreenState extends State<DispatchDriverChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  CollectionReference get _messagesRef => FirebaseFirestore.instance
      .collection('dispatch_driver_chats')
      .doc(widget.driverId)
      .collection('messages');

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _messagesRef.add({
        'text': text,
        'sender': 'dispatch',
        'senderEmail': user?.email ?? 'dispatch',
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Update chat metadata for unread badge on driver side
      await FirebaseFirestore.instance
          .collection('dispatch_driver_chats')
          .doc(widget.driverId)
          .set({
        'lastMessage': text,
        'lastSender': 'dispatch',
        'updatedAt': FieldValue.serverTimestamp(),
        'driverName': widget.driverName,
        'driverUnread': FieldValue.increment(1),
      }, SetOptions(merge: true));
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
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                widget.driverName.isNotEmpty
                    ? widget.driverName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Driver Chat',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.cardBorder),
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesRef.orderBy('timestamp', descending: false).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay mensajes aún',
              style: TextStyle(color: AppColors.textHint),
            ),
          );
        }
        // Mark dispatch-read
        _markDispatchRead();
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data()! as Map<String, dynamic>;
            final isDispatch = d['sender'] == 'dispatch';
            final text = d['text'] as String? ?? '';
            final ts = d['timestamp'] as Timestamp?;
            return _MessageBubble(
              text: text,
              isMe: isDispatch,
              time: ts?.toDate(),
            );
          },
        );
      },
    );
  }

  void _markDispatchRead() {
    FirebaseFirestore.instance
        .collection('dispatch_driver_chats')
        .doc(widget.driverId)
        .set({'dispatchUnread': 0}, SetOptions(merge: true));
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Mensaje...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? time;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 3),
              Text(
                '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
