# USB Debugging Troubleshooting - "Connection Timed Out" Error

## 🔴 The Problem

```
RegistrationFailed: ClientException with SocketException: 
Connection timed out (OS Error: Connection timed out, errno = 110)
```

This means your phone **cannot reach the backend server** through the network.

---

## ✅ Solution for USB Debugging (Recommended)

When your phone is connected via **USB cable** to your laptop, you need to tunnel the connection through **adb reverse**. This is the most reliable method.

### **Step 1: Verify Backend is Running**

```powershell
# Check Docker containers
docker ps

# You should see: flashcards_backend (Up) and flashcards_postgres (Up)

# If not running, start them:
cd backend/deployments
docker-compose up --build
```

Wait for the message:
```
flashcards_backend     | [GIN-debug] Listening and serving HTTP on :8080
```

### **Step 2: Verify Backend Responds on Localhost**

```powershell
# Test the health endpoint
curl http://localhost:8080/health

# Expected output: {"status":"ok"}
```

**If you get an error**, backend is not accessible. Check Docker logs:
```powershell
docker logs flashcards_backend
```

### **Step 3: Check USB Connection**

```powershell
# List connected devices
adb devices

# You should see your phone listed like:
# 123ABC456DEF     device

# If empty:
# 1. Connect phone via USB cable
# 2. On your phone: Settings → Developer Options → USB Debugging (enable)
# 3. Accept the "Allow debugging?" prompt on your phone
# 4. Run adb devices again
```

### **Step 4: Setup ADB Reverse (CRITICAL)**

```powershell
# This tunnels port 8080 from your phone through the USB cable to your laptop
adb reverse tcp:8080 tcp:8080

# Verify it's configured
adb reverse --list

# Output should show: reverse  tcp:8080  tcp:8080
```

### **Step 5: Update API Config**

Edit **`frontend/lib/core/config/api_config.dart`**:

```dart
class ApiConfig {
  static String host = 'localhost';  // ← MUST BE localhost for USB
  static int port = 8080;
  static String apiPrefix = '/api/v1';
  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
```

✅ **ALREADY DONE** - but verify it's set to `localhost`

### **Step 6: Rebuild and Run**

```powershell
cd frontend

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Run on your phone (connected via USB)
flutter run
```

### **Step 7: Test Registration**

In **separate PowerShell windows**, run:

```powershell
# Window 1: Monitor backend
docker logs -f flashcards_backend

# Window 2: Monitor Flutter
flutter logs

# Window 3: Perform action
# On your phone: Open app → Register → Enter credentials → Tap Register
```

---

## 🆘 Still Getting Timeout? Debugging Steps

### **Debug Step 1: Verify ADB Reverse is Active**

```powershell
adb reverse --list

# If empty, adb reverse was disconnected. Re-run:
adb reverse tcp:8080 tcp:8080

# Note: adb reverse might disconnect if:
# - You unplugged and replugged the USB cable
# - You restarted adb
# - You toggled USB debugging off/on
```

### **Debug Step 2: Test the Connection Manually**

```powershell
# From your laptop, test the backend directly
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/auth/register" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{"email":"test@test.com","username":"testuser","password":"pass123"}'

# If this works but Flutter app fails:
# - Issue is in Flutter app or network_security_config
# If this fails:
# - Issue is in Docker backend
```

### **Debug Step 3: Verify Phone Network Settings**

On your **phone**, open browser and test:
```
http://localhost:8080/health
```

Because of adb reverse, `localhost:8080` on your phone routes through USB to your laptop's port 8080.

If this works in browser but fails in app, the issue is in the Flutter code.

### **Debug Step 4: Check Flutter Code has Correct URL**

```powershell
# Search for hardcoded URLs in Flutter (should find NONE)
grep -r "192.168" frontend\lib

# Search for http:// calls (should use _client.uri only)
grep -r "http.post\|http.get" frontend\lib
```

### **Debug Step 5: Check Network Security Config**

**File:** `frontend/android/app/src/main/res/xml/network_security_config.xml`

