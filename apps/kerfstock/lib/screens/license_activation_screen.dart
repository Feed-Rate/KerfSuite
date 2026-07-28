import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/license_service.dart';
import '../theme.dart';

class LicenseActivationScreen extends StatefulWidget {
  final LicenseService licenseService;
  final VoidCallback onActivated;
  final String? initialMessage;

  const LicenseActivationScreen({
    super.key,
    required this.licenseService,
    required this.onActivated,
    this.initialMessage,
  });

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _keyController = TextEditingController();
  late final Future<String> _machineIdDisplay;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _machineIdDisplay = widget.licenseService.machineIdDisplay;
    _error = widget.initialMessage;
  }

  Future<void> _activate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.licenseService.activate(_keyController.text);
      if (result.licensed && mounted) widget.onActivated();
    } on LicenseRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'License activation failed unexpectedly.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyMachineId(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Machine ID copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ACTIVATE KERFSTOCK',
                      style: Theme.of(
                        context,
                      ).textTheme.displayLarge?.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter the KerfStock key generated in your KerfSuite Portal. '
                      'This installation will be bound to this machine.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KerfTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    FutureBuilder<String>(
                      future: _machineIdDisplay,
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? 'LOADING...';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: KerfTheme.panelBorder),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MACHINE ID',
                                      style: TextStyle(
                                        color: KerfTheme.textSecondary,
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      value,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy machine ID',
                                onPressed: snapshot.hasData
                                    ? () => _copyMachineId(value)
                                    : null,
                                icon: const Icon(Icons.copy, size: 18),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _keyController,
                      enabled: !_isLoading,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'KerfStock License Key',
                        hintText: 'KST-PRO-XXXX-XXXX',
                      ),
                      onSubmitted: (_) => _isLoading ? null : _activate(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(color: KerfTheme.statusError),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _activate,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ACTIVATE'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }
}
