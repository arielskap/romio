# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Roku (BrightScript + SceneGraph) app that works like the user's Stremio account: logs into api.strem.io, uses the account's addons and library ("Continuar viendo"), and plays the sources its addons return through Real-Debrid. Target device: Roku Express 3900X (no HEVC, no AC3/EAC3 decoding, ~100 MB app memory). User-facing text is Spanish (rioplatense); code and comments are English.

## Commands

All scripts read `.env` (`ROKU_HOST`, `ROKU_PASSWORD`, `STREMIO_EMAIL`, `STREMIO_PASSWORD`; see `.env.example`).

- `npm run build` — compile with BrighterScript (`bsc`) into `out/staging`. Use it as the typecheck: it catches undefined functions, wrong arg counts and reserved identifiers.
- `npm run deploy` — compile and sideload to the Roku. Keeps the saved session.
- `npm test` — compiles `bsconfig-test.json`, then runs Rooibos **on the device**. It only passes if the output contains `RESULT: Success`. To run a subset, annotate a suite or test with `@only` in its `.spec.bs` (remove before committing).
- `npm run logs` — stream the device console (port 8085).
- `npm run live-check` — Node script that walks login → addons → meta → streams → Real-Debrid → HLS → subtitles against the real services with the account in `.env`.

Device gotchas when running these:
- The console port 8085 accepts one client. Stop `npm run logs` (or any `nc` to 8085) before `npm test`, or Rooibos fails with "already in use". A killed client can keep the port busy for a while.
- `npm test` installs the test build in the dev channel, which shares the app's registry. The Rooibos CLI deletes the dev channel before sideloading (wiping the registry, so the session); `scripts/keep-registry.cjs` turns that off, and tests that touch `authKey`/`lastEmail` save and restore them. Run `npm run deploy` afterwards: otherwise opening the app runs the test suite.
- To drive the UI without a person: ECP keypresses (`curl -d '' http://$ROKU_HOST:8060/keypress/<Key>`, `Lit_<char>` to type), `/query/media-player` for playback state/container/position, and screenshots via the dev installer (`POST /plugin_inspect` with `mysubmit=Screenshot`, then `GET /pkgs/dev.jpg`, digest auth `rokudev`). Video frames don't appear in screenshots; subtitles and overlays do.

## Architecture

- `src/source/lib/*.brs` — pure logic, unit-tested: `Stremio` (API requests/parsing), `Addons` (manifest routing, URLs, stream parsing and ranking), `Meta`, `Library` (continue watching, progress updates, pending queue), `RealDebrid`, `Subtitles`, `Media` (codec sniffing from file headers), `Playback` (player decisions), `Format`. Network helpers `Http`/`Storage` and the operations in `Flows.brs` run only inside the Task.
- `src/components/tasks/ApiTask` — the single Task node. Screens call `Ui_runTask(op, args, callback)`; `Flows_run` dispatches `boot`, `login`, `catalog`, `search`, `meta`, `streams`, `play`, `saveProgress`, `shiftSubtitle`. All network I/O happens here, never on the render thread.
- `src/components/MainScene` — screen stack. Screens extend `Screen` (`params`, `active`, `navigate`); navigation is always `{ action: "push"|"back"|"boot", ... }`. `m.global.session` holds `authKey`, slim `addons`, `library`, `libraryLoaded`, `rdKey`; reading it deep-copies the whole library, so read it once per handler.
- Each component XML has its own script scope: a component can only call lib functions whose `.brs` it includes with `<script uri="pkg:/source/lib/...">`. `bsc` reports a missing include as "Cannot find function".
- Tests live in `src/source/tests/*.spec.bs` (Rooibos only finds specs in the `source` scope; the release bsconfig excludes them). `src/source/main.bs` must stay `.bs` so Rooibos can inject `Rooibos_init`.

## Playback model (why the player looks the way it does)

- `Flows_play`: HEAD the addon's stream URL (makes the addon add the file to Real-Debrid), find it in RD `/downloads` by filename (one retry after 3 s; the outcome feeds `addonOutcomes`), then:
  - **Direct play** when the file is H.264 with AAC/MP3 audio (`Media_canDirect`): MKV from the CodecIDs in the first 256 KB, MP4 by walking its boxes to the start of each `trak` (`Flows_mp4Info`). Starts instantly and seeks freely. If the Roku rejects it or it never starts, the player retries the same source transcoded.
  - Otherwise **Real-Debrid HLS transcode** (`/streaming/transcode/{id}` → `apple.high`).
