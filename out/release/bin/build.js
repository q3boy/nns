// Generated by CoffeeScript 1.7.1
var Parser, args, bar, build, builder, fs, now, pad, parser, path, pbar;

path = require('path');

fs = require('fs');

Parser = require('argparse').ArgumentParser;

pbar = require('../lib/progress-bar');

builder = require('../lib/builder');

pad = function(num) {
  if (num <= 9) {
    return "0" + num;
  } else {
    return "" + num;
  }
};

now = new Date();

now = now.getFullYear() + pad(now.getMonth() + 1) + pad(now.getDate());

parser = new Parser({
  version: '0.0.1',
  addHelp: true,
  description: 'NNS Builder'
});

parser.addArgument(['-d', '--dir'], {
  help: '文件输出目录 [%(defaultValue)s]',
  nargs: '?',
  defaultValue: "/dev/shm/" + now
});

parser.addArgument(['-l', '--index-length'], {
  help: '索引深度 [%(defaultValue)d]',
  nargs: '?',
  defaultValue: 5
});

parser.addArgument(['-p', '--info-packer'], {
  help: '数据文件存储格式 [%(defaultValue)s]',
  nargs: '?',
  defaultValue: 'bin',
  choices: ['bin', 'json']
});

parser.addArgument(['src_file'], {
  help: '数据文件路径 [%(defaultValue)s]',
  nargs: '?',
  defaultValue: path.join(process.cwd(), 'zone_info_town.txt')
});

args = parser.parseArgs();

console.log('Build start...');

build = builder(args);

bar = pbar().start(100 + 100 + 50 * args.index_length);

now = 0;

build.on('load_file', function(per) {
  return bar.change(now + per);
}).on('build_info', function(per) {
  return bar.change(100 + per);
}).on('write_index', function(length, per) {
  var i, _i, _ref, _results;
  _results = [];
  for (i = _i = 1, _ref = args.index_length; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
    if (length === i) {
      _results.push(bar.change(150 + i * 50 + per * 0.5));
    }
  }
  return _results;
}).on('done', function() {
  bar.end();
  return console.log('All done.');
});
