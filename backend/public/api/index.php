<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_SLASHES);
    exit;
}

function load_env(): void
{
    $path = dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . '.env';
    if (!is_file($path)) {
        return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        $value = trim(trim($value), "\"'");
        if (getenv($key) === false) {
            putenv($key . '=' . $value);
            $_ENV[$key] = $value;
        }
    }
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    $host = getenv('DB_HOST') ?: '127.0.0.1';
    $port = getenv('DB_PORT') ?: '3306';
    $name = getenv('DB_NAME') ?: 'glonlure_platform';
    $user = getenv('DB_USER') ?: 'root';
    $password = getenv('DB_PASSWORD') ?: '';
    $pdo = new PDO(
        "mysql:host={$host};port={$port};dbname={$name};charset=utf8mb4",
        $user,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ],
    );
    return $pdo;
}

function request_data(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        respond(400, ['error' => 'Request body must be a JSON object.']);
    }
    return $data;
}

function required_string(array $data, string $key, int $maxLength): string
{
    $value = $data[$key] ?? null;
    if (!is_string($value) || trim($value) === '' || mb_strlen(trim($value)) > $maxLength) {
        respond(422, ['error' => "A valid {$key} is required."]);
    }
    return trim($value);
}

function normalize_phone(string $phone): string
{
    $normalized = preg_replace('/[\s().-]/', '', $phone);
    if (!is_string($normalized) || !preg_match('/^\+?[1-9][0-9]{7,14}$/', $normalized)) {
        respond(422, ['error' => 'Enter a valid phone number including its country code.']);
    }
    return $normalized;
}

function issue_token(PDO $pdo, int $userId): string
{
    $token = bin2hex(random_bytes(32));
    $statement = $pdo->prepare(
        'INSERT INTO auth_tokens (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))',
    );
    $statement->execute([$userId, hash('sha256', $token)]);
    return $token;
}

function bearer_token(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        $headers = getallheaders();
        $header = is_array($headers) ? ($headers['Authorization'] ?? '') : '';
    }
    if (!preg_match('/^Bearer ([a-f0-9]{64})$/i', $header, $matches)) {
        respond(401, ['error' => 'Sign in to continue.']);
    }
    return $matches[1];
}

function current_user(PDO $pdo): array
{
    $statement = $pdo->prepare(
        'SELECT u.id, u.full_name, u.phone, u.role FROM auth_tokens t JOIN users u ON u.id = t.user_id WHERE t.token_hash = ? AND t.expires_at > UTC_TIMESTAMP() AND u.account_status = \'active\'',
    );
    $statement->execute([hash('sha256', bearer_token())]);
    $user = $statement->fetch();
    if (!$user) {
        respond(401, ['error' => 'Your session has expired. Please sign in again.']);
    }
    return $user;
}

function profile_for_user(PDO $pdo, int $userId): array
{
    $statement = $pdo->prepare(
        'SELECT u.full_name, u.phone, u.role, p.public_id, p.headline, p.bio, p.skills, p.location, p.photo_url, p.verification_status, p.completed_jobs FROM users u JOIN worker_profiles p ON p.user_id = u.id WHERE u.id = ?',
    );
    $statement->execute([$userId]);
    $profile = $statement->fetch();
    if (!$profile) {
        respond(404, ['error' => 'Profile was not found.']);
    }
    return $profile;
}

function require_admin(PDO $pdo): array
{
    $user = current_user($pdo);
    if ($user['role'] !== 'admin') {
        respond(403, ['error' => 'Administrator access is required.']);
    }
    return $user;
}

final class PaymentGatewayException extends RuntimeException
{
    public function __construct(string $message, int $statusCode = 502)
    {
        parent::__construct($message, $statusCode);
    }
}

function mtn_base_url(): string
{
    $environment = getenv('MTN_ENVIRONMENT') ?: 'sandbox';
    if ($environment === 'sandbox') {
        return 'https://sandbox.momodeveloper.mtn.com';
    }
    if ($environment === 'production') {
        return 'https://proxy.momoapi.mtn.com';
    }
    throw new PaymentGatewayException('MTN_ENVIRONMENT must be sandbox or production.', 503);
}

