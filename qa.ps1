param(
  [int]$Port = 4173
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$qaDir = Join-Path $root 'qa'
$index = Join-Path $root 'index.html'
$scriptCopy = Join-Path $qaDir 'index-script.js'
$proc = $null
Set-Location $root
New-Item -ItemType Directory -Force $qaDir | Out-Null

function Write-Section([string]$title) { Write-Host "`n== $title ==" }

try {
  Write-Section 'Stub scan'
  $stubMatches = Select-String -Path $index -Pattern 'TODO|stub|placeholder' -CaseSensitive:$false
  if ($stubMatches) { throw "Stub text found:`n$($stubMatches | Out-String)" }
  Write-Host 'No stub text found.'

  Write-Section 'Extract JS'
  @'
from pathlib import Path
import re
html = Path('index.html').read_text(encoding='utf-8')
match = re.search(r'<script>\s*(.*?)\s*</script>\s*</body>', html, re.S)
if not match:
    raise SystemExit('Main script block not found')
Path('qa/index-script.js').write_text(match.group(1), encoding='utf-8')
print(len(match.group(1)))
'@ | python -

  Write-Section 'Syntax check'
  node --check $scriptCopy

  Write-Section 'Link, asset, and structure check'
  @'
from pathlib import Path
from html.parser import HTMLParser

root = Path('.')
html = (root / 'index.html').read_text(encoding='utf-8')

class Finder(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.images = set(), [], []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs: self.ids.add(attrs['id'])
        if tag == 'a' and 'href' in attrs: self.links.append(attrs['href'])
        if tag == 'img' and 'src' in attrs: self.images.append(attrs['src'])

finder = Finder(); finder.feed(html)
missing = []
for href in finder.links:
    if href.startswith('#') and href[1:] not in finder.ids:
        missing.append(f'missing anchor {href}')
    if href.startswith('assets/') and not (root / href).exists():
        missing.append(f'missing asset {href}')
for src in finder.images:
    if src.startswith('assets/') and not (root / src).exists():
        missing.append(f'missing image {src}')
required_ids = {'home','meet','priorities','experience','statement','materials','contact'}
missing.extend(f'missing required section #{x}' for x in sorted(required_ids - finder.ids))
if missing: raise SystemExit('\n'.join(missing))
print(f'OK: {len(finder.ids)} ids, {len(finder.links)} links, {len(finder.images)} images')
'@ | python -

  Write-Section 'Browser interaction and visual smoke test'
  $proc = Start-Process python -ArgumentList '-m','http.server',"$Port",'--bind','127.0.0.1' -WorkingDirectory $root -PassThru -WindowStyle Hidden
  Start-Sleep -Seconds 2
  $env:SITE_URL = "http://127.0.0.1:$Port/index.html"
  @'
const { chromium } = require('playwright');
(async() => {
  const browser = await chromium.launch({ headless: true });
  const errors = [];
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1 });
  page.on('pageerror', err => errors.push(`pageerror: ${err.message}`));
  page.on('console', msg => { if (msg.type() === 'error') errors.push(`console: ${msg.text()}`); });
  const url = process.env.SITE_URL;
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => document.getElementById('loader')?.classList.contains('hidden'), null, { timeout: 15000 });

  for (const theme of ['navy','ivory','midnight']) {
    if (!(await page.locator('#customizer').evaluate(el => el.classList.contains('open')))) await page.click('#customizerToggle');
    await page.click(`#themeControls [data-theme="${theme}"]`, { force: true });
    const active = await page.evaluate(() => document.documentElement.dataset.theme);
    if (active !== theme) throw new Error(`Theme failed: ${theme}`);
  }
  for (const voice of ['steward','neighbor','nurse','educator','parent','patriot','commonsense']) {
    if (!(await page.locator('#customizer').evaluate(el => el.classList.contains('open')))) await page.click('#customizerToggle');
    await page.click(`[data-voice="${voice}"]`, { force: true });
    const active = await page.evaluate(() => localStorage.getItem('mary-gunn-voice'));
    if (active !== voice) throw new Error(`Voice failed: ${voice}`);
  }
  await page.keyboard.press('Escape');
  for (const anim of ['stars','compass','ribbons','grid','aurora','bubbles','fireflies','ballots','constellations','waves']) {
    await page.click(`[data-anim="${anim}"]`, { force: true });
    const active = await page.evaluate(() => localStorage.getItem('mary-gunn-anim'));
    if (active !== anim) throw new Error(`Animation failed: ${anim}`);
  }
  await page.evaluate(() => document.getElementById('powerToggle').click());

  async function revealPage() {
    await page.evaluate(async () => {
      const step = Math.max(500, Math.floor(innerHeight * .72));
      for (let y = 0; y < document.documentElement.scrollHeight; y += step) {
        scrollTo(0, y); await new Promise(r => setTimeout(r, 60));
      }
      scrollTo(0, 0); await new Promise(r => setTimeout(r, 200));
    });
  }
  await revealPage();
  const hiddenDesktop = await page.locator('.reveal:not(.visible)').count();
  if (hiddenDesktop) throw new Error(`${hiddenDesktop} desktop reveal elements remained hidden`);
  const desktopOverflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  if (desktopOverflow > 1) throw new Error(`Desktop horizontal overflow: ${desktopOverflow}px`);
  await page.screenshot({ path: 'qa/desktop-full.png', fullPage: true });
  await page.locator('#priorities').scrollIntoViewIfNeeded();
  await page.screenshot({ path: 'qa/desktop-priorities.png' });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForFunction(() => document.getElementById('loader')?.classList.contains('hidden'), null, { timeout: 15000 });
  await revealPage();
  const hiddenMobile = await page.locator('.reveal:not(.visible)').count();
  if (hiddenMobile) throw new Error(`${hiddenMobile} mobile reveal elements remained hidden`);
  const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  if (mobileOverflow > 1) throw new Error(`Mobile horizontal overflow: ${mobileOverflow}px`);
  await page.screenshot({ path: 'qa/mobile-full.png', fullPage: true });

  await page.evaluate(() => { document.documentElement.style.scrollBehavior = 'auto'; scrollTo(0,0); });
  await page.waitForTimeout(150);
  await page.click('#menuToggle');
  await page.waitForTimeout(400);
  if (!(await page.locator('#mobileNav').evaluate(el => el.classList.contains('open')))) throw new Error('Mobile menu did not open');
  await page.screenshot({ path: 'qa/mobile-menu.png' });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  await page.click('#customizerToggle');
  await page.waitForTimeout(400);
  if (!(await page.locator('#customizer').evaluate(el => el.classList.contains('open')))) throw new Error('Customizer did not open');
  await page.screenshot({ path: 'qa/mobile-customizer.png' });
  await page.locator('#customizer').evaluate(el => { el.scrollTop = el.scrollHeight; });
  await page.waitForTimeout(150);
  const customizerScroll = await page.locator('#customizer').evaluate(el => ({ top: el.scrollTop, max: el.scrollHeight - el.clientHeight }));
  if (customizerScroll.max > 0 && customizerScroll.top < customizerScroll.max - 2) throw new Error('Customizer did not scroll to its final controls');
  await page.screenshot({ path: 'qa/mobile-customizer-bottom.png' });

  console.log(JSON.stringify({ errors, hiddenDesktop, hiddenMobile, desktopOverflow, mobileOverflow }, null, 2));
  await browser.close();
  if (errors.length) process.exit(1);
})().catch(err => { console.error(err); process.exit(1); });
'@ | node -
  if ($LASTEXITCODE -ne 0) { throw "Browser QA failed with exit code $LASTEXITCODE" }

  Write-Section 'Done'
  Write-Host "QA artifacts in $qaDir"
}
finally {
  if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
}
