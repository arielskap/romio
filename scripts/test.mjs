import { execFileSync, spawnSync } from 'node:child_process'

const { ROKU_HOST, ROKU_PASSWORD } = process.env
if (!ROKU_HOST || !ROKU_PASSWORD) {
  console.error('Faltan ROKU_HOST o ROKU_PASSWORD en .env')
  process.exit(1)
}
try {
  // Compile first: with compile errors the Rooibos CLI deploys anyway and waits forever.
  execFileSync('npx', ['bsc', '--project', 'bsconfig-test.json', '--createPackage', 'false'], { stdio: 'inherit' })
} catch {
  process.exit(1)
}
// Close whatever app is open first: otherwise the CLI can read that app's exit as the test run ending.
await fetch(`http://${ROKU_HOST}:8060/keypress/Home`, { method: 'POST' }).catch(() => {})
await new Promise((resolve) => setTimeout(resolve, 3000))
// keep-registry.cjs stops the CLI from deleting the dev channel first, which would log the app out.
const cli = new URL('../node_modules/rooibos-roku/dist/cli.js', import.meta.url).pathname
const keep = new URL('./keep-registry.cjs', import.meta.url).pathname
const run = spawnSync('node', ['--require', keep, cli, '--project=bsconfig-test.json', `--host=${ROKU_HOST}`, `--password=${ROKU_PASSWORD}`], { encoding: 'utf8', timeout: 240000, maxBuffer: 64 * 1024 * 1024 })
process.stdout.write(run.stdout ?? '')
process.stderr.write(run.stderr ?? '')
// The CLI can exit 0 without having read any results (e.g. the console port was busy), so require the success line.
if (run.status !== 0 || !(run.stdout ?? '').includes('RESULT: Success')) {
  console.error('Los tests no terminaron con "RESULT: Success".')
  process.exit(1)
}
