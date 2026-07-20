---
summary: "Homebrew Cask release steps for AgentsBar (Sparkle-disabled builds)."
read_when:
  - Publishing a AgentsBar release via Homebrew
  - Updating the Homebrew tap cask definition
---

# AgentsBar Homebrew Release Playbook

Homebrew is for the UI app via Cask. When installed via Homebrew, AgentsBar disables Sparkle and shows a "update via brew" hint in About.

## Prereqs
- Homebrew installed.
- Access to the tap repo: `../homebrew-tap`.

## 1) Release AgentsBar normally
Follow `docs/RELEASING.md` to publish `AgentsBar-macos-universal-<version>.zip` to GitHub Releases.

## 2) Let the Release CLI workflow update the tap
After the GitHub release is published, `.github/workflows/release-cli.yml` builds the standalone CLI assets and dispatches `steipete/homebrew-tap`'s `update-formula.yml`. That tap workflow updates both:
- `Casks/agentsbar.rb` for the app zip.
- `Formula/agentsbar.rb` for the standalone CLI tarballs.

If dispatch fails or is rate-limited, update the files manually.

## 2a) Manual cask update
In `../homebrew-tap`, update the cask at `Casks/agentsbar.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/AgentsBar-macos-universal-<version>.zip`
- Update `sha256` to match that zip.
- Keep `depends_on macos: ">= :sonoma"` (AgentsBar is macOS 14+). Do not add an architecture restriction; the app zip is universal.

## 2b) Manual formula update
In `../homebrew-tap`, update the formula at `Formula/agentsbar.rb`:
- `url` points at the GitHub release assets:
  - macOS: `.../releases/download/v<version>/AgentsBarCLI-v<version>-macos-arm64.tar.gz`
  - macOS: `.../releases/download/v<version>/AgentsBarCLI-v<version>-macos-x86_64.tar.gz`
  - Linux: `.../releases/download/v<version>/AgentsBarCLI-v<version>-linux-aarch64.tar.gz`
  - Linux: `.../releases/download/v<version>/AgentsBarCLI-v<version>-linux-x86_64.tar.gz`
- Static musl tarballs are also published for manual Linux installs as `linux-musl-aarch64` and `linux-musl-x86_64`; keep the formula on the glibc assets unless intentionally changing its runtime contract.
- Update all `sha256` values to match those tarballs.

## 3) Verify install
```sh
brew uninstall --cask agentsbar || true
brew untap steipete/tap || true
brew tap steipete/tap
brew install --cask steipete/tap/agentsbar
open -a AgentsBar
```

## 4) Push tap changes
Commit + push in the tap repo.
