# KerfStock

KerfStock is the Flutter inventory client for the Feed Rate KerfSuite. It uses
Supabase for authentication and realtime notifications, and KerfPortal for
inventory business operations.

## Local configuration

1. Copy `.env.example` to `.env`.
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to the Feed Rate Supabase public
   client values. Never put a service-role or database secret in this file.
3. Set `KERFPORTAL_API_URL` to the KerfPortal server, normally
   `http://localhost:3000` for Windows desktop development.

The `.env` file is bundled into the Flutter client but ignored by Git. It must
contain public client configuration only.

For an Android emulator, use `http://10.0.2.2:3000`. For a physical device, use
the development computer's reachable LAN address or an HTTPS development URL.

## Database migration

Before using asset creation, apply KerfPortal's migration:

`KerfPortal_v1.0.2/supabase/migrations/202607270001_kerfstock_integrity.sql`


Then apply `202607280002_stock_permissions_location_archive.sql`. It adds
delegated KerfStock capabilities and safe location archival. Migrations are
idempotent and must be deployed before the matching desktop and Portal builds.
Apply it through the Supabase SQL editor or the project's migration workflow.
It removes recursive workspace policies, enforces unique asset names, and makes
asset creation plus its initial audit event transactional.

## Run locally

Start KerfPortal on the URL configured above, then run:

```powershell
flutter pub get
flutter run -d windows
```


## Licensing

KerfStock uses the same Portal-controlled, machine-bound license model as
KerfCut. Generate a `kerfstock` key in KerfPortal, activate the installation,
then sign in with a workspace employee account. The license authorizes the
installation; the signed-in employee's KerfStock capabilities authorize each
inventory operation.

The key is kept in operating-system secure storage. A successful online check
provides a 48-hour offline lease. Stock API requests carry the active license
and machine identity over HTTPS, and the Portal verifies that the license app
and workspace match the authenticated employee.
## Windows release build

The release build must target the production KerfPortal API. The compile-time
value overrides the bundled localhost development value:

```powershell
flutter build windows --release --dart-define=KERFPORTAL_API_URL=https://kerfsuite.vercel.app
```

Distribute the complete `build/windows/x64/runner/Release` directory, never the
executable by itself. If Inno Setup 6 is installed, compile `installer.iss` to
produce `dist/KerfStock_Setup_v1.0.1.exe`.

Before publishing a desktop build, deploy the matching KerfPortal API version
and verify that unauthenticated access to `/api/stock/assets` returns HTTP 401.

Release configuration contains only the Supabase URL, public publishable key,
and Portal URL. Never bundle a service-role, database, or JWT signing secret.
## Verification

```powershell
dart analyze lib test
flutter test
```

The application requires a valid Supabase user associated with a KerfSuite
workspace. Realtime must be enabled for the `public.assets` table in Supabase.
