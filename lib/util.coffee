fs   = require 'fs'
{
  encode, neighbor
  decode,decode_bbox
}    = require 'ngeohash'
Heap = require 'heap'

exports.packZoneInfo = {}
# pack zone data to binary
#     00      01      02      03      04      05      06      07
#     |---------zoneid---------|      |--------latitude--------|
#
#     08      09      0a      0b      0c      0d      0e      0f
#     |--------longitude-------|      |------person number-----|
#
#     10      11      12      13      14      15      16      17        ........
#  typelen|townlen|cotylen|citylen|provlen    |---type+town+county+city+province
exports.packZoneInfo.bin = (zone) ->

  txt = zone.type + zone.town + zone.county + zone.city + zone.province
  zone.blen = 21 + Buffer.byteLength txt
  buf = new Buffer zone.blen
  buf.writeUInt32BE zone.id                          , 0
  buf.writeUInt32BE (0.5 + zone.lati * 1000000) | 0  , 4
  buf.writeUInt32BE (0.5 + zone.long * 1000000) | 0  , 8
  buf.writeUInt32BE zone.pnum                        , 12
  pos1 = 16
  pos2 = 21
  for field in ['type', 'town', 'county', 'city', 'province']
    txt = new Buffer txt unless (txt = zone[field]) instanceof Buffer
    buf.writeUInt8 txt.length, pos1++
    txt.copy buf, pos2
    # buf.write txt, pos2
    pos2 += txt.length
  # buf.writeUInt8    Buffer.byteLength(zone.type)     , 16
  # buf.writeUInt8    Buffer.byteLength(zone.town)     , 17
  # buf.writeUInt8    Buffer.byteLength(zone.county)   , 18
  # buf.writeUInt8    Buffer.byteLength(zone.city)     , 19
  # buf.writeUInt8    Buffer.byteLength(zone.province) , 20
  # buf.write         txt                              , 21
  buf

exports.packZoneInfo.json = (zone) ->
  nzone = {}
  nzone[k] = zone[k] for k of zone when k not in ['offset', 'hash', 'blen']
  buf = new Buffer JSON.stringify nzone
  zone.blen = buf.length
  buf

exports.unpackZoneInfo = {}
exports.unpackZoneInfo.bin_buffer = (buf, start) ->
  offset = 21
  {
    id       : buf.readUInt32BE start+0, true
    lati     : buf.readUInt32BE(start+4, true) / 1000000
    long     : buf.readUInt32BE(start+8, true) / 1000000
    pnum     : buf.readUInt32BE start+12, true
    type     : buf.slice offset, offset += buf.readUInt8 start+16, true
    town     : buf.slice offset, offset += buf.readUInt8 start+17, true
    county   : buf.slice offset, offset += buf.readUInt8 start+18, true
    city     : buf.slice offset, offset += buf.readUInt8 start+19, true
    province : buf.slice offset, offset += buf.readUInt8 start+20, true
  }

zoneInfoBuffer = new Buffer 65536

exports.unpackZoneInfo.bin_fs = (fd, offset, length) ->

  fs.readSync fd, zoneInfoBuffer, 0, length, offset
  offset = 21
  {
    id       : zoneInfoBuffer.readUInt32BE 0, true
    lati     : zoneInfoBuffer.readUInt32BE(4, true) / 1000000
    long     : zoneInfoBuffer.readUInt32BE(8, true) / 1000000
    pnum     : zoneInfoBuffer.readUInt32BE 12, true
    type     : zoneInfoBuffer.slice offset, offset += zoneInfoBuffer.readUInt8 16, true
    town     : zoneInfoBuffer.slice offset, offset += zoneInfoBuffer.readUInt8 17, true
    county   : zoneInfoBuffer.slice offset, offset += zoneInfoBuffer.readUInt8 18, true
    city     : zoneInfoBuffer.slice offset, offset += zoneInfoBuffer.readUInt8 19, true
    province : zoneInfoBuffer.slice offset, offset += zoneInfoBuffer.readUInt8 20, true
  }



