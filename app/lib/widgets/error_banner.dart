import 'package:flutter/material.dart';

/// Mirrors frontend/src/lib/components/ErrorBanner.svelte: a dismissible strip shown above
/// a page's content when the last load/save failed.
class ErrorBanner extends StatelessWidget {
  final String? message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message!, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
