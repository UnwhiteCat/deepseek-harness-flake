# DeepSeek Harness (dsh) —— DeepSeek 官方的 all-plugin agent harness。
#
# 为什么不是 Flatpak / AppImage / nixpkgs：都没有；上游只在 GitHub 发 prerelease
# tag，不提供 Linux 二进制（releases 里没有 assets），也不打 Linux 桌面包
# （apps/desktop 的打包脚本只认 mac-arm64 / mac-x64 / win-x64）。所以只能源码构建。
#
# 配方要点（都是实测踩出来的）：
#   * 339 个 workspace 包的 pnpm monorepo，lockfileVersion 9.0，pin pnpm 11.7.0；
#     nixpkgs 的 pnpm_11 能读这份 lockfile（--frozen-lockfile 不改写）。
#   * build:native-system 只编译 native/system/packages/entry 的 flock Node-API
#     插件（`--host-addon-only` 会跳过需要 musl-gcc 的静态 landlock 载荷），
#     需要 cc 和与运行期 node 匹配的 include/node —— nodejs_24 两者都提供。
#   * pnpm 依赖预取只保留 Linux x64/glibc 所需包：关闭 nixpkgs fetchPnpmDeps
#     的全平台 --force，保留 frozen lockfile、ignore-scripts 和可复现 store 归一化。
#     不删 Linux 功能插件，不改 workspace 链接；这主要减少下载与依赖缓存体积。
#   * pnpmConfigHook / fetchPnpmDeps 都带 --ignore-scripts，所以 devDeps 里的
#     electron 二进制、playwright 浏览器都不会下载（也下不了：构建期无网）。
#   * 上游的 postinstall（install-lefthook）会失败且与运行无关，被 --ignore-scripts 跳过。
#   * 运行期靠工作区的 node_modules 符号链接图解析包名，所以 $out/share/dsh 里保留
#     **整棵构建树，一点不裁**：pnpm install --prod / pnpm prune 都会重排符号链接图，
#     把 @deepseek-ai/* 工作区链接删掉（运行时报 ERR_MODULE_NOT_FOUND）。2.3 GB 是代价值得的。
#   * 桌面版（bin/dsh-desktop）走源码里官方留的"未打包启动"路径，因为上游打包脚本
#     只认 mac/win。Electron 用**官方 44.0.0 二进制**：仓库声明 ^44 且原生 addon
#     node-addon-require-builtin 的白名单只认 43.0.0 / 44.0.0 / 45.0.0-alpha.6 的
#     精确 V8 指纹，nixpkgs 的 electron_43.1.0 会被拒。
#   * 桌面版 Host（子进程）必须用官方 node 跑，不能用 Electron 的 node 模式：
#     Electron(Linux) 泄漏系统 glib 符号，sharp 的 libvips 自带另一份 glib，
#     解码图片直接 SIGSEGV（宿主"无声退出"，只剩一条 SharpElectronLinux 警告）。
#     所以 postPatch 让 main.ts 认 DSH_DESKTOP_HOST_NODE，wrapper 指向官方 node。
#   * 沙箱后端不能缺：native/system/packages/linux-x64/prebuilds.json 声明三个产物
#     （静态 landlock-run + glibc/musl 两个 flock system.node）。根构建脚本默认带
#     --host-addon-only，只编 host addon；少了 landlock-run 而机器上又没有
#     bubblewrap 时，沙箱链两个 rung 都不可用 → shell 的 workspace-write 直接报
#     "no sandbox backend is usable on this host"（dsh 拒绝非受限执行，UI 上就是
#     「没有沙箱后端，只能按不安全方式放行」）。buildPhase 用上游同一脚本不带 flag
#     再跑一遍，并给它一个 musl-gcc（pkgsMusl 的 gcc 包同名 wrapper）。
#     installPhase 会跑 launcherPath()+probe() 自检，结果应为 full/partial。
#   * UI 缩放：Chromium 在分数缩放的 Wayland 上会把合成器的缩放因子再乘一遍
#     （niri 1.6 → 1.6 × force-device-scale-factor），所以想让界面是 100% 就得传
#     desktopScaleFactor = 1/1.6 = "0.625"（默认 1，见 apps.nix 的传参）。
#   * primary runtime（宿主第二个参数）里的 office 技能资源与 Python 3.12.14 都从上游
#     lock.json 可复现地取（wheels 全部带 sha256），不依赖任何在线安装步骤。
#   * ⚠️ 运行期的 Node 必须是 **nodejs.org 官方二进制**，不能换成 nixpkgs 的
#     nodejs_22/24：dsh 启动 profile 时会用预编译的 node-addon-require-builtin
#     去反汇编宿主 node 的机器码、找内部字段访问器，nixpkgs 的 node 构建
#     对不上它的模式识别，直接报
#       "node-addon-require-builtin unsupported: ... x64 sysv getter is not a
#        recognized this->field accessor"
#     （nodejs_22.23.3 和 nodejs_24.21.0 都试过，一样失败；官方 24.21.0 正常）。
#     版本与哈希取自仓库自己的 scripts/primary-runtime/lock.json。
#
# 升级步骤：
#   1. 取新 tag 的 commit：git ls-remote https://github.com/deepseek-ai/deepseek-harness refs/tags/dsh-vX
#      改 src.rev + version（tag 名去掉前缀 dsh-v）。tag 与 package.json 版本号此处一致。
#   2. src.hash 设 lib.fakeHash，构建报错里给正确 hash（nix-prefetch-url --unpack --type sha256 <archive url>）。
#   3. 每次升级都独立重取 pnpmDeps.hash（不依赖 pnpm-lock.yaml 的变化检测）：
#      设 ""（或 lib.fakeHash），单独构建 .#dsh.pnpmDeps，再抄回目标 mismatch 的 `got:`。
#      写回后先构建 .#dsh.pnpmDeps 验证，再构建 .#dsh；相同提交无需复算。
#      这是 Linux x64/glibc 专用依赖缓存，不能再填全平台 fetcher 算出的 hash。
#   4. 上游 monorepo 构建脚本常变（scripts/build.ts 的 build:native-system / build:lib / build:web 三段），
#      升级后先跑一遍 nix build 看 buildPhase 有没有新增步骤。
#   5. primary runtime 的版本数据全在同目录 lock.json（上游 lock 的副本）：
#      换新副本后重跑更新器（--regen-runtime）更新同目录 runtime-python.nix（node/python 版本与
#      哈希都从它读，对不上会直接构建失败）。
#   6. Electron 升级：改 electronOfficial 的 version + 新 zip 的 sha256；若原生 addon 的
#      白名单版本也跟着变，看 node_modules 里 addon 的报错提示再定版本。
{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_24,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
  fetchurl,
  unzip,
  autoPatchelfHook,
  glibc,
  makeDesktopItem,
  copyDesktopItems,
  # 自引用 pkgs：桌面版要给官方 Electron 补一整套 X11/GTK/音视频库的 rpath，
  # callPackage 逐个列参数太啰嗦（nixpkgs 里 pkgs.pkgs 就是它自己）。
  pkgs,
  # 桌面版 UI 缩放（= Chromium 的 --force-device-scale-factor）。默认 1；
  # **在分数缩放的 Wayland 上要设成 1 / 合成器缩放**（本机 niri 是 1.6 → 0.625），
  # 因为 Chromium 会把合成器缩放再乘一遍：1.0 会渲染成 160%。当前值在
  # ../modules/packages/apps.nix 里传。
  desktopScaleFactor ? "1",
}:

