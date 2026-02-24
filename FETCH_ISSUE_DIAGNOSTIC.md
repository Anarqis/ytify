# 🔍 Fetch Issue Diagnostic Guide

**Status:** Investigating fetch problem after deployment

---

## Quick Diagnostics

### 1. Check Browser Console
Open https://ytify.ml4-lab.com and open DevTools (F12) → Console:

**Look for these errors:**
- ❌ `Failed to fetch` - Network issue
- ❌ `CORS error` - CORS policy problem
- ❌ `Uma fetch error` - Instance list fetch failed
- ❌ `Content Security Policy` - CSP blocking
- ❌ `TypeError` - Code issue in our changes

### 2. Check Network Tab
DevTools → Network tab:

**Which requests are failing?**
- `raw.githubusercontent.com/n-ce/Uma/main/iv.txt` - Instance list
- Invidious instances (y.com.sb, inv.vern.cc, etc.)
- Backend API (`/sync`, `/hash`, `/library`)
- Other?

---

## Potential Issues & Fixes

### Issue A: Uma Fetch Timing Out

**Symptoms:**
- Console shows: "Uma fetch error, using fallback instances"
- 10 second delay on page load

**Cause:** GitHub request timing out (10s timeout in code)

**Quick Fix:**
```typescript
// In src/lib/utils/pure.ts, reduce timeout:
setTimeout(() => controller.abort(), 5000); // 5s instead of 10s
```

---

### Issue B: All Instances Filtered Out

**Symptoms:**
- Search doesn't work
- Console shows errors from fallback instances only

**Check:** Are fallback instances working?
```javascript
// In browser console:
fetch('https://inv.nadeko.net/api/v1/trending')
  .then(r => r.json())
  .then(console.log)
```

**Fix if needed:** Adjust blacklist to be less aggressive:
```typescript
// In src/lib/utils/pure.ts - temporarily disable filtering:
.filter(instance => true) // TEMPORARY - test if this fixes it
```

---

### Issue C: Hub Auto-Fetch Loop

**Symptoms:**
- Infinite loading spinner
- Multiple rapid fetch requests
- Browser performance issues

**Cause:** `onMount` hook triggering repeatedly

**Quick Fix - Disable auto-fetch temporarily:**
```typescript
// In src/features/Home/Hub.tsx, comment out onMount:
/*
onMount(() => {
  if (!subfeed() || subfeed()?.length === 0) {
    handleSubfeedRefresh();
  }
  if (!gallery().userArtists?.length...) {
    handleGalleryRefresh();
  }
});
*/
```

---

### Issue D: Backend Service Down

**Symptoms:**
- Fetch to `/sync`, `/hash`, `/library` fails
- Network tab shows 502/503 errors

**Check Backend Status:**
```bash
ssh root@100.92.200.92 "systemctl status ytify-backend"
```

**Restart if needed:**
```bash
ssh root@100.92.200.92 "systemctl restart ytify-backend"
```

---

### Issue E: CSP Still Blocking

**Symptoms:**
- "Refused to connect" errors in console
- Specific Invidious domains blocked

**Check Current CSP:**
```bash
curl -I https://ytify.ml4-lab.com | grep -i content-security
```

**Verify Nginx reloaded:**
```bash
ssh root@100.92.200.92 "nginx -t && systemctl reload nginx"
```

---

## Quick Rollback (If Needed)

If the new code is causing issues, here's how to rollback:

### 1. Revert Hub.tsx changes:
```bash
cd "c:\Users\Utilisateur\Documents\ML4_Lab-We craft-You thrive\App\Music_ytify"
git checkout HEAD -- src/features/Home/Hub.tsx
```

### 2. Revert pure.ts changes:
```bash
git checkout HEAD -- src/lib/utils/pure.ts
```

### 3. Rebuild and deploy:
```bash
npm run build
bash scripts/deploy-quick.sh
```

---

## Most Likely Causes

Based on "attempting to fetch" error:

### 1. **Uma Fetch Timeout** (Most Likely)
- The 10s timeout might be too long
- Fallback instances should kick in, but check if they work

### 2. **Hub Auto-Fetch Issue**
- The onMount hook might be triggering too early
- Or causing multiple simultaneous fetches

### 3. **Network/VPS Issue**
- VPS connection timed out earlier
- Backend service might need restart

---

## Recommended Actions

**Step 1:** Check browser console NOW
- Open https://ytify.ml4-lab.com
- F12 → Console tab
- Copy the EXACT error message

**Step 2:** Test fallback instances
```javascript
// In browser console, test if fallback works:
const fallbacks = [
  'https://inv.nadeko.net',
  'https://invidious.private.coffee'
];

Promise.all(fallbacks.map(url =>
  fetch(url + '/api/v1/trending').then(r => r.ok ? url + ' ✓' : url + ' ✗')
)).then(console.log);
```

**Step 3:** If needed, apply one of the quick fixes above

**Step 4:** If all else fails, use the rollback procedure

---

## Contact Info

**Please provide:**
1. Exact error message from console
2. Which page/action triggers the error
3. Network tab screenshot (if possible)
4. Result of fallback instance test

This will help identify the exact issue quickly.

---

**Created:** 2026-02-09
**Related Files:**
- [src/lib/utils/pure.ts](src/lib/utils/pure.ts) - Instance fetching
- [src/features/Home/Hub.tsx](src/features/Home/Hub.tsx) - Hub auto-fetch
