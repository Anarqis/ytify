# 🔧 Solution Rapide - Problème de Fetch

**Diagnostic:** Le site est accessible via Cloudflare, mais il y a un problème de fetch. La cause la plus probable est le **timeout de 10s** pour fetcher Uma ou un problème avec l'auto-fetch du Hub.

---

## Solution 1: Réduire le Timeout Uma (RECOMMANDÉ)

Le timeout de 10 secondes est trop long et peut causer des problèmes.

### Fichier: `src/lib/utils/pure.ts`

**Ligne 31 - Changez:**
```typescript
const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout
```

**En:**
```typescript
const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout
```

---

## Solution 2: Désactiver Temporairement l'Auto-Fetch du Hub

Si le Hub cause des boucles de fetch:

### Fichier: `src/features/Home/Hub.tsx`

**Lignes 27-35 - Commentez:**
```typescript
// Auto-fetch subfeed if empty on mount
// TEMPORAIREMENT DÉSACTIVÉ POUR DEBUG
/*
onMount(() => {
  if (!subfeed() || subfeed()?.length === 0) {
    handleSubfeedRefresh();
  }
  if (!gallery().userArtists?.length && !gallery().relatedArtists?.length && !gallery().relatedPlaylists?.length) {
    handleGalleryRefresh();
  }
});
*/
```

---

## Solution 3: Ajouter Plus de Logs pour Debug

### Fichier: `src/lib/utils/pure.ts`

**Après la ligne 55, ajoutez:**
```typescript
const instances = decompressedString.split(',')
  .map(i => `https://${i}`)
  .filter(instance => !BLACKLISTED_INSTANCES.some(blocked => instance.includes(blocked)));

// DEBUG: Log les instances filtrées
console.log(`[Uma] Fetched ${instances.length} instances after filtering`);
console.log('[Uma] Blacklisted:', BLACKLISTED_INSTANCES);

return instances.length > 0 ? instances : FALLBACK_INSTANCES;
```

---

## Rebuild & Deploy Rapide

Après avoir appliqué UNE des solutions ci-dessus:

```bash
cd "c:\Users\Utilisateur\Documents\ML4_Lab-We craft-You thrive\App\Music_ytify"
npm run build
bash scripts/deploy-quick.sh
```

---

## Alternative: Rollback Complet

Si vous voulez revenir en arrière temporairement:

```bash
# Annuler tous les changements
git checkout HEAD -- src/features/Home/Hub.tsx
git checkout HEAD -- src/lib/utils/pure.ts

# Rebuild et deploy
npm run build
bash scripts/deploy-quick.sh
```

---

## Quelle Solution Choisir?

- **Si vous voyez "Uma fetch error" dans la console:** → Solution 1 (réduire timeout)
- **Si le Hub charge infiniment:** → Solution 2 (désactiver auto-fetch)
- **Si vous ne savez pas exactement:** → Solution 3 (ajouter logs) puis rechargez la page
- **Si vous voulez être sûr:** → Rollback complet

---

## Info Technique

**État actuel détecté:**
- ✅ Site accessible via Cloudflare (IPs: 104.21.20.187, 172.67.194.17)
- ✅ DNS fonctionne (via Google DNS 8.8.8.8)
- ✅ Redirection HTTP → HTTPS active
- ✅ Code déployé sur le VPS

**Le problème n'est PAS:**
- ❌ DNS down
- ❌ Site inaccessible
- ❌ Nginx configuration (déjà déployée)

**Le problème est probablement:**
- ⚠️ Timeout Uma trop long (10s)
- ⚠️ Auto-fetch du Hub créant des requêtes multiples
- ⚠️ Instances Invidious temporairement down

---

**Créé:** 2026-02-09 21:25
**Priorité:** Haute
