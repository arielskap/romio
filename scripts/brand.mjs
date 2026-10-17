// Generates the channel icon, splash and logo from the `title=` line of src/manifest, plus the theme images,
// so renaming the app is: edit that line, run `npm run brand`, commit the images.
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const title = readFileSync('src/manifest', 'utf8').match(/^title=(.+)$/m)?.[1]?.trim()
if (!title) {
  console.error('No encontré "title=" en src/manifest')
  process.exit(1)
}

const escape = (s) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' })[c])
const name = escape(title.toUpperCase())

// The mark: coral circle with a white play triangle, `size` px wide at (x, y).
const mark = (x, y, size) => `
  <g transform="translate(${x} ${y}) scale(${size / 100})">
    <circle cx="50" cy="50" r="50" fill="url(#accent)"/>
    <path d="M40 30 L72 50 L40 70 Z" fill="#fff" stroke="#fff" stroke-width="6" stroke-linejoin="round"/>
  </g>`

// Long names shrink instead of being cut off.
const wordmark = (cx, y, maxWidth, baseSize) => {
  const size = Math.min(baseSize, maxWidth / (title.length * 0.62))
  return `<text x="${cx}" y="${y}" text-anchor="middle" font-family="Helvetica Neue, Arial, sans-serif" font-weight="800" font-size="${size.toFixed(1)}" letter-spacing="${(size * 0.06).toFixed(1)}" fill="#fff">${name}</text>`
}

const svg = (w, h, body, background = true) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F2613F"/><stop offset="1" stop-color="#B8321A"/></linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.42" r="0.6"><stop offset="0" stop-color="#2A1410"/><stop offset="1" stop-color="#0B0B0F"/></radialGradient>
  </defs>
  ${background ? `<rect width="${w}" height="${h}" fill="url(#glow)"/>` : ''}
  ${body}
</svg>`

const svgRaw = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`

// Icon layout at 540x405; the HD icon is the same drawing scaled down.
const icon = (w, h) => svg(w, h, `<g transform="scale(${w / 540})">${mark(205, 95, 130)}${wordmark(270, 300, 470, 46)}</g>`)

