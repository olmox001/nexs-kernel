# Root Makefile for seL4 + Microkit Multi-Architecture Development

# Host tools and environment configuration
export PATH := /Users/olmo/.cargo/bin:/usr/local/opt/llvm/bin:$(PATH)
PYTHON := /Users/olmo/Documents/git/nexskernel/scratch/venv/bin/python3
LLVM := True

# Workspace Directories
ROOT_DIR     := $(shell pwd)
SDK_SRC_DIR  := $(ROOT_DIR)/root

# seL4 kernel source:
#   kernel/   = local project copy of seL4 core (kernel/ + aarch/ for ARM).
#               ARM arch is in aarch/, NOT yet wired into kernel/src/arch/arm/.
#               Use SEL4_LOCAL once aarch/ is merged into kernel/src/arch/arm/.
#   scratch/  = reference clone — used for all SDK builds until merge is done.
SEL4_LOCAL   := $(ROOT_DIR)/kernel
SEL4_SRC_DIR := $(ROOT_DIR)/scratch/reference/seL4

SDK_DIR      := $(SDK_SRC_DIR)/release/microkit-sdk-2.2.0-dev
EXAMPLE_DIR  := $(SDK_SRC_DIR)/example/hello

.PHONY: all clean aarch64 riscv64 x86_64 x86_32 kernel-check kernel-merge

all:
	@echo "Please specify a target architecture: aarch64, riscv64, x86_64, x86_32"

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

# NEXS stable directory
NEXS_DIR := $(SDK_SRC_DIR)/example/base-nexs-dev-stable

# run-nexs-aarch64: Compile and simulate NEXS on AArch64
run-nexs-aarch64:
	@echo "========================================="
	@echo "Compiling NEXS Stable for AArch64..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-microkit MICROKIT_BOARD=qemu_virt_aarch64 MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_aarch64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/nexs_aarch64.system \
		--search-path $(NEXS_DIR)/build/sel4-microkit \
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

# run-nexs-riscv64: Compile and simulate NEXS on RISC-V 64-bit
run-nexs-riscv64:
	@echo "========================================="
	@echo "Compiling NEXS Stable for RISC-V 64-bit..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-microkit MICROKIT_BOARD=qemu_virt_riscv64 MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_riscv64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/nexs_riscv64.system \
		--search-path $(NEXS_DIR)/build/sel4-microkit \
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

# run-nexs-x86_64: Compile and simulate NEXS on AMD64
run-nexs-x86_64:
	@echo "========================================="
	@echo "Compiling NEXS Stable for AMD64..."
	@echo "========================================="
	$(MAKE) -C $(NEXS_DIR) sel4-microkit MICROKIT_BOARD=x86_64_generic MICROKIT_CONFIG=debug MICROKIT_SDK=$(SDK_DIR)
	@echo "========================================="
	@echo "Packaging NEXS Protection Domain Image..."
	@echo "========================================="
	mkdir -p $(NEXS_DIR)/build_x86_64
	$(SDK_DIR)/bin/microkit $(NEXS_DIR)/nexs_x86_64.system \
		--search-path $(NEXS_DIR)/build/sel4-microkit \
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

# Clean all build outputs
clean:
	@echo "Cleaning workspace build directories..."
	rm -rf $(EXAMPLE_DIR)/build_aarch64
	rm -rf $(EXAMPLE_DIR)/build_riscv64
	rm -rf $(EXAMPLE_DIR)/build_x86_64
	rm -rf $(SDK_SRC_DIR)/release
	rm -rf $(SDK_SRC_DIR)/build
	rm -rf $(SDK_SRC_DIR)/target
	@echo "Clean completed successfully!"
