import { setStore } from '@lib/stores/app.ts';
import { playerStore, setPlayerStore } from '@lib/stores/player.ts';

export default function(
  audio: HTMLAudioElement,
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
  const url = new URL(audio.src);
>>>>>>> upstream/main

  if (audio.src.endsWith('&fallback')) {
    if (!playerStore.isWatching && !prefetch) {
      setStore('snackbar', 'Error 403 : Unauthenticated Stream');
      setPlayerStore('playbackState', 'none');
    }
    return;
  }

  if (!proxy || url.origin === proxy) {
    if (!prefetch) {
      setPlayerStore({
        playbackState: 'none',
        status: 'Streaming Failed'
      });
      setStore('snackbar', 'Streaming Failed');
    }
    return;
  }

  console.log('ErrorHandler: Switching to proxy ' + proxy);
  audio.src = audio.src.replace(url.origin, proxy);
}
