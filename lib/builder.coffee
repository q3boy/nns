fs               = require 'fs'
path             = require 'path'
readline         = require 'readline'
stream           = require 'stream'
{sync:mkdirp}    = require 'mkdirp'
{EventEmitter}   = require 'events'
{encode:geohash} = require 'ngeohash'
{
  packZoneInfo
  packGpsInfo
  packIndex
  parseLineText
}                = require './util'
writer           = require './buffer-writer'

class Builder extends EventEmitter

  constructor : (options) ->
    @options =
      dir          : 'data'               # desc files dir
      src_file     : 'zone_info_town.txt' # data file path
      index_length : 5                    # max geohash length of index
      info_packer  : 'bin'                # info pack use bin/json
      line_parser  : 'text'               # line parser

    # overwrite options
    @options[k] = options[k] for k of options when @options[k]

    @lineParser = parseLineText

    @packer = packZoneInfo[@options.info_packer]

    @dir = @options.dir
    mkdirp @dir

    @data = []
    @finfo =
      packer : @options.info_packer
      index  : []

    # load data begin
    @on 'loaded', ->
      # build info files
      @buildInfo()
      # build all index files
      @buildIndex i for i in [1..@options.index_length]
      # write files info
      fs.writeFileSync path.join(@dir, 'files.json'), JSON.stringify @finfo, null, ' '
      process.nextTick =>
        @emit 'done'
      return

    @loadFromFile()

  loadFromFile : ->
    {size} = fs.statSync @options.src_file
    @emit 'load_file', 0
    now = 0
    # stream read
    streamIn = fs.createReadStream @options.src_file
    # empty stream for readline output
    streamOut = new stream
    # create readline
    rl = readline.createInterface streamIn, streamOut
    num = 0
    # on one line
    rl.on 'line', (line)=>
      @data.push zone for zone in  @lineParser line

      @emit 'load_file', now/size*100 if 0 is num++ % 2000
      now += Buffer.byteLength(line) + 1
    # all done
    rl.on 'close', =>
      @emit 'load_file', 100
      # unique datas
      @sort().uniq()
      @emit 'loaded'

  sort : ->
    @data.sort (a, b) -> if a.hash < b.hash then -1 else 1
    @

  uniq : ->
    prev = []; data = []
    data.push prev = curr for curr in @data when prev.lati isnt curr.lati or prev.long isnt curr.long
    @data = data
    @

  buildInfo : ->
    size = @data.length
    @emit 'build_info', 0
    # new writers
    zwriter = writer path.join @dir, @finfo.zone = 'zone.bin'
    gwriter = writer path.join @dir, @finfo.gps = 'gps.bin'

    offset = 0
    for zone, num in @data
      # set offset
      zone.offset = offset
      # next offset
      offset += (buf = @packer zone).length
      # write zone info line
      zwriter.write buf
      # write gps line
      gwriter.write packGpsInfo zone
      @emit 'build_info', num/size*100 if 0 is num % 2000
    # end all
    zwriter.close()
    gwriter.close()
    @emit 'build_info', 100
    @

  buildIndex : (length)->
    # hash index in memory
    index = {}
    size = @data.length
    @emit 'build_index', length, 0
    num = 0
    for zone, pos in @data
      hash = geohash zone.lati, zone.long, length
      if index[hash]
        index[hash].push pos
      else
        num++
        index[hash] = [pos]
      @emit 'build_index', length, pos/size*100 if 0 is pos % 2000
    @emit 'build_index', length, 100
    # create write stream
    w = writer path.join @dir, @finfo.index[length] = "index.#{length}"

    # write hash line
    size = num
    @emit 'write_index', length, 0
    now = 0
    for hash, list of index
      w.write packIndex hash, list[0], list.pop()
      @emit 'write_index', length, now/size*100 if 0 is now % 500
      now++
    w.close()
    @emit 'write_index', length, 100

module.exports = (opt)-> new Builder opt
module.exports.Builder = Builder
