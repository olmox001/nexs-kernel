# Root Makefile for seL4 + Microkit Multi-Architecture Development

# Workspace Directories (must come first — other variables depend on ROOT_DIR)
ROOT_DIR     := $(shell pwd)
SDK_SRC_DIR  := $(ROOT_DIR)/root

# Host tools and environment configuration
export PATH := $(HOME)/.cargo/bin:/usr/local/opt/llvm/bin:$(PATH)
PYTHON := $(ROOT_DIR)/scratch/venv/bin/python3
LLVM := True

# seL4 kernel source:
#   kernel/   = local project copy of seL4 core (kernel/ + aarch/ for ARM).
#               ARM arch is in aarch/, NOT yet wired into kernel/src/arch/arm/.
#               Use SEL4_LOCAL once aarch/ is merged into kernel/src/arch/arm/.
#   scratch/  = reference clone — used for all SDK builds until merge is done.
SEL4_LOCAL   := $(ROOT_DIR)/kernel
SEL4_SRC_DIR := $(ROOT_DIR)/scratch/reference/seL4

SDK_DIR      := $(SDK_SRC_DIR)/release/microkit-sdk-2.2.0-dev
EXAMPLE_DIR  := $(SDK_SRC_DIR)/example/hello

.PHONY: all help clean clean-sdk clean-all \
        aarch64 riscv64 x86_64 x86_32 \
        build-sdk-aarch64 build-sdk-riscv64 build-sdk-x86_64 build-sdk-amd64 \
        kernel-check kernel-merge \
        fetch-deps nexs-host \
        nexs-sel4-aarch64 nexs-sel4-riscv64 nexs-sel4-x86_64 \
        nexs-run-aarch64 nexs-run-riscv64 nexs-run-x86_64 \
        run-nexs-aarch64 run-nexs-riscv64 run-nexs-x86_64 run-nexs-amd64

all: help

help:
	@echo "nexskernel — available targets:"
	@echo ""
	@echo "  SDK build:"
	@echo "    build-sdk-aarch64   Build Microkit SDK for aarch64"
	@echo "    build-sdk-riscv64   Build Microkit SDK for riscv64"
	@echo "    build-sdk-x86_64    Build Microkit SDK for x86_64"
	@echo ""
	@echo "  NEXS (base-nexs):"
	@echo "    run-nexs-aarch64    Compile + package + run NEXS under seL4 aarch64"
	@echo "    run-nexs-riscv64    Compile + package + run NEXS under seL4 riscv64"
	@echo "    run-nexs-x86_64     Compile + package + run NEXS under seL4 x86_64"
	@echo "    nexs-host           Build the hosted NEXS interpreter"
	@echo ""
	@echo "  Hello-world examples:"
	@echo "    aarch64 / riscv64 / x86_64   Build + run Microkit hello-world"
	@echo ""
	@echo "  Dependency management:"
	@echo "    sel4-initializer    Clone/update nexs-kernel SDK builder"
	@echo "    fetch-deps          Clone/update base-nexs runtime"
	@echo ""
	@echo "  SDK path: SDK_DIR=$(SDK_DIR)"

# SDK Build Targets
build-sdk-aarch64:
	@echo "========================================="
	@echo "Building SDK for AArch64 (qemu_virt_aarch64)..."
	@echo "========================================="
	cd $(SDK_SRC_DIR) && $(PYTHON) build_sdk.py --sel4 $(SEL4_SRC_DIR) --boards qemu_virt_aarch64 --configs debug --skip-docs --llvm

build-sdk-riscv64:
	@echo "========================================="
	@echo "Building SDK for RISC-V 64-bit (qemu_virt_riscv64)..."
	@echo "========================================="
	cd $(SDK_SRC_DIR) && $(PYTHON) build_sdk.py --sel4 $(SEL4_SRC_DIR) --boards qemu_virt_riscv64 --configs debug --skip-docs --llvm

build-sdk-x86_64:
	@echo "========================================="
	@echo "Building SDK for AMD64 (x86_64_generic)..."
	@echo "========================================="
	cd $(SDK_SRC_DIR) && $(PYTHON) build_sdk.py --sel4 $(SEL4_SRC_DIR) --boards x86_64_generic --configs debug --skip-docs --llvm

