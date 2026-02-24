# 🔧 Nettoyer Service Worker & Cache

## Problème

Le Service Worker (sw-custom.js) cache l'ancienne liste d'instances Invidious, donc `inv-veltrix-2.zeabur.app` est toujours utilisé même après le déploiement.

---

## Solution 1: Désactiver/Réinitialiser Service Worker (RAPIDE)

### Dans Chrome/Edge:

1. **Ouvrez DevTools** (F12)
2. Allez dans **Application** (ou **Stockage**)
3. Dans le menu gauche, section **Application**:
   - Cliquez sur **Service Workers**
4. Vous devriez voir `sw-custom.js`
5. Cliquez sur **Unregister** (Désinscrire)
6. Cliquez sur **Clear storage** (Effacer le stockage)
7. Cochez toutes les cases:
   - ✅ Unregister service workers
   - ✅ Local and session storage
   - ✅ IndexedDB
   - ✅ Cache storage
8. Cliquez **Clear site data**
9. **Rechargez la page** (F5)

### Vérification:
- Le Service Worker devrait se ré-enregistrer automatiquement
- La nouvelle version du code sera chargée
- Cherchez dans Console: `✓ Uma: Fetched X instances (filtered out 3 blacklisted)`

---

## Solution 2: Hard Refresh Complet

```
Ctrl + Shift + Delete
```

1. Sélectionnez **Tout le temps**
2. Cochez:
   - ✅ Cookies et données de sites
   - ✅ Images et fichiers en cache
3. Cliquez **Effacer les données**
4. Fermez et rouvrez le navigateur
5. Allez sur https://music.ml4-lab.com

---

## Solution 3: Mode Incognito (Test Rapide)

Pour vérifier que le nouveau code fonctionne:

1. **Ctrl + Shift + N** (mode incognito)
2. Allez sur https://music.ml4-lab.com
3. F12 → Console
4. Cherchez: `✓ Uma: Fetched X instances`

Si ça marche en incognito → Le problème est bien le cache!

---

## Solution 4: Forcer Mise à Jour Service Worker (Code)

Si le problème persiste, on peut forcer la mise à jour du SW:

### Option A: Augmenter la version PWA

Éditez `vite.config.ts`:

```typescript
VitePWA({
  // ... existing config
  workbox: {
    // Force update
    skipWaiting: true,
    clientsClaim: true,
  }
})
```

Rebuild et redeploy.

### Option B: Changer le nom du Service Worker

Dans `src/lib/workers/sw-custom.ts`, ajoutez un commentaire en haut:

```typescript
// Version: 2.0.1 - Fixed instance blacklist
```

Cela change le hash du fichier, forçant le navigateur à recharger.

---

## Diagnostic

### Vérifier quelle instance est utilisée en premier:

Console browser:
```javascript
// Voir les instances chargées
console.log(store.invidious)
```

Devrait montrer un array SANS les instances zeabur:
```javascript
// ❌ NE DEVRAIT PAS contenir:
"https://inv-veltrix-2.zeabur.app"
"https://inv-veltrix.zeabur.app"
"https://inv-veltrix-3.zeabur.app"
```

---

## Pourquoi le Service Worker Pose Problème?

Le Service Worker cache:
1. **Les réponses API** (instances Invidious)
2. **Le code JavaScript** (y compris la liste d'instances)
3. **Les assets statiques**

Quand on déploie une nouvelle version:
- Le frontend est mis à jour ✅
- **MAIS** le Service Worker continue d'utiliser son cache ❌

**Solution:** Il faut vider le cache du Service Worker!

---

## Commandes Rapides

### Chrome DevTools Protocol (Pour purger le cache programmatiquement):

Ouvrez Console et exécutez:

```javascript
// Désinscrire tous les Service Workers
navigator.serviceWorker.getRegistrations().then(function(registrations) {
  for(let registration of registrations) {
    registration.unregister();
    console.log('SW désinscrit:', registration);
  }
});

// Vider tous les caches
caches.keys().then(function(names) {
  for (let name of names) {
    caches.delete(name);
    console.log('Cache supprimé:', name);
  }
});

// Recharger
location.reload(true);
```

---

## Après le Nettoyage

### ✅ Vous devriez voir:

1. Console:
   ```
   ✓ Uma: Fetched 8 instances (filtered out 3 blacklisted)
   ```

2. **AUCUNE erreur CORS** de zeabur.app

3. Les tentatives utilisent d'autres instances:
   ```
   Instance 0 (https://inv.nadeko.net) trying...
   Instance 1 (https://invidious.private.coffee) trying...
   ```

### ❌ Si vous voyez encore:

```
Instance 0 (https://inv-veltrix-2.zeabur.app) failed
```

→ Le Service Worker n'est pas nettoyé, recommencez la Solution 1.

---

## Notes Importantes

1. **music.ml4-lab.com vs ytify.ml4-lab.com**
   - Les deux domaines ont des caches SÉPARÉS
   - Nettoyez le cache sur les DEUX domaines si vous utilisez les deux

2. **Mobile vs Desktop**
   - Si vous testez sur mobile, videz aussi le cache mobile

3. **Différents navigateurs**
   - Chrome, Firefox, Safari ont des caches séparés
   - Testez dans un seul navigateur d'abord

---

**ACTION IMMÉDIATE:**

1. F12 → Application → Service Workers → **Unregister**
2. Application → Storage → **Clear site data**
3. Rechargez la page
4. Vérifiez console: `✓ Uma: Fetched X instances`

**Temps:** 1-2 minutes
**Impact:** Résout le problème des instances zeabur!
