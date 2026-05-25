part of '../free_up_space_screen.dart';

void _showFreeUpSpaceInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About freeing up space'),
      content: const SingleChildScrollView(
        child: Text(
          'Free up space removes local device copies of photos and videos that TeleDrive has verified were uploaded by Auto Backup.\n\n'
          'It does not delete anything from your TeleDrive cloud storage. You can still view, stream, or download backed-up items again.\n\n'
          'Manual uploads are not included. Files that are still uploading, failed to upload, cannot be verified, or are no longer available in the cloud will not be removed.\n\n'
          'Before anything is removed from your gallery, Android will show a system confirmation. If you cancel that prompt, nothing is deleted.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
