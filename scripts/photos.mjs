// Copies personal photos into src/images/photos (git-ignored), resized so they stay light on the Roku.
// The app shows one of them, a different one each time, on the intro and the player's loading screen.
// Usage: npm run photos -- <folder>   (replaces the photos copied before; macOS only)
import { execFileSync } from 'node:child_process'
import { cpSync, mkdtempSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// ImageIO through JavaScript for Automation: resizes to 800 px on the long side and applies the EXIF
// orientation to the pixels, since the Roku ignores the tag and phone photos would show sideways.
const resize = `
ObjC.import('ImageIO')
function run(argv) {
  const src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(argv[0]), null)
  if (!src) throw new Error('unreadable')
  const opts = $({ kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 800 })
  const img = $.CGImageSourceCreateThumbnailAtIndex(src, 0, opts)
  if (!img) throw new Error('unreadable')
  const dst = $.CGImageDestinationCreateWithURL($.NSURL.fileURLWithPath(argv[1]), $('public.jpeg'), 1, null)
  $.CGImageDestinationAddImage(dst, img, $({ kCGImageDestinationLossyCompressionQuality: 0.85 }))
  if (!$.CGImageDestinationFinalize(dst)) throw new Error('not saved')
}`

const source = process.argv[2]
if (!source) {
  console.error('Uso: npm run photos -- <carpeta con fotos>')
  process.exit(1)
}

const dest = 'src/images/photos'
const photos = readdirSync(source)
  .filter((f) => /\.(jpe?g|png|heic)$/i.test(f))
  .sort()

// Converted into a temp folder first, so a failure never leaves the app with half the photos.
const work = mkdtempSync(join(tmpdir(), 'romio-photos-'))
let count = 0
for (const f of photos) {
  const out = join(work, `${String(count + 1).padStart(2, '0')}.jpg`)
  try {
    execFileSync('osascript', ['-l', 'JavaScript', '-e', resize, join(source, f), out], { stdio: 'ignore' })
    count++
  } catch {
    console.warn(`Salteo ${f}: no se pudo leer como imagen`)
  }
}
if (count === 0) {
  rmSync(work, { recursive: true, force: true })
  console.error(`No encontré fotos que se puedan usar (jpg, png o heic) en ${source}`)
  process.exit(1)
}

rmSync(dest, { recursive: true, force: true })
cpSync(work, dest, { recursive: true })
rmSync(work, { recursive: true, force: true })
console.log(`${count} fotos copiadas a ${dest}`)
