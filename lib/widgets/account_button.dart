import 'package:flutter/material.dart';
import '../core/utils/safe_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import '../features/profile/widgets/account_bottom_sheet.dart';
import 'profile_avatar.dart';

class AccountButton extends ConsumerWidget {
  const AccountButton({this.avatarSize = 34, super.key});
  final double avatarSize;
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Account and settings',
    padding: const EdgeInsets.all(4),
    onPressed: () => Theme.of(context).platform == TargetPlatform.iOS
        ? context.safePush('/account')
        : showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            useRootNavigator: true,
            showDragHandle: false,
            backgroundColor: Colors.transparent,
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            builder: (_) => const AccountBottomSheet(),
          ),
    icon: ProfileAvatar(
      user: ref.watch(authControllerProvider).user,
      size: avatarSize,
    ),
  );
}
