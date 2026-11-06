const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  const jobs = JSON.parse(process.argv[2]);
  for (const [svg, out, w, h, transparent] of jobs) {
    await p.setViewportSize({ width: w, height: h });
    const html = `<html><body style="margin:0;background:transparent">${fs.readFileSync(svg, 'utf8')}</body></html>`;
    await p.setContent(html);
    await p.screenshot({ path: out, omitBackground: transparent, clip: { x: 0, y: 0, width: w, height: h } });
  }
  await b.close();
})();
