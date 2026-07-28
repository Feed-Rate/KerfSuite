import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/api_service.dart';
import '../providers/inventory_provider.dart';
import '../theme.dart';

class AddAssetDialog extends StatefulWidget {
  const AddAssetDialog({super.key});

  @override
  State<AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loadingDropdowns = true;
  bool _submitting = false;

  String? _selectedMaterialId;
  String? _selectedLocationId;
  String _selectedAssetType = 'full_sheet';
  bool _jobRefWasInherited = false;

  final _widthController = TextEditingController(text: '2440');
  final _heightController = TextEditingController(text: '1220');
  final _displayNameController = TextEditingController();
  final _jobRefController = TextEditingController();

  final List<Map<String, String>> _assetTypes = [
    {'value': 'full_sheet', 'label': 'Full Sheet'},
    {'value': 'remnant', 'label': 'Remnant'},
    {'value': 'offcut', 'label': 'Offcut'},
    {'value': 'custom', 'label': 'Custom'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final provider = context.read<InventoryProvider>();
      final results = await Future.wait([
        provider.fetchMaterials(),
        provider.fetchLocations(),
      ]);
      final materials = results[0];
      final locations = results[1];
      if (mounted) {
        setState(() {
          _materials = materials;
          _locations = locations;
          _loadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load form metadata: ${userFacingApiError(e)}',
            ),
            backgroundColor: KerfTheme.statusError,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterialId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a material'),
          backgroundColor: KerfTheme.statusError,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final width = double.parse(_widthController.text.trim());
      final height = double.parse(_heightController.text.trim());

      final provider = context.read<InventoryProvider>();
      await provider.addAsset(
        materialId: _selectedMaterialId!,
        width: width,
        height: height,
        type: _selectedAssetType,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        locationId: _selectedLocationId,
        jobReference: _jobRefController.text.trim().isEmpty
            ? null
            : _jobRefController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add asset: ${userFacingApiError(e)}'),
            backgroundColor: KerfTheme.statusError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDropdowns) {
      return const AlertDialog(
        backgroundColor: KerfTheme.bgPanel,
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_materials.isEmpty) {
      return AlertDialog(
        backgroundColor: KerfTheme.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: KerfTheme.panelBorder),
        ),
        title: Text(
          'SETUP REQUIRED',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        content: const Text(
          'No materials have been configured in this workspace. Please set up your material library in the KerfPortal web interface first.',
          style: TextStyle(color: KerfTheme.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: KerfTheme.bgPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: KerfTheme.panelBorder),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ADD NEW ASSET',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: KerfTheme.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: KerfTheme.panelBorder, height: 24),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Material Selector
                    DropdownButtonFormField<String>(
                      dropdownColor: KerfTheme.bgPanel,
                      decoration: const InputDecoration(
                        labelText: 'Material *',
                      ),
                      initialValue: _selectedMaterialId,
                      items: _materials.map((m) {
                        final thickness = m['thickness'] != null
                            ? ' (${m['thickness']}${m['unit']})'
                            : '';
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text('${m['name']}$thickness'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedMaterialId = val),
                      validator: (val) =>
                          val == null ? 'Select a material' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dimensions
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: 'Width (mm) *',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              final numVal = double.tryParse(val.trim());
                              if (numVal == null || numVal <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (mm) *',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              final numVal = double.tryParse(val.trim());
                              if (numVal == null || numVal <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Asset Type
                    DropdownButtonFormField<String>(
                      dropdownColor: KerfTheme.bgPanel,
                      decoration: const InputDecoration(
                        labelText: 'Asset Type',
                      ),
                      initialValue: _selectedAssetType,
                      items: _assetTypes.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['value'],
                          child: Text(t['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedAssetType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (Optional)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Selector
                    DropdownButtonFormField<String>(
                      dropdownColor: KerfTheme.bgPanel,
                      decoration: const InputDecoration(
                        labelText: 'Location (Optional)',
                      ),
                      initialValue: _selectedLocationId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._locations.map((l) {
                          final jobReference = (l['job_reference'] as String?)
                              ?.trim();
                          final suffix =
                              jobReference == null || jobReference.isEmpty
                              ? ''
                              : ' ? Job $jobReference';
                          return DropdownMenuItem<String>(
                            value: l['id'],
                            child: Text('${l['name']}$suffix'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        final location = val == null
                            ? null
                            : _locations
                                  .cast<Map<String, dynamic>?>()
                                  .firstWhere(
                                    (item) => item?['id'] == val,
                                    orElse: () => null,
                                  );
                        final inherited =
                            (location?['job_reference'] as String?)?.trim() ??
                            '';
                        setState(() {
                          _selectedLocationId = val;
                          if (_jobRefWasInherited ||
                              _jobRefController.text.trim().isEmpty) {
                            _jobRefController.text = inherited;
                            _jobRefWasInherited = inherited.isNotEmpty;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Job Reference
                    TextFormField(
                      controller: _jobRefController,
                      decoration: const InputDecoration(
                        labelText: 'Job Reference (Optional)',
                      ),
                      onChanged: (_) => _jobRefWasInherited = false,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ADD ASSET'),
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

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _displayNameController.dispose();
    _jobRefController.dispose();
    super.dispose();
  }
}
