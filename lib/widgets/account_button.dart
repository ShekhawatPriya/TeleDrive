import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import '../features/profile/widgets/account_bottom_sheet.dart';
import 'profile_avatar.dart';

class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Account and settings',
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: false,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (_) => const AccountBottomSheet(),
    ),
    icon: ProfileAvatar(user: ref.watch(authControllerProvider).user, size: 34),
  );
}
