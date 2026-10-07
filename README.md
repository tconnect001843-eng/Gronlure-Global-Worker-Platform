# Gronlure Global Worker Platform

Flutter app for web, Android, and iOS with a PHP REST API and MySQL database for
the included XAMPP installation.

## Run it locally

1. Start Apache and MySQL in the XAMPP Control Panel.
2. The `glonlure_platform` database already exists in this XAMPP workspace. For
   a fresh install, import `backend/database/schema.sql` in phpMyAdmin.
3. Copy `backend/.env.example` to `backend/.env` and set database credentials.
   The backend database name remains `glonlure_platform` to preserve existing
   installs and their data; this internal identifier is not displayed as the
   product name.
4. Check the API at
   `http://localhost/Profile%20Uganda/backend/public/api/health`; it should
   return `{"status":"ok","database":"connected"}`.
5. Launch the browser app:

   ```powershell
   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost/Profile%20Uganda/backend/public/api
   ```

The built web version is served from
`http://localhost/Profile%20Uganda/build_local/web/`. For Android, replace
`localhost` in `API_BASE_URL` with the computer's LAN IP and make sure Apache
can be reached from the phone. Production must use HTTPS.

## Free web pilot deployment

The GitHub repository contains source code, not a live service. InfinityFree
currently advertises free PHP, MySQL, SSL, and free subdomains without a card.
Free hosting is subject to provider limits and can be changed or suspended;
use it only as a low-traffic demo with test data. Do not upload real identity
documents, collect real payments, or promise production availability.

The PHP API and Flutter web app can share one host and HTTPS origin. This also
avoids cross-origin browser requests. Create a free InfinityFree account/site
first and note the exact assigned hostname (for example,
`your-site.infinityfreeapp.com`).

1. From PowerShell in the project folder, prepare a hostname-specific upload
   bundle:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-infinityfree.ps1 -SiteDomain your-site.infinityfreeapp.com
   ```

   The process-scoped execution-policy option lets Windows run this one script
   without changing your machine's PowerShell policy. The script builds Flutter
   with `https://your-site.infinityfreeapp.com/api`
   and creates `build_local\infinityfree-your-site.infinityfreeapp.com\` with
   three separate folders: `htdocs`, `database`, and `account-root`.
2. In the hosting control panel, create a MySQL database and database user.
   Import `database\schema.sql` using its database management tool. Record the
   exact database host, database name, and username shown there. Do not share
   those credentials in chat or put them in the public website folder.
3. Use the provider's file manager or FTP/SFTP tool to upload the *contents*
   of the bundle's `htdocs` folder into the website's `htdocs` directory,
   including hidden `.htaccess`. The resulting layout must include
   `htdocs\index.html`, `htdocs\assets\...`, `htdocs\.htaccess`, and
   `htdocs\api\index.php`.
4. Copy `account-root\.env.example` to a file named `.env` in the hosting
   account's home directory (one level above `htdocs`). Edit it privately with
   the hosting panel's database values, and set:

   ```dotenv
   DB_HOST=the-host-provided-database-host
   DB_PORT=3306
   DB_NAME=the-host-provided-database-name
   DB_USER=the-host-provided-database-user
   DB_PASSWORD=your-private-database-password
   CORS_ALLOWED_ORIGIN=https://your-site.infinityfreeapp.com
   ```

   Keep all MTN variables empty; production payment activation is not part of
   this free pilot. Do not place `.env` inside the public `htdocs` folder.
5. Enable HTTPS for the free subdomain using the provider's SSL instructions.
   Visit `https://your-site.infinityfreeapp.com/api/health`; it must return
   `{"status":"ok","database":"connected"}`. Then open
   `https://your-site.infinityfreeapp.com/` on a phone, create a test account,
   and check profile and job posting. Use the browser's **Add to Home Screen**
   command to install it as a home-screen web app.

The free web host may block API calls from native mobile apps, external payment
providers, or automated clients. Prove web-browser API access first. If the
Android APK cannot sign in against this host, use the installed web app for
the pilot; a reliable native app backend may require a paid host or a backend
migration. Free services have no production SLA, and their PHP/MySQL
restrictions can change. Review privacy, data retention, backups, and local
legal obligations before collecting any real personal information.

The GitHub Pages workflow remains available as a separate web-front-end
option if a compatible HTTPS API is hosted elsewhere. Configure its
`API_BASE_URL` GitHub Actions variable before enabling Pages deployment.

The application currently has no MTN production credentials. Leave payment
activation off until merchant access is approved and the provider credentials
are set only in the PHP host's private environment configuration.

### Build and install the Android app directly

Direct APK installation is not the same as publishing through Google Play.
Android release builds must use a private signing key; losing that key prevents
updating the installed app. Never commit or send the key or its passwords.

1. Install a Java JDK that includes `keytool`, then create the signing key once
   from the project root:

   ```powershell
   keytool -genkeypair -v -keystore android\gronlure-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gronlure
   ```

   Store a protected backup of the generated keystore. Use passwords you can
   retain securely; do not lose them.
