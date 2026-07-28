import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'theme.dart';

// Services & Repositories
import 'data/api_service.dart';
import 'repositories/stock_repository.dart';
import 'providers/inventory_provider.dart';
import 'services/license_service.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/license_activation_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = _requiredEnvironmentValue('SUPABASE_URL');
  final supabaseAnonKey = _requiredEnvironmentValue('SUPABASE_ANON_KEY');

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(const KerfStockApp());
}

String _requiredEnvironmentValue(String key) {
  final value = dotenv.env[key]?.trim();
  if (value == null ||
      value.isEmpty ||
      value.startsWith('YOUR_') ||
      value.startsWith('your_')) {
    throw StateError(
      'Missing $key in the KerfStock .env file. '
      'Copy .env.example to .env and replace its placeholder values.',
    );
  }
  return value;
}

class KerfStockApp extends StatelessWidget {
  const KerfStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Initialize licensing and the Portal API.
    final portalBaseUrl = resolvePortalApiBaseUrl(
      environmentValue: _requiredEnvironmentValue('KERFPORTAL_API_URL'),
    );
    final licenseService = LicenseService(baseUrl: portalBaseUrl);
    final apiService = ApiService(
      baseUrl: portalBaseUrl,
      licenseHeaders: licenseService.requestHeaders,
    );

    // 2. Initialize Repositories
    final stockRepo = StockRepository(apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider(stockRepo)),
      ],
      child: MaterialApp(
        title: 'KerfStock',
        theme: KerfTheme.darkTheme,
        home: LicenseGate(licenseService: licenseService),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LicenseGate extends StatefulWidget {
  final LicenseService licenseService;

  const LicenseGate({super.key, required this.licenseService});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late Future<LicenseGateResult> _licenseCheck;

  @override
  void initState() {
    super.initState();
    _licenseCheck = widget.licenseService.checkStoredLicense();
  }

  void _activated() {
    setState(() {
      _licenseCheck = Future.value(const LicenseGateResult(licensed: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LicenseGateResult>(
      future: _licenseCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;
        if (result?.licensed == true) return const AuthWrapper();

        return LicenseActivationScreen(
          licenseService: widget.licenseService,
          onActivated: _activated,
          initialMessage: result?.message,
        );
      },
    );
  }
}

/// AuthWrapper listens to the Supabase auth state.
/// If logged in, shows Dashboard. If not, shows Login.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
