import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';

/// Ported from frontend/src/pages/tags/{TagsListPage,TagFormPage}.svelte.
class TagsPage extends StatelessWidget {
  final ApiClient api;

  const TagsPage({super.key, required this.api});

  Future<void> _showForm(
    BuildContext context,
    VoidCallback reload, {
    Tag? existing,
  }) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(existing == null ? 'New Tag' : 'Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Name is required');
                  return;
                }
                try {
                  if (existing == null) {
                    await api.createTag(name);
                  } else {
                    await api.updateTag(existing.id, name);
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on ApiException catch (e) {
                  setState(() => error = e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true) reload();
  }

  Future<void> _delete(
    BuildContext context,
    Tag tag,
    VoidCallback reload,
  ) async {
    if (!await confirmDialog(context, 'Delete tag "${tag.name}"?')) return;
    try {
      await api.deleteTag(tag.id);
      reload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete tag: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<List<Tag>>(
      load: api.listTags,
      builder: (context, tags, reload) => Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(context, reload),
          tooltip: 'New Tag',
          child: const Icon(Icons.add),
        ),
        body: tags.isEmpty
            ? const Center(child: Text('No tags yet.'))
            : ListView.separated(
                itemCount: tags.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return ListTile(
                    title: Text(tag.name),
                    onTap: () => _showForm(context, reload, existing: tag),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, tag, reload),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
