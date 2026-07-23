# Website and Web Release

## Public Website

- URL: <https://pixelobservatorygame.com/>
- Repository: <https://github.com/tntsg1/Pixel-Observatory>
- Game title: Pixel Observatory
- Delivery format: Godot Web export

The public URL returned HTTP 200 and the Godot Web entry page was reachable in
the latest check. The live page is a built artifact, not a direct view of the
working tree.

## Deployment Path

The checked-in workflow is `.github/workflows/deploy-web.yml`. It runs on
pushes to `main` and `agent/current-version-2026-07-18`, or by manual dispatch.
It performs the following steps:

1. Installs Godot 4.7 and the matching Web export templates.
2. Exports the project to `build/web/index.html`.
3. Uploads `build/web` as a GitHub Pages artifact.
4. Deploys the artifact through the GitHub Pages environment.

The repository also contains `wrangler.jsonc`, `cloudflare/worker.mjs`, and
`build/cloudflare-public/`. These files describe the Cloudflare delivery layer
and custom-domain configuration. Do not change the production path to a
direct Wrangler deployment unless the GitHub Pages and Cloudflare routing
decision has been made deliberately.

## Publishing a New Version

1. Confirm that the Godot project opens without script errors.
2. Run the focused tests relevant to the change.
3. Export and test the Web build, including a hard refresh in a browser.
4. Commit only the intended source, data, asset, and documentation files.
5. Push the release branch or merge to `main`.
6. Open the GitHub Actions run and wait for both `build` and `deploy` jobs.
7. Open `https://pixelobservatorygame.com/` in a private window and verify the
   game title, loading screen, input, and the changed feature.
8. Record the date, commit, and user-visible changes in `docs/CHANGELOG.md`.

## Current Release Note

The latest source update changes the Concept Brief diagram and adds touch
swipe scrolling to the Parts Cabinet. These changes are ready to be included
in the next Web export after the CI workflow completes successfully.

## Important Distinction

Pushing source code to GitHub does not automatically update the live game
unless the deployment workflow succeeds. Local Godot scenes, generated caches,
temporary saves, and screenshots are not a substitute for a completed Web
export.
