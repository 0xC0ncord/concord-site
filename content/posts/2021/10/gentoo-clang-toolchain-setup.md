---
title: "Gentoo Clang Toolchain Initial Setup"
date: 2021-10-03T14:31:34-04:00
draft: false
categories:
- cobalt shield
tags:
- gentoo
- clang
- cfi
---
Clang is pivoted to become the next-generation C/C++ compiler for modern systems.
It aims to provide better diagnostics, be easier to integrate with IDEs, and have a license that is more compatible with commercial products.[^1]
On Gentoo, Clang is already available as a compiler that can be used system-wide instead of GCC.
The primary motivation for this is to take better advantage of link-time-optimization (LTO)[^2] features.
While GCC does support LTO, it only supports "full" LTO, which may not be feasible on lower-end systems.
This is because full LTO requires merging all of the program's input into a single module at once, which can be very demanding on systems with low memory or compute power.
Clang, on the other hand, supports "ThinLTO,"[^3] which aims to be a viable alternative to full LTO by only merging summaries of LTO bitcode at link time.
This allows for fast and efficient optimizations to be made to the program without requiring the amount of resources that full LTO otherwise would.

The other primary motivation for implementing this on Gentoo is to build programs with Control Flow Integrity (CFI)[^4] enabled.
CFI is a series of compile-time hardening features that can be utilized to mitigate or eliminate various code-reuse attacks, among other things.
Clang employs a variety of different CFI schemes, none of which are currently (nor are there any plans to be) supported by GCC.
We can take advantage of Clang's CFI to further harden the system by building our programs with it, and therefore reduce attack surface and prevent potentially malicious behavior as a result of a compromise.
Lastly, CFI is available[^5] as part of the mainline Linux kernel, although at the time of writing, it is only currently supported on ARM64 platforms.
Support for x86\_64 is in the works[^6], and will likely land in upstream Linux in 5.16.

Getting started with using Clang as a system-wide compiler isn't too difficult - it's _mostly_ supported in Gentoo[^7], with only a few various edge cases floating around in my personal experience.

{{< notice warning >}}
While I use Clang as a system-wide compiler on Gentoo systems in production, it is not without its problems.
First and foremost, GCC is the defacto standard compiler on Gentoo.
While Clang support does exist, it is not a high priority and as such I do not recommend removing GCC as an alternative compiler.
This is because many packages still refuse to compile (or run after being built) with Clang, although that number is shrinking.

Additionally, for those problematic packages that do not build cleanly, there are a series of workarounds that you must employ in order to get them to build, all of which I will detail in this guide.
I do not, however, consider any of these practices recommended for use by an inexperienced Gentoo user who is afraid of potentially breaking their system.
{{< /notice >}}

To get started, we need to initially build the entire Clang/LLVM toolchain using GCC.
I find it is much easier to create a package set so that we can emerge the set as opposed to each package individually.
```sh
# /etc/portage/sets/llvm-toolchain
sys-devel/llvm[abi_x86_32,gold]
sys-devel/clang[abi_x86_32,default-compiler-rt,default-libcxx,default-lld,static-analyzer]
sys-devel/lld
sys-devel/clang-runtime[abi_x86_32,compiler-rt,libcxx,sanitize]
sys-libs/compiler-rt[clang]
sys-libs/compiler-rt-sanitizers[clang,asan,cfi,dfsan,gwp-asan,hwasan,libfuzzer,lsan,memprof,msan,profile,safestack,scudo,tsan,ubsan,xray]
sys-libs/libcxx[abi_x86_32,libunwind,static-libs]
sys-libs/libcxxabi[abi_x86_32,libunwind,static-libs]
sys-libs/libunwind[abi_x86_32,static-libs]
```
{{< notice note >}}
The text inside square brackets ([]) next to each package name denotes USE flags required in this set.
`abi_x86_32` is the USE flag to enable 32-bit support if you intend on using Clang to build 32-bit packages.
If you do not need this, remove the `abi_x86_32` USE flag.
{{< /notice >}}

