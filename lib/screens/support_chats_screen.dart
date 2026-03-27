import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../services/dispatch_api_service.dart';
import 'support_chat_detail_screen.dart';

class SupportChatsScreen extends StatefulWidget {
  const SupportChatsScreen({super.key});
  @override
  State<SupportChatsScreen> createState() => _SupportChatsScreenState();
}

class _SupportChatsScreenState extends State<SupportChatsScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  StreamSubscription? _firestoreSub;

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Real-time listener: refresh from backend when Firestore changes
    _firestoreSub = FirebaseFirestore.instance
        .collection('support_chats')
        .snapshots()
        .listen((_) => _loadChats());
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await DispatchApiService.listSupportChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SupportChats] load error: $e');
      if (mounted && _loading) setState(() => _loading = false);
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
          'Soporte',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay chats de soporte',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _chats.length,
        itemBuilder: (context, i) => _buildChatCard(_chats[i]),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    final name = chat['user_name'] ?? 'Unknown';
    final subject = chat['subject'] ?? '';
    final lastMsg = chat['last_message'] ?? '';
    final unread = chat['unread_count'] ?? 0;
    final status = chat['status'] ?? 'open';
    final isOpen = status == 'open';
    final lastSenderRole = chat['last_sender_role'] ?? '';
    final userId = chat['user_id'] as int?;
    final chatId = chat['id'] as int;
    final needsEscalation = chat['needs_escalation'] == true;
    final botPhase = chat['bot_phase'] ?? ''; // ignore: unused_local_variable
    final agentName = chat['agent_name'] ?? '';

    final String? photoUrl;
    if (userId != null) {
      photoUrl = DispatchApiService.photoUrl(userId);
    } else {
      photoUrl = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsEscalation
              ? AppColors.error.withValues(alpha: 0.6)
              : unread > 0
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.cardBorder,
          width: needsEscalation ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              slideFromRightRoute(
                SupportChatDetailScreen(
                  chatId: chatId,
                  userName: name,
                  userId: userId,
                  needsEscalation: needsEscalation,
                  supervisorConnected: chat['supervisor_connected'] == true,
                ),
              ),
            );
            _loadChats();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (needsEscalation)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⚠️ Escalado',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.textHint.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOpen ? 'Abierto' : 'Cerrado',
                              style: TextStyle(
                                fontSize: 10,
                                color: isOpen
                                    ? AppColors.success
                                    : AppColors.textHint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (agentName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Bot: $agentName',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (subject.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subject,
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (lastMsg.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            lastSenderRole == 'dispatch'
                                ? 'Tú: $lastMsg'
                                : lastSenderRole == 'bot'
                                ? 'Bot: $lastMsg'
                                : lastMsg,
                            style: TextStyle(
                              color: unread > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
