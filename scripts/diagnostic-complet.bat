@echo off
echo ========================================
echo DIAGNOSTIC COMPLET - Music Ytify
echo ========================================
echo.

echo [1/6] Test Ping VPS...
ping -n 2 100.92.200.92 | findstr "TTL"
if %errorlevel% equ 0 (echo [OK] VPS accessible) else (echo [ERREUR] VPS inaccessible)
echo.

echo [2/6] Test DNS Resolution...
nslookup music.ml4-lab.com 8.8.8.8 | findstr "Address"
echo.

echo [3/6] Test HTTP Direct VPS...
curl -I http://100.92.200.92/ -H "Host: ytify.ml4-lab.com" --max-time 5 2>&1 | findstr "HTTP"
echo.

echo [4/6] Test HTTPS music.ml4-lab.com...
curl -I https://music.ml4-lab.com/ --max-time 10 2>&1 | findstr /C:"HTTP" /C:"Could not"
echo.

echo [5/6] Verification CSP Header...
curl -I https://music.ml4-lab.com/ --max-time 10 2>&1 | findstr /i "content-security-policy"
echo.

echo [6/6] Test Cloudflare Status...
curl -I https://music.ml4-lab.com/ --max-time 10 2>&1 | findstr /i "cf-"
echo.

echo ========================================
echo DIAGNOSTIC TERMINE
echo ========================================
echo.
echo Copiez TOUT ce qui est au-dessus et envoyez-le moi.
echo.
pause
