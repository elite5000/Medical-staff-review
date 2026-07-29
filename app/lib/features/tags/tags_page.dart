import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/bulk_add_dialog.dart';
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _TagFormDialog(api: api, existing: existing),
    );
    if (saved == true) reload();
  }

  Future<void> _showBulkForm(BuildContext context, VoidCallback reload) async {
    final created = await showBulkAddDialog(
      context: context,
      title: 'Bulk Add Tags',
      entityLabel: 'tag',
      entityLabelPlural: 'tags',
      skipsExistingNames: true,
      submit: (names, _) => api.bulkCreateTags(names),
    );
    if (created) reload();
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
        // These list pages have no AppBar of their own (AppShell owns the only one, and
        // only at phone widths), so bulk-add sits as a small FAB above the single-add one
        // rather than as an app bar action.
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              // Two FABs in one Scaffold otherwise share FloatingActionButton's default
              // hero tag and trip Flutter's duplicate-hero assertion on route transitions.
              heroTag: null,
              onPressed: () => _showBulkForm(context, reload),
              tooltip: 'Bulk Add Tags',
              child: const Icon(Icons.playlist_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              onPressed: () => _showForm(context, reload),
              tooltip: 'New Tag',
              child: const Icon(Icons.add),
            ),
          ],
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

class _TagFormDialog extends StatefulWidget {
  final ApiClient api;
  final Tag? existing;

  const _TagFormDialog({required this.api, required this.existing});

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  // Owned by this State (not created/disposed by the caller) so Flutter only disposes it once
  // this widget is actually removed from the tree — i.e. after the dialog's exit transition
  // finishes, not the moment Navigator.pop() is called. Disposing it eagerly right after
  // showDialog's Future resolves races that still-animating transition and crashes with
  // "A TextEditingController was used after being disposed."
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.api.createTag(name);
      } else {
        await widget.api.updateTag(existing.id, name);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Tag' : 'Edit Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
