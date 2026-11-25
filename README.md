# deepseek-harness-nix

[DeepSeek Harness (`dsh`)](https://github.com/deepseek-ai/deepseek-harness) 的 Nix 源码构建 flake（`x86_64-linux`），包含：

- `dsh`：CLI
- `dsh-web`：Web UI（默认与桌面版共用 `~/.local/state/dsh-desktop` 作为 `DSH_HOME`）
- `dsh-desktop`：Electron 桌面应用（含 Landlock 沙箱后端与 primary runtime Python/Node 环境）

## 直接使用

```bash
# 临时运行 CLI
nix run github:<owner>/<repo> -- --help

# 构建完整包（输出 bin/dsh, bin/dsh-web, bin/dsh-desktop）
nix build github:<owner>/<repo>
```

## 在 NixOS / Home Manager 中集成

```nix
{
  inputs.deepseek-harness = {
    url = "github:<owner>/<repo>";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### 方式一：通过 `lib.mkPackage`（推荐，可传入 Wayland 缩放参数）

```nix
let
  dsh = deepseek-harness.lib.mkPackage {
    inherit pkgs;
    # Wayland 分数缩放（如 niri 1.6）时建议设为 1 / 合成器缩放，例如 "0.625"；
    # 也可按需传其他值，默认 "1"。
    desktopScaleFactor = "1";
  };
in
{
  home.packages = [ dsh ];
}
```

### 方式二：通过 `overlays.default`

```nix
nixpkgs.overlays = [ deepseek-harness.overlays.default ];
# 之后可使用 pkgs.dsh / pkgs.deepseek-harness
```

## 文件说明

- `flake.nix`：独立 flake 入口（暴露 `packages`、`overlays.default`、`lib.mkPackage`）
- `package.nix`：主构建配方，具体取舍与手工升级说明见文件头部注释
- `lock.json`：上游 `scripts/primary-runtime/lock.json` 副本
- `runtime-python.nix`：由 `lock.json` 生成的 Python 3.12 + office wheels 配方（勿用 `nix fmt` 格式化）

## 许可

本打包配方遵循仓库自身约定；DeepSeek Harness 本体遵循上游 MIT 协议（见 `package.nix` 中 `meta.license`）。
