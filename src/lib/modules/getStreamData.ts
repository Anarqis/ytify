<<<<<<< HEAD
import { store, setStore } from "../stores";
import { fetchWithRetry } from "@lib/utils/fetch";
=======
import { playerStore, setPlayerStore } from '@stores';
import { shuffle } from '@utils';
import { streamCache } from './audioCache';

const instances = shuffle([
  "https://yt.omada.cafe",
  "https://invidious.schenkel.eti.br",
  "https://invidious.kemonomimi.nl",
  "https://echostreamz.com"
]);

const SESSION_KEY = 'ytify_session';
const SESSION_MIN_AGE_MS = 10000;
const SESSION_TTL_MS = 30 * 60 * 1000;
/**
 * The stream gate allows one in-flight call per key and answers 429 otherwise.
 * A 503 means the gate itself was unreachable, so the request is retried the
 * same way: both are "try again in a moment", never "try the next proxy".
 */
const LEASE_MAX_RETRIES = 2;
const LEASE_RETRY_DELAY_MS = 1500;
const GATE_RETRYABLE_STATUS = [429, 503];

type Session = { sessionId: string; createdAt: number };

// Shared so concurrent callers (queue prefetch, bulk capture) open one session
// instead of each burning their own 10s warm-up.
let pendingSession: Promise<string> | null = null;

function readSession(): Session | null {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw) as Session;
    if (typeof session?.sessionId !== 'string' || typeof session?.createdAt !== 'number') return null;
    return session;
  } catch {
    return null;
  }
}

function clearSession() {
  sessionStorage.removeItem(SESSION_KEY);
}

const sleep = (ms: number) => new Promise<void>(r => setTimeout(r, ms));

async function openSession(signal?: AbortSignal): Promise<string> {
  const res = await fetch('/s/', { headers: { 'Accept': 'application/json' }, signal });
  if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);

  const { sessionId } = await res.json();
  if (!sessionId) throw new Error('Invalid response: sessionId missing');

  const session: Session = { sessionId, createdAt: Date.now() };
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));

  setPlayerStore('status', 'Opening secure fallback session...');
  await sleep(SESSION_MIN_AGE_MS);
  return sessionId;
}

// The edge function requires a session older than 10s and under 30min old, so we
// mint one on demand and reuse it. A rejected session is dropped and re-opened once.
async function getOrCreateSession(signal?: AbortSignal): Promise<string> {
  const session = readSession();
  const age = session ? Date.now() - session.createdAt : Infinity;

  if (session && age >= SESSION_MIN_AGE_MS && age < SESSION_TTL_MS) return session.sessionId;

  pendingSession ??= openSession(signal).finally(() => { pendingSession = null; });
  return pendingSession;
}
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
=======
  const fetchData = async (proxy: string): Promise<Invidious> => {
    const isFallback = !proxy;
    const path = isFallback ? '/s/' : '/api/v1/videos/';
    let leaseRetries = LEASE_MAX_RETRIES;

    const request = async (sessionId?: string): Promise<Response> => {
      const res = await fetch(proxy + path + id, {
        headers: {
          'Accept': 'application/json',
          ...(sessionId && { 'x-session-id': sessionId })
        },
        signal
>>>>>>> upstream/main
      });
  };

<<<<<<< HEAD
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
      // A bodyless 403 is the 20s cooldown, not a session rejection, so it is left alone.
      // A JSON 403 means the session was rejected: drop it and re-open once.
      const isSessionRejection =
        res.status === 403 &&
        !!res.headers.get('content-type')?.includes('application/json');

      if (isFallback && isSessionRejection && !sessionId) {
        clearSession();
        return request(await getOrCreateSession(signal));
      }

      // Another request from this session still holds the upstream lease (429),
      // or the gate could not be reached (503). Both clear within seconds, so
      // wait them out instead of failing through to the next proxy, which would
      // burn its own lease.
      if (isFallback && GATE_RETRYABLE_STATUS.includes(res.status) && leaseRetries-- > 0) {
        const retryAfter = parseInt(res.headers.get('retry-after') || '0', 10);
        const delay = retryAfter * 1000 || LEASE_RETRY_DELAY_MS;
        await sleep(Math.min(delay, LEASE_RETRY_DELAY_MS * 2));
        return request(sessionId);
      }

      return res;
    };

    const sessionId = isFallback ? await getOrCreateSession(signal) : undefined;
    const res = await request(sessionId);
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
