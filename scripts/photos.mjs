// Copies personal photos into src/images/photos (git-ignored), resized so they stay light on the Roku.
// The app shows one of them, a different one each time, on the intro and the player's loading screen.
// Usage: npm run photos -- <folder>   (replaces the photos copied before)
import { execFileSync } from 'node:child_process'
import { mkdirSync, readdirSync, rmSync } from 'node:fs'
import { join } from 'node:path'

const source = process.argv[2]
if (!source) {
  console.error('Uso: npm run photos -- <carpeta con fotos>')
  process.exit(1)
}

const dest = 'src/images/photos'
const photos = readdirSync(source)
  .filter((f) => /\.(jpe?g|png|heic)$/i.test(f))
  .sort()
if (photos.length === 0) {
  console.error(`No encontré fotos (jpg, png o heic) en ${source}`)
  process.exit(1)
}

rmSync(dest, { recursive: true, force: true })
mkdirSync(dest, { recursive: true })
photos.forEach((f, i) => {
  const out = join(dest, `${String(i + 1).padStart(2, '0')}.jpg`)
  execFileSync('sips', ['-Z', '800', '-s', 'format', 'jpeg', join(source, f), '--out', out], { stdio: 'ignore' })
})
console.log(`${photos.length} fotos copiadas a ${dest}`)