let
  # 官方 Node 二进制（nodejs.org）。不是洁癖：见文件头关于 node-addon-require-builtin
  # 的说明 —— 反汇编式模式匹配只认官方构建。版本与哈希 = 上游
  # scripts/primary-runtime/lock.json 的 nodeVersion / targets."linux-x64".nodeSha256。
  nodejsOfficial = stdenv.mkDerivation (finalNode: {
    pname = "nodejs-official";
    version = "24.21.0";

    src = fetchurl {
      url = "https://nodejs.org/dist/v${finalNode.version}/node-v${finalNode.version}-linux-x64.tar.gz";
      hash = "sha256-bh24fvWLiBnl1UAu/xU2SRsY7djre+5e94l4duiNxf8=";
    };

    # tarball 里的 node 是给通用 Linux 编的（/lib64/ld-linux-x86-64.so.2），
    # 在 NixOS 上要用 autoPatchelfHook 换解释器、补 glibc/libstdc++ 的 rpath。
    nativeBuildInputs = [ autoPatchelfHook ];
    # libstdc++ / libgcc_s 在 stdenv.cc.cc.lib 里（lib.getLib stdenv.cc 只有个空壳）。
    buildInputs = [
      glibc
      stdenv.cc.cc.lib
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ./. $out/
      runHook postInstall
    '';

    meta.description = "Node.js 官方 Linux x64 二进制（dsh 运行时要求）";
  });

  # 官方 Electron 44.0.0。为什么不用 nixpkgs 的 electron_43：
  # dsh 的原生 addon（node-addon-require-builtin）带一份 Electron 白名单，
  # 只认 43.0.0 / 44.0.0 / 45.0.0-alpha.6 的精确 V8 指纹，nixpkgs 的 43.1.0
  # 对不上（应用会拒绝启动）。库清单抄 nixpkgs electron-unwrapped 的引用闭包。
  electronOfficial = stdenv.mkDerivation (finalElectron: {
    pname = "electron-official";
    version = "44.0.0";

    # 用 fetchurl 而不是 fetchzip：zip 的 sha256 是上游 release 页面就能核对的值，
    # fetchzip 要的是解包后目录的 NAR 哈希（两者不是一个东西）。
    src = fetchurl {
      url = "https://github.com/electron/electron/releases/download/v${finalElectron.version}/electron-v${finalElectron.version}-linux-x64.zip";
      hash = "sha256-1lKG2BJxnytMGhuAaoDyiKEFjInHsFja4eA6sl5JlEY=";
    };

    # 下载版 Electron 不带 RUNPATH，官方 tarball 的 /lib64 解释器在 NixOS 上也不存在：
    # autoPatchelfHook + 这堆库一次性解决（否则要手工维护一大条 LD_LIBRARY_PATH）。
    nativeBuildInputs = [
      autoPatchelfHook
      unzip
    ];
    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      flac
      glib
      gtk3
      libffi
      libglvnd
      libjpeg_turbo
      libnotify
      libpulseaudio
      libsecret
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxml2
      libxrandr
      libxslt
      mesa
      nspr
      nss
      pango
      pciutils
      pipewire
      speechd
      systemd
      vulkan-loader
      glibc
      stdenv.cc.cc.lib
    ];

    # zip 的顶层是散着的（electron、resources、locales…），stdenv 默认的
    # setSourceRoot 会因为"多个顶层目录"直接报错，所以自己解到 source/ 里。
    unpackPhase = ''
      runHook preUnpack
      mkdir -p source
      unzip -q $src -d source
      sourceRoot=source
      runHook postUnpack
    '';

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ./. $out/
      chmod +x $out/electron
      runHook postInstall
    '';

    meta.description = "Electron 44.0.0 官方 Linux x64 二进制（dsh 原生 addon 白名单要求）";
  });

  # primary runtime 的 Python 3.12.14 + office 文档 wheels（数据源：同目录 lock.json；
  # 生成脚本见 runtime-python.nix 头部说明）。
  primaryRuntimePython = pkgs.callPackage ./runtime-python.nix { };

  # 上游 native/system/scripts/build.ts 按名字调 `musl-gcc` 编静态 Landlock 启动器
  # （landlock-run：musl 静态可执行，无需 setuid、不依赖容器）。nixpkgs 没有顶层
  # musl-gcc，这里用 pkgsMusl 的 gcc 包一个同名 wrapper —— 只进构建期 PATH。
  muslGcc = pkgs.writeShellScriptBin "musl-gcc" ''
    exec ${pkgs.pkgsMusl.stdenv.cc}/bin/cc "$@"
  '';

  # 未打包（dev）启动时，desktop 主进程要求这几个目录/描述符存在：
  #   * DSH_DESKTOP_DSH_DIR：宿主 argv[2] 的 runtimeDir（"development project"）
  #   * DSH_DESKTOP_PRIMARY_RUNTIME_DIR：primary-runtime（office 技能的 Python/资源）
  # 这个 shim 复刻 apps/desktop/scripts/dev.ts 里的 prepareDevelopmentProject，
  # 只把 platform/arch 从替身 target（win-x64，仅用于通过上游的 target 校验）
  # 改写回 linux/x64 —— 上游的 resolveDesktopBuildTarget 不接受 linux-*。
  prepareProjectScript = pkgs.writeText "dsh-prepare-development-project.mts" ''
    import { readFileSync, writeFileSync } from 'node:fs'
    import { join } from 'node:path'
    import { pathToFileURL } from 'node:url'

    // shim 本身在 store 里，相对 import 会按 shim 的位置解析 → 必须用仓库根的绝对路径。
    const repo = process.env.DSH_DESKTOP_REPO!
    const projectDir = process.argv[2]!
    const load = (rel: string) => import(pathToFileURL(join(repo, rel)).href)

    const { prepareDevelopmentProject } = await load('apps/desktop/scripts/development-project.ts')
    const { DESKTOP_RUNTIME_FILE, readDesktopRuntime } = await load('apps/desktop/src/runtime-tree.ts')
    const { DESKTOP_HOST_PROTOCOL_VERSION } = await load('apps/desktop/src/host-protocol.ts')

    const desktopManifest = JSON.parse(readFileSync(join(repo, 'apps/desktop/package.json'), 'utf8')) as { version: string }
    const pnpmManifest = JSON.parse(readFileSync(join(repo, 'apps/desktop/node_modules/pnpm/package.json'), 'utf8')) as { version: string }

    prepareDevelopmentProject({
      projectDir,
      cliDir: join(repo, 'apps/cli'),
      hostDir: join(repo, 'apps/desktop-host'),
      dependencyDir: join(repo, 'node_modules/.pnpm/node_modules'),
      release: {
        schemaVersion: 1,
        version: desktopManifest.version,
        hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION,
        nodeVersion: process.env.DSH_NODE_VERSION!,
        pnpmVersion: pnpmManifest.version,
      },
      target: 'win-x64',
    })

    const descriptorPath = join(projectDir, DESKTOP_RUNTIME_FILE)
    const descriptor = JSON.parse(readFileSync(descriptorPath, 'utf8')) as { platform: string; arch: string }
    descriptor.platform = process.platform
    descriptor.arch = process.arch
    writeFileSync(descriptorPath, `''${JSON.stringify(descriptor, undefined, 2)}\n`)
    readDesktopRuntime(projectDir)
    console.log('desktop: development project prepared at', projectDir)
  '';

  # primary-runtime 的 runtime.json 由上游脚本生成（payloadDigest 是 lock + pnpm
  # 版本的纯函数），这里直接调用它自己的函数，保证字段与上游一致。
  prepareRuntimeJsonScript = pkgs.writeText "dsh-prepare-runtime-json.mts" ''
    import { readFileSync, writeFileSync } from 'node:fs'
    import { join } from 'node:path'
    import { pathToFileURL } from 'node:url'

    const repo = process.env.DSH_DESKTOP_REPO!
    const { primaryRuntimePayloadDigest } = await import(
      pathToFileURL(join(repo, 'scripts/primary-runtime/prepare.ts')).href
    )
    const lock = JSON.parse(readFileSync(join(repo, 'scripts/primary-runtime/lock.json'), 'utf8'))
    const pnpmVersion = process.env.DSH_PNPM_VERSION!
    const manifest = {
      desktopVersion: process.env.DSH_DESKTOP_VERSION!,
      platform: 'linux',
      arch: 'x64',
      payloadDigest: primaryRuntimePayloadDigest('linux-x64', lock, pnpmVersion),
      python: lock.pythonVersion,
      node: lock.nodeVersion,
      pnpm: pnpmVersion,
      pythonPackages: lock.pythonPackages,
    }
    writeFileSync(process.argv[2]!, `''${JSON.stringify(manifest, undefined, 2)}\n`)
    console.log('desktop: runtime.json written')
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "deepseek-harness";
  # 与 tag dsh-v0.2.1-rc.3 对齐（上游处于 developer preview，只发 alpha/rc）。
  version = "0.2.2-rc.4";

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    rev = "3f321d32bfe382212a8ed8785c1d47a5a300aa23";
    hash = "sha256-milWV/D6usfjicaZkOHrF904nLttAiHfMse5i1HP6/o=";
  };

  # Only the platform shipped by this recipe belongs in the fixed-output cache.
  # nixpkgs normally forces all OS/CPU variants for a platform-independent hash;
  # keep its reproducible-store fixup, but let pnpm filter optional native packages.
  pnpmDeps =
    (fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-ZsW8WwNdkSylKwLW62Ad4mw8RpgxW2KE181uUDPGQtU=";
      prePnpmInstall = ''
        export npm_config_platform=linux pnpm_config_platform=linux
        export npm_config_arch=x64 pnpm_config_arch=x64
        export npm_config_libc=glibc pnpm_config_libc=glibc
      '';
    }).overrideAttrs
      (old: {
        name = "${finalAttrs.pname}-pnpm-deps-linux-x64";
        installPhase =
          assert lib.hasInfix "export pnpm_config_force_ignores_platform=true" old.installPhase;
          assert lib.hasInfix ''"--force"'' old.installPhase;
          lib.replaceStrings
            [ "export pnpm_config_force_ignores_platform=true" ''"--force"'' ]
            [ "export pnpm_config_force_ignores_platform=false" "" ]
            old.installPhase;
      });

  nativeBuildInputs = [
    nodejs_24
    pnpm_11
    pnpmConfigHook
    makeWrapper
    copyDesktopItems
    # 上游 build.ts 通过 PATH 找 musl-gcc（静态 Landlock 启动器）。
    muslGcc
  ];

  desktopItems = [
    (makeDesktopItem {
      # 名字要与 Electron 上报的 Wayland app_id 严格一致，否则没图标、窗口归错组。
      # 实测（niri msg windows）app_id = deepseek-ai-dsh-desktop，来自包名
      # @deepseek-ai/dsh-desktop；所以文件名与 StartupWMClass 都用它，
      # 而命令本身仍叫 dsh-desktop。
      name = "deepseek-ai-dsh-desktop";
      exec = "dsh-desktop %U";
      icon = "deepseek-harness";
      desktopName = "DeepSeek Harness";
      genericName = "AI agent harness";
      comment = "DeepSeek 官方 agent harness 的桌面版（源码构建）";
      categories = [
        "Development"
        "Utility"
      ];
      startupWMClass = "deepseek-ai-dsh-desktop";
    })
  ];

  # 构建期不可能联网：显式关掉依赖包自己的二进制下载（--ignore-scripts 已经挡掉
  # 大部分，这里再钉一遍，避免将来上游改成 prepare 钩子时突然要网）。
  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

    # scripts/client-build-environment.ts 会 `git rev-parse HEAD` 取提交号写进前端
    # 构建元数据；源码树里没有 .git、沙箱里也没有 git，于是 ENOENT 直接失败。
    # 上游为无 Git 的构建环境留了 DSH_CLIENT_COMMIT_HASH（会校验成 Git 哈希格式），
    # 这里用 pin 住的 rev 前缀，构建保持可复现。
    DSH_CLIENT_COMMIT_HASH = builtins.substring 0 7 finalAttrs.src.rev;
  };

  # ⚠️ 桌面版 Host 必须跑在**官方 Node**上，不能用 Electron 的 node 模式：
  # Electron(Linux) 的动态库会把系统 glib 的符号泄漏进进程空间，而 sharp 自带的
  # libvips 用的是另一份 glib —— GObject 布局对不上，解码任何图片都会 SIGSEGV
  # （实测 electron 44.0.0 + sharp 0.35.5：连 metadata() 都段错误，退出码 139，
  #  stderr 只留下那条 [SharpElectronLinux] 警告，宿主进程"无声退出"）。
  # 上游只发 mac/win，所以没有这个分支；desktop 的 main.ts 里把 host 可执行文件
  # 写死成 process.execPath，这里让它认 DSH_DESKTOP_HOST_NODE（wrapper 里给官方
  # node）。Host 本身不 import electron，官方 node 跑起来一切正常。
  postPatch = ''
    substituteInPlace apps/desktop/src/main.ts \
      --replace-fail "const node = process.execPath" \
      "const node = process.env.DSH_DESKTOP_HOST_NODE ?? process.execPath"
  '';

  buildPhase = ''
    runHook preBuild
    # build:native-system -> build:lib(host+client) -> build:web 三段，见 scripts/build.ts
    pnpm run build

    # 根脚本的 build:native-system 带 --host-addon-only：只编 host 的 flock addon，
    # 把 prebuilds.json 里另外两个产物跳过了 —— 静态 Landlock 启动器
    # `bin/landlock-run`（bash-sandbox 的唯一 Linux 兜底后端）和 musl 版 system.node。
    # 少了 landlock-run、机器上又没有 bubblewrap 时，dsh 的沙箱链两个 rung 全不可用：
    # shell 的 workspace-write 直接报 "no sandbox backend is usable on this host"
    # （拒绝非受限执行），UI 里就表现为「没有可用的沙箱后端、只能按不安全方式放行」。
    # 所以再用上游自己的脚本（不带 flag）补齐全部原生载荷。
    ${nodejsOfficial}/bin/node node_modules/tsx/dist/cli.mjs native/system/scripts/build.ts

    runHook postBuild
  '';

  # 不要对整个 node_modules 树做 patchShebangs（几万个文件，慢且无意义：
  # 入口是用 makeWrapper + node 显式起的，不依赖 shebang）。
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    # 整棵构建树搬进 store（同一文件系统，rename 即可）。
    # 注意 `mv .` 会被 mv 拒绝（"refusing to remove '.'"），必须移动源目录本身。
    # 注意：这里**不做** pnpm --prod 裁剪。试过两种写法，都会把 workspace 包之间的
    # 链接清掉（@deepseek-ai/cordis 这类包直接 ERR_MODULE_NOT_FOUND）：
    #   1) 搬进 $out 之后再 `pnpm install --prod`：.modules.yaml 里记的 virtualStoreDir
    #      是旧路径，pnpm 会清空 node_modules 重装，装完基本啥都没了；
    #   2) 搬之前 `pnpm prune --prod`：链接同样被清掉（构建期日志里有 - typescript、
    #      - vitest 之类的移除列表，随后 CLI 起不来）。
    # 所以整棵构建树（含 devDependencies）原样进 store，约 2.3 GB。installPhase 末尾的
    # 冒烟测试就是用来兜这个底的。
    mkdir -p $out/share
    # installPhase 里的 $sourceRoot 是相对名（"source"），要用 $PWD（就是解包目录本体）。
    if ! mv "$PWD" $out/share/dsh 2>/dev/null; then
      cp -a "$PWD" $out/share/dsh
    fi
    cd $out/share/dsh

    # build:lib 的产物入口，缺了说明构建脚本改了结构，早点报错
    test -f apps/cli/lib/bin.js || { echo "apps/cli/lib/bin.js 不存在，构建布局变了" >&2; exit 1; }

    makeWrapper ${nodejsOfficial}/bin/node $out/bin/dsh \
      --add-flags "$out/share/dsh/apps/cli/lib/bin.js"

    # Web UI 与桌面版必须落在同一个 harness home：`dsh web` 默认用 ~/.dsh，而桌面版
    # 的 DSH_HOME 是 ~/.local/state/dsh-desktop（见下面的 dsh-desktop）。sessions/、
    # storages/workspace.json、.credentials.yaml（含浏览器 cookie 的签名密钥
    # client-connection/browser-session）全都挂在 DSH_HOME 下，分成两个 home 就是
    # 「两套互不相通的会话列表 + 两把不同的 cookie 密钥」，而 cookie 还绑 host:port，
    # 所以靠搬 cookie/搬密钥去共享是走不通的，只能共享 home。
    # 仍然允许 DSH_HOME=... 覆盖，语义与桌面版一致。
    makeWrapper ${nodejsOfficial}/bin/node $out/bin/dsh-web \
      --add-flags "$out/share/dsh/apps/cli/lib/bin.js web" \
      --run 'export DSH_HOME="''${DSH_HOME:-$HOME/.local/state/dsh-desktop}"; mkdir -p "$DSH_HOME"'

    # 冒烟测试：store 里这棵树必须真的能跑。--version 只走 CLI 骨架，所以再跑一次
    # \`web --help\`——它会真的 boot web profile、装 require 拦截层，能挡住
    # 「node 不对 / workspace 链接被裁坏 / native 插件不匹配」这类问题。
    HOME=$TMPDIR timeout 120 ${nodejsOfficial}/bin/node $out/share/dsh/apps/cli/lib/bin.js --version \
      | grep -q '${finalAttrs.version}' || { echo "打包后的 dsh 跑不起来（CLI --version 失败）" >&2; exit 1; }
    HOME=$TMPDIR timeout 180 ${nodejsOfficial}/bin/node $out/share/dsh/apps/cli/lib/bin.js web --help \
      > /dev/null || { echo "打包后的 dsh 跑不起来（dsh web --help 失败）" >&2; exit 1; }

    # dsh-web 冒烟：wrapper 的 --add-flags / --run 拼错只会在运行时才炸，所以这里
    # 真的跑一次 --help；同时核对 DSH_HOME 的默认值真的落在桌面 home（两边共用一个
    # home 是这条 wrapper 存在的全部理由）。
    HOME=$TMPDIR timeout 180 $out/bin/dsh-web --help > /dev/null \
      || { echo "dsh-web 跑不起来（wrapper 的 --add-flags/--run 有问题）" >&2; exit 1; }
    test -d "$TMPDIR/.local/state/dsh-desktop" \
      || { echo "dsh-web 没有把 DSH_HOME 默认指向桌面 home" >&2; exit 1; }

    # 沙箱后端自检：`launcherPath()` 必须解析到真实二进制，`probe()` 必须是
    # full/partial（构建机与运行机同一内核，landlock 在 LSM 列表里，构建沙箱内也能过）。
    # 这条挡住的是「原生载荷被 --host-addon-only 跳过」——运行时表现为 shell 的
    # workspace-write 报 "no sandbox backend is usable on this host"，很难从 UI 反查。
    DSH_NATIVE_ENTRY="$out/share/dsh/native/system/packages/entry/lib/index.js" \
    ${nodejsOfficial}/bin/node --input-type=module -e '
      import { existsSync } from "node:fs"
      import { pathToFileURL } from "node:url"
      const { launcherPath, probe } = await import(pathToFileURL(process.env.DSH_NATIVE_ENTRY).href)
      const launcher = launcherPath()
      if (!existsSync(launcher)) {
        console.error("sandbox: Landlock launcher missing: " + launcher)
        process.exit(1)
      }
      const verdict = probe(launcher)
      console.log("sandbox backend: " + verdict + " (" + launcher + ")")
      if (verdict === "unusable") process.exit(1)
    ' || { echo "沙箱后端不可用（landlock-run 探针失败）" >&2; exit 1; }

    # ── 桌面版（Electron）───────────────────────────────────────────────
    # 上游只给 mac/win 打包（apps/desktop/scripts/package-target.ts 的
    # SUPPORTED_TARGETS 没有 linux-*，dev.ts 也会抛 unsupported target），
    # 所以走源码里官方留的"未打包启动"路径：main.ts 在 !app.isPackaged 时
    # 读 DSH_DESKTOP_{DSH_DIR,PRIMARY_RUNTIME_DIR,PNPM_ENTRY}。
    mkdir -p $out/share/dsh-desktop/runtime/primary-runtime/dependencies \
             $out/share/dsh-desktop/runtime/office-skills

    # (1) dev project = 宿主 argv[2] 的 runtimeDir（含 1497 个 workspace 共享包链接）
    DSH_DESKTOP_REPO=$PWD DSH_NODE_VERSION=${nodejsOfficial.version} \
      ${nodejs_24}/bin/node node_modules/tsx/dist/cli.mjs ${prepareProjectScript} \
      $out/share/dsh-desktop/project

    # (2) primary runtime：office 技能资源（缺了宿主直接拒绝启动）
    cp -r packages/skill/skill-office/assets/. $out/share/dsh-desktop/runtime/office-skills/
    #     宿主的 validatePayloadEntries 会硬校验这几条：dependencies/node/bin/node 必须是文件、
    #     dependencies/node/node_modules 必须是目录、dependencies/python/bin/python3 必须是文件、
    #     lib/python3.12/site-packages 必须是目录 —— 所以 node 不能直接软链整棵树，
    #     得按上游 prepare.ts 的布局摊开。
    deps=$out/share/dsh-desktop/runtime/primary-runtime/dependencies
    mkdir -p "$deps/node/node_modules"
    ln -s ${nodejsOfficial}/bin "$deps/node/bin"
    ln -s ${nodejsOfficial}/lib "$deps/node/lib"
    ln -s ${nodejsOfficial}/include "$deps/node/include"
    ln -s ${nodejsOfficial}/share "$deps/node/share"
    ln -s ${nodejsOfficial}/LICENSE "$deps/node/LICENSE"
    ln -s ${primaryRuntimePython} "$deps/python"
    ln -s $out/share/dsh/node_modules/pnpm "$deps/pnpm"
    # (3) runtime.json 用上游自己的 digest 函数生成，升级时不用手抄字段
    DSH_DESKTOP_REPO=$PWD DSH_DESKTOP_VERSION=${finalAttrs.version} \
    DSH_PNPM_VERSION=$(${nodejs_24}/bin/node -p "require('$out/share/dsh/node_modules/pnpm/package.json').version") \
      ${nodejs_24}/bin/node node_modules/tsx/dist/cli.mjs ${prepareRuntimeJsonScript} \
      $out/share/dsh-desktop/runtime/primary-runtime/runtime.json

    # (4) 启动器：DSH_HOME 必须是可写目录（profiles/sessions 落地处），
    #     所以用 --run 在启动时展开 $HOME，不能写死 store 路径。
    #     UI 缩放：Chromium 默认跟随合成器的缩放因子（本机 niri 是 1.6 倍 → 界面
    #     按 160% 渲染，显得很大），这里强制 100%；要改就设 DSH_DESKTOP_SCALE_FACTOR，
    #     或在命令行再传一次 --force-device-scale-factor=<x>（Chromium 取最后一个）。
    #     另外要给 LD_LIBRARY_PATH 加 gcc 的 lib：原生 addon
    #     （node-addon-require-builtin）自己不带 rpath，dlopen 时只看 LD_LIBRARY_PATH
    #     （可执行文件的 RUNPATH 对 dlopen 不生效），缺 libstdc++.so.6 时会报
    #     "No usable native binding found"；dev 流程里也是靠这条撑住的。
    makeWrapper ${electronOfficial}/electron $out/bin/dsh-desktop \
      --add-flags "$out/share/dsh/apps/desktop" \
      --set DSH_DESKTOP_DSH_DIR "$out/share/dsh-desktop/project" \
      --set DSH_DESKTOP_HOST_NODE "${nodejsOfficial}/bin/node" \
      --set DSH_DESKTOP_PRIMARY_RUNTIME_DIR "$out/share/dsh-desktop/runtime/primary-runtime" \
      --set DSH_DESKTOP_PNPM_ENTRY "$out/share/dsh/apps/desktop/node_modules/pnpm/bin/pnpm.mjs" \
      --set DSH_DESKTOP_OPEN_DEVTOOLS "0" \
      --add-flags "--force-device-scale-factor=\''${DSH_DESKTOP_SCALE_FACTOR:-${desktopScaleFactor}}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      --run 'export DSH_HOME="''${DSH_HOME:-$HOME/.local/state/dsh-desktop}"; mkdir -p "$DSH_HOME"' \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-wayland-ime=true}}"

    install -Dm644 apps/desktop/resources/icon.png \
      $out/share/icons/hicolor/512x512/apps/deepseek-harness.png

    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness：all-plugin agent harness（源码构建，CLI + Web UI + 桌面 Electron 应用）";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [ "x86_64-linux" ];
  };
})
