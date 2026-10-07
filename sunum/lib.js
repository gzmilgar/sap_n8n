const pptxgen = require('pptxgenjs');
// shared primitives for the SIT deck - extracted from the first build
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const sharp = require('sharp');
const Fi = require('react-icons/fi');

// ---- palette: two systems, two colours ----------------------------------
const NAVY = '0F1A2B', INK = '14202E', MUTED = '6B7A8C';
const SAP = '0A6ED1', SAP_SOFT = 'E4EFFB';
const N8N = 'EA4B71', N8N_SOFT = 'FCE8ED';
const PANEL = 'EEF3F8', LINE = 'D9E1EA', WHITE = 'FFFFFF', ICE = 'CADCFC';
const OK = '2E7D4F', OKBG = 'E4F1E9', WAIT = 'B07503', WAITBG = 'F7EFDC';

const H = 'Cambria', B = 'Calibri', M = 'Courier New';

async function icon(name, color, size = 256) {
  const svg = renderToStaticMarkup(React.createElement(Fi[name], { color: '#' + color, size, strokeWidth: 2 }));
  const buf = await sharp(Buffer.from(svg)).png().toBuffer();
  return 'image/png;base64,' + buf.toString('base64');
}

// icon inside a soft circle - the deck's recurring motif
async function badge(slide, name, x, y, d, bg, fg) {
  slide.addShape('ellipse', { x, y, w: d, h: d, fill: { color: bg }, line: { color: bg } });
  const pad = d * 0.27;
  slide.addImage({ data: await icon(name, fg), x: x + pad, y: y + pad, w: d - 2 * pad, h: d - 2 * pad });
}

function pill(slide, text, x, y, bg, fg, w = 1.05) {
  slide.addShape('roundRect', { x, y, w, h: 0.28, fill: { color: bg }, line: { color: bg }, rectRadius: 0.14 });
  slide.addText(text, { x, y, w, h: 0.28, fontFace: B, fontSize: 9.5, bold: true, color: fg,
    align: 'center', valign: 'middle', margin: 0, isTextBox: true, charSpacing: 1 });
}

function eyebrow(slide, text, x, y, color, w = 6) {
  slide.addText(text.toUpperCase(), { x, y, w, h: 0.3, fontFace: B, fontSize: 10.5, bold: true,
    color, charSpacing: 3, margin: 0, isTextBox: true });
}

function title(slide, text, x, y, w, color = INK, size = 28, h = 0.65) {
  slide.addText(text, { x, y, w, h, fontFace: H, fontSize: size, bold: true, color,
    margin: 0, isTextBox: true, valign: 'top' });
}

function arrow(slide, x1, y1, x2, y2, color = MUTED) {
  slide.addShape('line', { x: x1, y: y1, w: x2 - x1, h: y2 - y1,
    line: { color, width: 1.5, endArrowType: 'triangle' } });
}


module.exports = { pptxgen, icon, badge, pill, eyebrow, title, arrow,
  NAVY, INK, MUTED, SAP, SAP_SOFT, N8N, N8N_SOFT, PANEL, LINE, WHITE, ICE, OK, OKBG, WAIT, WAITBG, H, B, M };