2. Create `android\key.properties` locally (this file and the keystore are
   ignored by Git) with the values you chose:

   ```properties
   storePassword=YOUR_PRIVATE_STORE_PASSWORD
   keyPassword=YOUR_PRIVATE_KEY_PASSWORD
   keyAlias=gronlure
   storeFile=gronlure-release.jks
   ```

3. Build the signed APK, replacing the URL with the live HTTPS API base URL:

   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api
   ```

   Flutter prints the generated APK path. Transfer that APK to the phone using
   a trusted private download link or USB, then install it. Android may ask the
   user to allow installs from that browser/file manager. Do not share the
   signing key when sharing the APK.

The direct APK is not automatically updated when you deploy new web versions;
build and redistribute an updated APK when the app changes.

## Sign in as an administrator

1. Register an account in Gronlure using the phone number you will use as the
   administrator.
2. In phpMyAdmin, choose the `glonlure_platform` database, open the SQL tab,
   and run this command with that exact account phone number:

   ```sql
   UPDATE users SET role = 'admin' WHERE phone = '+2567XXXXXXXX';
   ```

3. Log out of Gronlure and sign back in so the new admin role is loaded.
4. Open **Admin** in the left-hand navigation on desktop, or the **Admin**
   destination in the mobile bottom navigation. The panel reads the live
   summary, pending worker verifications, disputes, payment records, and
   payment/database configuration status from the API.

Only use the `UPDATE` command for the intended account. Public registration
cannot create administrator accounts.

## Activate MTN Mobile Money

**Yes, activation is possible.** MTN is the only payment provider currently
wired into this project. To bring up the sandbox with the fewest steps:

1. Sign in to the MTN MoMo developer portal and create/subscribe to a **Collection**
   product for the sandbox environment.
2. In that product, create an API user and generate its API key. Keep the
   product's subscription key, API user ID, and API key available privately.
3. Copy `backend/.env.example` to `backend/.env`, then set:

   ```dotenv
   MTN_ENVIRONMENT=sandbox
   MTN_TARGET_ENVIRONMENT=sandbox
   MTN_CURRENCY=UGX
   MTN_SUBSCRIPTION_KEY=your_collection_product_subscription_key
   MTN_API_USER=your_sandbox_api_user_uuid
   MTN_API_KEY=your_sandbox_api_key
   ```

   Set `MTN_CURRENCY` to the currency supported by your selected MTN
   environment and merchant market. Uganda production should use UGX; use the
   currency specified by MTN for the sandbox product if it differs.
4. Restart Apache and test with a sandbox MSISDN provided by MTN. Select
   **Subscribe now** (UGX 4,000) or unlock a verified worker contact (UGX 500),
   approve the prompt on the test phone, then select **Check payment status**.
5. For live charges, first get MTN production access/credentials for the
   merchant account, then deploy the PHP API on a public HTTPS host. Set
   `MTN_ENVIRONMENT=production`, `MTN_TARGET_ENVIRONMENT=mtnuganda`, the
   production Collection subscription key, production API user/key, and
   `MTN_CURRENCY=UGX`. Only then test with a small authorized live transaction.

The optional `MTN_CALLBACK_URL` must be a public HTTPS URL reachable by MTN.
This app can poll MTN for payment status without it; local `localhost` URLs
cannot receive provider callbacks. The backend generates the required request
reference, creates the collection request server-side, and activates a
subscription or releases a contact only after MTN reports a successful
payment. Amounts are fixed on the server; do not trust client-provided amounts.

Never put MTN keys in Flutter code, commit `backend/.env`, or send secrets in
chat. Airtel Money, PayPal, Visa, and Mastercard are displayed as future options
but are not payment integrations yet.

## Implemented API

- `GET /api/health`
- `POST /api/register`, `POST /api/login`, `POST /api/logout`
- `GET /api/profile`, `PUT /api/profile`
- `GET /api/workers?q=...` (approved profiles only)
- `POST /api/jobs`, `GET /api/jobs`, `GET /api/jobs/mine` (any signed-in user
  can publish a job; open listings are visible to signed-in users)
- `POST /api/payments/request`, `GET /api/payments/status`
- Admin-only: `GET /api/admin/summary`, `GET /api/admin/verifications`,
  `POST /api/admin/verifications/{workerId}`, `GET /api/admin/disputes`,
  `POST /api/admin/disputes/{id}`, `GET /api/admin/payments`

The app also includes a theme switch on the login/register and dashboard
screens. The choice is saved on the device. Every signed-in user can publish a
job with a title, skill, location, description, and optional UGX budget; the
Jobs screen lists their own posts and open community jobs. Applying to jobs and
offer/hire management, dispute creation, feedback submission, document/photo
uploads, SMS verification, password reset, monthly analytics charts, and
non-MTN payment integrations remain future work.

## Validation

```powershell
flutter analyze
flutter test
flutter build web --base-href /Profile%20Uganda/build_local/web/
& C:\xamp\php\php.exe -l backend\public\api\index.php
```
