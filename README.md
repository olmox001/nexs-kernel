# nexskernel — seL4 + Microkit SDK builder

This repository builds the Microkit SDK and runs **NEXS** (a Plan 9-style language runtime) as a seL4 Protection Domain.

**NEXS runtime** lives in a separate repository: [olmox001/base-nexs](https://github.com/olmox001/base-nexs).

## Quick start

```sh
# 1. Build the Microkit SDK for aarch64
make build-sdk-aarch64

# 2. Compile NEXS + package + launch under seL4 QEMU
make run-nexs-aarch64     # aarch64
make run-nexs-riscv64     # riscv64
make run-nexs-x86_64      # x86_64
```

Run `make` or `make help` to list all available targets.

## Targets

| Target | Description |
|--------|-------------|
| `build-sdk-aarch64/riscv64/x86_64` | Build Microkit SDK for the given arch |
| `run-nexs-aarch64/riscv64/x86_64` | Compile NEXS PD + package + run in QEMU |
| `nexs-host` | Build the NEXS host interpreter (from base-nexs dependency) |
| `aarch64 / riscv64 / x86_64` | Build + run Microkit hello-world example |
| `sel4-initializer` | Clone/update this repo's SDK builder |
| `fetch-deps` | Clone/update base-nexs runtime |
| `kernel-check` | Check seL4 ARM integration status |
| `kernel-merge` | Merge aarch/ into kernel/src/arch/arm/ |
| `clean` | Remove all build outputs |

## Repository layout

This repo is the **SDK builder** for seL4 + Microkit. It does not contain the NEXS language runtime. The runtime is fetched automatically via `make fetch-deps` or used from the local path `root/example/base-nexs-dev-stable/` during development.

## Directory layout

| Path | What it is |
|------|-----------|
| `root/` | Microkit SDK source + `build_sdk.py` |
| `root/example/base-nexs-dev-stable/` | NEXS runtime (dev copy; published as [olmox001/base-nexs](https://github.com/olmox001/base-nexs)) |
| `kernel/` | seL4 kernel core (arch-independent) |
| `aarch/` | ARM 32/64-bit arch support |
| `scratch/reference/seL4` | seL4 reference clone used for SDK builds |
| `dependencies/` | External dependencies fetched by `make fetch-deps` |
