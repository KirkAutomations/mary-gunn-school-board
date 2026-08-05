# Mary Gunn for Troy School Board — Conversion V3

Production: https://marygunn.com/

GitHub Pages mirror: https://kirkautomations.github.io/mary-gunn-school-board/

## Direction

A bold editorial civic campaign site built around campaign-poster typography, warm paper textures, deep navy, campaign red, and restrained gold. V2 replaces the original glassmorphism/canvas concept.

The background animation engine and left-side background selector were removed completely.

## Features

- Responsive one-page campaign architecture
- Editorial hero, campaign ticker, five-priority manifesto, experience timeline, candidate statement, and conversion-first action desk
- Three persistent presentation palettes: Heritage, Chalkboard, Blueprint
- Seven persistent message voices
- Interactive action engine for yard signs, volunteering, hosting Mary, and campaign updates; generates a prefilled campaign email without storing visitor data
- Share-campaign control, stronger hero/header CTAs, red closing CTA, and context-aware mobile action bar
- Sticky navigation, mobile menu, loading screen, scroll progress, reveal animations, counters, cursor spotlight, magnetic buttons, and photo tilt
- SEO, Open Graph, JSON-LD, accessibility, and print styles

## Files

- `index.html` — complete self-contained site
- `assets/` — campaign logo, photographs, and archived source flyers
- `qa.ps1` — static, interaction, responsive, and screenshot QA
- `robots.txt` and `sitemap.xml` — production discovery metadata
- `deploy/server-deploy.sh` — atomic nginx release deployment with HTTP/HTTPS preservation
- `.github/workflows/deploy.yml` — GitHub Pages mirror deployment

## QA

```powershell
powershell -ExecutionPolicy Bypass -File .\qa.ps1
```

The suite validates JavaScript syntax, local assets and anchors, all palettes and copy voices, desktop/mobile reveals, horizontal overflow, mobile navigation, action-form behavior, and the presentation panel.

## Production

`marygunn.com` and `www.marygunn.com` run on nginx with Let's Encrypt HTTPS. The deploy script creates immutable release directories, switches a `current` symlink atomically, validates nginx, verifies the local virtual host, and retains the newest three releases.
