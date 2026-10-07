param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9.-]+$')]
    [string]$SiteDomain
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$siteDomain = $SiteDomain.ToLowerInvariant()
$apiUrl = "https://$siteDomain/api"

Push-Location $projectRoot
try {
    flutter build web --release --base-href / "--dart-define=API_BASE_URL=$apiUrl"
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter web build failed with exit code $LASTEXITCODE."
    }

    $webOutput = Join-Path $projectRoot 'build_local\web'
    if (-not (Test-Path (Join-Path $webOutput 'index.html'))) {
        $webOutput = Join-Path $projectRoot 'build\web'
    }
    if (-not (Test-Path (Join-Path $webOutput 'index.html'))) {
        throw 'Flutter completed without producing a web index.html.'
    }

    $packageRoot = Join-Path $projectRoot "build_local\infinityfree-$siteDomain"
    if (Test-Path $packageRoot) {
        throw "Output folder already exists; move or rename it before rebuilding: $packageRoot"
    }

    $htdocs = Join-Path $packageRoot 'htdocs'
    $apiDirectory = Join-Path $htdocs 'api'
    $accountRoot = Join-Path $packageRoot 'account-root'
    $databaseDirectory = Join-Path $packageRoot 'database'
    New-Item -ItemType Directory -Path $apiDirectory, $accountRoot, $databaseDirectory -Force | Out-Null

    Copy-Item (Join-Path $webOutput '*') $htdocs -Recurse -Force
    Copy-Item (Join-Path $projectRoot 'backend\public\.htaccess') (Join-Path $htdocs '.htaccess')
    Copy-Item (Join-Path $projectRoot 'backend\public\api\index.php') (Join-Path $apiDirectory 'index.php')
    Copy-Item (Join-Path $projectRoot 'backend\.env.example') (Join-Path $accountRoot '.env.example')
    Copy-Item (Join-Path $projectRoot 'backend\database\schema.sql') (Join-Path $databaseDirectory 'schema.sql')

    Write-Output "Deployment package prepared at: $packageRoot"
    Write-Output "Upload the CONTENTS of htdocs to the hosting site's htdocs directory."
    Write-Output 'Import database/schema.sql using the hosting provider database panel.'
    Write-Output 'Copy account-root/.env.example to /home/<account>/.env and fill in private database credentials.'
    Write-Output "Flutter API URL embedded in this build: $apiUrl"
}
finally {
    Pop-Location
}
