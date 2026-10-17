import net from 'node:net'

const host = process.env.ROKU_HOST
if (!host) {
  console.error('Falta ROKU_HOST en .env')
  process.exit(1)
}
const socket = net.connect(8085, host)
socket.pipe(process.stdout)
socket.on('error', (err) => {
  console.error(`No se pudo conectar al log del Roku: ${err.message}`)
  process.exit(1)
})
