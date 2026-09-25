#!/usr/bin/env node
// Renders the app icon from Design/icon.svg.
//
// Produces opaque PNGs (App Store icons must not have an alpha channel):
//   KimbiaSync/Assets.xcassets/AppIcon.appiconset/icon-1024.png  (1024 px)
//   web/icon.png                                                  (512 px)
//
// See Design/README.md for the one-liner that installs @resvg/resvg-js into
// a temporary directory first.

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { Resvg } = require("@resvg/resvg-js");

const repo = path.resolve(__dirname, "..");
const svg = fs.readFileSync(path.join(__dirname, "icon.svg"), "utf8");

// resvg always emits RGBA PNGs. App Store Connect rejects icons that carry an
// alpha channel at all (even a fully opaque one), so re-encode the raw pixels
// as an 8-bit RGB PNG.
function encodeRGB(width, height, rgba) {
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter type: None
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const o = y * (stride + 1) + 1 + x * 3;
      if (rgba[i + 3] !== 255) throw new Error(`pixel (${x},${y}) is not opaque`);
      raw[o] = rgba[i];
      raw[o + 1] = rgba[i + 1];
      raw[o + 2] = rgba[i + 2];
    }
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body));
    return Buffer.concat([len, body, crc]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bit depth
  header[9] = 2; // colour type: RGB
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function render(size, outPath) {
  const image = new Resvg(svg, { fitTo: { mode: "width", value: size } }).render();
  fs.writeFileSync(path.join(repo, outPath), encodeRGB(image.width, image.height, image.pixels));
  console.log(`wrote ${outPath} (${size}px)`);
}

render(1024, "KimbiaSync/Assets.xcassets/AppIcon.appiconset/icon-1024.png");
render(512, "web/icon.png");
