e      = require 'expect.js'
path   = require 'path'
fs     = require 'fs'
writer = require '../lib/buffer-writer'


describe 'Buffer Writer', ->
  file = path.join __dirname, 'data/bw.txt'

  beforeEach ->
    fs.unlinkSync file if fs.existsSync file

  afterEach ->
    fs.unlinkSync file if fs.existsSync file

  checkFile = (expect)->
    e(fs.readFileSync(file).toString()).to.be expect

  it 'write into buffer, flush before close ', ->
    w = writer file, 100
    w.write 'a'
    w.write 'b'
    w.write 'c'
    w.write 'def'
    w.write new Buffer 'ghi'
    checkFile ''
    w.close()
    checkFile 'abcdefghi'
  it 'flush buffer to disk, when buffer will be full', ->
    w = writer file, 5
    w.write new Buffer 'ab'
    w.write new Buffer 'cd'
    w.write new Buffer 'e'
    checkFile ''
    w.write new Buffer 'fgh'
    checkFile 'abcde'
    w.write new Buffer 'ijk'
    checkFile 'abcdefgh'
    w.close()
    checkFile 'abcdefghijk'

  it 'flush buffer & data to disk, when buffer will be full and data is too large', ->
    w = writer file, 5
    w.write new Buffer 'ab'
    w.write new Buffer 'cd'
    checkFile ''
    w.write new Buffer 'efghij'
    checkFile 'abcdefghij'
    w.write new Buffer 'kl'
    checkFile 'abcdefghij'
    w.close()
    checkFile 'abcdefghijkl'

