# Romio

Cliente no oficial para Roku (modo desarrollador) que usa tu cuenta de Stremio: tus addons, tu biblioteca y "Continuar viendo". Reproduce todo convertido por Real-Debrid a H.264 + AAC, porque los Roku de entrada (como el Express 3900X) no reproducen x265 ni audio 5.1.

> Romio no tiene relación con Stremio ni con Smart Code, ni está respaldado por ellos. "Stremio" es una marca de sus dueños y se nombra solo para indicar compatibilidad.

## Requisitos

- Roku en modo desarrollador (en el control: Home ×3, Arriba ×2, Derecha, Izquierda, Derecha, Izquierda, Derecha)
- Cuenta de Stremio con addons que devuelvan fuentes de Real-Debrid
- Node 22

## Uso

1. `cp .env.example .env` y completá `ROKU_HOST`, `ROKU_PASSWORD`, `STREMIO_EMAIL` y `STREMIO_PASSWORD`
2. `npm install`
3. `npm run deploy` instala la app en el Roku

| Comando | Qué hace |
|---|---|
| `npm test` | Corre los tests de Rooibos en el Roku (borra la sesión guardada: después hay que volver a iniciar sesión) |
| `npm run live-check` | Recorre el flujo completo contra Stremio y Real-Debrid con tu cuenta |
| `npm run logs` | Muestra el log del Roku (puerto 8085; cerralo antes de `npm test`, que usa el mismo puerto) |

## En la tele

- **Fuentes:** van de la que mejor anda en tu Roku a la que peor; las grabadas en el cine o con subtítulos incrustados quedan al final.
- **Subtítulos:** se eligen solos en español. Con la flecha para arriba, mientras se reproduce, elegís otro, los sacás o los sincronizás ("Sincronizar subtítulos": izquierda o derecha corren medio segundo, OK aplica).
- **Adelantar:** los archivos H.264 con audio AAC se reproducen directo y se adelantan libremente.
- **La primera vez** que se reproduce un archivo, Real-Debrid puede tardar hasta un minuto y medio en empezar a convertirlo.

## Limitaciones

- El resto se reproduce convertido por Real-Debrid, que convierte solo en orden desde el principio. Si retomás o adelantás a una parte que todavía no convirtió, el video se traba: en saltos cortos la app espera hasta un minuto, y si no, vuelve a donde estabas (o al principio, sin pisar tu progreso guardado).
- Algunas fuentes marcadas como cacheadas (`[RD+]`) en realidad no lo están; la app te ofrece probar la siguiente.
- No incluye perfiles, catálogos de anime, YouTube, archivos locales ni trailers.
- Si se hace un factory reset del Roku, hay que volver a activar el modo desarrollador y correr `npm run deploy`.

## Aviso

La app no incluye, aloja ni indexa contenido: reproduce lo que devuelven los addons que configuraste en tu cuenta. Vos sos responsable de qué addons usás y de tener derecho a ver lo que reproducís.

## Licencia

[MIT](LICENSE)
