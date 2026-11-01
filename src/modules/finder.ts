import { normalizeText } from "@utils";

const SEARCH_RESULT_LIMIT = 50;

export default (searchTerm: string, tracksMap: Collection) => {
  const toFind = normalizeText(searchTerm);
  const results: TrackItem[] = [];
  let isTruncated = false;

  if (!toFind) {
    return { results, isTruncated };
  }

  const allItems = Object.values(tracksMap);

  for (const v of allItems) {
    if (results.length >= SEARCH_RESULT_LIMIT) {
      isTruncated = true;
      break;
    }
    if (!('title' in v && typeof v.title === 'string')) continue;
<<<<<<< HEAD:src/lib/modules/finder.ts
    const titleMatch = removeDiacritics(v.title.toLowerCase()).includes(toFind);
    const authorMatch = ('author' in v && typeof v.author === 'string')
      ? removeDiacritics(v.author.toLowerCase()).includes(toFind)
      : false;
=======
    const title = normalizeText(v.title).includes(toFind);
    if (!('author' in v && typeof v.author === 'string')) continue;
    const author = normalizeText(v.author).includes(toFind);
>>>>>>> upstream/main:src/modules/finder.ts

    if (titleMatch || authorMatch) {
      results.push(v);
    }
  }

  return { results, isTruncated };
};
