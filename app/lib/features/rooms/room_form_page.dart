import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';

/// Ported from frontend/src/pages/rooms/RoomFormPage.svelte. A full page (not a dialog,
/// unlike Tags/Roles/Buildings) since it needs a building dropdown plus a tag checklist
/// loaded from two other endpoints.
class RoomFormPage extends StatefulWidget {
  final ApiClient api;
  final Room? existing;

  const RoomFormPage({super.key, required this.api, this.existing});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  late final TextEditingController _nameController;
  int? _buildingId;
  final Set<int> _selectedTagIds = {};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _buildingId = widget.existing?.buildingId;
    _selectedTagIds.addAll(widget.existing?.tags.map((t) => t.id) ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_buildingId == null) {
      setState(() => _error = 'A building is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing == null) {
        await widget.api.createRoom(
          name: name,
          buildingId: _buildingId!,
          tagIds: _selectedTagIds.toList(),
        );
      } else {
        await widget.api.updateRoom(
          widget.existing!.id,
          name: name,
          buildingId: _buildingId,
          tagIds: _selectedTagIds.toList(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New Room' : 'Edit Room')),
      body: AsyncLoader<(List<Building>, List<Tag>)>(
        load: () async {
          final buildings = await widget.api.listBuildings();
          final tags = await widget.api.listTags();
          _buildingId ??= buildings.firstOrNull?.id;
          return (buildings, tags);
        },
        builder: (context, data, _) {
          final (buildings, tags) = data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorBanner(message: _error),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _buildingId,
                decoration: const InputDecoration(labelText: 'Building'),
                items: buildings
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: (value) => setState(() => _buildingId = value),
              ),
              const SizedBox(height: 16),
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              for (final tag in tags)
                CheckboxListTile(
                  title: Text(tag.name),
                  value: _selectedTagIds.contains(tag.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedTagIds.add(tag.id);
                    } else {
                      _selectedTagIds.remove(tag.id);
                    }
                  }),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