- Real-Debrid's transcode only converts segments in order from 0, and each request may land on a different server that starts from scratch. Seeking or resuming past what was converted **buffers forever without a Video error**. `PlayerScreen` therefore has a position-based watchdog (`watchTimer`) that falls back to 0:00 when the resume point was never reached; after a seek it waits up to a minute for short jumps (≤ 2 min, `Playback_stallAction`) and then returns to the last smooth position. A `convertTimer` covers starts that never happen (90 s converted, 30 s direct; a direct file that doesn't start is retried converted). None of this applies in direct mode.
- Subtitles: auto-pick and menu order share `Subs_rank` (Spanish from strem.io first). The menu (up key) starts with "Sincronizar subtítulos"; sync reloads the video with a shifted copy (see below), and picking another subtitle resets the offset to 0.
- Progress-overwrite protection is deliberate and spread across `Playback_canSave`, `Playback_savePosition`, `Library_shouldSave` and `Library_mergePending`: never save before playback starts or after a failure, never save below an unreached resume point, never push pending items older than the server copy, and never save unknown items when the library failed to load. Saving a wrong position corrupts the user's progress in every Stremio app.
- Stream ranking (`Addons_rankStreams`): 1080p > 720p > 480p > unknown > 4K+, lighter files first; unknown sizes and sub-200 MB samples last within a quality; cinema/pre-release/hardsub copies (`Addons_isLowQualityCopy`) and, for movies, other years' releases at the end. Addons that recently failed to deliver files (outcomes in the registry key `addonOutcomes`) rank lower. Some addons often return wrong titles or are down ("Debrid service is down").

## BrightScript rules learned on the device

- **Key casing:** unquoted AA literal keys and dot-assignment (`x.key = v`) are lowercased by `FormatJson`; `ParseJson` AAs are case-sensitive while dot reads keep source case. Anything sent to a server (Stremio payloads, library items) must use quoted keys (`{ "authKey": k }`) and bracket assignment (`st["timeOffset"] = v`). Test fixtures that stand for server JSON go through `ParseJson(FormatJson({ quoted keys }))`.
- `pos`, `next` and `step` are reserved: use `positionSec`, `nextBtn`, `deltaMs`.
- In roRegex `.` doesn't match `\r`; use `[\s\S]` when CRLF text (SRT files) must be kept.
- Real-Debrid answers suffix ranges (`Range: bytes=-N`) with the *start* of the file; only explicit ranges work. MP4 codecs are found by walking boxes (`Flows_mp4Info`), not by reading the tail.
- Long loops are dangerous: heavy work on the render thread or byte-by-byte copies of large roByteArrays get the app killed (`EXIT_UNKNOWN` / `EXIT_SYSTEM_KILL`). Do it in the Task, and prefer small range requests over copying.
- Changing `subtitleTracks` while playing crashes the player, and switching `subtitleTrack` mid-play loses sync. Subtitle sync writes a shifted SRT to `tmp:` (Task op `shiftSubtitle`) and reloads the video at the same position.
- An OK that selects a LabelList item also bubbles to the screen's `onKeyEvent`; ignore it when the selection opens a mode that uses OK (see `openSync`).
- Comparing `invalid` to a string crashes at runtime. Guard response fields with `Addons_str`, `Addons_arr`, `Addons_int`, `Addons_isTrue`, `Library_num`.
- Resolve sources with HEAD, not a ranged GET: on the redirect to Real-Debrid the Roku drops the `Range` header and downloads the whole file into memory (`EXIT_CHANNEL_MEM_LIMIT_FG`).
- A focused Video node handles remote keys itself (its own trickplay on left/right/OK) even with `enableUI="false"`. Calling `setFocus(true)` on a screen does not take focus back from a focused child (hidden lists and buttons keep getting keys). Every screen inherits an empty focusable `keys` node from `Screen.xml`: `Ui_parkFocus(m.top)` focuses it so every key reaches the screen's `onKeyEvent`; the player parks there during playback.
- The Roku system font has no `▶`; LabelLists need `vertFocusAnimationStyle="floatingFocus"` or they wrap.

## Working against the real account

Testing playback writes progress to the user's real Stremio library. Before a device test that plays a title, note its `state` (via `datastoreGet`) and restore it afterwards with `datastorePut` if the test moved it; prefer exiting the player with Home (no save) over Back. Fast-forward passes through "paused", which saves too, and the 30 s save timer fires during longer tests. Don't play titles the user is watching on another device at the same time.
