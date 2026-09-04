param([int]$Port=4173)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$qa=Join-Path $root 'qa'
$proc=$null
Set-Location $root
New-Item -ItemType Directory -Force $qa|Out-Null
try{
  Write-Host "`n== Static checks =="
  $bad=Select-String -Path index.html -Pattern 'TODO|stub|lorem ipsum' -CaseSensitive:$false
  if($bad){throw "Unfinished markers found: $($bad|Out-String)"}
  @'
from pathlib import Path
from html.parser import HTMLParser
import re
html=Path('index.html').read_text(encoding='utf-8')
if 'mailto:' in html.lower(): raise SystemExit('mailto link remains in site')
donation='https://secure.anedot.com/mary-gunn-4-troy-school-board/63e34f8b-be36-4ab6-9bb3-71ec2e14dcd1'
if html.count(donation)<3: raise SystemExit('secure Anedot donation links missing')
if '1061 Snead, Troy, MI 48085' not in html: raise SystemExit('required campaign address missing')
if 'id="contactEmail"' not in html or 'id="contactMessage"' not in html: raise SystemExit('two-field contact popup missing')
if "fetch('/api/contact'" not in html: raise SystemExit('contact API wiring missing')
if not Path('deploy/contact-api.py').exists() or not Path('deploy/marygunn-contact.service').exists(): raise SystemExit('contact backend deployment files missing')
m=re.search(r'<script>\s*(.*?)\s*</script>\s*</body>',html,re.S)
if not m: raise SystemExit('main script missing')
Path('qa/index-script.js').write_text(m.group(1),encoding='utf-8')
class P(HTMLParser):
 def __init__(self): super().__init__(); self.ids=set(); self.links=[]; self.assets=[]
 def handle_starttag(self,t,a):
  a=dict(a)
  if 'id' in a:self.ids.add(a['id'])
  if t=='a' and 'href' in a:self.links.append(a['href'])
  for key in ('src','poster'):
   if key in a and a[key].startswith('assets/'):self.assets.append(a[key])
p=P();p.feed(html);bad=[]
for h in p.links:
 if h.startswith('#') and h[1:] not in p.ids:bad.append('missing anchor '+h)
 if h.startswith('assets/') and not Path(h).exists():bad.append('missing asset '+h)
for s in p.assets:
 if not Path(s).exists():bad.append('missing asset '+s)
need={'home','meet','watch','priorities','experience','statement','act','contact'}
bad += ['missing section #'+x for x in sorted(need-p.ids)]
if bad:raise SystemExit('\n'.join(bad))
if 'assets/mary-gunn-message.mp4' not in p.assets:bad.append('campaign video source missing')
if 'assets/mary-gunn-message-poster.webp' not in p.assets:bad.append('campaign video poster missing')
if 'assets/mary-community-message-september-2026.mp4' not in p.assets:bad.append('latest campaign video source missing')
if 'assets/mary-community-message-september-2026-poster.webp' not in p.assets:bad.append('latest campaign video poster missing')
if 'assets/mary-supporting-our-teachers.webp' not in p.assets:bad.append('teacher campaign update missing')
if 'assets/anedot-donation-qr.png' not in p.assets:bad.append('donation QR code missing')
if bad:raise SystemExit('\n'.join(bad))
print(f'OK: {len(p.ids)} ids, {len(p.links)} links, {len(p.assets)} local assets')
'@|python -
  node --check qa/index-script.js
  if($LASTEXITCODE -ne 0){throw 'JavaScript syntax check failed'}

  Write-Host "`n== Browser QA =="
  $proc=Start-Process python -ArgumentList '-m','http.server',"$Port",'--bind','127.0.0.1' -WorkingDirectory $root -PassThru -WindowStyle Hidden
  Start-Sleep 2
  $env:SITE_URL="http://127.0.0.1:$Port/index.html"
  @'
const{chromium}=require('playwright');
(async()=>{const b=await chromium.launch({headless:true});const errors=[];let contactPayload=null;const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route('**/api/contact',async route=>{contactPayload=route.request().postDataJSON();await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({ok:true})})});p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error')errors.push(m.text())});await p.goto(process.env.SITE_URL,{waitUntil:'networkidle'});await p.waitForFunction(()=>document.querySelector('#loader')?.classList.contains('hidden'),null,{timeout:15000});
for(const theme of['heritage','chalk','blueprint']){if(!await p.locator('#viewPanel').evaluate(e=>e.classList.contains('open')))await p.click('#viewToggle');await p.click(`[data-theme="${theme}"]`);if(await p.evaluate(()=>document.documentElement.dataset.theme)!==theme)throw Error('theme failed '+theme)}
for(const voice of['steward','neighbor','nurse','educator','parent','civic','direct']){if(!await p.locator('#viewPanel').evaluate(e=>e.classList.contains('open')))await p.click('#viewToggle');await p.click(`[data-voice="${voice}"]`);await p.waitForTimeout(160);if(await p.evaluate(()=>localStorage.getItem('mary-v2-voice'))!==voice)throw Error('voice failed '+voice)}
if(!await p.locator('#viewPanel').evaluate(e=>e.classList.contains('open')))await p.click('#viewToggle');await p.click('[data-theme="heritage"]');await p.click('[data-voice="steward"]');await p.waitForTimeout(220);await p.keyboard.press('Escape');
const videos=p.locator('#watch video');if(await videos.count()!==2)throw Error('campaign videos missing');for(let i=0;i<2;i++){const video=videos.nth(i);if(!await video.evaluate(v=>v.hasAttribute('controls')))throw Error('campaign video controls missing');if(!await video.getAttribute('poster'))throw Error('campaign video poster missing')}const sources=await videos.locator('source').evaluateAll(xs=>xs.map(x=>x.getAttribute('src')));if(sources[0]!=='assets/mary-gunn-message.mp4'||sources[1]!=='assets/mary-community-message-september-2026.mp4')throw Error('wrong campaign video sources');for(const src of sources){const videoStatus=await p.evaluate(async src=>{const r=await fetch(src,{headers:{Range:'bytes=0-1023'}});return r.status},src);if(![200,206].includes(videoStatus))throw Error('campaign video unavailable '+src+' '+videoStatus)}if(await p.locator('.campaign-post img').getAttribute('src')!=='assets/mary-supporting-our-teachers.webp')throw Error('teacher update image missing');
if(await p.locator('.action-option').count()!==4)throw Error('action choices missing');const donate=await p.locator('#donateNow');if(await donate.getAttribute('href')!=='https://secure.anedot.com/mary-gunn-4-troy-school-board/63e34f8b-be36-4ab6-9bb3-71ec2e14dcd1')throw Error('Anedot donation URL wrong');if(await donate.getAttribute('target')!=='_blank')throw Error('donation link must open separately');if(await p.locator('.donation-panel img').getAttribute('src')!=='assets/anedot-donation-qr.png')throw Error('donation QR wiring wrong');await p.locator('.action-option').nth(1).click();if(!await p.locator('input[value="volunteer"]').isChecked())throw Error('action choice failed');await p.fill('#actionName','QA Test');if(!await p.locator('#actionForm').evaluate(f=>f.checkValidity()))throw Error('action form invalid after required fields');await p.locator('#actionForm').evaluate(f=>f.requestSubmit());if(await p.locator('#contactModal').isHidden())throw Error('contact popup did not open');if(await p.locator('#contactForm input').count()!==1||await p.locator('#contactForm textarea').count()!==1)throw Error('contact popup must have exactly two fields');if(!await p.inputValue('#contactMessage').then(v=>v.includes('volunteer')))throw Error('action message not prefilled');await p.screenshot({path:'qa/contact-modal-desktop.png'});await p.fill('#contactEmail','qa.sender@example.com');await p.click('#contactSubmit');await p.waitForFunction(()=>document.querySelector('#contactStatus')?.classList.contains('success'));if(!contactPayload||contactPayload.email!=='qa.sender@example.com')throw Error('contact email payload wrong');if(!contactPayload.context.startsWith('I want to volunteer - QA Test'))throw Error('contact context wrong');if(!contactPayload.message.includes('Hello Mary campaign team'))throw Error('contact body wrong');await p.click('#contactClose');await p.locator('.action-option').first().click();await p.fill('#actionName','');await p.waitForTimeout(300);
async function reveal(){await p.evaluate(async()=>{document.documentElement.style.scrollBehavior='auto';for(let y=0;y<document.documentElement.scrollHeight;y+=600){scrollTo(0,y);await new Promise(r=>setTimeout(r,50))}scrollTo(0,0);await new Promise(r=>setTimeout(r,180))})}
await reveal();const hiddenD=await p.locator('.reveal:not(.visible)').count();const overflowD=await p.evaluate(()=>document.documentElement.scrollWidth-innerWidth);if(hiddenD)throw Error('desktop hidden reveals '+hiddenD);if(overflowD>1)throw Error('desktop overflow '+overflowD);await p.screenshot({path:'qa/v3-desktop-full.png',fullPage:true});await p.locator('#priorities').scrollIntoViewIfNeeded();await p.screenshot({path:'qa/v3-desktop-priorities.png'});await p.locator('#act').scrollIntoViewIfNeeded();await p.screenshot({path:'qa/v3-desktop-action.png'});
await p.setViewportSize({width:390,height:844});await p.reload({waitUntil:'networkidle'});await p.waitForFunction(()=>document.querySelector('#loader')?.classList.contains('hidden'),null,{timeout:15000});await reveal();const hiddenM=await p.locator('.reveal:not(.visible)').count();const overflowM=await p.evaluate(()=>document.documentElement.scrollWidth-innerWidth);if(hiddenM)throw Error('mobile hidden reveals '+hiddenM);if(overflowM>1)throw Error('mobile overflow '+overflowM);await p.screenshot({path:'qa/v3-mobile-full.png',fullPage:true});await p.locator('#act').scrollIntoViewIfNeeded();await p.waitForTimeout(250);if(!await p.locator('.mobile-cta').evaluate(e=>e.classList.contains('context-hidden')))throw Error('mobile CTA should hide over action form');await p.screenshot({path:'qa/v3-mobile-action.png'});await p.evaluate(()=>scrollTo(0,0));await p.waitForTimeout(250);await p.click('#menuToggle');await p.waitForTimeout(350);if(!await p.locator('#mobileMenu').evaluate(e=>e.classList.contains('open')))throw Error('mobile menu failed');if(await p.locator('.mobile-cta').evaluate(e=>getComputedStyle(e).pointerEvents!=='none'))throw Error('mobile CTA should hide behind menu');await p.screenshot({path:'qa/v3-mobile-menu.png'});await p.keyboard.press('Escape');await p.click('#viewToggle');await p.waitForTimeout(250);await p.screenshot({path:'qa/v3-mobile-view.png'});await p.keyboard.press('Escape');await p.click('.mobile-cta .contact-open');await p.waitForTimeout(150);await p.screenshot({path:'qa/contact-modal-mobile.png'});await p.click('#contactClose');
console.log(JSON.stringify({errors,hiddenD,hiddenM,overflowD,overflowM},null,2));await b.close();if(errors.length)process.exit(1)})().catch(e=>{console.error(e);process.exit(1)});
'@|node -
  if($LASTEXITCODE -ne 0){throw "Browser QA failed: $LASTEXITCODE"}
  Write-Host "`nQA PASS"
}finally{if($proc){Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue}}
