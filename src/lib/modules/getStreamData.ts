<<<<<<< HEAD
import { store, setStore } from "../stores";
import { fetchWithRetry } from "@lib/utils/fetch";
=======
import { playerStore, setPlayerStore } from '@stores';
import { streamCache, shuffle } from '@utils';

const instances = shuffle([
 "https://yt.omada.cafe",
 "https://invidious.schenkel.eti.br",
 "https://invidious.kemonomimi.nl"
]);
>>>>>>> upstream/main

export default function(
  id: string,
  signal?: AbortSignal
): Promise<Invidious | Record<'error' | 'message', string>> {

<<<<<<< HEAD
  const tryFetch = (instance: string): Promise<Invidious> => {
    const url = `${instance}/api/v1/videos/${id}`;
    return fetchWithRetry(url, {
      signal,
      timeout: prefetch ? 5000 : 10000,
      maxRetries: prefetch ? 0 : 1
    })
      .then(response => response.json() as Promise<Invidious | { error: string }>)
      .then(data => {
        if ('adaptiveFormats' in data) return data;
        throw new Error((data as Record<string, string>).error || 'Invalid response structure');
      });
  };

  // Guard: bail out if no instances are available
  if (!store.invidious.length) {
    return Promise.resolve({
      error: 'No Invidious instances available',
      message: 'Could not fetch stream data — no instances configured'
    });
  }

  // 1. Try current instance first
  const currentIndex = store.index;
  const currentInstance = store.invidious[currentIndex];

  return tryFetch(currentInstance)
    .catch((e) => {
      console.warn(`Instance ${currentIndex} (${currentInstance}) failed:`, e);

      // 2. Build list of remaining instances (skip current)
      const remaining = store.invidious
        .map((inst, idx) => ({ inst, idx }))
        .filter(({ idx }) => idx !== currentIndex);

      // 3. Try each remaining instance sequentially
      return remaining.reduce<Promise<Invidious>>(
        (chain, { inst, idx }) =>
          chain.catch(() => {
            console.warn(`Trying fallback instance ${idx} (${inst})...`);
            return tryFetch(inst).then(data => {
              // Update preferred instance on success
              setStore('index', idx);
              return data;
            });
          }),
        Promise.reject(e)
      );
    })
    .catch((e) => {
      // 4. Last resort: try VPS local proxy
      console.warn('All Invidious instances failed, trying local proxy...', e);
      return tryFetch(window.location.origin)
        .catch(() => ({
          error: 'All Invidious instances failed',
          message: 'Could not fetch stream data'
        }));
    });
=======
  const fetchData = async (proxy: string): Promise<Invidious> => {
    const path = proxy ? '/api/v1/videos/' : '/s/';
    const res = await fetch(proxy + path + id, {
      headers: { 'Accept': 'application/json' },
      signal
    });
    if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
    const data = await res.json();

    if (!data || !('adaptiveFormats' in data) || !Array.isArray(data.adaptiveFormats)) {
      throw new Error(data?.error || 'Invalid response: adaptiveFormats missing or not an array');
    }

    if (!data.adaptiveFormats.every((f: { type: string }) => typeof f.type === 'string')) {
      throw new Error('Invalid response: formats missing type property');
    }

    if (!data.adaptiveFormats.some((f: { type: string }) => f.type.startsWith('audio'))) {
      throw new Error('Invalid response: no audio streams found');
    }

    return data;
  };

  async function getData() {
    // 1. Try current proxy first if available
    if (playerStore.proxy) {
      const p = playerStore.proxy || instances[0];
      try {
        const data = await fetchData(p);
        data.proxy = p;
        return data;
      } catch (e) {
        console.warn(`Prefetch failed with error ${(e as Error).message} on ${p}, starting retries...`);
      }
    }

    // 2. One by one retry through all instances
    for (const proxy of instances) {
      if (proxy === playerStore.proxy) continue;
      try {
        const data = await fetchData(proxy);
        data.proxy = proxy;
        return data;
      } catch (e) {
        console.warn(`Proxy ${proxy} failed, trying next...`);
      }
    }

    // 3. Last resort: Emergency Fallback (Local Edge Function)
    try {
      console.warn('All proxies failed, attempting emergency fallback...');
      const data = await fetchData('');
      data.proxy = '';
      // reset proxy to use local fallback
      return data;
    } catch (e) {
      console.error('Emergency fallback failed:', e);
    }
  }
  const cached = streamCache.get(id) as Invidious;

  const data = cached || await getData();

  if (data) {
    streamCache.set(id, data);
    setPlayerStore('proxy', data.proxy || '');
    return data;
  }

  return { error: 'All proxies failed', message: 'Failed to fetch stream data from all available instances' };
>>>>>>> upstream/main
}
