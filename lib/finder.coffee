fs             = require 'fs'
path           = require 'path'
Heap           = require 'heap'
stream         = require 'stream'
{EventEmitter} = require 'events'
{
  unpackZoneInfo, unpackIndex
  gpsStructLength, unpackGpsInfo
  distance, hashBox
}              = require './util'

class Finder extends EventEmitter

  constructor : (options) ->
    @options =
      dir         : path.join __dirname, '../data' # desc files dir
      distance    : 'sphere'                       # distance algorithm
      read_info   : 'fs'                           # save zone info in mem/fs
      max_topn    : 100                            # max topn number
      min_index   : 3                              # minimal index length when search

    @options[k] = options[k] for k of options when @options[k]

    # set distance method
    @distance = distance[@options.distance]

    # read files info
    fs.readFile path.join(@options.dir, 'files.json'), (err, data)=>
      return @emit 'error', err if err
      @finfo = JSON.parse data.toString()

      # set unpack method
      @unpackInfo = unpackZoneInfo["#{@finfo.packer}_#{@options.read_info}"]

      # init indexes
      @index = []

      # max index lenggth
      @indexLength = @finfo.index.length - 1

      # event loaded
      loadFlag = @indexLength + 2
      load = => @emit 'loaded' if 0 is --loadFlag
      @on 'index_load' , load
      @on 'gps_load'   , load
      @on 'zone_load'  , load

      # load all data
      @loadGps().loadZone()
      @loadIndex length for length in [1..@indexLength]

  # load one index file
  loadIndex : (length)->
    file = path.join @options.dir, @finfo.index[length]
    fs.readFile file, (err, data)=>
      return @emit 'error', err if err
      index = {}
      # extract index file
      for start in [0...data.length] by length + 8
        [hash, begin, end] = unpackIndex data, length, start
        index[hash] = if begin is end then [begin] else [begin, end]
      @index[length] = index
      data = null
      @emit 'index_load', length
      return
    @


  loadGps : ->
    file = path.join @options.dir, @finfo.gps
    fs.readFile file, (err, data) =>
      return @emit 'error', err if err
      @gps = data
      @emit 'gps_load'
    @

  loadZone : ->
    file = path.join @options.dir, @finfo.zone
    # info use fs
    if @options.read_info is 'fs'
      fs.open file, 'r', (err, @zone)=>
        return @emit 'error', err if err
        @emit 'zone_load'
    # info use buffer
    else
      fs.readFile file, (err, data) =>
        return @emit 'error', err if err
        @zone = data
        @emit 'zone_load'
    @

  # heap sort comparer
  sortList : (a, b) -> a[4] - b[4]

  # get topn poi
  topn : (lati, long, num = 3, min_index = @options.min_index) ->
    # use search when n number is 1
    if num is 1
      return [] if null is zone = @search lati, long, min_index
      return [zone]
    # max number for performance
    num = @options.max_topn if num > @options.max_topn
    # min_index greater then 0
    min_index = 1 if min_index < 1

    # get all gps info
    list = []
    i = @indexLength
    # break when i <= min_index or length of list greater then n number
    while i >= min_index and list.length < num
      l = @_searchIndex lati, long, i--
      # append result of index searching to list
      list.push zone for zone in l

    # create new smallest heap with negative distance
    heap = new Heap @sortList
    # heap data init

    num = list.length if num > list.length


    for i in [0...num]
      zone = list[i]
      zone[4] = 0 - @distance lati, long, zone[0], zone[1]
      heap.push zone

    # check rest of list, replace heap root with current item when distance is smaller (nagative greater)
    for i in [num...list.length]
      zone = list[i]
      zone[4] = 0 - @distance lati, long, zone[0], zone[1]
      heap.replace zone if zone[4] > heap.top()[4]
    list = []

    # topn done, get all info data & recover distance
    for zone in heap.toArray()
      z = @unpackInfo @zone, zone[2], zone[3]
      z.distance = 0 - zone[4]
      list.push z
    # return result
    list

  search : (lati, long, min_index = @options.min_index) ->
    # min_index greater then 0
    min_index = 1 if min_index < 1

    list = []
    i = @indexLength
    # break when i <= min_index or list is not empty
    while i >= min_index and list.length is 0
      list = @_searchIndex lati, long, i--

    found = null
    switch list.length
      # return null when found nothing
      when 0 then return null
      # fast return when only on zone in list
      when 1
        found = [list[0][2], list[0][3]]
        min = [@distance lati, long, list[0][0], list[0][1]]
      else
        # find minimal poi
        min = [999999999, null]
        for zone in list
          dist = @distance lati, long, zone[0], zone[1]
          # return this zone when distancs is zero
          if dist is NaN or dist is 0
            found = [zone[2], zone[3]]
            min[0] = 0
            break
          min = [dist, [zone[2], zone[3]]] if dist < min[0]
        found = min[1] unless found

    # unpack info data & return
    zone = @unpackInfo @zone, found[0], found[1]
    zone.distance = min[0]
    zone

  # search poi in special length of index
  _searchIndex : (lati, long, length) ->
    # get a 3x3 hashbox
    box = hashBox lati, long, length
    list = []
    index = @index[length]
    for hash in box
      if poi = index[hash]
        # only one poi in index
        if poi.length is 1
          list.push unpackGpsInfo @gps, poi[0]
        # index has multi poi (offset & length)
        else
          for offset in [poi[0]..poi[1]] by gpsStructLength
            list.push unpackGpsInfo @gps, offset
    list

  close : ->
    fs.closeSync @zone if @zone and @options.read_info is 'fs'
    @zone = null
    @gps = null
    @index[i] = null for i in [0..@indexLength]

    return


module.exports = (opt) -> new Finder opt
module.exports.Finder = Finder

# a = new Finder
# a.on 'loaded', ->
#   b = a.topn 30, 120
#   console.log b
#   console.log 1

  # console.time 'a'
  # console.log process.memoryUsage()
  # for i in [0...100000]
  #   c = a.topn 30, 120, 10
  #   console.log process.memoryUsage().rss if 0 is i % 10000
  # console.timeEnd 'a'
  # console.log process.memoryUsage()
  # console.log c
#   console.log c.type.toString()
#   console.log c.town.toString()
#   console.log c.county.toString()
#   console.log c.city.toString()
#   console.log c.province.toString()
#   # b = a.search 27.987322, 85.983252, 5
#   # console.log b.type.toString()
#   # console.log b.town.toString()
#   # console.log b.county.toString()
#   # console.log b.city.toString()
#   # console.log b.province.toString()
