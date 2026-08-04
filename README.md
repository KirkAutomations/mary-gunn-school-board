# Mary Gunn for Troy School Board

Single-page campaign site for Mary Gunn.

## Contents

- `index.html` - complete site with inline CSS, SVG, and JavaScript
- `assets/` - original flyer images plus two cropped portrait visuals
- `.github/workflows/deploy.yml` - GitHub Pages workflow
- `qa.ps1` - local verification script
- `qa/` - screenshots and extracted QA artifacts

## Local preview

Run a simple web server from this folder:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:4173/
```

## QA

Run the verification script from this folder:

```powershell
.\qa.ps1
```

The script checks for unfinished text markers, extracts and syntax-checks the JavaScript, verifies local links and assets, and runs a Playwright smoke test if available.

## Notes

- Copy source is limited to the intake files.
- No election date is published because it was not provided in the intake.
- Contact action is email only and is labeled as such on the site.
