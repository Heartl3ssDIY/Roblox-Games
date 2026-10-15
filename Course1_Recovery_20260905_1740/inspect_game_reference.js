const fs = require("fs");

const sourcePath = process.argv[2];
const needle = process.argv[3];
const radius = Number(process.argv[4] || 1200);
const source = fs.readFileSync(sourcePath, "utf8");

let start = 0;
let count = 0;
while (count < 30) {
  const index = source.indexOf(needle, start);
  if (index < 0) break;
  const left = Math.max(0, index - radius);
  const right = Math.min(source.length, index + needle.length + radius);
  process.stdout.write("\nMATCH " + (count + 1) + " at " + index + "\n");
  process.stdout.write(source.slice(left, right).replace(/;/g, ";\n"));
  process.stdout.write("\n");
  start = index + needle.length;
  count += 1;
}

if (!count) {
  process.stderr.write("No matches found\n");
  process.exitCode = 1;
}
