import { setStore, playerStore, setPlayerStore } from '@stores';
import { streamCache } from '@utils';

export default function(
  audio: HTMLAudioElement | HTMLVideoElement,
  prefetch = ''
) {
  audio.pause();
<<<<<<< HEAD
  const message = 'Error 403 : Unauthenticated Stream';
  const { stream } = playerStore;
  const id = prefetch || stream.id;
  const { index, invidious } = store;

  // Guard: if audio.src is empty or invalid, bail out
  if (!audio.src) {
    setPlayerStore('playbackState', 'none');
    return;
  }

  let origin: string;
  try {
    origin = new URL(audio.src).origin;
  } catch {
    setPlayerStore('playbackState', 'none');
    return;
  }
=======
  const { proxy } = playerStore;
>>>>>>> upstream/main

  if (!audio.src || audio.src === location.href) return;

  const url = new URL(audio.src);
  const isFallback = audio.src.endsWith('&fallback');
  const isAlreadyProxy = url.origin === proxy || audio.dataset.retried === 'true';

  const id = prefetch || playerStore.stream.id;

  if (isFallback) {
    if (!playerStore.isWatching && !prefetch) {
      setStore('snackbar', 'Error 403 : Unauthenticated Stream');
      setPlayerStore('playbackState', 'none');
    }
    streamCache.remove(id);
    return;
  }

  if (!proxy || isAlreadyProxy) {
    if (!prefetch) {
      setPlayerStore({
        playbackState: 'none',
        status: 'Streaming Failed EA'
      });
      setStore('snackbar', 'Streaming Failed EA');
      console.log(audio.src);
    }
    streamCache.remove(id);
    return;
  }

  console.log('ErrorHandler: Switching to proxy ' + proxy);
  const newSrc = audio.src.replace(url.origin, proxy);

  if (newSrc !== audio.src) {
    audio.dataset.retried = 'true';
    audio.src = newSrc;
  } else if (!prefetch) {
    setPlayerStore({
      playbackState: 'none',
      status: 'Streaming Failed EB'
    });
    streamCache.remove(id);
  }
}