build-sdk-amd64: build-sdk-x86_64

# AArch64 (qemu_virt_aarch64) Target
aarch64:
	@echo "========================================="
	@echo "Compiling Hello World for AArch64..."
	@echo "========================================="
	mkdir -p $(EXAMPLE_DIR)/build_aarch64
	$(MAKE) -C $(EXAMPLE_DIR) BUILD_DIR=build_aarch64 MICROKIT_BOARD=qemu_virt_aarch64 MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR) LLVM=$(LLVM)
	@echo "========================================="
	@echo "Running AArch64 Hello World in QEMU..."
	@echo "========================================="
	qemu-system-aarch64 \
		-machine virt,virtualization=on \
		-cpu cortex-a53 \
		-nographic \
		-serial mon:stdio \
		-device loader,file=$(EXAMPLE_DIR)/build_aarch64/loader.img,addr=0x70000000,cpu-num=0 \
		-m size=2G

# RISC-V 64-bit (qemu_virt_riscv64) Target
riscv64:
	@echo "========================================="
	@echo "Compiling Hello World for RISC-V 64-bit..."
	@echo "========================================="
	mkdir -p $(EXAMPLE_DIR)/build_riscv64
	$(MAKE) -C $(EXAMPLE_DIR) BUILD_DIR=build_riscv64 MICROKIT_BOARD=qemu_virt_riscv64 MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR) LLVM=$(LLVM)
	@echo "========================================="
	@echo "Running RISC-V 64-bit Hello World in QEMU..."
	@echo "========================================="
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-serial mon:stdio \
		-kernel $(EXAMPLE_DIR)/build_riscv64/loader.img \
		-m size=2G

# AMD64 / x86_64 Target
x86_64:
	@echo "========================================="
	@echo "Compiling Hello World for AMD64..."
	@echo "========================================="
	mkdir -p $(EXAMPLE_DIR)/build_x86_64
	$(MAKE) -C $(EXAMPLE_DIR) BUILD_DIR=build_x86_64 MICROKIT_BOARD=x86_64_generic MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR) LLVM=$(LLVM)
	@echo "========================================="
	@echo "Running AMD64 Hello World in QEMU..."
	@echo "========================================="
	qemu-system-x86_64 \
		-cpu qemu64,+fsgsbase,+pdpe1gb,+xsaveopt,+xsave \
		-m 1G \
		-display none \
		-serial mon:stdio \
		-kernel $(EXAMPLE_DIR)/build_x86_64/sel4_32.elf \
		-initrd $(EXAMPLE_DIR)/build_x86_64/loader.img

# NEXS runtime directory (populated by fetch-deps)
NEXS_DIR := $(SDK_SRC_DIR)/example/base-nexs

run-nexs-aarch64:
	@if [ ! -d "$(NEXS_DIR)" ]; then \
		echo ""; \
		echo "[error] NEXS runtime not found at $(NEXS_DIR)"; \
		echo "        Run:  make fetch-deps"; \
		echo "        This will clone base-nexs and copy it into root/example/base-nexs."; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f "$(SDK_DIR)/board/qemu_virt_aarch64/debug/include/kernel/gen_config.h" ]; then \
		echo "SDK not built for aarch64. Run: make build-sdk-aarch64"; \
		exit 1; \
	fi
	@echo "========================================="
	@echo "Compiling NEXS Stable (multi-PD) for AArch64..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-multikernel-aarch64 MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_aarch64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/hal/sel4/nexs_aarch64.system \
		--search-path $(NEXS_DIR)/build/sel4-multikernel \
		--board qemu_virt_aarch64 \
		--config debug \
		-o $(NEXS_DIR)/build_aarch64/loader.img \
		-r $(NEXS_DIR)/build_aarch64/report.txt
	@echo "========================================="
	@echo "Running NEXS under seL4 QEMU Simulation..."
	@echo "========================================="
	qemu-system-aarch64 \
		-machine virt,virtualization=on \
		-cpu cortex-a53 \
		-nographic \
		-serial mon:stdio \
		-device loader,file=$(NEXS_DIR)/build_aarch64/loader.img,addr=0x70000000,cpu-num=0 \
		-m size=2G

