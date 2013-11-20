class Cursor
  constructor :(fd) ->
    @fd = fd
    @esc = "\u001b["
    @num_type =
      left    : "D"
      right   : "C"
      up      : "A"
      down    : "B"
      delline : "M"
    @type =
      hide : "?25l"
      end  : "K"
      show : "?25h"

  getChars : (type, num) ->
    if @num_type[type] isnt `undefined`
      num = (if num is `undefined` then 1 else num * 1)
      @esc + num + @num_type[type]
    else
      @esc + @type[type]

  left : (num) ->
    @write @getChars("left", num)

  # right : (num) ->
  #   @write @getChars("right", num)

  up : (num) ->
    @write @getChars("up", num)

  # down : (num) ->
  #   @write @getChars("down", num)

  delLine : (num) ->
    @write @getChars("delline", num)

  # hide : ->
  #   @write @getChars("hide")

  show : ->
    @write @getChars("show")

  # end : ->
  #   @write @getChars("end")

  home : ->
    @left process.stdout.columns

  clearLine : ->
    @delLine()
    @home()

  write : (chars) ->
    @fd.write chars

repeat = (str, num) -> if num*1 <= 0 then '' else new Array(num * 1 + 1).join str

class ProgressBar
  constructor : ->
    @isTTY = process.stderr.isTTY
    return unless @isTTY
    @total = 100
    @now = 0
    @cursor = new Cursor(process.stderr)

  start : (total) ->
    return @ unless @isTTY
    @total = total
    @cursor.clearLine()
    @cursor.write @getLine()
    @

  change : (now) ->
    return @ unless @isTTY
    @now = now
    @cursor.up()
    @cursor.clearLine()
    @cursor.write @getLine()
    @

  end : ->
    return @ unless @isTTY
    @change @total
    @cursor.show()
    @

  getLine : ->
    line = "["
    width = process.stderr.columns - 7
    left = Math.floor(@now / @total * width)
    line += repeat("#", left)
    line += "+"  if line.length <= width
    blank = width - left - 1
    line += repeat(" ", if blank > 0 then blank else 0)
    line += "] "
    used = Math.round(@now / @total * 100)
    line += if used > 0 then used else 0
    line += "%\n"
    line
module.exports = ->
  new ProgressBar