function mtn_request(
    string $method,
    string $path,
    ?array $payload = null,
    bool $tokenRequest = false,
    array $extraHeaders = [],
): array
{
    $subscriptionKey = getenv('MTN_SUBSCRIPTION_KEY') ?: '';
    $apiUser = getenv('MTN_API_USER') ?: '';
    $apiKey = getenv('MTN_API_KEY') ?: '';
    if ($subscriptionKey === '' || $apiUser === '' || $apiKey === '') {
        throw new PaymentGatewayException('MTN Mobile Money is not configured. Add the MTN sandbox or production credentials to backend/.env.', 503);
    }

    $environment = getenv('MTN_ENVIRONMENT') ?: 'sandbox';
    $targetEnvironment = getenv('MTN_TARGET_ENVIRONMENT')
        ?: ($environment === 'sandbox' ? 'sandbox' : 'mtnuganda');
    if (($environment === 'sandbox' && $targetEnvironment !== 'sandbox')
        || ($environment === 'production' && $targetEnvironment !== 'mtnuganda')) {
        throw new PaymentGatewayException(
            'Set MTN_TARGET_ENVIRONMENT=sandbox for sandbox or mtnuganda for Uganda production.',
            503,
        );
    }

    $baseUrl = mtn_base_url();
    $curl = curl_init($baseUrl . $path);
    if ($curl === false) {
        throw new PaymentGatewayException('Could not initialize the MTN payment connection.');
    }

    $headers = [
        'Ocp-Apim-Subscription-Key: ' . $subscriptionKey,
        'X-Target-Environment: ' . $targetEnvironment,
    ];
    if ($tokenRequest) {
        $headers[] = 'Authorization: Basic ' . base64_encode($apiUser . ':' . $apiKey);
    } else {
        $accessToken = mtn_access_token();
        $headers[] = 'Authorization: Bearer ' . $accessToken;
    }
    foreach ($extraHeaders as $header) {
        $headers[] = $header;
    }
    if ($payload !== null) {
        $headers[] = 'Content-Type: application/json';
        curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($payload));
    }
    curl_setopt_array($curl, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 25,
    ]);
    $body = curl_exec($curl);
    $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $curlError = curl_error($curl);
    curl_close($curl);

    if ($body === false) {
        error_log('MTN request failed: ' . $curlError);
        throw new PaymentGatewayException('The MTN payment service could not be reached. Try again shortly.');
    }
    $decoded = $body === '' ? [] : json_decode($body, true);
    if ($status < 200 || $status >= 300) {
        error_log('MTN request returned HTTP ' . $status . ': ' . substr((string) $body, 0, 500));
        throw new PaymentGatewayException('MTN did not accept the request. Check provider credentials and try again.');
    }
    return is_array($decoded) ? $decoded : [];
}

function mtn_access_token(): string
{
    static $token = null;
    if (is_string($token)) {
        return $token;
    }
    $result = mtn_request('POST', '/collection/token/', null, true);
    if (!isset($result['access_token']) || !is_string($result['access_token'])) {
        throw new PaymentGatewayException('MTN returned an invalid authentication response.');
    }
    $token = $result['access_token'];
    return $token;
}

function route_path(): string
{
    $route = $_GET['route'] ?? '';
    if ($route === '') {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
        $route = is_string($path) ? preg_replace('#^.*/api/?#', '', $path) : '';
    }
    return trim((string) $route, '/');
}

load_env();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$route = route_path();

