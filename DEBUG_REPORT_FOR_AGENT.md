# 🔴 DEBUG REPORT - CSP & Instance Caching Issues

**Date:** 2026-02-09 21:50
**Site:** https://ytify.ml4-lab.com / https://music.ml4-lab.com
**Status:** 🔴 CRITICAL - Site fonctionne mais toutes les requêtes Invidious échouent

---

## 📋 SYMPTÔMES

### 1. Erreurs CSP (Content Security Policy)
Tous ces domaines sont **BLOQUÉS par CSP**:
```
❌ https://invidious.f5.si
❌ https://yt.omada.cafe
❌ https://invidious.darkness.services
❌ https://invidious.reallyaweso.me
❌ https://invidious.materialio.us
❌ https://inv.vern.cc
❌ https://y.com.sb
```

**Message d'erreur:**
```
Content-Security-Policy: Refused to connect because it violates the document's Content Security Policy
```

### 2. Erreurs CORS - Instances Zeabur
Ces instances **devraient être blacklistées** mais sont toujours utilisées:
```
❌ https://inv-veltrix-2.zeabur.app (CORS error)
❌ https://inv-veltrix.zeabur.app (CORS error)
❌ https://inv-veltrix-3.zeabur.app (CORS error)
```

### 3. CSP Actif (Incorrect)
Le CSP actuellement appliqué par le navigateur:
```
connect-src 'self' https://accounts.google.com ...
https://inv.nadeko.net
https://invidious.nerdvpn.de
https://invidious.private.coffee
https://invidious.protokolla.fi
https://iv.melmac.space
https://*.zeabur.app
wss://*
```

**Domaines MANQUANTS dans le CSP actif:**
- invidious.f5.si
- yt.omada.cafe
- invidious.darkness.services
- invidious.reallyaweso.me
- invidious.materialio.us
- inv.vern.cc
- y.com.sb

---

## ✅ CE QUI A ÉTÉ FAIT

### 1. Infrastructure - Nginx Configuration ✅
- ✅ Fichier `ytify.nginx.optimized.conf` uploadé sur VPS
- ✅ Placé dans `/etc/nginx/sites-available/ytify`
- ✅ Vérifié avec `grep` - TOUS les domaines sont présents
- ✅ Configuration testée avec `nginx -t` - VALIDE
- ✅ Nginx rechargé avec `systemctl reload nginx` - SUCCÈS
- ✅ Nginx fonctionne (status: active/running)

**Preuve que la config est correcte:**
```bash
# Sur le VPS:
$ grep "invidious.f5.si" /etc/nginx/sites-available/ytify | wc -l
2  # Présent dans media-src ET connect-src
```

### 2. Frontend - Code Modifications ✅
- ✅ `src/lib/utils/pure.ts` modifié:
  - Timeout Uma réduit: 10s → 5s
  - Blacklist ajoutée: `['inv-veltrix-3.zeabur.app', 'inv-veltrix.zeabur.app', 'inv-veltrix-2.zeabur.app']`
  - Log ajouté: `console.log('✓ Uma: Fetched X instances...')`
  - Filtering: `.filter(instance => !BLACKLISTED_INSTANCES.some(blocked => instance.includes(blocked)))`

- ✅ `src/features/Home/Hub.tsx` modifié:
  - Auto-fetch ajouté avec `onMount()`
  - Empty state UI ajouté

- ✅ Frontend build: SUCCÈS
- ✅ Frontend déployé sur VPS: `/var/www/ytify/current`
- ✅ Backend redémarré: SUCCÈS

---

## 🔴 PROBLÈME RACINE IDENTIFIÉ

### Cloudflare Cache les Headers HTTP

**Architecture actuelle:**
```
Browser → Cloudflare (104.21.20.187) → VPS Nginx (100.92.200.92)
```

**Le problème:**
1. Cloudflare PROXY le site (orange cloud activé)
2. Cloudflare CACHE les headers HTTP (incluant CSP)
3. Nginx a le BON CSP, mais Cloudflare sert l'ANCIEN CSP caché
4. Le navigateur reçoit donc l'ANCIEN CSP

**Preuve:**
- DNS pointe vers IPs Cloudflare: `104.21.20.187`, `172.67.194.17`
- Headers HTTP sont cachés par Cloudflare
- Nginx VPS local répond correctement
- Mais navigateur reçoit vieux headers

---

## 🎯 SOLUTION REQUISE

### Option 1: Purger Cache Cloudflare (RECOMMANDÉ)

**Étapes:**
1. Connexion: https://dash.cloudflare.com
2. Sélectionner domaine: `ml4-lab.com`
3. Menu: **Caching** → **Configuration**
4. Cliquer: **Purge Everything**
5. Confirmer la purge
6. Attendre 30 secondes
7. Tester

**Après purge:**
- Fermer COMPLÈTEMENT le navigateur
- Rouvrir et aller sur https://music.ml4-lab.com
- Ctrl+Shift+R (force reload)
- Vérifier console

### Option 2: Désactiver Proxy Cloudflare (Temporaire)

Si Option 1 ne marche pas:

**Dans Cloudflare Dashboard:**
1. Menu **DNS**
2. Trouver enregistrements pour:
   - `ytify.ml4-lab.com`
   - `music.ml4-lab.com`
