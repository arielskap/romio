// Walks the same flow as the Roku app against the real services, using the account in .env.
const { STREMIO_EMAIL, STREMIO_PASSWORD, LIVE_VIDEO_ID = 'tt2708480:1:1' } = process.env
if (!STREMIO_EMAIL || !STREMIO_PASSWORD) {
  console.error('Faltan STREMIO_EMAIL o STREMIO_PASSWORD en .env')
  process.exit(1)
}

let failed = false
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`)
  if (!ok) failed = true
  return ok
}
const stremio = async (method, body) => {
  const res = await fetch(`https://api.strem.io/api/${method}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
  return res.json()
}
const getJson = async (url, headers = {}) => (await fetch(url, { headers, signal: AbortSignal.timeout(20000) })).json()
const base = (url) => url.replace(/\/manifest\.json$/, '')
const supports = (addon, resource, id) => (addon.manifest.resources ?? []).some((r) => {
  const name = typeof r === 'string' ? r : r.name
  const prefixes = (typeof r === 'string' ? null : r.idPrefixes) ?? addon.manifest.idPrefixes
  return name === resource && (!prefixes || prefixes.some((p) => id.startsWith(p)))
})

const login = await stremio('login', { type: 'Login', email: STREMIO_EMAIL, password: STREMIO_PASSWORD, facts: {} })
if (!check('login', Boolean(login.result?.authKey), login.error?.message)) process.exit(1)
const authKey = login.result.authKey

const { result: { addons } } = await stremio('addonCollectionGet', { type: 'AddonCollectionGet', authKey, update: true })
check('addons', addons.length > 0, `${addons.length} addons`)
const rdKey = addons.map((a) => a.transportUrl.match(/realdebrid=([A-Za-z0-9]+)/)?.[1]).find(Boolean)
if (!check('real-debrid key in addons', Boolean(rdKey))) process.exit(1)

const library = await stremio('datastoreGet', { authKey, collection: 'libraryItem', ids: [], all: true })
check('library', Array.isArray(library.result), `${library.result?.length} items`)

const [seriesId] = LIVE_VIDEO_ID.split(':')
const metaAddon = addons.find((a) => supports(a, 'meta', seriesId))
const meta = await getJson(`${base(metaAddon.transportUrl)}/meta/series/${seriesId}.json`)
check('meta', meta.meta?.videos?.length > 0, `${meta.meta?.name}, ${meta.meta?.videos?.length} videos`)

const streamAddons = addons.filter((a) => supports(a, 'stream', LIVE_VIDEO_ID) && !a.transportUrl.startsWith('http://127.0.0.1'))
const streams = (await Promise.all(streamAddons.map((a) => getJson(`${base(a.transportUrl)}/stream/series/${encodeURIComponent(LIVE_VIDEO_ID)}.json`).catch(() => ({ streams: [] })))))
  .flatMap((r) => r.streams ?? [])
  .filter((s) => s.url?.startsWith('http') && s.behaviorHints?.filename)
if (!check('streams', streams.length > 0, `${streams.length} playable`)) process.exit(1)

// "[RD+]" can be stale: the addon then redirects to a "downloading" video and the file never
// shows up in downloads. The app offers the next source in that case; do the same here.
let stream
let download
for (const candidate of streams.slice(0, 5)) {
  await fetch(candidate.url, { method: 'HEAD', signal: AbortSignal.timeout(60000) }).catch(() => {})
  const downloads = await getJson('https://api.real-debrid.com/rest/1.0/downloads?limit=50', { Authorization: `Bearer ${rdKey}` })
  download = downloads.find((d) => d.filename === candidate.behaviorHints.filename)
  if (download) {
    stream = candidate
    break
  }
  console.log(`skip ${candidate.behaviorHints.filename} (not in Real-Debrid)`)
}
if (!check('download found by filename', Boolean(download), stream?.behaviorHints.filename ?? 'none of the first 5 sources')) process.exit(1)

const transcode = await getJson(`https://api.real-debrid.com/rest/1.0/streaming/transcode/${download.id}`, { Authorization: `Bearer ${rdKey}` })
check('hls transcode', Boolean(transcode.apple?.high))

const subAddons = addons.filter((a) => supports(a, 'subtitles', LIVE_VIDEO_ID))
const subs = (await Promise.all(subAddons.map((a) => getJson(`${base(a.transportUrl)}/subtitles/series/${encodeURIComponent(LIVE_VIDEO_ID)}/filename=${encodeURIComponent(stream.behaviorHints.filename)}.json`).catch(() => ({ subtitles: [] })))))
  .flatMap((r) => r.subtitles ?? [])
check('spanish subtitles', subs.some((s) => ['spa', 'spl', 'es'].includes(s.lang)), `${subs.length} total`)

process.exit(failed ? 1 : 0)
