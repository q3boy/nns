e       = require 'expect.js'
path    = require 'path'
fs      = require 'fs'
rm      = require 'find-remove'
builder = require '../lib/builder'
finder  = require '../lib/finder'
util    = require '../lib/util'


describe 'Finder', ->

  dir = path.join __dirname,  'build/data'
  b = f = null

  bd = (cb)->
    b = builder
      dir          : dir
      src_file     : path.join __dirname, 'data/zone_info.txt'
      index_length : 3
      info_packer  : 'json'
    b.on 'done', cb


  beforeEach ->
    f = null
  afterEach ->
    f.close() if f
  after -> rm dir

  describe 'load data', ->

    loadAssert = (read_info, event, done, cb) ->
      flag = false
      f = finder dir : dir, read_info : read_info
      f.on event, (args...)->
        cb.apply f, args
        flag = true
      f.on 'loaded', ->
        e(flag).to.be true
        done()
    describe 'ok', ->
      before bd
      describe 'zone info', ->
        it 'in fs', (done) ->
          loadAssert 'fs', 'zone_load', done, -> e(typeof @zone).to.be 'number'
        it 'in fs', (done) ->
          loadAssert 'buffer', 'zone_load', done, ->
            e(@zone).to.be.a Buffer
            e(@zone.length).to.be fs.statSync(path.join dir, 'zone.bin').size
      it 'gps info', (done) ->
        loadAssert 'buffer', 'gps_load', done, ->
          e(@gps).to.be.a Buffer
          e(@gps.length).to.be fs.statSync(path.join dir, 'gps.bin').size
      it 'index', (done) ->
        loadAssert 'buffer', 'index_load', done, (length)->
          if length is 1
            e(@index[1]).to.eql w : [0, 126]
          else if length is 2
            e(@index[2].wm).to.eql [0]
            e(@index[2].ws).to.eql [28, 84]
          else
            e(@index[3].wm7).to.eql [0]
            e(@index[3].ws0).to.eql [28, 42]
    describe 'error', ->
      beforeEach bd
      loadErrorAssert = (file, done) ->
        fs.unlinkSync path.join dir, file
        f = finder dir : dir
        f.on 'error', (err)->
          e(err.code).to.be 'ENOENT'
          e(err.path).to.be path.join dir, file
          done()
      it 'files info', (done)-> loadErrorAssert 'files.json', done
      it 'zone info in fd', (done)-> loadErrorAssert 'zone.bin', done
      it 'zone info in buffer', (done)->
        fs.unlinkSync path.join dir, 'zone.bin'
        f = finder dir : dir, read_info : 'buffer'
        f.on 'error', (err)->
          e(err.code).to.be 'ENOENT'
          e(err.path).to.be path.join dir, 'zone.bin'
          done()
      it 'gps info file', (done)-> loadErrorAssert 'gps.bin', done
      it 'index file', (done)-> loadErrorAssert 'index.2', done



  describe 'search', ->
    before bd
    dist = util.distance.sphere
    dirty = (lati, long, num = 3)->
      zones = b.data
      for zone in zones
        zone.distance = dist lati, long, zone.lati, zone.long

      zones.sort (a, b) -> a.distance - b.distance
      zones.slice 0, num



    describe 'nearest poi', ->
      it 'found', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          zone = f.search 30, 120, 1
          zone1 = dirty 30, 120, 1
          e(zone[k]).to.be zone1[0][k] for k of zone
          done()
      it 'found min_index too small', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          zone = f.search 30, 120, -1
          zone1 = dirty 30, 120, 1
          e(zone[k]).to.be zone1[0][k] for k of zone
          done()
      it 'found only one in hash box', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          zone = f.search 30, 106, 1
          zone1 = dirty 30, 106, 1
          e(zone[k]).to.be zone1[0][k] for k of zone
          done()
      it 'found on spot', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          zone = f.search 23.119328, 113.620748, 1
          zone1 = dirty 23.119328, 113.620748, 1
          e(zone[k]).to.be zone1[0][k] for k of zone
          done()
      it 'not found', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          zone = f.search 1, 2
          e(zone).to.be null
          done()

    describe 'topn poi', ->
      it 'found 3+', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          list = f.topn 30, 120, 3, 1
          list.sort (a, b)-> a.distance - b.distance
          list1 = dirty 30, 120, 3
          e(list.length).to.be 3
          for zone, i in list
            e(zone[k]).to.be list1[i][k] for k of zone
          done()
      it 'found 3+ min_index too small', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          list = f.topn 30, 120, 3, -1
          list.sort (a, b)-> a.distance - b.distance
          list1 = dirty 30, 120, 3
          e(list.length).to.be 3
          for zone, i in list
            e(zone[k]).to.be list1[i][k] for k of zone
          done()
      it 'found num too big', (done)->
        f = finder dir : dir, read_info : 'fs', max_topn : 2
        f.on 'loaded', ->
          list = f.topn 30, 120, 100, 1
          list.sort (a, b)-> a.distance - b.distance
          list1 = dirty 30, 120, 2
          e(list.length).to.be 2
          for zone, i in list
            e(zone[k]).to.be list1[i][k] for k of zone
          done()
      it 'found 3-', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          list = f.topn 23.11, 113.62, 3, 3
          list.sort (a, b)-> a.distance - b.distance
          list1 = dirty 23.11, 113.62, 3
          e(list.length).to.below 3
          for zone, i in list
            e(zone[k]).to.be list1[i][k] for k of zone
          done()

      it 'top1', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          list = f.topn 30, 120, 1, 1
          list.sort (a, b)-> a.distance - b.distance
          list1 = dirty 30, 120, 1
          e(list.length).to.be 1
          for zone, i in list
            e(zone[k]).to.be list1[i][k] for k of zone
          done()

      it 'top1 not found', (done)->
        f = finder dir : dir, read_info : 'fs'
        f.on 'loaded', ->
          list = f.topn 1, 2, 1, 1
          e(list.length).to.be 0
          done()
      it 'not found', (done) ->
        f = finder dir : dir, read_info : 'fs', min_index : 1
        f.on 'loaded', ->
          list = f.topn 1, 2
          e(list.length).to.be 0
          done()


