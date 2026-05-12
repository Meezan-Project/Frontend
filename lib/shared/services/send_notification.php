<?php
/**
 * FCM HTTP v1 Notification Trigger Script
 * Handles payload requests from Flutter and routes them through Google's v1 API.
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Methods: POST');

// 1. Parse the incoming JSON payload from Flutter
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data || empty($data['token']) || empty($data['title']) || empty($data['body'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameters: token, title, or body']);
    exit;
}

$fcmToken = $data['token'];
$title = $data['title'];
$body = $data['body'];
$customData = isset($data['data']) ? $data['data'] : [];

// 2. Load the Service Account JSON
// IMPORTANT: Download this from Firebase Console -> Project Settings -> Service Accounts
// KEEP THIS FILE SECURE AND OUT OF PUBLIC WEB DIRECTORIES!
$serviceAccountPath = __DIR__ . '/firebase-service-account.json';
if (!file_exists($serviceAccountPath)) {
    http_response_code(500);
    echo json_encode(['error' => 'Service account file not found.']);
    exit;
}
$serviceAccount = json_decode(file_get_contents($serviceAccountPath), true);

// 3. Generate OAuth2 Access Token (Pure PHP using JWT)
function getOAuthToken($serviceAccount)
{
    $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
    $now = time();

    // Generate the JWT claim
    $claim = json_encode([
        'iss' => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $serviceAccount['token_uri'],
        'exp' => $now + 3600, // Token valid for 1 hour
        'iat' => $now
    ]);

    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlClaim = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($claim));
    $signatureInput = $base64UrlHeader . '.' . $base64UrlClaim;

    // Sign the JWT with the private key
    $signature = '';
    openssl_sign($signatureInput, $signature, $serviceAccount['private_key'], 'sha256WithRSAEncryption');
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    $jwt = $signatureInput . '.' . $base64UrlSignature;

    // Exchange JWT for access token via cURL
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $serviceAccount['token_uri']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt
    ]));

    $response = curl_exec($ch);
    curl_close($ch);

    $responseData = json_decode($response, true);
    return $responseData['access_token'] ?? null;
}

$accessToken = getOAuthToken($serviceAccount);
if (!$accessToken) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to generate OAuth token']);
    exit;
}

// 4. Construct the FCM HTTP v1 payload
$projectId = $serviceAccount['project_id'];
$fcmUrl = 'https://fcm.googleapis.com/v1/projects/' . $projectId . '/messages:send';

// FCM v1 strictly requires all 'data' payload values to be strings
$stringifiedData = [];
foreach ($customData as $key => $value) {
    if (is_array($value) || is_object($value)) {
        $stringifiedData[$key] = json_encode($value);
    } else {
        $stringifiedData[$key] = strval($value);
    }
}

$messagePayload = [
    'message' => [
        'token' => $fcmToken,
        'notification' => ['title' => $title, 'body' => $body],
        'data' => (object) $stringifiedData,
        'android' => ['priority' => 'high', 'notification' => ['sound' => 'default']],
        'apns' => ['payload' => ['aps' => ['sound' => 'default']]]
    ]
];

// 5. Send the request to FCM HTTP v1 API
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $fcmUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $accessToken,
    'Content-Type: application/json'
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($messagePayload));

$result = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

// 6. Return response to Flutter
http_response_code($httpCode == 200 ? 200 : $httpCode);
echo $result; // Returns the raw FCM response JSON back to the caller