import { execFileSync } from 'node:child_process'

const { ROKU_HOST, ROKU_PASSWORD } = process.env
if (!ROKU_HOST || !ROKU_PASSWORD) {
  console.error('Faltan ROKU_HOST o ROKU_PASSWORD en .env')
  process.exit(1)
}
execFileSync('npx', ['bsc', '--project', 'bsconfig.json', '--deploy', '--host', ROKU_HOST, '--password', ROKU_PASSWORD], { stdio: 'inherit' })
