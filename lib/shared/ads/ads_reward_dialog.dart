import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_constants.dart';
import 'ads_provider.dart';

Future<bool> requestRewardedFeature(
  BuildContext context,
  WidgetRef ref, {
  required RewardedFeature feature,
  required String title,
  required String message,
}) async {
  final shouldWatch = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Watch video'),
          ),
        ],
      );
    },
  );

  if (shouldWatch != true || !context.mounted) return false;

  final rewarded = await ref.read(adsServiceProvider).requestReward(feature);
  return rewarded;
}