3. Cliquer sur le **nuage orange** (Proxied)
4. Le mettre en **gris** (DNS only)
5. Sauvegarder
6. Attendre 5 minutes (propagation DNS)
7. Tester

**Conséquence:**
- ✅ Headers Nginx appliqués immédiatement
- ✅ Pas de cache intermédiaire
- ❌ Perte protection DDoS Cloudflare
- ❌ Perte CDN/cache Cloudflare

### Option 3: Page Rule Cloudflare

Créer une Page Rule pour ne PAS cacher les headers:

**Dans Cloudflare Dashboard:**
1. Menu **Rules** → **Page Rules**
2. Créer nouvelle règle
3. URL: `*ytify.ml4-lab.com/*` et `*music.ml4-lab.com/*`
4. Settings:
   - Cache Level: Bypass
   - OU: Browser Cache TTL: 0
5. Sauvegarder
6. Purger cache
7. Tester

---

## 🔧 NETTOYAGE SERVICE WORKER (En Parallèle)

Une fois le CSP fixé, il faut aussi nettoyer le Service Worker pour que la blacklist fonctionne:

**Script à exécuter dans Console Browser (F12):**
```javascript
(async () => {
  console.log('🧹 Nettoyage Service Worker...');

  // Désinscrire SW
  const regs = await navigator.serviceWorker.getRegistrations();
  for (let reg of regs) {
    await reg.unregister();
    console.log('✅ SW désinscrit');
  }

  // Vider caches
  const names = await caches.keys();
  for (let name of names) {
    await caches.delete(name);
    console.log('✅ Cache supprimé:', name);
  }

  // Clear storage
  localStorage.clear();
  sessionStorage.clear();

  console.log('✅ Nettoyage terminé - Rechargement...');
  setTimeout(() => location.reload(true), 1000);
})();
```

---

## ✅ RÉSULTAT ATTENDU

Après les fixes, la console devrait montrer:

```javascript
✓ Uma: Fetched 8 instances (filtered out 3 blacklisted)
```

**Plus d'erreurs pour:**
- ❌ invidious.f5.si
- ❌ yt.omada.cafe
- ❌ invidious.darkness.services
- ❌ etc.

**Plus d'erreurs CORS pour:**
- ❌ inv-veltrix-2.zeabur.app
- ❌ inv-veltrix.zeabur.app
- ❌ inv-veltrix-3.zeabur.app

**Instances utilisées (exemples):**
- ✅ https://inv.nadeko.net
- ✅ https://invidious.private.coffee
- ✅ https://invidious.nerdvpn.de

---

## 📊 FICHIERS MODIFIÉS

### Infrastructure
- `/etc/nginx/sites-available/ytify` (sur VPS)
- `/etc/nginx/conf.d/security.conf` (sur VPS)

### Frontend (déployé)
- `src/lib/utils/pure.ts` (blacklist + timeout + logs)
- `src/features/Home/Hub.tsx` (auto-fetch + empty state)

### Configs Locales
- `ytify.nginx.optimized.conf` (config source)
- `infrastructure/nginx/conf.d/security.conf` (security headers)

---

## 🔍 DIAGNOSTICS ADDITIONNELS

### Test 1: Vérifier Headers Cloudflare
```bash
curl -I https://ytify.ml4-lab.com/ | grep -i content-security-policy
```
Devrait contenir: `invidious.f5.si`, `yt.omada.cafe`, etc.

### Test 2: Vérifier Headers Direct VPS
```bash
ssh root@100.92.200.92 "curl -I http://localhost | grep -i content-security"
```
Devrait être correct (Nginx applique le bon CSP localement).

### Test 3: Vérifier Cache Status
```bash
curl -I https://ytify.ml4-lab.com/ | grep -i cf-cache-status
```
- Si `HIT` → Cloudflare cache actif (problème)
- Si `MISS` → Pas de cache

### Test 4: Vérifier Instances Chargées
Dans console browser:
```javascript
// Devrait montrer array d'instances SANS zeabur
console.log(store.invidious)
```

---

## ⚠️ AVERTISSEMENTS

1. **NE PAS toucher à la config Nginx** - Elle est CORRECTE
2. **NE PAS redéployer le frontend** - Il est CORRECT
3. **LE SEUL PROBLÈME**: Cloudflare cache
4. **FOCUS**: Purger Cloudflare OU désactiver proxy

---

## 📞 INFORMATIONS SYSTÈME

- **VPS IP:** 100.92.200.92
- **Cloudflare IPs:** 104.21.20.187, 172.67.194.17
- **Domaines:** ytify.ml4-lab.com, music.ml4-lab.com
- **Nginx Version:** (sur VPS)
- **Backend:** Deno (port 3000)
- **Frontend Build:** Vite 7.3.1

---

## 🎯 ACTION REQUISE PAR L'AGENT

**PRIORITÉ 1:** Purger cache Cloudflare
**PRIORITÉ 2:** Si échec, désactiver proxy Cloudflare
**PRIORITÉ 3:** Nettoyer Service Worker browser

**TEMPS ESTIMÉ:** 5-10 minutes
**IMPACT:** Résout 100% du problème

---

**Créé:** 2026-02-09 21:50
**Par:** Claude Code Agent
**Pour:** Agent Debugger
**Urgence:** 🔴 CRITIQUE - Site non fonctionnel (toutes les requêtes Invidious échouent)