{{< notice note >}}
The `compiler-rt` and `compiler-rt-sanitizers` packages and USE flags allow Clang to use its own static analyzer when performing compile-time sanitization.
The `libcxx` and `libcxxabi` packages and USE flags allow Clang to use `libc++` as the default C++ standard library instead of GCC's `stdlibc++`.
We will need these if you want to set up CFI support later, but they are otherwise optional.

It should be noted that switching between `libc++` and `stdlibc++` should not be taken lightly, as they are not ABI-compatible. However, some packages (namely Chromium) refuse to build with CFI unless its dependencies are built with `libc++`.
{{< /notice >}}

{{< notice note >}}
`llvm-libunwind` is the better option over `libunwind`.
However, there are several packages that still hard-depend on `libunwind` as opposed to offerring `llvm-libunwind` as an alternative, namely [Samba](https://bugs.gentoo.org/791349).
If you do not use any of these problematic packages, you are encouraged to use `llvm-libunwind` instead and enable the corresponding USE flags.
{{< /notice >}}

After that, enable the USE flags in this set, either globally or on a per-package basis.

```sh
# /etc/portage/make.conf
...
USE="llvm clang gold libcxx libcxxabi
    default-libcxx compiler-rt
    default-compiler-rt default-lld libunwind"
...
```

Finally, we can emerge the set.
```sh
emerge -av @llvm-toolchain
```

Before we begin using it, the Clang toolchain needs to be bootstrapped, or in other words, rebuilt using Clang itself.
We need to set Clang and the LLVM tools as the defaults for the system.
Additionally, we should start enabling the relevant `CFLAGS` and `CXXFLAGS`.
It is imperative that we enable LTO now if we intend to use it, as Clang or LLVM may emit spurious errors when building LTO-enabled packages when they themselves are not built with LTO (also, we get a nice performance boost to compilation).

```sh
# /etc/portage/make.conf

# Use clang instead of gcc
CC="clang"
CXX="clang++"
LD="ld.lld"

# Use the proper tools capable of dealing with LLVM bitcode
AR="llvm-ar"
NM="llvm-nm"
RANLIB="llvm-ranlib"
STRIP="llvm-strip"
OBJDUMP="llvm-objdump"
OBJCOPY="llvm-objcopy"
OBJSIZE="llvm-objsize"
STRINGS="llvm-strings"
READELF="llvm-readelf"

# Standard flags that normally don't cause problems
COMMON_FLAGS="-march=native -mtune=native -O3 -pipe -fomit-frame-pointer"

# Flags for compile-time hardening
HARDENED_FLAGS="${COMMON_FLAGS} -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fstack-clash-protection"

# LTO flags. We use LTO_FLAGS_THIN here but we declare LTO_FLAGS
# with full LTO as it will be easier to switch to later
LTO_FLAGS="-flto"
LTO_FLAGS_THIN="-flto=thin"

CFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS_THIN}"
# Use libc++ as the standard C++ library
CXXFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS_THIN} -stdlib=libc++"
# Hardened LDFLAGS and use lld as the default linker
LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-S -Wl,-z,now -Wl,-z,relro -fuse-ld=lld -Wl,-unwindlib=libunwind"
```
{{< notice note >}}
If you do not intend to use `libc++` as the standard C++ library, omit the corresponding argument from `CXXFLAGS`.
{{< /notice >}}

After that, rebuild your toolchain.
```sh
emerge -av @llvm-toolchain
```

At this point you should now have a functioning Clang toolchain.
But, we need to set up our environment to work around various problematic packages.
To do this, we create package env files in `/etc/portage/env` with various flags that override our defaults in `make.conf`.
Then, we can tell Portage to use these overrides in `/etc/portage/package.env`.

```sh
# /etc/portage/env/compiler-gcc

CC="gcc"
CXX="g++"
AR="ar"
NM="nm"
RANLIB="ranlib"
STRIP="strip"
OBJDUMP="objdump"
OBJCOPY="objcopy"
OBJSIZE="objsize"
STRINGS="strings"
READELF="readelf"
CFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS}"
CXXFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS} -nostdinc++ -I/usr/include/c++/v1"
FCFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS}"
FFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS}"
LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-S -Wl,-z,now -Wl,-z,relro -fuse-ld=lld -nodefaultlibs -lc++ -lc++abi -lm -lc -lgcc_s -lgcc"
```

This env file overrides various flags in `make.conf` when building a package.
To apply this to a package, we provide it in an entry in `/etc/portage/package.env` like so:
```sh
# /etc/portage/package.env/podman

app-emulation/podman compiler-gcc
```
The above env file tells Portage to use GCC as the compiler, but still using `lld` as the linker and `libc++` as the standard C++ library.
Not all packages can be built this way, so we simply narrow down the flags closer to the Gentoo defaults until it builds.
This is usually a series of trial and error steps, but in my experience I have only found a small handful of packages that can only be built with the defaults.

{{< notice tip >}}
You can stack env flags on a package by declaring more than one in `/etc/portage/package.env`.
When this is done, the flags will be applied in order from left to right.
You can use this to your advantage by keeping your env files slim and only containing the flags for a specific purpose.
{{< /notice >}}

What follows are additional env files I use that can help with this entire procedure.
```sh
# /etc/portage/env/linker-gold

# This env tells Portage to use the `gold` linker.
# While `gold` is technically deprecated, it is still
# functional and supports LTO, unlike the `bfd` linker
# which is the Gentoo default.
LD="ld.gold"
LDFLAGS="${LDFLAGS} -fuse-ld=gold"
```

```sh
# /etc/portage/env/no-lto

# This env disables LTO completely for the package.
# Some packages simply refuse to build with LTO.
CFLAGS="${CFLAGS} -fno-lto"
CXXFLAGS="${CXXFLAGS} -fno-lto"
```

```sh
# /etc/portage/env/linker-bfd

#  This env tells Portage to use the `bfd` linker.
LD="ld.bfd"
LDFLAGS="${LDFLAGS} -fuse-ld=bfd"
```

```sh
# /etc/portage/env/with-lomp

# This tells Portage to explicitly link the package
# with `libomp`.
#
# For some reason, some packages do not declare all
# required shared objects during the link phase when
# built with Clang, even though they compile fine
# otherwise (Audacity is one of these).
#
# If you get any compilation errors that say things
# like "unresolved symbol", try identifying what
# shared object provides that symbol and link to it
# explicitly like above. Some other libraries I have
# seen affected by this include `libm`, `libz`, and
# `libdl`, but these are usually rare.
CFLAGS="${CFLAGS} -lomp"
CXXFLAGS="${CXXFLAGS} -lomp"
```

```sh
# /etc/portage/env/compiler-gcc-libstdc++

# Use GCC as the compiler with `libstdc++` as the
# standard C++ library. There isn't really an easy
# way to explicitly specify the standard C++ library
# with GCC like you can with Clang's `-stdlib=`
# argument, so unfortuantely we have to declare
# these flags in combination with setting GCC.
CC="gcc"
CXX="g++"
AR="ar"
NM="nm"
RANLIB="ranlib"
STRIP="strip"
OBJDUMP="objdump"
OBJCOPY="objcopy"
OBJSIZE="objsize"
STRINGS="strings"
READELF="readelf"
CFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS}"
CXXFLAGS="${HARDENED_FLAGS} ${LTO_FLAGS}"
LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-S -Wl,-z,now -Wl,-z,relro -fuse-ld=gold"
```

Whenever troubleshooting a problematic package, I usually follow this order of flags, adding on additional ones until the package builds.
1. Disable LTO.
2. Use GCC as the compiler.
3. Use `gold` as the linker.
4. Use GCC as the compiler and `libstdc++` as the standard C++ library.
5. Use `bfd` as the linker.

In the next part of this series of guides we will move into building packages with CFI, and then finally I will detail my process for building Ungoogled Chromium with CFI as well.

See you next time!

[^1]: https://clang.llvm.org/
[^2]: https://www.llvm.org/docs/LinkTimeOptimization.html
[^3]: https://clang.llvm.org/docs/ThinLTO.html
[^4]: https://clang.llvm.org/docs/ControlFlowIntegrity.html
[^5]: http://lkml.iu.edu/hypermail/linux/kernel/2104.3/01746.html
[^6]: https://github.com/samitolvanen/linux/tree/clang-cfi
[^7]: https://wiki.gentoo.org/wiki/Clang
