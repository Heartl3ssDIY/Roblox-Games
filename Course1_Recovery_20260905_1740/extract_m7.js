const fs = require("fs");

const source = fs.readFileSync(process.argv[2], "utf8");
const start = source.indexOf("fm.LoadLevel=function");
const end = source.indexOf("var gm=", start);
if (start < 0 || end < 0) throw new Error("M7 level function was not found");

const body = source.slice(start, end);
const tiles = [];
const tilePattern = /new b\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),"([^"]+)",(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)/g;
for (const match of body.matchAll(tilePattern)) {
  tiles.push({
    x: Number(match[1]),
    y: Number(match[2]),
    width: Number(match[3]),
    height: Number(match[4]),
    type: Number(match[5]),
    layer: Number(match[6]),
    extra: Number(match[7]),
    sprite: match[8],
    flags: Number(match[9]),
    angle: Number(match[10]),
  });
}

const checkpoints = [];
const checkpointPattern = /new Na\((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)/g;
for (const match of body.matchAll(checkpointPattern)) {
  checkpoints.push({
    x: Number(match[1]),
    y: Number(match[2]),
    angle: Number(match[3]),
  });
}

process.stdout.write(JSON.stringify({ tiles, checkpoints }));
