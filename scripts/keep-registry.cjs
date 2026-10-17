// Preloaded into the Rooibos CLI: its roku-deploy deletes the dev channel before sideloading,
// which wipes the app's registry (the saved session). Sideloading over it keeps the registry.
const path = require('node:path')
const rooibos = path.dirname(require.resolve('rooibos-roku/package.json'))
const { RokuDeploy } = require(require.resolve('roku-deploy', { paths: [rooibos] }))
const sideload = RokuDeploy.prototype.sideload
RokuDeploy.prototype.sideload = function (options) {
  return sideload.call(this, { ...options, deleteDevChannel: false })
}
