import { playerStore, setPlayerStore, setStore, updateParam } from "@stores";
import { config, player, applyMetadata } from "@utils";

export default function () {
  setPlayerStore("status", "Loading music information...");

  const { stream, audio } = playerStore;
  const { author, id, title } = stream;

<<<<<<< HEAD
  // Fallback APIs in case the primary one fails
  const SAAVN_APIS = [
    'https://fast-saavn.vercel.app/api',
    'https://saavn.dev/api',
    'https://saavn-api.vercel.app/api'
  ];

  const fetchStreamUrl = async () => {
    for (const apiBase of SAAVN_APIS) {
      try {
        console.log(`Trying JioSaavn API: ${apiBase}`);
        const res = await fetch(`${apiBase}?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(author?.replace(' - Topic', '') ?? '')}&duration=${encodeURIComponent(stream.duration)}`);
        
        if (!res.ok) continue;
        
        const trimmedDownloadUrl = await res.text();
        if (trimmedDownloadUrl) return trimmedDownloadUrl;
      } catch (e) {
        console.warn(`Failed to fetch from ${apiBase}:`, e);
      }
    }
    throw new Error('All JioSaavn APIs failed');
  };

  fetchStreamUrl()
    .then(trimmedDownloadUrl => {
      if (!trimmedDownloadUrl) throw new Error('Music stream not found in JioSaavn results');
=======
  fetch(
    `https://fast-saavn.vercel.app/api?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(author?.replace(" - Topic", "") ?? "")}&duration=${encodeURIComponent(stream.duration)}`,
  )
    .then(async (res) => {
      if (!res.ok) {
        return res.text().then((text) => {
          throw new Error(text);
        });
      }
      return res.text();
    })
    .then((trimmedDownloadUrl) => {
      if (!trimmedDownloadUrl)
        throw new Error("Music stream not found in JioSaavn results");
>>>>>>> upstream/main

      const baseUrl = "https://aac.saavncdn.com/";
      const desiredBitrateSuffix =
        {
          worst: "12",
          low: "48",
          medium: "160",
          high: "320",
        }[config.quality] || "320";
      const fullDownloadUrl = `${baseUrl}${trimmedDownloadUrl}_${desiredBitrateSuffix || "96"}.mp4`;

      setPlayerStore("data", { ...stream, downloadUrl: fullDownloadUrl });

      applyMetadata(stream);

      delete audio.dataset.retried;
      audio.src = fullDownloadUrl;
      updateParam("s", id);
    })
<<<<<<< HEAD
    .catch(e => {
      console.error('JioSaavn Error:', e);
      setPlayerStore('status', e.message || e.error || 'JioSaavn Playback Failure');
      setStore('useSaavn', false);
=======
    .catch((e) => {
      setPlayerStore(
        "status",
        e.message || e.error || "JioSaavn Playback Failure",
      );
      setStore("useSaavn", false);
>>>>>>> upstream/main
      player(id);
    });
}
