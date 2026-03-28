adb reverse tcp:8080 tcp:8080

go env -w GOPROXY=https://proxy.golang.org,direct
go env -w GOSUMDB=sum.golang.org

go get github.com/gin-gonic/gin@latest
go get github.com/gofiber/fiber/v2@latest
go get gofr.dev@latest
go get github.com/lib/pq@latest
go get github.com/joho/godotenv@latest
go get github.com/golang-jwt/jwt/v5@latest
go mod tidy
go mod verify

$postgresUser = Read-Host "PostgreSQL Username (default: postgres)"
if ([string]::IsNullOrWhiteSpace($postgresUser)) { $postgresUser = "postgres" }

$postgresPassword = Read-Host "PostgreSQL Password (default: postgres)" -AsSecureString
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($postgresPassword))
if ([string]::IsNullOrWhiteSpace($plainPassword)) { $plainPassword = "postgres" }

$postgresDB = Read-Host "PostgreSQL Database name (default: flashcards)"
if ([string]::IsNullOrWhiteSpace($postgresDB)) { $postgresDB = "flashcards" }

$jwtSecret = Read-Host "JWT Secret (default: your-secret-key-change-in-production)" -AsSecureString
$plainJwtSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($jwtSecret))
if ([string]::IsNullOrWhiteSpace($plainJwtSecret)) { $plainJwtSecret = "your-secret-key-change-in-production" }

$envContent = @"
POSTGRES_USER=$postgresUser
POSTGRES_PASSWORD=$plainPassword
POSTGRES_DB=$postgresDB

PORT=8080

DB_HOST=postgres
DB_PORT=5433
GO_POST=5432
DB_USER=$postgresUser
DB_PASSWORD=$plainPassword
DB_NAME=$postgresDB
DB_SSLMODE=disable

JWT_SECRET=$plainJwtSecret
JWT_EXPIRY_MINUTES=120
"@

Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
Set-Content -Path ".env" -Value $envContent
Write-Host "✓ .env file created in backend/" -ForegroundColor Green

Write-Host "`n.env file contents:" -ForegroundColor Yellow
Get-Content .env

Write-Host "Stopping old containers and DELETING old volumes..." -ForegroundColor Yellow
docker compose  down -v --remove-orphans
docker system prune -a -f

Write-Host "Building and starting fresh containers..." -ForegroundColor Yellow
docker compose up --build -d

Write-Host "`nWaiting for PostgreSQL container to start..." -ForegroundColor Cyan
$containerReady = $false
for ($i = 1; $i -le 20; $i++) {
    $running = docker ps --filter "name=flashcards_postgres" --format "{{.Status}}"
    if ($running) {
        Write-Host "✓ Container is running: $running" -ForegroundColor Green
        $containerReady = $true
        break
    }
    Write-Host "  Attempt $i/20..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if (-not $containerReady) {
    Write-Host "✗ Container failed to start!" -ForegroundColor Red
    docker logs flashcards_postgres
    exit 1
}

Write-Host "`nWaiting for PostgreSQL to accept connections..." -ForegroundColor Cyan
$dbReady = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $result = docker exec flashcards_postgres pg_isready -U $postgresUser -d $postgresDB 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ PostgreSQL is ready!" -ForegroundColor Green
            $dbReady = $true
            break
        }
    } catch {
        # Ignore error, continue trying
    }
    Write-Host "  Attempt $i/30..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if (-not $dbReady) {
    Write-Host "✗ PostgreSQL failed to become ready!" -ForegroundColor Red
    Write-Host "`nPostgreSQL logs:" -ForegroundColor Red
    docker logs flashcards_postgres
    
}

Write-Host "`nVerifying database connection..." -ForegroundColor Cyan
$testConn = docker exec flashcards_postgres psql -U $postgresUser -d $postgresDB -c "SELECT 1" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Database connection successful!" -ForegroundColor Green
} else {
    Write-Host "✗ Database connection failed!" -ForegroundColor Red
    Write-Host $testConn
    
}

Write-Host "`nRunning database migrations..." -ForegroundColor Cyan

$migrationFile = "../migrations/01. init.sql"
if ($migrationFile) {
    Write-Host "Using migration file: $migrationFile" -ForegroundColor Yellow
    $migrationContent = Get-Content $migrationFile -Raw
    $migrationContent | docker exec -i flashcards_postgres psql -U $postgresUser -d $postgresDB

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Migrations completed!" -ForegroundColor Green
    } else {
        Write-Host "⚠ Migrations completed with warnings. Check logs above." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ No migration file found. Skipping migrations." -ForegroundColor Yellow
    Write-Host "Available files in migrations/:" -ForegroundColor YellowUsage
    ls ../migrations/
}

docker exec -it flashcards_postgres psql -U $postgresUser -d $postgresDB