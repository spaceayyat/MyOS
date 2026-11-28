#!/usr/bin/env bash
# Build the PIP package, test it, install it, run it headless, measure it and
# remove it. Meant for a throwaway Fedora 44 container (CI).
# Usage: scripts/test-pip.sh OUTPUT-DIR
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || die "usage: $0 OUTPUT-DIR"
out="$(mkdir -p "$1" && cd "$1" && pwd)"

dnf install -y rpm-build cmake gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel \
  layer-shell-qt-devel wayland-devel wlr-protocols-devel pkgconf-pkg-config \
  labwc xorg-x11-server-Xwayland grim wlr-randr dbus-daemon qt6-qtwayland qt6-qtsvg \
  rsms-inter-fonts jetbrains-mono-fonts google-noto-sans-fonts google-noto-sans-symbols2-fonts \
  papirus-icon-theme procps-ng libnotify xdg-utils

work="$(mktemp -d)"
info "Tests"
cmake -S "${VYLO_ROOT}" -B "${work}/tests" -DVYLO_BUILD_PIP=ON -DVYLO_BUILD_TESTS=ON \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "${work}/tests" -j"$(nproc)"
VYLO_NETWORK_TEST=1 "${work}/tests/desktop/pip/pip-test"
cmake --install "${work}/tests" >/dev/null   # desktop too, for the screenshots

info "Package"
mkdir -p "${work}/rpm/SOURCES"
tar -czf "${work}/rpm/SOURCES/vylo-0.4.0.tar.gz" -C "${VYLO_ROOT}" --transform 's,^\.,vylo-0.4.0,' \
  --exclude=./.git --exclude=./build --exclude=./output .
rpmbuild --define "_topdir ${work}/rpm" -bb "${VYLO_ROOT}/packaging/vylo-pip.spec"
rm /usr/bin/vylo-pip
dnf install -y "${work}"/rpm/RPMS/*/vylo-pip-*.rpm
cp "${work}"/rpm/RPMS/*/vylo-pip-*.rpm "${out}/"
rpm -ql vylo-pip

info "Switched off by default: started at sign-in it must leave at once"
mkdir -p "${work}/run" "${work}/home" "${work}/labwc"
chmod 700 "${work}/run"
export XDG_RUNTIME_DIR="${work}/run" HOME="${work}/home" USER=traveller OUT="${out}"
timeout 5 vylo-pip --autostart   # exit status 0, and no display is needed
if pgrep -x vylo-pip; then die "PIP stayed running although it is switched off"; fi

info "Running"
cp "${VYLO_ROOT}"/image/config/rootfs/usr/share/vylo/labwc/{rc.xml,themerc-override} "${work}/labwc/"
export VYLO_DATA_DIR="${VYLO_ROOT}/image/config/rootfs/usr/share"
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software XDG_CURRENT_DESKTOP=VYLO
cat > "${work}/run.sh" <<'RUN'
#!/usr/bin/env bash
set -u
wlr-randr --output HEADLESS-1 --custom-mode 1600x900
VYLO_PREVIEW=none vylo-shell >"${OUT}/shell.log" 2>&1 &
shell=$!
sleep 4
shot() {
  VYLO_PIP_DEMO="$2" vylo-pip >>"${OUT}/pip.log" 2>&1 &
  local pid=$!
  sleep 7
  if kill -0 "${pid}" 2>/dev/null; then grim "${OUT}/$1.png"; else echo "$1: PIP exited" >>"${OUT}/errors"; fi
  kill "${pid}"; wait "${pid}" 2>/dev/null
}
shot pip "help"
shot pip-calc "12 * (3 + 4)"
shot pip-download "download https://example.org/files/star-map.pdf"
vylo-pip >>"${OUT}/pip.log" 2>&1 &
pid=$!
sleep 10
before=$(awk '{print $14+$15}' "/proc/${pid}/stat")
sleep 30
after=$(awk '{print $14+$15}' "/proc/${pid}/stat")
{
  grep -E '^(VmRSS|Threads)' "/proc/${pid}/status"
  awk '/^Pss:/ {print "Pss (share of memory):", $2, $3}' "/proc/${pid}/smaps_rollup"
  echo "CPU ticks in 30 idle seconds: $((after - before)) of $((30 * $(getconf CLK_TCK)))"
} >"${OUT}/resources.txt"
kill "${pid}"; wait "${pid}" 2>/dev/null
vylo-settings --pip >"${OUT}/settings.log" 2>&1 &
pid=$!
sleep 6
grim "${OUT}/pip-settings.png"
kill "${pid}" "${shell}"
RUN
chmod +x "${work}/run.sh"
timeout 180 dbus-run-session labwc -C "${work}/labwc" -S "${work}/run.sh" >"${out}/labwc.log" 2>&1 || true

status=0
for f in pip.png pip-download.png pip-settings.png resources.txt; do
  [[ -s "${out}/${f}" ]] || { echo "missing: ${f}"; status=1; }
done
[[ ! -s "${out}/errors" ]] || { cat "${out}/errors"; status=1; }
tail -n +1 "${out}"/{pip,settings}.log "${out}/resources.txt"
if grep -nE 'qrc:/|TypeError|ReferenceError|is not installed|Binding loop' "${out}"/{pip,settings,shell}.log; then
  echo "QML problems found"; status=1
fi

info "Removal"
dnf remove -y vylo-pip
if command -v vylo-pip || [[ -e /usr/share/applications/vylo-pip.desktop ]]; then
  echo "PIP files remain"; status=1
fi
exit "${status}"
