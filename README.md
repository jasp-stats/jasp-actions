# jasp-actions

centralized location for custom jasp-actions

## Update R wrappers

`.github/workflows/update-wrappers.yml` regenerates the R wrappers of a module (`R/<analysis>Wrapper.R`) and their help files (`man/*.Rd`) from its QML forms, and commits them when they changed. It installs [jaspSyntax](https://github.com/jasp-stats/jaspSyntax) with the pre-built SyntaxInterface library from its GitHub release, so nothing of JASP is built. Modules that do not set `hasWrappers: true` in `inst/Description.qml` are skipped.

Add this as `.github/workflows/update-wrappers.yml` to a module:

```yaml
name: Update R Wrappers

on:
  push:
    branches:
      - master
    paths: ['inst/qml/**', 'inst/Description.qml', '.github/workflows/update-wrappers.yml']
  workflow_dispatch:

jobs:
  update-wrappers:
    uses: jasp-stats/jasp-actions/.github/workflows/update-wrappers.yml@master
    secrets:
      BUMP_TOKEN: ${{ secrets.BUMP_TOKEN }}
    permissions:
      contents: write
```

`BUMP_TOKEN` is the token the version bump uses to push to a protected `master`; without it the `GITHUB_TOKEN` is used. The commit carries `[skip ci]`, so it does not trigger the version bump or the unit tests again. The inputs `jaspsyntax_ref` and `syntaxinterface_release` pin the jaspSyntax version and the SyntaxInterface release.

To run it locally on a checkout, with jaspSyntax and roxygen2 installed: `Rscript update-wrappers/updateWrappers.R <module>`.