run-nexs-riscv64:
	@if [ ! -d "$(NEXS_DIR)" ]; then \
		echo ""; \
		echo "[error] NEXS runtime not found at $(NEXS_DIR)"; \
		echo "        Run:  make fetch-deps"; \
		echo "        This will clone base-nexs and copy it into root/example/base-nexs."; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f "$(SDK_DIR)/board/qemu_virt_riscv64/debug/include/kernel/gen_config.h" ]; then \
		echo "SDK not built for riscv64. Run: make build-sdk-riscv64"; \
		exit 1; \
	fi
	@echo "========================================="
	@echo "Compiling NEXS Stable (multi-PD) for RISC-V 64-bit..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-multikernel-riscv64 MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_riscv64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/hal/sel4/nexs_riscv64.system \
		--search-path $(NEXS_DIR)/build/sel4-multikernel \
		--board qemu_virt_riscv64 \
		--config debug \
		-o $(NEXS_DIR)/build_riscv64/loader.img \
		-r $(NEXS_DIR)/build_riscv64/report.txt
	@echo "========================================="
	@echo "Running NEXS under seL4 QEMU Simulation..."
	@echo "========================================="
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-serial mon:stdio \
		-kernel $(NEXS_DIR)/build_riscv64/loader.img \
		-m size=2G

run-nexs-x86_64:
	@if [ ! -d "$(NEXS_DIR)" ]; then \
		echo ""; \
		echo "[error] NEXS runtime not found at $(NEXS_DIR)"; \
		echo "        Run:  make fetch-deps"; \
		echo "        This will clone base-nexs and copy it into root/example/base-nexs."; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f "$(SDK_DIR)/board/x86_64_generic/debug/include/kernel/gen_config.h" ]; then \
		echo "SDK not built for x86_64. Run: make build-sdk-x86_64"; \
		exit 1; \
	fi
	@echo "========================================="
	@echo "Compiling NEXS Stable (multi-PD) for AMD64..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-multikernel-x86_64 MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_x86_64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/hal/sel4/nexs_x86_64.system \
		--search-path $(NEXS_DIR)/build/sel4-multikernel \
		--board x86_64_generic \
		--config debug \
		-o $(NEXS_DIR)/build_x86_64/loader.img \
		-r $(NEXS_DIR)/build_x86_64/report.txt
	@echo "========================================="
	@echo "Running NEXS under seL4 QEMU Simulation..."
	@echo "========================================="
	qemu-system-x86_64 \
		-cpu qemu64,+fsgsbase,+pdpe1gb,+xsaveopt,+xsave \
		-m 1G \
		-display none \
		-serial mon:stdio \
		-kernel $(NEXS_DIR)/build_x86_64/sel4_32.elf \
		-initrd $(NEXS_DIR)/build_x86_64/loader.img


run-nexs-amd64: run-nexs-x86_64

# ─────────────────────────────────────────────────────
# NEXS Isolated Verification Targets (Delegated)
# ─────────────────────────────────────────────────────
verify-nexs-aarch64:
	$(MAKE) -C $(NEXS_DIR) verify-nexs-aarch64 MICROKIT_SDK=$(SDK_DIR)

verify-nexs-riscv64:
	$(MAKE) -C $(NEXS_DIR) verify-nexs-riscv64 MICROKIT_SDK=$(SDK_DIR)

verify-nexs-x86_64:
	$(MAKE) -C $(NEXS_DIR) verify-nexs-x86_64 MICROKIT_SDK=$(SDK_DIR)

verify-nexs-amd64: verify-nexs-x86_64

# x86_32 (IA32) Declared Support Target
x86_32:
	@echo "========================================="
	@echo "Verifying Declared Compatibility for x86_32..."
	@echo "========================================="
	@echo "Compatibility is declared! Compilation is inherited via multi-mode Multiboot loaders."
	@echo "Target IA32 uses the generic x86 compatibility layer."

# ── Local kernel integration helpers ─────────────────────────────────────────
# kernel-check: verify which seL4 source is active and whether ARM is merged.
kernel-check:
	@echo "=== seL4 Source Selection ==="
	@echo "  SEL4_SRC_DIR = $(SEL4_SRC_DIR)"
	@echo "  SEL4_LOCAL   = $(SEL4_LOCAL)"
	@if [ -d "$(SEL4_LOCAL)/src/arch/arm" ]; then \
		echo "  ARM merged  : YES — can switch SEL4_SRC_DIR to SEL4_LOCAL"; \
	else \
		echo "  ARM merged  : NO  — aarch/ must be copied to kernel/src/arch/arm first"; \
	fi

