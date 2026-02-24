import { store, setStore } from "../stores";
import { fetchWithRetry } from "@lib/utils/fetch";

export default function(
  id: string,
  prefetch: boolean = false,
  signal?: AbortSignal
): Promise<Invidious | Record<'error' | 'message', string>> {

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
}
