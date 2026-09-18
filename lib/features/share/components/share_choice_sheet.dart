import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../widgets/sheet/ios_action_group.dart';
import '../../../widgets/sheet/sheet_action_tile.dart';

enum ShareChoice { copy, link }

class ShareChoiceSheet extends StatelessWidget {
  const ShareChoiceSheet({
    super.key,
    required this.count,
    required this.includesFolders,
  });
  final int count;
  final bool includesFolders;
  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final options = <Widget>[
      if (!includesFolders)
        ios
            ? IosActionRow(
                label: 'Share a copy',
                subtitle:
                    'Send the original ${count == 1 ? 'file' : 'files'} to another app.',
                icon: CupertinoIcons.doc_on_doc,
                onPressed: () => Navigator.pop(context, ShareChoice.copy),
              )
            : SheetActionTile(
                label: 'Share a copy',
                subtitle:
                    'Send the original ${count == 1 ? 'file' : 'files'} to another app.',
                icon: Icons.copy_outlined,
                onTap: () => Navigator.pop(context, ShareChoice.copy),
              ),
      ios
          ? IosActionRow(
              label: 'Create link',
              subtitle: includesFolders
                  ? 'Share files and folders with a link.'
                  : 'Let others access ${count == 1 ? 'this file' : 'these files'} through a link.',
              icon: CupertinoIcons.link,
              onPressed: () => Navigator.pop(context, ShareChoice.link),
            )
          : SheetActionTile(
              label: 'Create link',
              subtitle: includesFolders
                  ? 'Share files and folders with a link.'
                  : 'Let others access ${count == 1 ? 'this file' : 'these files'} through a link.',
              icon: Icons.link,
              onTap: () => Navigator.pop(context, ShareChoice.link),
            ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              count == 1
                  ? 'Share'
                  : 'Share $count ${includesFolders ? 'items' : 'files'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (ios) IosActionGroup(children: options) else ...options,
        ],
      ),
    );
  }
}