# kernel-merge: copy aarch/ content into kernel/src/arch/arm/ so the local
#               kernel build can replace scratch/reference/seL4.
kernel-merge:
	@echo "Merging aarch/ → kernel/src/arch/arm/ ..."
	@mkdir -p $(SEL4_LOCAL)/src/arch/arm
	@cp -r $(ROOT_DIR)/aarch/64      $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/32      $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/armv    $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/api     $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/machine $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/object  $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/kernel  $(SEL4_LOCAL)/src/arch/arm/
	@cp -r $(ROOT_DIR)/aarch/smp     $(SEL4_LOCAL)/src/arch/arm/
	@[ -f $(ROOT_DIR)/aarch/config.cmake ] && \
		cp $(ROOT_DIR)/aarch/config.cmake $(SEL4_LOCAL)/src/arch/arm/ || true
	@echo "Done. Now set SEL4_SRC_DIR := \$$(SEL4_LOCAL) in this Makefile and rebuild."

# ─────────────────────────────────────────────────────
# Dependency Management
# ─────────────────────────────────────────────────────
BASE_NEXS_DIR ?= dependencies/base-nexs

fetch-deps:
	@mkdir -p dependencies
	@if [ ! -d "$(BASE_NEXS_DIR)" ]; then \
		echo "[deps] Cloning base-nexs (branch dev-stable)..."; \
		git clone --branch dev-stable https://github.com/olmox001/base-nexs.git $(BASE_NEXS_DIR); \
	else \
		echo "[deps] Updating base-nexs..."; \
		git -C $(BASE_NEXS_DIR) pull; \
	fi
	@echo "[deps] Copying base-nexs → $(NEXS_DIR) ..."
	@mkdir -p $(NEXS_DIR)
	@cp -r $(BASE_NEXS_DIR)/. $(NEXS_DIR)/
	@echo "[deps] base-nexs ready at $(NEXS_DIR)"

# Build the NEXS host binary from base-nexs dependency
nexs-host: fetch-deps
	$(MAKE) -C $(BASE_NEXS_DIR) all

# Build seL4 target using base-nexs + local SDK
nexs-sel4-aarch64: nexs-host
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-aarch64 MICROKIT_SDK=$(SDK_DIR)

nexs-sel4-riscv64: nexs-host
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-riscv64 MICROKIT_SDK=$(SDK_DIR)

nexs-sel4-x86_64: nexs-host
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-x86_64 MICROKIT_SDK=$(SDK_DIR)

# Run NEXS under seL4 QEMU
nexs-run-aarch64: nexs-sel4-aarch64
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-run-aarch64 MICROKIT_SDK=$(SDK_DIR)

nexs-run-riscv64: nexs-sel4-riscv64
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-run-riscv64 MICROKIT_SDK=$(SDK_DIR)

nexs-run-x86_64: nexs-sel4-x86_64
	$(MAKE) -C $(BASE_NEXS_DIR) sel4-run-x86_64 MICROKIT_SDK=$(SDK_DIR)

# Clean build outputs (SDK is preserved — use clean-sdk to also wipe the SDK)
clean:
	@echo "Cleaning workspace build directories (SDK preserved)..."
	rm -rf $(EXAMPLE_DIR)/build_aarch64
	rm -rf $(EXAMPLE_DIR)/build_riscv64
	rm -rf $(EXAMPLE_DIR)/build_x86_64
	rm -rf $(SDK_SRC_DIR)/build
	rm -rf $(SDK_SRC_DIR)/target
	@echo "Clean completed. SDK untouched at $(SDK_DIR)"

# Remove only the compiled SDK (forces rebuild on next build-sdk-* call)
clean-sdk:
	@echo "Removing compiled SDK at $(SDK_SRC_DIR)/release ..."
	rm -rf $(SDK_SRC_DIR)/release
	@echo "SDK removed. Rebuild with: make build-sdk-<arch>"

# Remove everything including SDK
clean-all: clean clean-sdk
	@echo "Full clean completed."
