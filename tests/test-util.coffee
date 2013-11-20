e    = require 'expect.js'
path = require 'path'
fs   = require 'fs'
util = require '../lib/util'

describe 'Util', ->
  it 'hashbox', ->
    {encode} = require 'geo-hash'
    hashs = util.hashBox 30, 120, 12
    e(hashs[0]).to.be encode 30, 120 # mid block correct
    e(hashs.length).to.be 9 # length ok
    e(hash.substr 0, 11).to.be hashs[0].substr 0, 11 for hash in hashs # prefix ok
  it 'distance on sphere', ->
    e(Math.round(util.distance.sphere 30, 120, 40, 110)).to.be 1436941
  it 'distance on ellipsoid', ->
    e(Math.round(util.distance.ellipsoid 30, 120, 40, 110)).to.be 10699694
  it 'pack & unpack gps info', ->
    zone = lati : 30, long : 120, offset : 100, blen : 50
    buf = util.packGpsInfo zone
    e(util.unpackGpsInfo buf, 0).to.eql [30, 120, 100, 50]
  it 'pack & unpack index', ->
    buf = util.packIndex 'abc', 10, 100
    len = util.gpsStructLength
    e(util.unpackIndex buf, 3, 0).to.eql ['abc', 10 * len, 100 * len]
  describe 'parse text line', ->
    it 'one pos', ->
      line = '100049\t江西省 抚州市 广昌县 甘竹镇;城镇;26.948208:116.371327,;1068\t20131111'
      zone = util.parseLineText line
      e(zone).to.eql [
        id       : 100049
        hash     : 'wsfc21g08qnd'
        lati     : 26.948208
        long     : 116.371327
        type     : '城镇'
        pnum     : 1068
        town     : '甘竹镇'
        county   : '广昌县'
        city     : '抚州市'
        province : '江西省'
      ]
    it 'multi pos', ->
      line = '100049\t江西省 抚州市 广昌县 甘竹镇;城镇;26.948208:116.371327,28.948208:136.371327,;1068\t20131111'
      zone = util.parseLineText line
      e(zone).to.eql [
        {
          id       : 100049
          hash     : 'wsfc21g08qnd'
          lati     : 26.948208
          long     : 116.371327
          type     : '城镇'
          pnum     : 1068
          town     : '甘竹镇'
          county   : '广昌县'
          city     : '抚州市'
          province : '江西省'
        }, {
          id       : 100049
          hash     : 'xj0uxjyed1pd'
          lati     : 28.948208
          long     : 136.371327
          type     : '城镇'
          pnum     : 1068
          town     : '甘竹镇'
          county   : '广昌县'
          city     : '抚州市'
          province : '江西省'
        },
      ]

  describe 'pack zone info', ->
    describe 'binary', ->
      it '& unpack with buffer', ->
        zone =
          id       : 1, lati : 2
          long     : 3, pnum : 4
          type     : new Buffer 'type'
          town     : new Buffer 'town'
          county   : new Buffer 'county'
          city     : new Buffer 'city'
          province : new Buffer 'province'
        buf = util.packZoneInfo.bin zone
        zone1 = util.unpackZoneInfo.bin_buffer buf, 0
        zone1.blen = buf.length
        e(zone1).to.eql zone

      it '& unpack with file handle', ->
        file = path.join __dirname, 'data/packzone.bin'
        zone =
          id       : 1, lati : 2
          long     : 3, pnum : 4
          type     : new Buffer 'type'
          town     : new Buffer 'town'
          county   : new Buffer 'county'
          city     : new Buffer 'city'
          province : new Buffer 'province'
        buf = util.packZoneInfo.bin zone
        fs.unlinkSync file if fs.existsSync file
        fs.writeFileSync file, buf

        fd = fs.openSync file, 'r'

        zone1 = util.unpackZoneInfo.bin_fs fd, 0, buf.length
        zone1.blen = buf.length
        e(zone1).to.eql zone

        fs.unlinkSync file if fs.existsSync file

    describe 'text', ->
      it '& unpack with buffer', ->
        zone =
          id       : 1, lati : 2
          long     : 3, pnum : 4
          type     : 'type'
          town     : 'town'
          county   : 'county'
          city     : 'city'
          province : 'province'
        buf = util.packZoneInfo.json zone
        zone1 = util.unpackZoneInfo.json_buffer buf, 0, zone.blen
        zone1.blen = buf.length
        e(zone1).to.eql zone

      it '& unpack with file handle', ->
        file = path.join __dirname, 'data/packzone.json'
        zone =
          id       : 1, lati : 2
          long     : 3, pnum : 4
          type     : 'type'
          town     : 'town'
          county   : 'county'
          city     : 'city'
          province : 'province'

        buf = util.packZoneInfo.json zone
        fs.unlinkSync file if fs.existsSync file
        fs.writeFileSync file, buf

        fd = fs.openSync file, 'r'

        zone1 = util.unpackZoneInfo.json_fs fd, 0, buf.length
        zone1.blen = buf.length
        e(zone1).to.eql zone

        fs.unlinkSync file if fs.existsSync file






