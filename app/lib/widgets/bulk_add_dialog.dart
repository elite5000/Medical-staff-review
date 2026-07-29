import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../api/models.dart';

/// How many already-existing names the summary spells out before collapsing the rest into
/// "and N more" — a paste of a whole spreadsheet column can skip dozens, which would
/// overflow the SnackBar.
const _maxNamesInSummary = 5;

/// Shows the paste-a-batch-of-names dialog used by the Rooms/Tags/Roles/Staff list pages,
/// the bulk counterpart to their single-add forms. The pasted text is split on newlines
/// (trimmed, blanks dropped) and sent to [submit] in one request; the outcome is reported
/// in a SnackBar on [context] after the dialog closes.
///
/// Buildings deliberately have no bulk-add: each one needs its own opening/closing hours,
/// which a names-only textarea can't carry.
///
/// Returns true if anything was created, so the caller can run its `reload()`. Returns
/// false when cancelled, or when every pasted name already existed (nothing changed, so
/// there is nothing to reload).
Future<bool> showBulkAddDialog({
  required BuildContext context,
  required String title,
  required String entityLabel,
  required String entityLabelPlural,
  required Future<BulkAddResult<Object>> Function(
    List<String> names,
    int? buildingId,
  )
  submit,
  bool skipsExistingNames = false,
  List<Building>? buildings,
}) async {
  final result = await showDialog<BulkAddResult<Object>>(
    context: context,
    builder: (_) => _BulkAddDialog(
      title: title,
      submit: submit,
      skipsExistingNames: skipsExistingNames,
      buildings: buildings,
    ),
  );
  if (result == null) return false; // cancelled
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_summary(result, entityLabel, entityLabelPlural))),
    );
  }
  return result.created.isNotEmpty;
}

String _summary(
  BulkAddResult<Object> result,
  String entityLabel,
  String entityLabelPlural,
) {
  final count = result.created.length;
  final noun = count == 1 ? entityLabel : entityLabelPlural;
  final added = count == 0
      ? 'No $entityLabelPlural added'
      : 'Added $count $noun';
  if (result.skipped.isEmpty) return '$added.';
  final shown = result.skipped.take(_maxNamesInSummary).join(', ');
  final overflow = result.skipped.length - _maxNamesInSummary;
  final names = overflow > 0 ? '$shown and $overflow more' : shown;
  return '$added. ${result.skipped.length} already existed: $names.';
}

class _BulkAddDialog extends StatefulWidget {
  final String title;
  final Future<BulkAddResult<Object>> Function(
    List<String> names,
    int? buildingId,
  )
  submit;

  /// True for the entities with a UNIQUE name column (Tags, Roles), where a pasted name the
  /// practice already has is skipped rather than duplicated — worth saying up front, since
  /// it explains a summary reporting fewer created than lines pasted.
  final bool skipsExistingNames;

  /// Non-null only for Rooms, which need every name in the batch to land in one Building.
  /// The list is passed in rather than fetched here because RoomsPage has already loaded it
  /// for its own list.
  final List<Building>? buildings;

  const _BulkAddDialog({
    required this.title,
    required this.submit,
    required this.skipsExistingNames,
    this.buildings,
  });

  @override
  State<_BulkAddDialog> createState() => _BulkAddDialogState();
}

class _BulkAddDialogState extends State<_BulkAddDialog> {
  final _controller = TextEditingController();
  int? _buildingId;
  String? _error;
  bool _saving = false;

  bool get _needsBuilding => widget.buildings != null;

  @override
  void initState() {
    super.initState();
    _buildingId = widget.buildings?.firstOrNull?.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Split here as well as server-side so the "enter at least one name" check below sees
    // the same list the backend will, and a paste that is nothing but blank lines is caught
    // before a pointless round trip.
    final names = _controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      setState(() => _error = 'Enter at least one name');
      return;
    }
    if (_needsBuilding && _buildingId == null) {
      setState(() => _error = 'A building is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.submit(names, _buildingId);
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildings = widget.buildings;
    // Rooms can't exist without a Building, so with none set up there is nothing to add to.
    final blockedOnBuildings = buildings != null && buildings.isEmpty;
    return AlertDialog(
      title: Text(widget.title),
      // AlertDialog doesn't scroll its content: on a short window (a phone in landscape) a
      // ten-line textarea plus the building picker would otherwise overflow.
      content: SingleChildScrollView(
        child: SizedBox(
          // The textarea is the point of this dialog, so give it a stable, generously sized
          // box rather than letting it shrink-wrap a single line before anything is typed.
          // Narrower dialogs clamp this down, so it can't force a horizontal overflow.
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blockedOnBuildings)
                Text(
                  'Add a building first — every room belongs to one.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else ...[
                if (buildings != null) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _buildingId,
                    decoration: const InputDecoration(labelText: 'Building'),
                    items: buildings
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _buildingId = value),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Names',
                    alignLabelWithHint: true,
                    helperText:
                        'One name per line. Blank lines are ignored.'
                        '${widget.skipsExistingNames ? ' Names that already exist are skipped.' : ''}',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || blockedOnBuildings ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
