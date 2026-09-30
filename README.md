# Mary Gunn for Troy School Board

Production: https://marygunn.com/

GitHub Pages mirror: https://kirkautomations.github.io/mary-gunn-school-board/

## Direction

A bold editorial civic campaign site built around campaign-poster typography, warm paper textures, deep navy, campaign red, and restrained gold. V2 replaces the original glassmorphism/canvas concept.

The background animation engine and left-side background selector were removed completely.

## Features

- Responsive one-page campaign architecture
- Editorial hero, campaign ticker, embedded candidate media, a six-part **Issues / Where We Stand** section, experience timeline, candidate statement, and conversion-first action desk
- Six sourced issue positions: Responsible Budgeting, Early Literacy, Special Education, Technology & AI, Instructional Materials, and Dignity, Opportunity & Belonging
- Accessible, expandable issue briefs with desktop and mobile navigation access
- Three persistent presentation palettes: Heritage, Chalkboard, Blueprint
- Seven persistent message voices
- Interactive action engine for yard signs, volunteering, hosting Mary, and campaign updates; opens the site's secure two-field contact form with a prefilled message
- Share-campaign control, stronger hero/header CTAs, red closing CTA, and context-aware mobile action bar
- Sticky navigation, mobile menu, loading screen, scroll progress, reveal animations, counters, cursor spotlight, magnetic buttons, and photo tilt
- SEO, Open Graph, JSON-LD, accessibility, and print styles

## Files

- `index.html` — complete self-contained site
- `assets/` — campaign logo, photographs, optimized campaign video/poster, and archived source flyers
- `qa.ps1` — static, interaction, responsive, overflow, console-error, and screenshot QA
- `QA/artifacts/` — stable 1440px desktop and 390px mobile full-page QA captures
- `robots.txt` and `sitemap.xml` — production discovery metadata
- `deploy/server-deploy.sh` — atomic nginx release deployment with HTTP/HTTPS preservation
- `.github/workflows/deploy.yml` — GitHub Pages mirror deployment

## QA

```powershell
powershell -ExecutionPolicy Bypass -File .\qa.ps1
```

The suite validates JavaScript syntax, local assets and anchors, all six issue titles and expandable interactions, desktop/mobile Issues navigation, campaign-video availability, every palette and copy voice, desktop/mobile reveals, horizontal overflow, console errors, mobile navigation, action-form behavior, the secure contact popup, and the presentation panel.

## Mark Gunn update — 2026-08-07

- Replaced the group photo featuring Mark in the blue shirt with Mark's supplied portrait of Mary alone
- Added a fifth action path for campaign contributions
- Every action—including contribution and campaign-update requests—opens a prefilled email addressed directly to Mark Gunn at `markgunn4troy@gmail.com` and BCCs Michael at `michael.kirk@kirkautomations.com`
- No payment information is collected or stored by the site

## Mark Gunn update — 2026-08-11

- Added Mark's supplied 33-second candidate video as an optimized, responsive HTML5 video with controls and a custom poster frame
- Added Watch Mary navigation links and a dedicated In Her Own Words section
- Shifted the family-photo crop so Mary sits closer to the center on desktop and mobile
- Kept video loading lightweight with metadata-only preload

## Production

`marygunn.com` and `www.marygunn.com` run on nginx with Let's Encrypt HTTPS. The deploy script creates immutable release directories, switches a `current` symlink atomically, validates nginx, verifies the local virtual host, and retains the newest three releases.
