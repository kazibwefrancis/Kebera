# Hosting the Kebera website on Railway

The website is a static page in `site/`. It's served by a tiny Caddy web server in a
Docker image, configured for [Railway](https://railway.com).

| File | Purpose |
|---|---|
| `railway.json` | The same build settings as the dashboard (below). Railway stops reading it after 1 December 2026; the dashboard settings take over |
| `deploy/website.Dockerfile` | Copies `site/` and the images into a Caddy image |
| `deploy/Caddyfile` | Serves the files on Railway's `$PORT`, with security headers and caching |

## Deploy from GitHub (recommended)

1. Push the repository to GitHub.
2. In Railway: **New Project → Deploy from GitHub repo** → choose `Kebera`.
3. Open the service → **Settings** and set these (Railway is retiring config files
   such as `railway.json` on 1 December 2026, so set them in the dashboard):

   | Setting | Value |
   |---|---|
   | Source → Branch connected to production | `main`, with **auto deploy enabled** |
   | Build → Builder | **Dockerfile** |
   | Build → Dockerfile Path | `/deploy/website.Dockerfile` |
   | Build → Watch Paths | `/site/**`, `/docs/images/**`, `/deploy/**` |
   | Deploy → Healthcheck Path | `/` |

   Then click **Deploy** on the "Apply changes" bar at the bottom left.
4. **Settings → Networking → Generate Domain** to get a public address like
   `kebera-production.up.railway.app`, or add your own domain.
5. Put that address in the README's "Website" line.

Every push to `main` that changes `site/`, `docs/images/` or `deploy/` redeploys the
site within a couple of minutes. Pushes that only change docs or scripts are skipped
on purpose.

**Site not updating after a push?** Check **Settings → Source** says "Auto deploys when
pushed to GitHub". If it says "Auto deploy is disabled", click **Enable**, then press
**Ctrl+K → Deploy latest commit**. (**Redeploy** on an old deployment rebuilds that old
commit, not the latest one.)

## Deploy from your computer (Railway CLI)

```powershell
npm install -g @railway/cli
railway login
railway init
railway up
```

Run these from the repository root. `railway login` opens your browser so you can
sign in yourself.

## Test locally

With Docker installed:

```powershell
docker build -f deploy/website.Dockerfile -t kebera-site .
docker run --rm -p 8080:8080 kebera-site
```

Then open http://localhost:8080. Without Docker, any static server works for a quick look:

```powershell
python -m http.server 8080 --directory site
```

(Images load from `site/images/`; copy `docs/images/*.svg` there first. That folder
is ignored by git, because the Docker build copies them in.)

## Changing the repository the site points to

The live GitHub stats and all links are set at the top of the script in
`site/index.html`:

```js
var OWNER = 'kazibwefrancis', REPO = 'Kebera', BRANCH = 'main';
```
