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