Must include `localhost`:
```xml
<domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">localhost</domain>
    <domain includeSubdomains="true">127.0.0.1</domain>
</domain-config>
```

✅ **ALREADY DONE** - Verify it's there

### **Debug Step 6: Restart Everything**

```powershell
# Kill adb
adb kill-server

# Kill Docker
docker-compose -f backend/deployments/docker-compose.yaml down

# Wait 5 seconds
Start-Sleep -Seconds 5

# Start Docker again
cd backend/deployments
docker-compose up --build

# Wait for backend to start (15 seconds)
Start-Sleep -Seconds 15

# Restart adb
adb reverse tcp:8080 tcp:8080

# Verify
adb devices
adb reverse --list

# Build and run Flutter
cd ..\..\frontend
flutter clean
flutter pub get
flutter run
```

---

## 📋 Complete Setup with Automatic Script

I created a PowerShell script to automate all of this. Run it:

```powershell
# From project root
.\setup-usb-debug.ps1 all

# Or step-by-step:
.\setup-usb-debug.ps1 backend   # Start backend
.\setup-usb-debug.ps1 adb       # Setup adb reverse
.\setup-usb-debug.ps1 test      # Test connectivity
.\setup-usb-debug.ps1 build     # Build and run app
```

---

## 🔄 Alternative: WiFi Connection (If USB Doesn't Work)

If USB debugging truly doesn't work, fall back to WiFi:

```powershell
# 1. Get your laptop's local IP
ipconfig

# Find: IPv4 Address (like 192.168.x.x) - but NOT 192.168.240.1 if that's a gateway

# 2. Update api_config.dart
# static String host = '192.168.x.x';  // Your laptop's IP from ipconfig

# 3. Rebuild app
# 4. Phone and laptop on SAME WiFi network

# 5. Test
# adb devices (should show your phone over WiFi)
```

But **USB + adb reverse is more reliable** for development.

---

## 📂 Files Modified

| File | Change |
|------|--------|
| `frontend/lib/core/config/api_config.dart` | `host = 'localhost'` |
| `frontend/android/app/src/main/res/xml/network_security_config.xml` | Added `localhost` domain config |
| `setup-usb-debug.ps1` | NEW - Automatic setup script |

---

## ✨ What Should Happen When Connection Works

1. **On your phone**: Open app, tap "Register Here"
2. **Fill in**: email, username, password
3. **Tap**: "Register"
4. **Backend logs show**: `[GIN] 2026/03/22-... POST /api/v1/auth/register`
5. **Database logs show**: User created
6. **Phone shows**: "Account created successfully!"
7. **Phone navigates to**: Login page
8. **Enter credentials**: From registration
9. **Tap**: "Login"
10. **Phone shows**: "Welcome Back, [username]!"
11. **Phone navigates to**: Home page

---

## 🚀 Quick Copy-Paste Commands

```powershell
# All at once:
docker-compose -f backend/deployments/docker-compose.yaml down
docker-compose -f backend/deployments/docker-compose.yaml up --build -d
Start-Sleep -Seconds 10
adb kill-server
adb start-server
adb devices
adb reverse tcp:8080 tcp:8080
adb reverse --list
curl http://localhost:8080/health
cd frontend
flutter clean
flutter pub get
flutter run
```

Then test registration on your phone!

---

## 📞 If Still Stuck

1. **Check backend is running**: `docker ps` should show both containers UP
2. **Check backend responds**: `curl http://localhost:8080/health`
3. **Check adb is connected**: `adb devices` (should list your phone)
4. **Check adb reverse**: `adb reverse --list` (should show tcp:8080)
5. **Check code**: `api_config.dart` must have `host = 'localhost'`
6. **Check XML**: `network_security_config.xml` must allow localhost
7. **Clean rebuild**: `flutter clean && flutter pub get && flutter run`

If ALL of these pass and it still fails, the issue is likely:
- Your phone's USB debugging mode
- Windows Defender firewall blocking Docker
- Docker network configuration

Check `docker logs flashcards_backend` for exact error!