const outputs = {
  'logo.png': [360, 360, svg(360, 360, mark(0, 0, 360), false)],
  'icon_focus_fhd.png': [540, 405, icon(540, 405)],
  'icon_focus_hd.png': [290, 218, icon(290, 218)],
  'splash_fhd.png': [1920, 1080, svg(1920, 1080, `${mark(840, 330, 240)}${wordmark(960, 680, 1400, 72)}`)],
  // Theme images (not name-dependent). Fades are drawn small and stretched on screen: cheap in memory.
  'fade_left.png': [480, 270, svgRaw(480, 270, `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#0B0B0F"/><stop offset="0.35" stop-color="#0B0B0F" stop-opacity="0.85"/><stop offset="0.75" stop-color="#0B0B0F" stop-opacity="0"/></linearGradient></defs><rect width="480" height="270" fill="url(#g)"/>`)],
  'fade_bottom.png': [480, 270, svgRaw(480, 270, `<defs><linearGradient id="g" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#0B0B0F"/><stop offset="0.3" stop-color="#0B0B0F" stop-opacity="0.6"/><stop offset="0.7" stop-color="#0B0B0F" stop-opacity="0"/></linearGradient></defs><rect width="480" height="270" fill="url(#g)"/>`)],
  // Nine-patch: the 1 px outer border marks the stretchable middle (black pixels on the top row and left column).
  'focus.9.png': [48, 48, svgRaw(48, 48, `<rect x="3" y="3" width="42" height="42" rx="8" fill="none" stroke="#F2613F" stroke-width="4"/><g shape-rendering="crispEdges" fill="#000"><rect x="14" y="0" width="20" height="1"/><rect x="0" y="14" width="1" height="20"/></g>`)],
  'icon_play.png': [40, 40, svgRaw(40, 40, '<path d="M11 6 L33 20 L11 34 Z" fill="#000"/>')],
  'icon_info.png': [40, 40, svgRaw(40, 40, '<circle cx="20" cy="20" r="16" fill="none" stroke="#fff" stroke-width="3"/><rect x="18" y="17" width="4" height="12" fill="#fff"/><circle cx="20" cy="12" r="2.4" fill="#fff"/>')],
  'icon_restart.png': [40, 40, svgRaw(40, 40, '<path d="M30 12 A12 12 0 1 0 32 22" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/><path d="M24 5 L32 11 L24 16 Z" fill="#fff"/>')],
  'icon_add.png': [40, 40, svgRaw(40, 40, '<path d="M20 8 V32 M8 20 H32" stroke="#fff" stroke-width="4" stroke-linecap="round"/>')],
  'icon_sources.png': [40, 40, svgRaw(40, 40, '<path d="M8 11 H32 M8 20 H32 M8 29 H32" stroke="#fff" stroke-width="4" stroke-linecap="round"/>')],
  'icon_arrow.png': [40, 40, svgRaw(40, 40, '<path d="M8 20 H30 M21 11 L30 20 L21 29" fill="none" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')],
  'icon_back.png': [40, 40, svgRaw(40, 40, '<path d="M32 20 H10 M19 11 L10 20 L19 29" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')],
  'icon_back10.png': [40, 40, svgRaw(40, 40, '<path d="M9 20 A12 12 0 1 0 14 10" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/><path d="M8 4 L15 10 L7 14 Z" fill="#fff"/><text x="21" y="25" font-family="Helvetica, Arial, sans-serif" font-size="11" font-weight="bold" fill="#fff" text-anchor="middle">10</text>')],
  'icon_fwd10.png': [40, 40, svgRaw(40, 40, '<path d="M31 20 A12 12 0 1 1 26 10" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/><path d="M32 4 L25 10 L33 14 Z" fill="#fff"/><text x="19" y="25" font-family="Helvetica, Arial, sans-serif" font-size="11" font-weight="bold" fill="#fff" text-anchor="middle">10</text>')],
  'icon_audio.png': [40, 40, svgRaw(40, 40, '<path d="M7 15 H13 L21 8 V32 L13 25 H7 Z" fill="#fff"/><path d="M26 14 A8 8 0 0 1 26 26 M29 10 A13 13 0 0 1 29 30" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>')],
  'icon_subs.png': [40, 40, svgRaw(40, 40, '<rect x="5" y="9" width="30" height="22" rx="3" fill="none" stroke="#fff" stroke-width="3"/><path d="M11 19 H20 M23 19 H29 M11 25 H17 M20 25 H29" stroke="#fff" stroke-width="3" stroke-linecap="round"/>')],
  'icon_episodes.png': [40, 40, svgRaw(40, 40, '<rect x="6" y="7" width="28" height="7" rx="1.5" fill="#fff"/><rect x="6" y="17" width="28" height="7" rx="1.5" fill="#fff"/><rect x="6" y="27" width="28" height="7" rx="1.5" fill="#fff"/>')],
  'icon_next.png': [40, 40, svgRaw(40, 40, '<path d="M9 8 L26 20 L9 32 Z" fill="#fff"/><rect x="27" y="8" width="4" height="24" fill="#fff"/>')],
  'icon_eye.png': [40, 40, svgRaw(40, 40, '<path d="M3 20 C9 10 31 10 37 20 C31 30 9 30 3 20 Z" fill="none" stroke="#fff" stroke-width="3.5" stroke-linejoin="round"/><circle cx="20" cy="20" r="5.5" fill="#fff"/>')],
  'icon_eye_off.png': [40, 40, svgRaw(40, 40, '<path d="M3 20 C9 10 31 10 37 20 C31 30 9 30 3 20 Z" fill="none" stroke="#fff" stroke-width="3.5" stroke-linejoin="round"/><circle cx="20" cy="20" r="5.5" fill="#fff"/><path d="M7 33 L33 7" stroke="#0B0B0F" stroke-width="8" stroke-linecap="round"/><path d="M7 33 L33 7" stroke="#fff" stroke-width="3.5" stroke-linecap="round"/>')],
  'icon_gear.png': [40, 40, svgRaw(40, 40, '<g fill="#fff" transform="translate(20 20)"><circle r="10"/><rect x="-3" y="-16" width="6" height="8"/><rect x="-3" y="8" width="6" height="8"/><rect x="-16" y="-3" width="8" height="6"/><rect x="8" y="-3" width="8" height="6"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(45)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(135)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(225)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(315)"/></g><circle cx="20" cy="20" r="4.5" fill="#0B0B0F"/>')],
  'icon_gear_dark.png': [40, 40, svgRaw(40, 40, '<g fill="#000" transform="translate(20 20)"><circle r="10"/><rect x="-3" y="-16" width="6" height="8"/><rect x="-3" y="8" width="6" height="8"/><rect x="-16" y="-3" width="8" height="6"/><rect x="8" y="-3" width="8" height="6"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(45)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(135)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(225)"/><rect x="-3" y="-16" width="6" height="8" transform="rotate(315)"/></g><circle cx="20" cy="20" r="4.5" fill="#FFFFFF"/>')],
  // Background-colored square with a transparent circle: laid over cast photos to make them round.
  'mask_circle.png': [160, 160, svgRaw(160, 160, '<path fill="#0B0B0F" fill-rule="evenodd" d="M0 0 H160 V160 H0 Z M80 10 A70 70 0 1 0 80.01 10 Z"/>')],
  'icon_check.png': [40, 40, svgRaw(40, 40, '<circle cx="20" cy="20" r="18" fill="#F2613F"/><path d="M11 20.5 L17.5 27 L29.5 14" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')],
}

mkdirSync('src/images', { recursive: true })
const dir = mkdtempSync(join(tmpdir(), 'brand-'))
try {
  for (const [file, [w, h, content]] of Object.entries(outputs)) {
    const src = join(dir, file.replace('.png', '.svg'))
    writeFileSync(src, content)
    try {
      execFileSync('rsvg-convert', ['-w', String(w), '-h', String(h), src, '-o', join('src/images', file)])
    } catch (e) {
      if (e.code === 'ENOENT') {
        console.error('Falta rsvg-convert. Instalá librsvg: brew install librsvg')
        process.exit(1)
      }
      throw e
    }
    console.log(`src/images/${file} ${w}x${h}`)
  }
} finally {
  rmSync(dir, { recursive: true, force: true })
}
