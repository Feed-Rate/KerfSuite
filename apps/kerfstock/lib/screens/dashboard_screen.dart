import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../domain/models/asset.dart';
import '../theme.dart';
import '../services/stock_service.dart';
import 'add_asset_dialog.dart';
import 'workshop_setup_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  bool _showArchive = false;

  // Realtime Sync Flash Indicator state
  bool _syncConnected = false;
  bool _syncPulse = false;
  Timer? _pulseTimer;
  Timer? _refreshDebounce;
  RealtimeChannel? _subscription;
  String? _subscribedWorkspaceId;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeInventory());
    });
  }

  Future<void> _initializeInventory() async {
    final provider = context.read<InventoryProvider>();
    await provider.refresh();

    if (!mounted || provider.workspaceId == null) return;
    _ensureRealtimeSubscription(provider.workspaceId!);
  }

  void _ensureRealtimeSubscription(String workspaceId) {
    if (_subscription != null &&
        _subscribedWorkspaceId == workspaceId &&
        _syncConnected) {
      return;
    }

    final previousSubscription = _subscription;
    if (previousSubscription != null) {
      unawaited(Supabase.instance.client.removeChannel(previousSubscription));
    }

    _subscribedWorkspaceId = workspaceId;

    _subscription = StockService.subscribeToAssets(
      workspaceId,
      () {
        if (!mounted) return;

        _triggerSyncFlash();
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
          if (mounted) {
            unawaited(context.read<InventoryProvider>().refresh());
          }
        });
      },
      (status, error) {
        if (!mounted) return;
        setState(() {
          _syncConnected = status == RealtimeSubscribeStatus.subscribed;
        });
      },
    );
  }

  Color get _syncIndicatorColor {
    if (!_syncConnected) return KerfTheme.statusError;
    if (_syncPulse) return Colors.greenAccent;
    return Colors.green.withValues(alpha: 0.6);
  }

  void _triggerSyncFlash() {
    if (!mounted) return;
    setState(() => _syncPulse = true);
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _syncPulse = false);
      }
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _openWorkshopSetup() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WorkshopSetupDialog(),
    );
  }

  Future<void> _openAddAssetDialog() async {
    final provider = context.read<InventoryProvider>();
    final wsId = provider.workspaceId;

    if (wsId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace not loaded. Please wait.')),
      );
      return;
    }

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddAssetDialog(),
    );
    if (success == true) {
      if (mounted) {
        provider.refresh();
        _triggerSyncFlash();
      }
    }
  }

  Future<void> _openEditAssetDialog(Asset asset) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddAssetDialog(asset: asset),
    );
    if (success == true && mounted) {
      await context.read<InventoryProvider>().refresh();
      _triggerSyncFlash();
    }
  }

  Future<void> _removeAsset(Asset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('REMOVE SHEET?'),
        content: Text(
          'Remove ${asset.systemName} from active inventory?\n\n'
          'The sheet will remain in Archived/Consumed Assets so its history '
          'and stock ID are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<InventoryProvider>().removeAsset(asset);
      if (!mounted) return;
      _triggerSyncFlash();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asset.systemName} removed from inventory')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove sheet')));
    }
  }

  List<Asset> _getFilteredAssets(List<Asset> assets) {
    var list = assets;
    if (!_showArchive) {
      list = list.where((asset) {
        return asset.status != 'consumed' && asset.status != 'disposed';
      }).toList();
    }

    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((asset) {
      return asset.systemName.toLowerCase().contains(query) ||
          (asset.displayName?.toLowerCase().contains(query) ?? false) ||
          asset.materialName.toLowerCase().contains(query) ||
          asset.locationName.toLowerCase().contains(query) ||
          (asset.jobReference?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _buildStatusBadge(String status) {
    final Color bgColor;
    final Color textColor;
    switch (status) {
      case 'available':
        bgColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        break;
      case 'reserved':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        break;
      case 'consumed':
        bgColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatAssetType(String type) {
    switch (type) {
      case 'full_sheet':
        return 'Full Sheet';
      case 'remnant':
        return 'Remnant';
      case 'offcut':
        return 'Offcut';
      case 'custom':
        return 'Custom';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KERFSTOCK DASHBOARD'),
        actions: [
          // Live Sync Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _syncIndicatorColor,
                    shape: BoxShape.circle,
                    boxShadow: _syncPulse
                        ? [
                            const BoxShadow(
                              color: Colors.greenAccent,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _syncConnected ? 'LIVE SYNC' : 'SYNC OFFLINE',
                  style: GoogleFonts.robotoMono(
                    color: _syncConnected
                        ? (_syncPulse
                              ? Colors.greenAccent
                              : KerfTheme.textSecondary)
                        : KerfTheme.statusError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Row(
        children: [
          // Basic Sidebar
          Container(
            width: 250,
            color: Theme.of(context).cardTheme.color,
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('Inventory Data'),
                  selected: true,
                  selectedColor: Theme.of(context).primaryColor,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scanner Tool'),
                  subtitle: const Text('COMING SOON'),
                  enabled: false,
                ),
                ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: const Text('Workshop Setup'),
                  onTap: _openWorkshopSetup,
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildMainContent(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(InventoryProvider provider) {
    if (provider.isLoading && provider.assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: KerfTheme.statusError,
            ),
            const SizedBox(height: 16),
            Text(
              'Communication Error',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              style: const TextStyle(color: KerfTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => unawaited(_initializeInventory()),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    final filteredList = _getFilteredAssets(provider.assets);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.error != null) ...[
          Card(
            margin: EdgeInsets.zero,
            color: KerfTheme.statusError.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: KerfTheme.statusError),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Inventory refresh failed. Showing the last loaded data.',
                      style: TextStyle(color: KerfTheme.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_initializeInventory()),
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Controls / Title header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STOCK OVERVIEW',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(
              onPressed: _openAddAssetDialog,
              child: const Text('+ ADD ASSET'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Search Bar
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText:
                    'Search inventory by name, material, location, or job ref...',
                prefixIcon: Icon(Icons.search, color: KerfTheme.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Show Archived/Consumed Assets',
              style: TextStyle(color: KerfTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _showArchive,
              activeThumbColor: KerfTheme.accentOrange,
              onChanged: (val) {
                setState(() {
                  _showArchive = val;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Spreadsheet Container
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No assets in inventory'
                          : 'No assets match your search',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                KerfTheme.bgPrimary,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'SYSTEM NAME',
                                    style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'MATERIAL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'DISPLAY NAME',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'DIMENSIONS (mm)',
                                    style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'QUANTITY',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'TYPE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'LOCATION',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'JOB REF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: filteredList.map((asset) {
                                final matName =
                                    "${asset.materialName} (${asset.materialThickness}mm)";
                                final dimensions =
                                    "${asset.width.toInt()}x${asset.height.toInt()}";

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        asset.systemName,
                                        style: GoogleFonts.robotoMono(
                                          fontWeight: FontWeight.bold,
                                          color: KerfTheme.accentOrange,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(matName)),
                                    DataCell(
                                      Text(
                                        asset.displayName ?? '-',
                                        style: TextStyle(
                                          color: asset.displayName != null
                                              ? KerfTheme.textPrimary
                                              : KerfTheme.textSecondary,
                                          fontStyle: asset.displayName != null
                                              ? FontStyle.normal
                                              : FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        dimensions,
                                        style: GoogleFonts.robotoMono(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('${asset.quantity}')),
                                    DataCell(
                                      Text(_formatAssetType(asset.type)),
                                    ),
                                    DataCell(_buildStatusBadge(asset.status)),
                                    DataCell(Text(asset.locationName)),
                                    DataCell(Text(asset.jobReference ?? '-')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit sheet',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            onPressed: () =>
                                                _openEditAssetDialog(asset),
                                          ),
                                          if (asset.status != 'disposed' &&
                                              asset.status != 'consumed')
                                            IconButton(
                                              tooltip: 'Remove sheet',
                                              color: KerfTheme.statusError,
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  _removeAsset(asset),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(Supabase.instance.client.removeChannel(subscription));
    }
    _pulseTimer?.cancel();
    _subscribedWorkspaceId = null;
    _refreshDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
