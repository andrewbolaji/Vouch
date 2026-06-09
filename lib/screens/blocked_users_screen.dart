import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vouch/repositories/user_repository.dart';
import 'package:vouch/services/auth_service.dart';
import 'package:vouch/theme/app_theme.dart';

/// Screen showing the current user's blocked users with an unblock action.
///
/// Accessible from the profile/settings screen.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<String> _blockedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBlocked());
  }

  Future<void> _loadBlocked() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final ids = await UserRepository().getBlockedIds(uid);
      if (mounted) setState(() { _blockedIds = ids; _isLoading = false; });
    } on Exception catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(String blockedUid) async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    try {
      await UserRepository().removeBlock(uid, blockedUid);
      if (mounted) {
        setState(() => _blockedIds.remove(blockedUid));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedIds.isEmpty
              ? Center(
                  child: Text(
                    'No blocked users.',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedIds.length,
                  itemBuilder: (context, index) {
                    final uid = _blockedIds[index];
                    return ListTile(
                      title: Text(
                        'User ${uid.substring(0, 8)}...',
                        style: AppTheme.bodyMedium,
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblock(uid),
                        child: Text(
                          'Unblock',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
