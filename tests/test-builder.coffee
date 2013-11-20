e       = require 'expect.js'
path    = require 'path'
fs      = require 'fs'
rm      = require 'find-remove'
builder = require '../lib/builder'
util    = require '../lib/util'

dir = path.join __dirname,  'build/data'
describe 'Builder', ->
  it 'json info file', (done)->
    b = builder
      dir          : dir
      src_file     : path.join __dirname, 'data/zone_info.txt'
      index_length : 2
      info_packer  : 'json'

    b.on 'done', (per)->
      return if per < 100
      bin = fs.readFileSync path.join dir, @finfo.zone
      zone = util.unpackZoneInfo.json_buffer bin, 0, b.data[0].blen
      delete zone.hash
      delete zone.offset
      delete zone.blen
      e(zone).to.eql
        id       : 100056
        lati     : 30.889946
        long     : 106.816818
        pnum     : 1068
        type     : '城镇'
        town     : '清溪场镇'
        county   : '渠县'
        city     : '达州市'
        province : '四川省'
      done()
  describe 'binary info file', ->
    b = null
    beforeEach ->
      b = builder
        dir          : dir
        src_file     : path.join __dirname, 'data/zone_info.txt'
        index_length : 2
    after -> rm dir

    it 'load file', (done)->
      flag = false
      b.on 'load_file', (per) ->
        return if per < 100
        flag = true
        e(b.data.length).to.be 10
        e(b.data[9]).to.eql
          id       : 100056
          hash     : 'wm7zwxmdur23'
          lati     : 30.889946
          long     : 106.816818
          type     : '城镇'
          pnum     : 1068
          town     : '清溪场镇'
          county   : '渠县'
          city     : '达州市'
          province : '四川省'
      b.on 'done', ->
        e(flag).to.be true
        done()

    it 'sort & unique data', (done)->
      flag = false
      b.on 'loaded', ->
        flag = true
        prev = null
        for {hash} in b.data
          e(hash).to.be.above prev if prev
          prev = hash
      b.on 'done', ->
        e(flag).to.be true
        done()


    it 'build zone info file', (done)->
      flag = false
      b.on 'build_info', (per)->
        return if per < 100
        flag = true
        bin = fs.readFileSync path.join dir, @finfo.zone
        zone = util.unpackZoneInfo.bin_buffer bin, 0
        e(zone).to.eql
          id       : 100056
          lati     : 30.889946
          long     : 106.816818
          pnum     : 1068
          type     : new Buffer '城镇'
          town     : new Buffer '清溪场镇'
          county   : new Buffer '渠县'
          city     : new Buffer '达州市'
          province : new Buffer '四川省'
      b.on 'done', ->
        e(flag).to.be true
        done()

    it 'build gps info file', (done)->
      flag = false
      b.on 'build_info', (per) ->
        return if per < 100
        flag = true
        bin = fs.readFileSync path.join dir, @finfo.gps
        gps = util.unpackGpsInfo bin, 0
        e(gps).to.eql [30.889946, 106.816818, 0, 63]
      b.on 'done', ->
        e(flag).to.be true
        done()

    it 'build index', (done)->
      flag = false
      b.on 'write_index', (length, per) ->
        return if per < 100
        flag = true
        bin = fs.readFileSync path.join dir, @finfo.index[length]
        e(util.unpackIndex bin, length, 0).to.eql if length is 2 then ['wm', 0, 0] else [ 'w', 0, 126 ]
      b.on 'done', ->
        e(flag).to.be true
        done()

    it 'write file info', (done)->
      b.on 'done', () ->
        json = JSON.parse fs.readFileSync(path.join @dir, 'files.json').toString()
        delete json.index[0]
        e(json).to.eql @finfo
        done()

    # # b.on 'done', done
