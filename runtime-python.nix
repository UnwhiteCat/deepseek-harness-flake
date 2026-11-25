# 自动生成 —— 数据来自上游 scripts/primary-runtime/lock.json（副本见同目录
# lock.json）。升级 dsh 时换掉 lock 副本并重跑生成脚本即可，
# 哈希对不上会直接构建失败，不会静默降级。
{
  lib,
  fetchurl,
  stdenv,
  unzip,
  autoPatchelfHook,
  glibc,
  zlib,
  openssl,
  libffi,
  bzip2,
  xz,
  ncurses,
  readline,
  sqlite,
  libxcrypt-legacy,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-primary-runtime-python";
  version = "3.12.14";

  src = fetchurl {
    url = "https://github.com/astral-sh/python-build-standalone/releases/download/20260901/cpython-3.12.14+20260901-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz";
    hash = "sha256-cnSNoTGXwfsWHjr+7yCmo4X/JPIWXm4nWORwCOf6ukw=";
  };

  # office 技能要的 13 个 wheel（numpy/pandas/python-docx/python-pptx/openpyxl/Pillow/lxml/…），
  # 顶层 9 个 + linux-x64 专属 4 个，全是 PyPI 官方 URL + sha256。
  wheels = [
    (fetchurl { name = "python_dateutil-2.9.0.post0-py2.py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/ec/57/56b9bcc3c9c6a792fcbaf139543cee77261f3651ca9da0c93f5c1221264b/python_dateutil-2.9.0.post0-py2.py3-none-any.whl"; hash = "sha256-qLK8e/+uKCKByBQKl9OqnBTaCxNt/oP4UO6ppfdHBCc="; })
    (fetchurl { name = "six-1.17.0-py2.py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/b7/ce/149a00dd41f10bc29e5921b496af8b574d8413afcd5e30dfa0ed46c2cc5e/six-1.17.0-py2.py3-none-any.whl"; hash = "sha256-RyHzke2QVB/drKtaz5R6oNPcfSey4ejtor6JcFhsMnQ="; })
    (fetchurl { name = "tzdata-2025.2-py2.py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/5c/23/c7abc0ca0a1526a0774eca151daeb8de62ec457e77262b66b359c3c7679e/tzdata-2025.2-py2.py3-none-any.whl"; hash = "sha256-GkA/raAf+SIcqARNcBho+hMiFdhL65IkLZrNIUf2Z6g="; })
    (fetchurl { name = "python_docx-1.2.0-py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/d0/00/1e03a4989fa5795da308cd774f05b704ace555a70f9bf9d3be057b680bcf/python_docx-1.2.0-py3-none-any.whl"; hash = "sha256-P9R48yUPu7/TuU/h6YWVVzfBRWJ0mIlqimv4H0uvZsc="; })
    (fetchurl { name = "python_pptx-1.0.2-py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/d9/4f/00be2196329ebbff56ce564aa94efb0fbc828d00de250b1980de1a34ab49/python_pptx-1.0.2-py3-none-any.whl"; hash = "sha256-Fgg44LhWWosfZ5R2dYhun+oYql55XbeuUxYG1o54XLo="; })
    (fetchurl { name = "openpyxl-3.1.5-py2.py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/c0/da/977ded879c29cbd04de313843e76868e6e13408a94ed6b987245dc7c8506/openpyxl-3.1.5-py2.py3-none-any.whl"; hash = "sha256-UoLBKxB7/+74JfRhfcApr69B0Opggju7Zl7zB53HneI="; })
    (fetchurl { name = "xlsxwriter-3.2.9-py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/3a/0c/3662f4a66880196a590b202f0db82d919dd2f89e99a27fadef91c4a33d41/xlsxwriter-3.2.9-py3-none-any.whl"; hash = "sha256-ml20K8Xf8BSAbFiiC56ucyKhNKu2/OPJLBgb+ydexbM="; })
    (fetchurl { name = "typing_extensions-4.16.0-py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/49/d3/b8441a820a491ddfc024b0b0cf0393375b75ea13866d9c66727e54c2fc80/typing_extensions-4.16.0-py3-none-any.whl"; hash = "sha256-SByqSBN06BPBsXatoU6X8fZ6RTnOnP6z81DXjWNwwug="; })
    (fetchurl { name = "et_xmlfile-2.0.0-py3-none-any.whl"; url = "https://files.pythonhosted.org/packages/c1/8b/5fe2cc11fee489817272089c4203e679c63b570a5aaeb18d852ae3cbba6a/et_xmlfile-2.0.0-py3-none-any.whl"; hash = "sha256-epFyC8dWhDUCw7dQTHe4/kQhfIXFN9hQN/D1NhUbLKo="; })
    (fetchurl { name = "numpy-2.3.5-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"; url = "https://files.pythonhosted.org/packages/b6/23/2a1b231b8ff672b4c450dac27164a8b2ca7d9b7144f9c02d2396518352eb/numpy-2.3.5-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"; hash = "sha256-DYFj9DrN6ac8KjNgU1Ok8bxHmHRaix1zGDso5bQ1rig="; })
    (fetchurl { name = "pandas-3.0.1-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl"; url = "https://files.pythonhosted.org/packages/3d/fe/89d77e424365280b79d99b3e1e7d606f5165af2f2ecfaf0c6d24c799d607/pandas-3.0.1-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl"; hash = "sha256-UyUnpwEoG53TceL1gu2QlPTBLdn/uCwMVO4o2KyVIMQ="; })
    (fetchurl { name = "pillow-12.3.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"; url = "https://files.pythonhosted.org/packages/84/21/a35af28dcc61f37ed850a2d64c65c701321dfbf25085e469d5559360cbbf/pillow-12.3.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl"; hash = "sha256-eMssaGWjWrj/i3X9Ei9gM7kqYsgoAREOSN3WyTakXZE="; })
    (fetchurl { name = "lxml-6.1.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"; url = "https://files.pythonhosted.org/packages/db/36/aa413bc214dc4f785ad2b2ddd8cc99aae7062d49ab155e91e6011af00daf/lxml-6.1.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl"; hash = "sha256-N5+Kdc9ut+7wrwdLVfSatzuGg4ipjeFGRqvN+kVkuxE="; })
  ];

  nativeBuildInputs = [ unzip ];
  # glibc 只为了构建期用它的 loader 跑冒烟；zlib / gcc-lib 是为了把宿主 nix-ld
  # 那套库路径里"恰好有"的东西固化进包（见 installPhase 的软链）。
  # ⚠️ 故意不挂 autoPatchelfHook：python-build-standalone 是"自带 $ORIGIN rpath + 捆绑库"的
  # 设计，NixOS 上由 programs.nix-ld 提供 /lib64 解释器（本机 configuration.nix 已开）。
  # 实测 autoPatchelf 会把它的符号版本表改坏，起不来：
  #   python3: symbol lookup error: python3: undefined symbol: , version
  # 所以保持上游原样；构建沙箱里没有 nix-ld，冒烟测试改用 glibc 的 loader 显式跑。
  buildInputs = [ glibc zlib stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;
  # ⚠️ 关掉 fixup 的 strip / patchelf：python-build-standalone 的二进制是"已 stripped
  # 且布局非标准"的（binutils 会警告 allocated section `.dynstr' not in segment），
  # 再 strip 一次会把符号版本表弄坏 —— 实测基线正常、`strip -S -p` 后必现
  #   no version information available / symbol lookup error: undefined symbol: , version
  # （patchelf 改写 ELF 同理，所以一起关）。
  dontStrip = true;
  dontPatchELF = true;
  dontShrinkRPath = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    # 官方 tarball 顶层是 python/ 一层，里面才是 bin/ lib/ include/ share/
    cp -r ./. $out/   # unpackPhase 已 cd 进 sourceRoot(=python/)
    site=$out/lib/python3.12/site-packages
    mkdir -p "$site"
    for w in ${lib.concatStringsSep " " (map toString finalAttrs.wheels)}; do
      unzip -q "$w" -d "$site"
    done
    # ⚠️ bin/ 下的符号链接必须实体化：pbs 的 bin/python3 是指向 python3.12 的软链，
    # 从软链路径启动时 glibc/nix-ld 解析符号版本会炸（实测复现：
    #   <path>: no version information available (required by <path>) ×N
    #   <path>: symbol lookup error: undefined symbol: , version
    # 换成实体文件立刻正常）。上游 prepare.ts 其实也是把 bin/ 下的链接复制成实体。
    for link in $out/bin/*; do
      if [ -L "$link" ]; then
        target=$(readlink -f "$link")
        rm "$link"
        cp "$target" "$link"
        chmod u+w "$link"
      fi
    done

    # np/pandas 的 so 需要 libz / libstdc++ / libgcc_s。本机是靠 programs.nix-ld
    # 的库路径提供的，但那是宿主配置、不可依赖 —— 直接放进 python 自带的 lib/，
    # 它的 rpath 是 $ORIGIN/../lib，所有 dlopen 都能命中。
    ln -s ${zlib}/lib/libz.so.1 "$out/lib/libz.so.1"
    ln -s ${stdenv.cc.cc.lib}/lib/libstdc++.so.6 "$out/lib/libstdc++.so.6"
    ln -s ${stdenv.cc.cc.lib}/lib/libgcc_s.so.1 "$out/lib/libgcc_s.so.1"

    # 构建期冒烟：office 技能真正会 import 的那批。沙箱里没有 nix-ld，
    # 用 glibc 的 loader + --library-path 显式拉起（等价于运行时的 nix-ld 效果）。
    loader=${glibc}/lib/ld-linux-x86-64.so.2
    "$loader" --library-path "${lib.makeLibraryPath [ glibc stdenv.cc.cc.lib ]}:$out/lib" \
      "$out/bin/python3" -c 'import numpy, pandas, docx, pptx, openpyxl, lxml, PIL, xlsxwriter, dateutil, six, et_xmlfile; print("python runtime OK:", numpy.__version__, pandas.__version__)'
    runHook postInstall
  '';

  meta.description = "dsh primary runtime 的 Python 3.12.14（python-build-standalone + office wheels）";
})
