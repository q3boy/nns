if (require.extensions['.coffee']) {
  module.exports = require('./lib/nnspoi.coffee');
} else {
  module.exports = require('./out/release/lib/nnspoi.js');
}
