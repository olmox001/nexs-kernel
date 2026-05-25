#!/bin/bash
# =============================================================================
# make-nexs-iso.sh - Crea ISO bootabili NEXS-seL4 con GRUB
# =============================================================================

set -e

PROJECT_ROOT="$(pwd)"
NEXS_DIR="${PROJECT_ROOT}/root/example/base-nexs"
ISO_DIR="${PROJECT_ROOT}/iso"

mkdir -p "${ISO_DIR}/boot/grub"

# =============================================================================
# Funzione per creare ISO
# =============================================================================
create_iso() {
    local ARCH="$1"
    echo "=== Creazione ISO NEXS-seL4 per $ARCH ==="

    case "$ARCH" in
        x86_64|amd64)
            BUILD_DIR="${NEXS_DIR}/build_x86_64"
            KERNEL="${BUILD_DIR}/sel4_32.elf"
            INITRD="${BUILD_DIR}/loader.img"
            ISO_NAME="nexs-sel4-x86_64.iso"
            BUILD_TARGET="nexs-sel4-x86_64"
            ;;
        aarch64)
            BUILD_DIR="${NEXS_DIR}/build_aarch64"
            KERNEL="${BUILD_DIR}/loader.img"
            INITRD=""
            ISO_NAME="nexs-sel4-aarch64.iso"
            BUILD_TARGET="nexs-sel4-aarch64"
            ;;
        riscv64)
            BUILD_DIR="${NEXS_DIR}/build_riscv64"
            KERNEL="${BUILD_DIR}/loader.img"
            INITRD=""
            ISO_NAME="nexs-sel4-riscv64.iso"
            BUILD_TARGET="nexs-sel4-riscv64"
            ;;
        *)
            echo "❌ Architettura non supportata: $ARCH"
            return 1
            ;;
    esac

    # Compila se i file mancano
    if [ ! -f "$KERNEL" ] || { [ "$ARCH" = "x86_64" ] && [ ! -f "$INITRD" ]; }; then
        echo "Build per $ARCH mancante o incompleto. Sto compilando..."
        make "$BUILD_TARGET"
    fi

    # Fallback per x86_64 (alcuni build producono nexs.elf invece di sel4_32.elf)
    if [ "$ARCH" = "x86_64" ] && [ ! -f "$KERNEL" ]; then
        if [ -f "${BUILD_DIR}/nexs.elf" ]; then
            KERNEL="${BUILD_DIR}/nexs.elf"
            echo "Usato fallback: nexs.elf"
        else
            echo "❌ Kernel non trovato per x86_64!"
            return 1
        fi
    fi

    # Directory temporanea
    local TEMP_DIR="${ISO_DIR}/temp_${ARCH}"
    mkdir -p "${TEMP_DIR}/boot/grub"

    # Creazione grub.cfg
    cat > "${TEMP_DIR}/boot/grub/grub.cfg" << EOF
set timeout=5
set default=0

menuentry "NEXS-seL4 ($ARCH)" {
    echo "Avvio NEXS su seL4 ($ARCH)..."
EOF

    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
        cat >> "${TEMP_DIR}/boot/grub/grub.cfg" << EOF
    multiboot2 /boot/kernel
    module2 /boot/loader.img
    boot
EOF
    else
        cat >> "${TEMP_DIR}/boot/grub/grub.cfg" << EOF
    chainloader /boot/kernel
    boot
EOF
    fi

    cat >> "${TEMP_DIR}/boot/grub/grub.cfg" << EOF
}

menuentry "Riavvia" { reboot }
menuentry "Spegni"  { halt }
EOF

    # Copia file
    cp "$KERNEL" "${TEMP_DIR}/boot/kernel"
    if [ -n "$INITRD" ] && [ -f "$INITRD" ]; then
        cp "$INITRD" "${TEMP_DIR}/boot/loader.img"
    fi

    # Crea ISO
    echo "Creazione file ISO..."
    grub-mkrescue -o "${ISO_DIR}/${ISO_NAME}" "${TEMP_DIR}" --compress=xz --quiet

    echo "✅ ISO creata: ${ISO_NAME}"
    rm -rf "${TEMP_DIR}"
}

# =============================================================================
# Test ISO (avvia in QEMU)
# =============================================================================
test_iso() {
    local ARCH="$1"
    local ISO="${ISO_DIR}/nexs-sel4-${ARCH}.iso"

    if [ ! -f "$ISO" ]; then
        echo "ISO non trovata per $ARCH. Creazione in corso..."
        create_iso "$ARCH"
    fi

    echo "🚀 Avvio test QEMU per $ARCH..."

    case "$ARCH" in
        x86_64|amd64)
            qemu-system-x86_64 \
                -cpu qemu64,+fsgsbase,+pdpe1gb \
                -m 1G \
                -cdrom "$ISO" \
                -boot d \
                -serial mon:stdio \
                -nographic \
                -display none &
            ;;
        aarch64)
            qemu-system-aarch64 \
                -machine virt,virtualization=on \
                -cpu cortex-a53 \
                -m 2G \
                -cdrom "$ISO" \
                -boot d \
                -nographic &
            ;;
        riscv64)
            qemu-system-riscv64 \
                -machine virt \
                -m 2G \
                -cdrom "$ISO" \
                -boot d \
                -nographic &
            ;;
    esac
}

# =============================================================================
# Main
# =============================================================================
case "$1" in
    --all)
        echo "========================================="
        echo "🚀 Creazione ISO per TUTTE le architetture"
        echo "========================================="
        create_iso "x86_64"
        create_iso "aarch64"
        create_iso "riscv64"
        echo "🎉 Tutte le ISO create in ${ISO_DIR}/"
        ls -lh "${ISO_DIR}/"*.iso
        ;;

    --test)
        if [ -z "$2" ]; then
            echo "Uso: $0 --test <aarch64|x86_64|riscv64>"
            exit 1
        fi
        test_iso "$2"
        ;;

    --test-all)
        echo "🚀 Avvio test in 3 terminali separati..."
        test_iso "x86_64" &
        sleep 2
        test_iso "aarch64" &
        sleep 2
        test_iso "riscv64" &
        echo "✅ Test avviati (3 istanze QEMU)"
        ;;

    *)
        if [ -n "$1" ]; then
            create_iso "$1"
        else
            echo "Uso:"
            echo "  $0 <aarch64 | x86_64 | riscv64>     → crea una ISO"
            echo "  $0 --all                            → crea tutte le ISO"
            echo "  $0 --test <arch>                    → crea + avvia in QEMU"
            echo "  $0 --test-all                       → avvia test su 3 architetture"
        fi
        ;;
esac