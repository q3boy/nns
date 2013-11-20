path    = require 'path'
fs      = require 'fs'
Parser  = require('argparse').ArgumentParser
pbar    = require '../lib/progress-bar'
builder = require '../lib/builder'

pad = (num) -> if num <= 9 then "0#{num}" else "#{num}"

now = new Date()
now = now.getFullYear() + pad(now.getMonth()+1) + pad(now.getDate())

parser = new Parser version: '0.0.1', addHelp: true, description: 'NNS Builder'

parser.addArgument [ '-d', '--dir' ],
  help: '文件输出目录 [%(defaultValue)s]', nargs: '?', defaultValue: "/dev/shm/#{now}"

parser.addArgument [ '-l', '--index-length' ],
  help: '索引深度 [%(defaultValue)d]', nargs: '?', defaultValue: 5

parser.addArgument [ '-p', '--info-packer' ],
  help: '数据文件存储格式 [%(defaultValue)s]', nargs: '?', defaultValue: 'bin', choices : ['bin', 'json']

parser.addArgument ['src_file'],
  help: '数据文件路径 [%(defaultValue)s]', nargs: '?',
  defaultValue: path.join process.cwd(), 'zone_info_town.txt'

args = parser.parseArgs()

# args.dir      = fs.realpathSync args.dir
# args.src_file = fs.realpathSync args.src_file


console.log 'Build start...'
build = builder args
bar = pbar().start 100 + 100 + 50 * args.index_length
now = 0
build.on 'load_file', (per)->
  bar.change now + per
.on 'build_info', (per)->
  bar.change 100 + per
.on 'write_index', (length, per)->
  for i in [1..args.index_length] when length is i
    bar.change 150 + i * 50 + per * 0.5
.on 'done', ->
  bar.end()
  console.log 'All done.'

