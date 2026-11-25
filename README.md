# deepseek-harness-nix

English | [简体中文](README.zh-CN.md)

Nix source-build flake (`x86_64-linux`) for [DeepSeek Harness (`dsh`)](https://github.com/deepseek-ai/deepseek-harness), providing:

- `dsh`: CLI
- `dsh-web`: Web UI (shares `~/.local/state/dsh-desktop` as `DSH_HOME` with the desktop app by default)
- `dsh-desktop`: Electron desktop app (with Landlock sandbox backend and primary runtime Python/Node environment)

## Quick Start

```bash
# Run CLI without installing
nix run github:<owner>/<repo> -- --help

# Build the full package (outputs bin/dsh, bin/dsh-web, bin/dsh-desktop)
nix build github:<owner>/<repo>
```

## NixOS / Home Manager Integration

```nix
{
  inputs.deepseek-harness = {
    url = "github:<owner>/<repo>";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### Option 1: Via `lib.mkPackage` (Recommended — supports Wayland scaling)

```nix
let
  dsh = deepseek-harness.lib.mkPackage {
    inherit pkgs;
    # On fractionally scaled Wayland compositors (e.g. niri at 1.6x), set to
    # 1 / compositor_scale (e.g. "0.625"); defaults to "1".
    desktopScaleFactor = "1";
  };
in
{
  home.packages = [ dsh ];
}
```

### Option 2: Via `overlays.default`

```nix
nixpkgs.overlays = [ deepseek-harness.overlays.default ];
# Then use pkgs.dsh / pkgs.deepseek-harness
```

## Files

- `flake.nix`: Standalone flake entry point (`packages`, `overlays.default`, `lib.mkPackage`)
- `package.nix`: Main build recipe (see header comments for design decisions and manual upgrade steps)
- `lock.json`: Copy of upstream `scripts/primary-runtime/lock.json`
- `runtime-python.nix`: Generated Python 3.12 + office wheels recipe from `lock.json` (do not format with `nix fmt`)
- `LICENSE`: MIT License for this packaging repository

## License

This packaging repository is licensed under the [MIT License](LICENSE). DeepSeek Harness itself is licensed under the upstream MIT License (see `meta.license` in `package.nix`).
