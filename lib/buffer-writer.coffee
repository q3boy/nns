fs = require 'fs'
class BufferWriter
  constructor : (@file, @size=1048576) ->
    @fd = fs.openSync @file, 'w', '0664'
    @offset = 0 # fs write offset

    @buffer = new Buffer @size
    @length = 0 # buffer length

  write : (data) ->
    data = new Buffer data unless data instanceof Buffer
    {size} = @
    if data.length + @length <= size # copy to buffer not full
      @append data
    else if data.length < size # data is not too large, flush buffer & copy data into buffer
      @flush().append data
    else # data is too large, flush buffer & write data immediately
      @flush()._write data, data.length
    return

  append : (data) ->
    @length += data.copy @buffer, @length
    @

  flush : ->
    if @length > 0
      @_write @buffer, @length
      @length = 0
    @

  _write : (buf, length) ->
    @offset += fs.writeSync @fd, buf, 0, length, @offset

  close : ->
    @flush()
    fs.closeSync @fd

module.exports = (file, size) -> new BufferWriter file, size
module.exports.BufferWriter = BufferWriter
