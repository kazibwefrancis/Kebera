# Hosting the Kebera website on Railway

The website is a static page in `site/`. It's served by a tiny Caddy web server in a
Docker image, configured for [Railway](https://railway.com).

| File | Purpose |
|---|---|
| `railway.json` | Tells Railway to build with `deploy/website.Dockerfile` and redeploy when `site/`, `docs/images/` or `deploy/` change |
| `deploy/website.Dockerfile` | Copies `site/` and the images into a Caddy image |
| `deploy/Caddyfile` | Serves the files on Railway's `$PORT`, with security headers and caching |

## Deploy from GitHub (recommended)

1. Push the repository to GitHub.
2. In Railway: **New Project → Deploy from GitHub repo** → choose `kebera`.
3. Railway reads `railway.json` and builds the Dockerfile automatically.
4. Open the service → **Settings → Networking → Generate Domain** to get a public
   address like `kebera-production.up.railway.app`, or add your own domain.
5. Put that address in the README's "Website" line.

Every push to `main` that changes the site redeploys it.

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
