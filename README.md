# meshbench.github.io

The MeshBench website. One page, static, no build step: `index.html`,
`styles.css`, and the brand assets it needs.

## Publishing

**Not published yet.** GitHub Pages serves a private repository only on Pro,
Team or Enterprise, and the MeshBench organisation is on Free — so while this
repository is private, `.github/workflows/pages.yml` will fail at the deploy
step. It publishes the moment either is true:

- the repository is made public, or
- the organisation moves to Team.

Nothing else has to change. The workflow uploads the tree as it stands.

To read it before then, open `index.html` in a browser.

## Brand assets

`brand/` is copied from [MeshBench/brand](https://github.com/MeshBench/brand)
rather than fetched at deploy time, so the site does not depend on a private
repository being reachable to render. Refresh it with:

    cp -r ../meshbench-brand/webfonts brand/
    cp ../meshbench-brand/logo/meshbench-logo-mono.svg brand/
    cp ../meshbench-brand/logo/secondary/meshbench-landform-dark.svg brand/landform.svg
    cp ../meshbench-brand/png/meshbench-card-1200x630.png brand/card.png

The type is six subsetted woff2 faces, about 120 KB, served from this origin. A
font host would have told that host who is reading, and would have stopped
rendering the day it was unreachable.

## Content

Every claim on the page comes from the product's own README or
`docs/shortcomings.md`, in the same words where it matters. The board table says
how far each board actually got, and the honesty section is not optional
furniture — it is the reason the numbers above it are worth reading.
