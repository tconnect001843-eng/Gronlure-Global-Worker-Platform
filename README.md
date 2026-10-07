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

## Public pilot deployment

The GitHub repository is the source code, not a running server. The Flutter web
client can be hosted free on GitHub Pages; the PHP API and MariaDB database
must still be hosted separately. A free PHP/MySQL plan may sleep, have small
storage or traffic limits, or restrict commercial use. Treat a free deployment
as a demo with test data only: do not upload real identity documents, collect
real payments, or promise production availability until the host and privacy
requirements are reviewed.

### Deploy the Flutter web client

1. In the GitHub repository, open **Settings → Pages** and set the build and
   deployment source to **GitHub Actions**.
2. First provision the public HTTPS PHP API and database as described below.
   Do not publish the client with the local `localhost` API URL.
3. In **Settings → Secrets and variables → Actions → Variables**, add the
   repository variable `API_BASE_URL`, set to the HTTPS API base URL, for
   example `https://YOUR_API_HOST/api` (no trailing slash).
4. Set the API's `CORS_ALLOWED_ORIGIN` environment variable to
   `https://tconnect001843-eng.github.io`. It must be the website origin only:
   no path and no trailing slash.
5. Run **Actions → Deploy Gronlure web app → Run workflow**. The workflow
   analyzes/tests the Flutter app, builds it with the HTTPS API URL, and
   publishes it. The site URL is
   `https://tconnect001843-eng.github.io/Gronlure-Global-Worker-Platform/`.
   Later pushes to `main` automatically redeploy it.

### Provision the PHP API and MariaDB

Choose a PHP 8+ host that explicitly includes HTTPS, URL rewrite support,
PDO-MySQL, `mbstring`, and outbound HTTPS requests (required if MTN payments
are activated later). Create a MariaDB/MySQL database and a dedicated database
user; do not use the MySQL `root` account. Keep the database credentials in the
host's private environment-variable settings, not in GitHub or Flutter code.

1. Create/import the tables from `backend/database/schema.sql` using the
   provider's database tools.
2. Upload the `backend` directory so the website's document root is
   `backend/public`. This keeps `backend/.env` outside the public web folder.
   If the host cannot set that document root, place secrets outside its public
   directory and configure the host's PHP environment variables instead.
3. Configure `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and
   `CORS_ALLOWED_ORIGIN` in the hosting panel. `CORS_ALLOWED_ORIGIN` must match
   the GitHub Pages origin above. Ensure Apache rewrite rules from
   `backend/public/.htaccess` are enabled, or configure equivalent routes in
   the host.
4. Visit `https://YOUR_API_HOST/api/health`; it must return
   `{"status":"ok","database":"connected"}`. Then register a test account
   using the hosted web app and verify sign-in, profile, and job-posting flows.
5. A free hosting subdomain is fine for a test pilot. Use a paid plan and
   review local privacy, retention, backup, and incident-response obligations
   before storing real users' phone numbers or other personal information.

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
