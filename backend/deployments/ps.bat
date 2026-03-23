adb reverse tcp:8080 tcp:8080

go env -w GOPROXY=https://proxy.golang.org,direct
go env -w GOSUMDB=sum.golang.org

# Download Go dependencies (suppress errors)
go get github.com/gin-gonic/gin@latest 2>$null
go get github.com/gofiber/fiber/v2@latest 2>$null
go get gofr.dev@latest 2>$null
go get github.com/lib/pq@latest 2>$null
go get github.com/joho/godotenv@latest 2>$null
go get github.com/golang-jwt/jwt/v5@latest 2>$null
go mod tidy
go mod verify

# Interactive setup
Write-Host "Setup Backend Database Credentials" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

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

# Create .env file in backend directory (NOT deployments)
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

# Navigate to deployments
cd deployments

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting Docker containers..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# CRITICAL: Stop containers AND DELETE VOLUMES with -v flag
Write-Host "Stopping old containers and DELETING old volumes..." -ForegroundColor Yellow
docker-compose --env-file ../.env down -v 2>&1 | Out-Null

Write-Host "Building and starting fresh containers..." -ForegroundColor Yellow
docker-compose --env-file ../.env up --build -d

# Wait for container to be running
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

# Wait for PostgreSQL to be ready
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

# Verify database connection
Write-Host "`nVerifying database connection..." -ForegroundColor Cyan
$testConn = docker exec flashcards_postgres psql -U $postgresUser -d $postgresDB -c "SELECT 1" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Database connection successful!" -ForegroundColor Green
} else {
    Write-Host "✗ Database connection failed!" -ForegroundColor Red
    Write-Host $testConn
    
}

# Run migrations
Write-Host "`nRunning database migrations..." -ForegroundColor Cyan

# Find migration file
$migrationFile = "../migrations/init_scheme.sql"
if ($migrationFile) {
    Write-Host "Using migration file: $migrationFile" -ForegroundColor Yellow
    
    # Read migration file and execute
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

cd ../..

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✓ SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Check backend is running: docker ps" -ForegroundColor Cyan
Write-Host "2. Test health endpoint: curl http://localhost:8080/health" -ForegroundColor Cyan
Write-Host "3. Check logs: docker logs flashcards_backend" -ForegroundColor Cyan
Write-Host "4. Run Flutter app: cd frontend && flutter run" -ForegroundColor Cyan

docker exec -it flashcards_postgres psql -U $postgresUser -d $postgresDB