try {
    $pdo = db();

    if ($method === 'GET' && $route === 'health') {
        $pdo->query('SELECT 1');
        respond(200, ['status' => 'ok', 'database' => 'connected']);
    }

    if ($method === 'POST' && $route === 'register') {
        $data = request_data();
        $name = required_string($data, 'full_name', 120);
        $phone = normalize_phone(required_string($data, 'phone', 20));
        $password = $data['password'] ?? null;
        if (!is_string($password) || strlen($password) < 8 || strlen($password) > 200) {
            respond(422, ['error' => 'Password must be between 8 and 200 characters.']);
        }
        $pdo->beginTransaction();
        try {
            $statement = $pdo->prepare('INSERT INTO users (full_name, phone, password_hash) VALUES (?, ?, ?)');
            $statement->execute([$name, $phone, password_hash($password, PASSWORD_DEFAULT)]);
            $userId = (int) $pdo->lastInsertId();
            $profileId = 'UGW-' . strtoupper(bin2hex(random_bytes(4)));
            $statement = $pdo->prepare('INSERT INTO worker_profiles (public_id, user_id) VALUES (?, ?)');
            $statement->execute([$profileId, $userId]);
            $token = issue_token($pdo, $userId);
            $pdo->commit();
            respond(201, [
                'token' => $token,
                'profile' => profile_for_user($pdo, $userId),
            ]);
        } catch (PDOException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if ($error->getCode() === '23000') {
                respond(409, ['error' => 'An account with that phone number already exists.']);
            }
            throw $error;
        }
    }

    if ($method === 'POST' && $route === 'login') {
        $data = request_data();
        $phone = normalize_phone(required_string($data, 'phone', 20));
        $password = $data['password'] ?? null;
        if (!is_string($password) || $password === '') {
            respond(422, ['error' => 'Password is required.']);
        }
        $statement = $pdo->prepare('SELECT id, password_hash FROM users WHERE phone = ? AND account_status = \'active\'');
        $statement->execute([$phone]);
        $user = $statement->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            respond(401, ['error' => 'Phone number or password is incorrect.']);
        }
        $userId = (int) $user['id'];
        respond(200, ['token' => issue_token($pdo, $userId), 'profile' => profile_for_user($pdo, $userId)]);
    }

    if ($method === 'POST' && $route === 'logout') {
        current_user($pdo);
        $statement = $pdo->prepare('DELETE FROM auth_tokens WHERE token_hash = ?');
        $statement->execute([hash('sha256', bearer_token())]);
        respond(200, ['message' => 'You have been signed out.']);
    }

    if ($route === 'profile' && $method === 'GET') {
        $user = current_user($pdo);
        respond(200, ['profile' => profile_for_user($pdo, (int) $user['id'])]);
    }

    if ($route === 'profile' && $method === 'PUT') {
        $user = current_user($pdo);
        $data = request_data();
        $allowed = ['full_name', 'headline', 'bio', 'skills', 'location'];
        foreach (array_keys($data) as $key) {
            if (!in_array($key, $allowed, true)) {
                respond(422, ['error' => "The profile field {$key} cannot be changed here."]);
            }
        }
        $pdo->beginTransaction();
        if (isset($data['full_name'])) {
            $statement = $pdo->prepare('UPDATE users SET full_name = ? WHERE id = ?');
            $statement->execute([required_string($data, 'full_name', 120), $user['id']]);
        }
        $columns = ['headline' => 180, 'bio' => 5000, 'skills' => 1000, 'location' => 160];
        $updates = [];
        $values = [];
        foreach ($columns as $column => $maximum) {
            if (array_key_exists($column, $data)) {
                if (!is_string($data[$column]) || mb_strlen($data[$column]) > $maximum) {
                    $pdo->rollBack();
                    respond(422, ['error' => "The {$column} value is invalid."]);
                }
                $updates[] = "{$column} = ?";
                $values[] = trim($data[$column]);
            }
        }
        if ($updates !== []) {
            $values[] = $user['id'];
            $statement = $pdo->prepare('UPDATE worker_profiles SET ' . implode(', ', $updates) . ' WHERE user_id = ?');
            $statement->execute($values);
        }
        $pdo->commit();
        respond(200, ['profile' => profile_for_user($pdo, (int) $user['id'])]);
    }

    if ($method === 'GET' && $route === 'workers') {
        $user = current_user($pdo);
        $query = $_GET['q'] ?? '';
        if (!is_string($query) || mb_strlen($query) > 120) {
            respond(422, ['error' => 'Search text must be 120 characters or fewer.']);
        }
        $term = '%' . trim($query) . '%';
        $statement = $pdo->prepare(
            'SELECT p.public_id, u.full_name, p.headline, p.skills, p.location, p.photo_url, p.completed_jobs, COALESCE(AVG(f.rating), 0) AS rating, COUNT(f.id) AS review_count FROM worker_profiles p JOIN users u ON u.id = p.user_id LEFT JOIN feedback f ON f.profile_id = p.id WHERE p.verification_status = \'approved\' AND p.user_id <> ? AND (? = \'%%\' OR u.full_name LIKE ? OR p.headline LIKE ? OR p.skills LIKE ? OR p.location LIKE ?) GROUP BY p.id, u.full_name, p.headline, p.skills, p.location, p.photo_url, p.completed_jobs ORDER BY rating DESC, p.completed_jobs DESC LIMIT 50',
        );
        $statement->execute([$user['id'], $term, $term, $term, $term, $term]);
        respond(200, ['workers' => $statement->fetchAll()]);
    }

    if ($route === 'jobs' && $method === 'POST') {
        $user = current_user($pdo);
        $data = request_data();
        $title = required_string($data, 'title', 180);
        $description = required_string($data, 'description', 5000);
        $skill = required_string($data, 'skill', 120);
        $location = required_string($data, 'location', 160);
        $budget = $data['budget_ugx'] ?? null;
        if ($budget !== null
            && (!is_int($budget) || $budget < 1 || $budget > 2000000000)) {
            respond(422, ['error' => 'Budget must be a whole UGX amount between 1 and 2,000,000,000.']);
        }
        $statement = $pdo->prepare(
            'INSERT INTO jobs (employer_id, title, description, skill, location, budget_ugx) VALUES (?, ?, ?, ?, ?, ?)',
        );
        $statement->execute([
            $user['id'],
            $title,
            $description,
            $skill,
            $location,
            $budget,
        ]);
        $jobId = (int) $pdo->lastInsertId();
        $statement = $pdo->prepare(
            'SELECT j.id, j.title, j.description, j.skill, j.location, j.budget_ugx, j.status, j.created_at, u.full_name AS employer_name FROM jobs j JOIN users u ON u.id = j.employer_id WHERE j.id = ?',
        );
        $statement->execute([$jobId]);
        respond(201, ['job' => $statement->fetch()]);
    }

    if ($method === 'GET' && $route === 'jobs/mine') {
        $user = current_user($pdo);
        $statement = $pdo->prepare(
            'SELECT j.id, j.title, j.description, j.skill, j.location, j.budget_ugx, j.status, j.created_at, (SELECT COUNT(*) FROM job_applications a WHERE a.job_id = j.id) AS application_count FROM jobs j WHERE j.employer_id = ? ORDER BY j.created_at DESC LIMIT 100',
        );
        $statement->execute([$user['id']]);
        respond(200, ['jobs' => $statement->fetchAll()]);
    }

    if ($method === 'GET' && $route === 'jobs') {
        current_user($pdo);
        $statement = $pdo->query(
            'SELECT j.id, j.title, j.description, j.skill, j.location, j.budget_ugx, j.status, j.created_at, u.full_name AS employer_name FROM jobs j JOIN users u ON u.id = j.employer_id WHERE j.status = \'open\' ORDER BY j.created_at DESC LIMIT 100',
        );
        respond(200, ['jobs' => $statement->fetchAll()]);
    }

    if ($method === 'GET' && $route === 'admin/summary') {
        require_admin($pdo);
        $summary = $pdo->query(
            'SELECT (SELECT COUNT(*) FROM users WHERE account_status = \'active\') AS active_users, (SELECT COUNT(*) FROM worker_profiles WHERE verification_status = \'approved\') AS verified_profiles, (SELECT COUNT(*) FROM subscriptions WHERE status = \'active\' AND ends_at > UTC_TIMESTAMP()) AS active_subscriptions, (SELECT COALESCE(SUM(amount_ugx), 0) FROM payments WHERE status = \'successful\') AS payments_total_ugx, (SELECT COUNT(*) FROM payments WHERE status = \'successful\') AS payments_processed, (SELECT COUNT(*) FROM worker_profiles WHERE verification_status = \'pending\') AS pending_verifications, (SELECT COUNT(*) FROM disputes WHERE status IN (\'open\', \'reviewing\')) AS open_disputes',
        )->fetch();
        $summary['mtn_configured'] = (getenv('MTN_SUBSCRIPTION_KEY') ?: '') !== ''
            && (getenv('MTN_API_USER') ?: '') !== ''
            && (getenv('MTN_API_KEY') ?: '') !== '';
        respond(200, ['summary' => $summary]);
    }

    if ($method === 'GET' && $route === 'admin/verifications') {
        require_admin($pdo);
        $statement = $pdo->query(
            'SELECT p.id, p.public_id, u.full_name, u.phone, p.headline, p.skills, p.location, p.created_at, (SELECT COUNT(*) FROM verification_documents d WHERE d.profile_id = p.id AND d.review_status = \'pending\') AS pending_documents FROM worker_profiles p JOIN users u ON u.id = p.user_id WHERE p.verification_status = \'pending\' ORDER BY p.created_at ASC LIMIT 100',
        );
        respond(200, ['verifications' => $statement->fetchAll()]);
    }

    if ($method === 'POST' && preg_match('#^admin/verifications/([A-Za-z0-9-]+)$#', $route, $matches)) {
        $admin = require_admin($pdo);
        $data = request_data();
        $decision = $data['decision'] ?? '';
        if (!in_array($decision, ['approved', 'rejected'], true)) {
            respond(422, ['error' => 'Choose approved or rejected.']);
        }
        $pdo->beginTransaction();
        $statement = $pdo->prepare(
            'UPDATE worker_profiles SET verification_status = ? WHERE public_id = ? AND verification_status = \'pending\'',
        );
        $statement->execute([$decision, $matches[1]]);
        if ($statement->rowCount() !== 1) {
            $pdo->rollBack();
            respond(404, ['error' => 'Pending worker profile was not found.']);
        }
        $statement = $pdo->prepare(
            'UPDATE verification_documents d JOIN worker_profiles p ON p.id = d.profile_id SET d.review_status = ?, d.reviewed_by = ?, d.reviewed_at = UTC_TIMESTAMP() WHERE p.public_id = ? AND d.review_status = \'pending\'',
        );
        $statement->execute([$decision, $admin['id'], $matches[1]]);
        $statement = $pdo->prepare(
            'INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, details) SELECT ?, ?, \'worker_profile\', id, ? FROM worker_profiles WHERE public_id = ?',
        );
        $statement->execute([
            $admin['id'],
            'verification_' . $decision,
            json_encode(['public_id' => $matches[1]], JSON_THROW_ON_ERROR),
            $matches[1],
        ]);
        $pdo->commit();
        respond(200, ['public_id' => $matches[1], 'verification_status' => $decision]);
    }

    if ($method === 'GET' && $route === 'admin/disputes') {
        require_admin($pdo);
        $statement = $pdo->query(
            'SELECT d.id, d.details, d.status, d.created_at, j.title AS job_title, opener.full_name AS opened_by, against_user.full_name AS against_user FROM disputes d JOIN jobs j ON j.id = d.job_id JOIN users opener ON opener.id = d.opened_by JOIN users against_user ON against_user.id = d.against_user_id ORDER BY d.created_at DESC LIMIT 100',
        );
        respond(200, ['disputes' => $statement->fetchAll()]);
    }

    if ($method === 'GET' && $route === 'admin/payments') {
        require_admin($pdo);
        $statement = $pdo->query(
            'SELECT p.id, p.provider_reference, p.purpose, p.amount_ugx, p.payer_phone, p.provider, p.status, p.provider_status, p.created_at, u.full_name AS customer_name FROM payments p JOIN users u ON u.id = p.user_id ORDER BY p.created_at DESC LIMIT 100',
        );
        respond(200, ['payments' => $statement->fetchAll()]);
    }

    if ($method === 'POST' && preg_match('#^admin/disputes/([0-9]+)$#', $route, $matches)) {
        $admin = require_admin($pdo);
        $data = request_data();
        $decision = $data['decision'] ?? '';
        $resolution = required_string($data, 'resolution', 5000);
        if (!in_array($decision, ['resolved', 'dismissed'], true)) {
            respond(422, ['error' => 'Choose resolved or dismissed.']);
        }
        $statement = $pdo->prepare(
            'UPDATE disputes SET status = ?, resolution = ?, resolved_by = ?, resolved_at = UTC_TIMESTAMP() WHERE id = ? AND status IN (\'open\', \'reviewing\')',
        );
        $statement->execute([$decision, $resolution, $admin['id'], (int) $matches[1]]);
        if ($statement->rowCount() !== 1) {
            respond(404, ['error' => 'Open dispute was not found.']);
        }
        respond(200, ['id' => (int) $matches[1], 'status' => $decision]);
    }

    if ($method === 'POST' && $route === 'payments/request') {
        $user = current_user($pdo);
        $data = request_data();
        $purpose = $data['purpose'] ?? '';
        if (!in_array($purpose, ['subscription', 'contact_unlock'], true)) {
            respond(422, ['error' => 'Unsupported payment purpose.']);
        }
        if ((getenv('MTN_SUBSCRIPTION_KEY') ?: '') === ''
            || (getenv('MTN_API_USER') ?: '') === ''
            || (getenv('MTN_API_KEY') ?: '') === '') {
            respond(503, ['error' => 'MTN Mobile Money is not configured. Add the MTN sandbox or production credentials to backend/.env.']);
        }
        $phone = normalize_phone(required_string($data, 'phone', 20));
        $amount = $purpose === 'subscription' ? 4000 : 500;
        $currency = strtoupper(getenv('MTN_CURRENCY') ?: 'UGX');
        $environment = getenv('MTN_ENVIRONMENT') ?: 'sandbox';
        if ($environment === 'production' && $currency !== 'UGX') {
            respond(503, ['error' => 'Production payments in this Uganda setup must use MTN_CURRENCY=UGX.']);
        }
        if (!preg_match('/^[A-Z]{3}$/', $currency)) {
            respond(503, ['error' => 'MTN_CURRENCY must be a three-letter ISO currency code.']);
        }
        $targetProfileId = null;
        if ($purpose === 'contact_unlock') {
            $workerId = required_string($data, 'worker_id', 24);
            $statement = $pdo->prepare('SELECT id FROM worker_profiles WHERE public_id = ? AND verification_status = \'approved\'');
            $statement->execute([$workerId]);
            $targetProfileId = $statement->fetchColumn();
            if ($targetProfileId === false) {
                respond(404, ['error' => 'Verified worker profile was not found.']);
            }
            $statement = $pdo->prepare('SELECT id FROM contact_unlocks WHERE buyer_id = ? AND profile_id = ?');
            $statement->execute([$user['id'], $targetProfileId]);
            if ($statement->fetchColumn() !== false) {
                respond(409, ['error' => 'You have already unlocked this worker contact.']);
            }
        }
        $reference = sprintf(
            '%s-%s-%s-%s-%s',
            bin2hex(random_bytes(4)),
            bin2hex(random_bytes(2)),
            '4' . substr(bin2hex(random_bytes(2)), 1),
            dechex((hexdec(bin2hex(random_bytes(2))) & 0x3fff) | 0x8000),
            bin2hex(random_bytes(6)),
        );
        $statement = $pdo->prepare(
            'INSERT INTO payments (user_id, target_profile_id, purpose, amount_ugx, payer_phone, provider_reference) VALUES (?, ?, ?, ?, ?, ?)',
        );
        $statement->execute([$user['id'], $targetProfileId, $purpose, $amount, $phone, $reference]);
        $paymentId = (int) $pdo->lastInsertId();

        $payload = [
            'amount' => (string) $amount,
            'currency' => $currency,
            'externalId' => (string) $paymentId,
            'payer' => ['partyIdType' => 'MSISDN', 'partyId' => ltrim($phone, '+')],
            'payerMessage' => $purpose === 'subscription' ? 'Gronlure monthly subscription' : 'Gronlure worker contact unlock',
            'payeeNote' => 'Gronlure platform',
        ];
        $extraHeaders = ['X-Reference-Id: ' . $reference];
        $callbackUrl = getenv('MTN_CALLBACK_URL') ?: '';
        if ($callbackUrl !== '') {
            $extraHeaders[] = 'X-Callback-Url: ' . $callbackUrl;
        }

        try {
            mtn_request(
                'POST',
                '/collection/v1_0/requesttopay',
                $payload,
                extraHeaders: $extraHeaders,
            );
        } catch (PaymentGatewayException $error) {
            $statement = $pdo->prepare('UPDATE payments SET status = \'failed\' WHERE id = ?');
            $statement->execute([$paymentId]);
            throw $error;
        }
        respond(202, [
            'reference' => $reference,
            'status' => 'pending',
            'amount_ugx' => $amount,
            'message' => 'Payment request sent. Approve the MTN Mobile Money prompt on your phone.',
        ]);
    }

    if ($method === 'GET' && $route === 'payments/status') {
        $user = current_user($pdo);
        $reference = $_GET['reference'] ?? '';
        if (!is_string($reference) || !preg_match('/^[a-f0-9-]{36}$/i', $reference)) {
            respond(422, ['error' => 'A valid payment reference is required.']);
        }
        $statement = $pdo->prepare('SELECT id, status FROM payments WHERE provider_reference = ? AND user_id = ?');
        $statement->execute([$reference, $user['id']]);
        $payment = $statement->fetch();
        if (!$payment) {
            respond(404, ['error' => 'Payment was not found.']);
        }
        $providerStatus = mtn_request(
            'GET',
            '/collection/v1_0/requesttopay/' . rawurlencode($reference),
            extraHeaders: ['X-Reference-Id: ' . $reference],
        );
        $mtnStatus = strtoupper((string) ($providerStatus['status'] ?? 'PENDING'));
        $status = match ($mtnStatus) {
            'SUCCESSFUL' => 'successful',
            'FAILED' => 'failed',
            'REJECTED', 'CANCELLED' => 'cancelled',
            default => 'pending',
        };
        $pdo->beginTransaction();
        $statement = $pdo->prepare('SELECT status FROM payments WHERE id = ? FOR UPDATE');
        $statement->execute([$payment['id']]);
        $lockedPayment = $statement->fetch();
        $statement = $pdo->prepare('UPDATE payments SET status = ?, provider_status = ? WHERE id = ?');
        $statement->execute([$status, $mtnStatus, $payment['id']]);
        if ($status === 'successful' && $lockedPayment['status'] !== 'successful') {
            $statement = $pdo->prepare('SELECT user_id, target_profile_id, purpose FROM payments WHERE id = ?');
            $statement->execute([$payment['id']]);
            $paymentDetails = $statement->fetch();
            if ($paymentDetails['purpose'] === 'contact_unlock' && $paymentDetails['target_profile_id'] !== null) {
                $statement = $pdo->prepare(
                    'INSERT IGNORE INTO contact_unlocks (buyer_id, profile_id, payment_id) VALUES (?, ?, ?)',
                );
                $statement->execute([$paymentDetails['user_id'], $paymentDetails['target_profile_id'], $payment['id']]);
            } elseif ($paymentDetails['purpose'] === 'subscription') {
                $statement = $pdo->prepare('SELECT id FROM users WHERE id = ? FOR UPDATE');
                $statement->execute([$paymentDetails['user_id']]);
                $statement = $pdo->prepare(
                    'INSERT INTO subscriptions (user_id, payment_id, starts_at, ends_at, status) SELECT ?, ?, GREATEST(UTC_TIMESTAMP(), COALESCE(MAX(ends_at), UTC_TIMESTAMP())), DATE_ADD(GREATEST(UTC_TIMESTAMP(), COALESCE(MAX(ends_at), UTC_TIMESTAMP())), INTERVAL 1 MONTH), \'active\' FROM subscriptions WHERE user_id = ? AND status = \'active\' AND ends_at > UTC_TIMESTAMP()',
                );
                $statement->execute([
                    $paymentDetails['user_id'],
                    $payment['id'],
                    $paymentDetails['user_id'],
                ]);
            }
        }
        $pdo->commit();
        $result = ['reference' => $reference, 'status' => $status, 'provider_status' => $mtnStatus];
        if ($status === 'successful') {
            $statement = $pdo->prepare(
                'SELECT u.phone FROM payments p JOIN worker_profiles wp ON wp.id = p.target_profile_id JOIN users u ON u.id = wp.user_id WHERE p.id = ? AND p.purpose = \'contact_unlock\'',
            );
            $statement->execute([$payment['id']]);
            $contact = $statement->fetchColumn();
            if (is_string($contact)) {
                $result['contact'] = $contact;
            }
        }
        respond(200, $result);
    }

    respond(404, ['error' => 'API route not found.']);
} catch (PDOException $error) {
    error_log('Database request failed: ' . $error->getMessage());
    respond(500, ['error' => 'The database request failed. Check that MySQL is running and the database schema is imported.']);
} catch (PaymentGatewayException $error) {
    respond($error->getCode(), ['error' => $error->getMessage()]);
} catch (Throwable $error) {
    error_log('API request failed: ' . $error->getMessage());
    respond(500, ['error' => 'The server could not complete the request.']);
}
