import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api_service.dart';
import '../providers/inventory_provider.dart';
import '../theme.dart';

class WorkshopSetupDialog extends StatefulWidget {
  const WorkshopSetupDialog({super.key});

  @override
  State<WorkshopSetupDialog> createState() => _WorkshopSetupDialogState();
}

class _WorkshopSetupDialogState extends State<WorkshopSetupDialog> {
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;
  String _role = 'member';
  List<String> _permissions = [];

  bool get _canManageMaterials =>
      _role == 'admin' || _permissions.contains('materials.manage');
  bool get _canManageLocations =>
      _role == 'admin' || _permissions.contains('locations.manage');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final provider = context.read<InventoryProvider>();
      final values = await Future.wait([
        provider.fetchMaterials(),
        provider.fetchLocations(),
        provider.fetchCurrentRole(),
        provider.fetchCurrentPermissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _materials = values[0] as List<Map<String, dynamic>>;
        _locations = values[1] as List<Map<String, dynamic>>;
        _role = values[2] as String;
        _permissions = values[3] as List<String>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingApiError(error);
      });
    }
  }

  Future<void> _addMaterial() async {
    final name = TextEditingController();
    final thickness = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KerfTheme.bgPanel,
        title: const Text('ADD MATERIAL'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Material name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: thickness,
                  decoration: const InputDecoration(
                    labelText: 'Thickness (mm)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Enter a positive thickness'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final created = await context
                    .read<InventoryProvider>()
                    .addMaterial(
                      name: name.text.trim(),
                      thickness: double.parse(thickness.text.trim()),
                    );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, created);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(userFacingApiError(error)),
                      backgroundColor: KerfTheme.statusError,
                    ),
                  );
                }
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
    name.dispose();
    thickness.dispose();
    if (result != null && mounted) {
      setState(() {
        _materials = [..._materials, result]
          ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      });
    }
  }

  Future<void> _addLocation() async {
    final name = TextEditingController();
    final jobReference = TextEditingController();
    String? parentId;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: KerfTheme.bgPanel,
          title: const Text('ADD RACK / CRATE'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Location name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: parentId,
                    dropdownColor: KerfTheme.bgPanel,
                    decoration: const InputDecoration(
                      labelText: 'Parent (Optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Top level'),
                      ),
                      ..._locations
                          .where((item) => (item['depth'] as num? ?? 0) < 2)
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['id'] as String,
                              child: Text('${item['name']}'),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => parentId = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: jobReference,
                    decoration: const InputDecoration(
                      labelText: 'Job reference (Optional)',
                      helperText: 'Leave blank for general stock',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final created = await this.context
                      .read<InventoryProvider>()
                      .addLocation(
                        name: name.text.trim(),
                        parentId: parentId,
                        jobReference: jobReference.text.trim().isEmpty
                            ? null
                            : jobReference.text.trim(),
                      );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, created);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(userFacingApiError(error)),
                        backgroundColor: KerfTheme.statusError,
                      ),
                    );
                  }
                }
              },
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    jobReference.dispose();
    if (result != null && mounted) {
      setState(() {
        _locations = [..._locations, result]
          ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      });
    }
  }

  Future<void> _removeLocation(Map<String, dynamic> location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KerfTheme.bgPanel,
        title: const Text('REMOVE RACK / CRATE?'),
        content: Text(
          'Remove ${location['name']} from active workshop setup? '
          'Historical records will be preserved. Removal is blocked if it still contains active stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<InventoryProvider>().removeLocation(
        location['id'] as String,
      );
      if (!mounted) return;
      setState(
        () => _locations.removeWhere((item) => item['id'] == location['id']),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${location['name']} removed from active setup'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingApiError(error)),
          backgroundColor: KerfTheme.statusError,
        ),
      );
    }
  }

  Widget _panel({
    required String title,
    required Widget child,
    required VoidCallback onAdd,
    required bool canManage,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (canManage)
                    ElevatedButton(
                      onPressed: onAdd,
                      child: const Text('+ ADD'),
                    ),
                ],
              ),
              const Divider(height: 28),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KerfTheme.bgPrimary,
      child: SizedBox(
        width: 960,
        height: 650,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'WORKSHOP SETUP',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (!_canManageMaterials && !_canManageLocations && !_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Read-only access. Ask an administrator to delegate setup capabilities.',
                    style: TextStyle(color: KerfTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 20),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: KerfTheme.statusError),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      _panel(
                        title: 'MATERIALS',
                        onAdd: _addMaterial,
                        canManage: _canManageMaterials,
                        child: ListView.separated(
                          itemCount: _materials.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final item = _materials[index];
                            return ListTile(
                              title: Text('${item['name']}'),
                              trailing: Text(
                                '${item['thickness']}${item['unit']}',
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      _panel(
                        title: 'RACKS / CRATES',
                        onAdd: _addLocation,
                        canManage: _canManageLocations,
                        child: ListView.separated(
                          itemCount: _locations.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final item = _locations[index];
                            final job = (item['job_reference'] as String?)
                                ?.trim();
                            return ListTile(
                              title: Text('${item['name']}'),
                              subtitle: job == null || job.isEmpty
                                  ? const Text('General stock')
                                  : Text('Job $job'),
                              trailing: _canManageLocations
                                  ? IconButton(
                                      tooltip: 'Remove rack / crate',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _removeLocation(item),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