exports.unpackZoneInfo.json_buffer = (buf, offset, length) ->
  JSON.parse buf.toString 'utf8', offset, offset+length

exports.unpackZoneInfo.json_fs = (fd, offset, length) ->
  fs.readSync fd, zoneInfoBuffer, 0, length, offset
  JSON.parse zoneInfoBuffer.toString('utf8', 0, length)


# pack gps info
#     00      01      02      03      04      05      06      07
#     |--------latitude--------|      |--------longitude-------|
#
#     08      09      0a      0b      0c      0d
#     |-------zone offset------|      |zone length|
exports.gpsStructLength = 14
exports.packGpsInfo = (zone) ->
  buf = new Buffer 14
  buf.writeUInt32BE (0.5 + zone.lati * 1000000) | 0 , 0
  buf.writeUInt32BE (0.5 + zone.long * 1000000) | 0 , 4
  buf.writeUInt32BE zone.offset                     , 8
  buf.writeUInt16BE zone.blen                       , 12
  buf

exports.unpackGpsInfo = (buf, start) ->
  [
    buf.readUInt32BE(start, true) / 1000000, buf.readUInt32BE(start+4, true) / 1000000
    buf.readUInt32BE(start+8, true), buf.readUInt16BE(start+12, true)
  ]

exports.packIndex = (hash, begin, end) ->
  buf = new Buffer (length = hash.length) + 8
  buf.write hash                                    , 0
  buf.writeUInt32BE begin * exports.gpsStructLength , length
  buf.writeUInt32BE end * exports.gpsStructLength   , length + 4
  buf
exports.unpackIndex = (buf, length, start) ->
  [
    buf.toString 'utf8', start, pos = start + length
    buf.readUInt32BE pos
    buf.readUInt32BE pos + 4
  ]

# consts for distance
radius = 6378137.0
deg180 = Math.PI/180.0
deg360 = Math.PI/360
fl     = 1/298.257

# distance on sphere
exports.distance =
  sphere : (alati, along, blati, blong) ->
    flat = alati * deg180
    flng = along * deg180
    tlat = blati * deg180
    tlng = blong * deg180
    result  = Math.sin(flat) * Math.sin(tlat) + Math.cos(flat) * Math.cos(tlat) * Math.cos(flng-tlng)
    Math.acos(result) * radius

# distance on ellipsoid
  ellipsoid : (alati, along, blati, blong) ->
    sg = Math.sin deg360 * (alati - blati)
    sl = Math.sin deg360 * (along + blong)
    sf = Math.sin deg360 * (alati + blati)

    sg *= sg
    sl *= sl
    sf *= sf

    s = sg * (1 - sl) + (1 - sf) * sl
    c = (1 - sg) * (1 - sl) + sf * sl

    w = Math.atan(Math.sqrt(s / c))
    r = Math.sqrt(s * c) / w
    h1 = (3 * r - 1) / 2 / c
    h2 = (3 * r + 1) / 2 / s

    d = 2 * w * radius
    d * (1 + fl * (h1 * sf * (1 - sg) - h2 * (1 - sf) * sg))

exports.hashBox = (lati, long, length) ->
  hash = encode lati, long, length

  [
    hash
    neighbor hash, [1, 0]
    neighbor hash, [-1, 0]
    neighbor hash, [0, 1]
    neighbor hash, [0, -1]
    neighbor hash, [1, 1]
    neighbor hash, [1, -1]
    neighbor hash, [-1, 1]
    neighbor hash, [-1, -1]
  ]

exports.parseLineText = (line) ->
  [id, txt] = line.split /\t+/g
  id *=1
  [zone, type, pos, pnum] = txt.split(';')
  pos = pos.split ','
  pnum *=1
  [province, city, county, town] = zone.split ' '
  list = []
  for p in pos when p isnt ''
    [lati, long] = p.split ':'
    lati *= 1
    long *= 1
    hash = encode lati, long, 12
    list.push
      id   : id,   hash     : hash
      lati : lati, long     : long
      type : type, pnum     : pnum
      town : town, county   : county
      city : city, province : province
  list
