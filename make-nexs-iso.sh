#!/bin/bash
# =============================================================================
# make-nexs-iso.sh — NEXS-seL4 ISO con Limine (fix fsgsbase)
# =============================================================================

set -e

PROJECT_ROOT="$(pwd)"
NEXS_DIR="${PROJECT_ROOT}/root/example/base-nexs"
ISO_DIR="${PROJECT_ROOT}/iso"
mkdir -p "${ISO_DIR}"

BREW_PREFIX=$(brew --prefix)
LIMINE_BIN="$BREW_PREFIX/bin/limine"

# =============================================================================
create_iso() {
    local ARCH="$1"
    echo "=== Creazione ISO NEXS-seL4 ($ARCH) con Limine ==="

    BUILD_DIR="${NEXS_DIR}/build_x86_64"
    KERNEL="${BUILD_DIR}/sel4_32.elf"
    MODULE="${BUILD_DIR}/loader.img"
    ISO_NAME="nexs-sel4-x86_64.iso"
    MAKE_TARGET="run-nexs-x86_64"

    if [ ! -f "$KERNEL" ] || [ ! -f "$MODULE" ]; then
        echo "→ Build mancante, eseguo $MAKE_TARGET..."
        make "$MAKE_TARGET"
    fi

    ISO_ROOT="${ISO_DIR}/temp_iso"
    rm -rf "$ISO_ROOT"
    mkdir -p "$ISO_ROOT/limine"

    cp "$KERNEL" "$ISO_ROOT/nexs.elf"
    cp "$MODULE" "$ISO_ROOT/loader.img"

    cp "$BREW_PREFIX/share/limine/limine-bios.sys" "$ISO_ROOT/"
    cp "$BREW_PREFIX/share/limine/limine-bios.sys" "$ISO_ROOT/limine/"
    cp "$BREW_PREFIX/share/limine/limine-bios-cd.bin" "$ISO_ROOT/limine/"

    cat > "$ISO_ROOT/limine/limine.conf" << EOF
timeout: 3
serial: yes

/NEXS-seL4 (x86_64)
    protocol: multiboot2
    path: boot():/nexs.elf
    module_path: boot():/loader.img
EOF

    echo "[*] Creazione ISO..."
    xorriso -as mkisofs \
        -R -J -V "NEXS_SEL4" \
        -b limine/limine-bios-cd.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -o "${ISO_DIR}/${ISO_NAME}" \
        "$ISO_ROOT" > /dev/null

    echo "[*] Installazione Limine..."
    "$LIMINE_BIN" bios-install "${ISO_DIR}/${ISO_NAME}" > /dev/null

    echo "✅ ISO creata: ${ISO_NAME} ($(du -sh "${ISO_DIR}/${ISO_NAME}" | cut -f1))"
    rm -rf "$ISO_ROOT"
}

# =============================================================================
test_iso() {
    local ISO="${ISO_DIR}/nexs-sel4-x86_64.iso"
    [ ! -f "$ISO" ] && create_iso "x86_64"

    echo "🚀 Avvio in QEMU (con fsgsbase + pdpe1gb)..."
    qemu-system-x86_64 \
        -cpu qemu64,+fsgsbase,+pdpe1gb,+xsaveopt,+xsave \
        -m 1G \
        -cdrom "$ISO" \
        -boot d \
        -serial mon:stdio \
        -nographic
}

# =============================================================================
case "$1" in
    --all|x86_64|amd64)
        create_iso "x86_64"
        ;;
    --test)
        test_iso
        ;;
    *)
        echo "Uso:"
        echo "  $0 x86_64     → crea ISO"
        echo "  $0 --all      → crea ISO"
        echo "  $0 --test     → crea + avvia in QEMU"
        ;;
esac