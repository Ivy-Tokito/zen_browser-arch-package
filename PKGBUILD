_pkgname=zen
pkgname=zen-browser
_pkgver=""
pkgver="${_pkgver//-/.}"
pkgrel=1
pkgdesc="Standalone web browser"
arch=('x86_64')
url="https://github.com/zen-browser/desktop"
license=(MPL-2.0)
depends=(libxt mime-types dbus-glib nss ttf-font systemd)
optdepends=('ffmpeg: H264/AAC/MP3 decoding'
            'networkmanager: Location detection via available WiFi networks'
            'libnotify: Notification integration'
            'pulseaudio: Audio support'
            'speech-dispatcher: Text-to-Speech'
            'hunspell-en_US: Spell checking, American English')
makedepends=('unzip' 'zip' 'diffutils' 'yasm' 'mesa' 'imake' 'inetutils' 'xorg-server-xvfb'
             'rust' 'clang' 'llvm' 'alsa-lib' 'jack' 'cbindgen' 'nasm'
             'nodejs' 'lld' 'bc' 'python' 'pciutils' 'dump_syms'
             'wasi-compiler-rt' 'wasi-libc' 'wasi-libc++' 'wasi-libc++abi'
             'git' 'npm' 'rsync' 'libpulse' 'sccache' 'jq')
provides=("zen-browser=$pkgver")
conflicts=('zen-browser' 'zen-browser-bin')

source=("git+https://github.com/zen-browser/desktop.git#tag=$_pkgver"
        "$_pkgname.desktop"
        "policies.json"
        "mozconfig")
sha256sums=('SKIP'
            '5b7d8f37fb1c57aa1a19105ad51d8196fd66e5c09072efb1e1fe2bd2035cd7e0'
            '81a724e7d329def16088c6788c322b4f9e8f016fb876f8a6b0eb88c4e55d93d8'
            '2d6794c776490fc8418a5bfd3999f52f14e318baa1858a22ff02ceef982214d8')
options=(!strip !debug)

build() {
	cd desktop || exit 1
	git submodule init && git submodule update

	# sccache
	sccache --stop-server || echo "No sccache Server Running" # Kill any sccache server running
	export SCCACHE_DIRECT=true SCCACHE_LOG=error SCCACHE_ERROR_LOG=/tmp/sccache.log
	sccache --start-server

	# Optimize flags
	export CFLAGS+=" -O3 -ffp-contract=fast -march=x86-64-v3 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -mavx2 -mfma -maes -mpopcnt -mpclmul"
	export CPPFLAGS+=" -O3 -ffp-contract=fast -march=x86-64-v3 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -mavx2 -mfma -maes -mpopcnt -mpclmul"
	export CXXFLAGS+=" -O3 -flto=full -ffat-lto-objects -ffp-contract=fast -march=x86-64-v3 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -mavx2 -mfma -maes -mpopcnt -mpclmul"
	export LDFLAGS+=" -Wl,-O3 -Wl,-mllvm,-fp-contract=fast -march=x86-64-v3 -Wl,--no-keep-memory"
	export RUSTFLAGS+=" -C target-cpu=x86-64-v3 -C target-feature=+sse4.1 -C target-feature=+avx2 -C codegen-units=1 -Clink-args=--icf=safe"
	export POLLY=" -mllvm -polly -mllvm -polly-2nd-level-tiling -mllvm -polly-loopfusion-greedy -mllvm -polly-pattern-matching-based-opts -mllvm -polly-position=before-vectorizer -mllvm -polly-vectorizer=stripmine"

	export MOZ_NOSPAM=1
	export MOZBUILD_STATE_PATH="$srcdir/mozbuild"
	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=pip

	# Get Firefox Source And import Zen Changes
	pnpm install
	pnpm surfer download
	pnpm surfer import

	# Export Build Variables
	export builddate=$(date +"%Y-%m-%d")
	export version="$_pkgver"
	export COMMIT_HEAD="$(git rev-parse HEAD)"
	export BUILD_OBJ_PATH="${srcdir}/desktop/engine/obj"
	echo "$version" > engine/browser/config/version_display.txt
	echo "$version" > engine/browser/config/version.txt

	# Langpacks
	echo "Fetching Langpacks"
	bash scripts/download-language-packs.sh

	cd engine || exit 1

	# LTO needs more open files
	ulimit -n 4096

	# Do 3-tier PGO
	echo "Building instrumented browser..."
	cat > .mozconfig $srcdir/mozconfig - <<END
ac_add_options --enable-profile-generate=cross
END
	./mach build

	echo "Profiling Instrumented Browser..."
	./mach package
	LLVM_PROFDATA=llvm-profdata \
		JARLOG_FILE="$PWD/jarlog" \
		xvfb-run -s "-screen 0 1920x1080x24 -nolisten local" \
		./mach python build/pgo/profileserver.py
	stat -c "Profile data found (%s bytes)" merged.profdata
	test -s merged.profdata

	stat -c "Jar log found (%s bytes)" jarlog
	test -s jarlog

	echo "Removing Instrumented Browser..."
	./mach clobber

	echo "Building PGO+LTO Optimized Browser..."
	cat > .mozconfig "$srcdir/mozconfig" - <<END
ac_add_options --enable-lto=full,cross
ac_add_options --enable-profile-use=cross
ac_add_options --with-pgo-profile-path=${PWD@Q}/merged.profdata
ac_add_options --with-pgo-jarlog=${PWD@Q}/jarlog
END
	./mach build
	echo "Build Completed!"
}
package() {
	cd desktop/engine || exit 1

	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=pip

	DESTDIR="${pkgdir}" ./mach install

	rm -rf "${pkgdir}/src"

	# Desktops
	install -d "${pkgdir}/usr/share/applications/"
	install -m644 "${srcdir}/${_pkgname}.desktop" "$pkgdir/usr/share/applications/"

	# Icons
	for i in 16 32 48 64 128; do
		install -d "${pkgdir}/usr/share/icons/hicolor/${i}x${i}/apps/"
		ln -Ts "/usr/lib/zen/browser/chrome/icons/default/default${i}.png" \
			"${pkgdir}/usr/share/icons/hicolor/${i}x${i}/apps/${_pkgname}.png"
	done

	# Install a wrapper to avoid confusion about binary path
	install -Dm755 /dev/stdin "${pkgdir}/usr/bin/zen" <<END
#!/bin/sh
exec /usr/lib/zen/zen "\$@"
END

	# Replace duplicate binary with wrapper
	# https://bugzilla.mozilla.org/show_bug.cgi?id=658850
	ln -srf "${pkgdir}/usr/bin/zen" \
		"${pkgdir}/usr/lib/zen/zen-bin"

	# Disable update checks (managed by pacman)
	mkdir "${pkgdir}/usr/lib/zen/distribution"
	install -m644 "${srcdir}/policies.json" "${pkgdir}/usr/lib/${_pkgname}/distribution/"
}
