import { lazy, Show } from "solid-js";
import { config } from "@utils";
import {
  LikeButton,
  MediaDetails,
  PlayButton,
  PlayNextButton,
} from "./MediaPartials";
import { playerStore, setNavStore, queueStore } from "@stores";

const MediaArtwork = lazy(
  () => import("@components/MediaPartials/MediaArtwork"),
);

export default function () {
  return (
<<<<<<< HEAD
    <div class='miniplayer' onclick={(e) => {
      if (!e.target.matches('button'))
        setNavStore('player', 'state', true);
    }
    }>
      <progress value={(playerStore.currentTime / playerStore.fullDuration) || 0}></progress>
=======
    <div
      class="miniplayer"
      onclick={(e) => {
        const target = e.target as HTMLElement;
        if (!target.closest("button")) {
          setNavStore("player", "state", true);
          requestAnimationFrame(() => {
            const leftPanel = document.querySelector(".left-panel");
            leftPanel?.scrollIntoView({ behavior: "smooth" });
          });
        }
      }}
    >
      <progress
        value={(
          playerStore.currentTime / playerStore.fullDuration || 0
        ).toFixed(3)}
      ></progress>
>>>>>>> upstream/main
      <Show when={config.loadImage}>
        <MediaArtwork />
      </Show>
      <MediaDetails />
      <PlayButton />
      <Show when={queueStore.list.length} fallback={<LikeButton />}>
        <PlayNextButton />
      </Show>
    </div>
  );
}
