# 第2回：RV32I／ILP32／-O1で実生成物を観察する．
# 配布改訂番号 -1 はバナーに出ないため，取得時にアーカイブのSHA-256で確認する．
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:

override PACKAGE := xpack-riscv-none-elf-gcc-15.2.0-1
override QEMU_PACKAGE := xpack-qemu-riscv-9.2.4-1
override GCC_PROGRAMS := riscv-none-elf-gcc riscv-none-elf-objdump riscv-none-elf-readelf riscv-none-elf-gdb
override QEMU_PROGRAM := qemu-system-riscv32

ifeq ($(OS),Windows_NT)
override SHELL := cmd.exe
.SHELLFLAGS := /d /c
EXE := .exe
NULL_DEVICE := NUL
PROBE_C := echo int compsys_probe = 1;
FAIL := exit /b 1
EXPLICIT_PARENT := $(subst \,/,$(COMPSYS_TOOLS))
STANDARD_PARENT := $(subst \,/,$(USERPROFILE))/compsys-tools

# 指定された実行ファイルがそろったディレクトリの絶対パスを返す．
find_bin = $(subst \,/,$(shell cd /d "$(1)" 2>NUL && $(foreach exe,$(2),if exist "$(exe).exe") cd))
bin_parent = $(subst \,/,$(shell cd /d "$(1)/.." && cd))

# WindowsのPATHには空白やドライブ文字が入るため，セミコロン単位で調べる．
define find_path_bin
$(shell powershell.exe -NoProfile -NonInteractive -Command \
  "foreach ($$entry in ($$env:Path -split ';')) { \
    if (-not $$entry) { continue }; \
    try { $$dir = [IO.Path]::GetFullPath($$entry.Trim([char]34)) } catch { continue }; \
    $$complete = $$true; \
    foreach ($$program in ('$(1)' -split ' ')) { \
      if (-not [IO.File]::Exists([IO.Path]::Combine($$dir, $$program + '.exe'))) { $$complete = $$false; break } \
    }; \
    if ($$complete) { \
      [Console]::WriteLine($$dir.Replace([char]92,[char]47)); break \
    } \
  }")
endef
else
override SHELL := /bin/sh
.SHELLFLAGS := -c
EXE :=
NULL_DEVICE := /dev/null
PROBE_C := printf '%s\n' 'int compsys_probe = 1;'
FAIL := exit 1
EXPLICIT_PARENT := $(COMPSYS_TOOLS)
STANDARD_PARENT := $(HOME)/compsys-tools

# サブシェル内で移動し，すべてのプログラムが実行可能なら絶対パスを返す．
sh_quote = '$(subst ','"'"',$(1))'
define probe_bin
probe() ( \
  CDPATH= cd -P "$$1" 2>/dev/null || exit 1; \
  for tool in $(1); do \
    file=./$$tool; \
    test -f "$$file" && test -x "$$file" || exit 1; \
  done; \
  pwd -P \
)
endef
find_bin = $(shell $(call probe_bin,$(2)); probe $(call sh_quote,$(1)))
bin_parent = $(shell CDPATH= cd -P $(call sh_quote,$(1)/..) && pwd -P)

# 空のPATH成分はカレントディレクトリを指す．空白では分割しない．
define find_path_bin
$(shell $(call probe_bin,$(1)); \
  rest=$$PATH:; \
  while test -n "$$rest"; do \
    entry=$${rest%%:*}; rest=$${rest#*:}; \
    if probe "$${entry:-.}"; then break; fi; \
  done)
endef
endif

# パッケージごとに明示配置，ホームの標準配置，PATHの順で調べる．
explicit_bin = $(if $(strip $(EXPLICIT_PARENT)),$(call find_bin,$(EXPLICIT_PARENT)/$(1)/bin,$(2)))
standard_bin = $(if $(1),,$(call find_bin,$(STANDARD_PARENT)/$(2)/bin,$(3)))
select_bin = $(or $(1),$(2),$(call find_path_bin,$(3)))
source_name = $(if $(1),COMPSYS_TOOLS,$(if $(2),home/compsys-tools,PATH))

ifneq ($(filter-out help clean check-qemu,$(MAKECMDGOALS)),)
GCC_EXPLICIT := $(call explicit_bin,$(PACKAGE),$(GCC_PROGRAMS))
GCC_STANDARD := $(call standard_bin,$(GCC_EXPLICIT),$(PACKAGE),$(GCC_PROGRAMS))
override RISCV_BIN := $(call select_bin,$(GCC_EXPLICIT),$(GCC_STANDARD),$(GCC_PROGRAMS))
override TOOLCHAIN_SOURCE := $(call source_name,$(GCC_EXPLICIT),$(GCC_STANDARD))
ifneq ($(RISCV_BIN),)
override RISCV_TOOLCHAIN_ROOT := $(call bin_parent,$(RISCV_BIN))
endif
endif

ifneq ($(filter check check-qemu trace-example,$(MAKECMDGOALS)),)
QEMU_EXPLICIT := $(call explicit_bin,$(QEMU_PACKAGE),$(QEMU_PROGRAM))
QEMU_STANDARD := $(call standard_bin,$(QEMU_EXPLICIT),$(QEMU_PACKAGE),$(QEMU_PROGRAM))
override QEMU_BIN := $(call select_bin,$(QEMU_EXPLICIT),$(QEMU_STANDARD),$(QEMU_PROGRAM))
override QEMU_SOURCE := $(call source_name,$(QEMU_EXPLICIT),$(QEMU_STANDARD))
endif

override RISCV_GCC := $(RISCV_BIN)/riscv-none-elf-gcc$(EXE)
override RISCV_OBJDUMP := $(RISCV_BIN)/riscv-none-elf-objdump$(EXE)
override RISCV_GDB := $(RISCV_BIN)/riscv-none-elf-gdb$(EXE)
override RISCV_QEMU := $(QEMU_BIN)/$(QEMU_PROGRAM)$(EXE)
override RISCV_READELF := $(RISCV_BIN)/riscv-none-elf-readelf$(EXE)
override TARGET_FLAGS := -march=rv32i -mabi=ilp32 -mstrict-align
override COURSE_CFLAGS := $(TARGET_FLAGS) -O1 -std=c11 -Wall -Wextra -ffreestanding -fno-pic -fno-pie -fno-asynchronous-unwind-tables -fno-unwind-tables
override COURSE_LDFLAGS := $(TARGET_FLAGS) -nostdlib -T tools/link.ld
override OBJECT_DUMP_FLAGS := -dr
override ELF_DUMP_FLAGS := -d -t
override QEMU_MACHINE := -machine virt -bios none -S -display none -serial none -nic none
override QEMU_TRACE := $(QEMU_MACHINE) -kernel build/example.elf -gdb stdio -monitor none

# GDBとQEMUはstdioで接続する．固定TCPポートは使わない．
ifeq ($(OS),Windows_NT)
GDB_CONNECT = "target remote | \"$(RISCV_QEMU)\" $(QEMU_TRACE)"
ps_quote = '$(subst ','',$(1))'
define check_version
	@powershell.exe -NoProfile -NonInteractive -Command \
	  "$$v = & $(call ps_quote,$(1)) --version; if ($$LASTEXITCODE -ne 0) { exit 1 }; \
	  $$found = $$v | Where-Object { $$_ -match '$(2)' }; \
	  if (-not $$found) { Write-Host 'ERROR: $(3) is required. See README.md.'; exit 1 }; $$found"
endef
else
GDB_CONNECT = $(call sh_quote,target remote | exec $(call sh_quote,$(RISCV_QEMU)) $(QEMU_TRACE))
define check_version
	@version=$$("$(1)" --version) && printf '%s\n' "$$version" | grep -E $(call sh_quote,$(2)) || { echo 'ERROR: $(3) is required. See README.md.'; exit 1; }
endef
endif

override ARTIFACTS := build/example.s build/example.o build/example.dump build/example.elf build/example.elf.dump \
                     build/task.s build/task.o build/task.dump build/task.elf build/task.elf.dump
.SECONDARY: $(ARTIFACTS) build/example_start.o build/task_start.o
.PHONY: help check check-toolchain check-qemu all example task trace-example clean

help:
	@echo make check   - Check GCC, objdump, readelf, GDB and QEMU.
	@echo make example - Generate example.s, .o, .dump, .elf and .elf.dump.
	@echo make task    - Generate task.s, .o, .dump, .elf and .elf.dump.
	@echo make all     - Generate both examples and tasks.
	@echo make trace-example - Observe calls, registers and stack in QEMU.
	@echo make clean   - Remove generated files and keep build/.gitkeep.

check: check-toolchain check-qemu

check-toolchain:
ifeq ($(RISCV_BIN),)
	$(info RISC-V toolchain was not found.)
	$(info Place the extracted folder at: $(STANDARD_PARENT)/$(PACKAGE))
	$(info Required in its bin directory: $(GCC_PROGRAMS) (with $(EXE) on this OS).)
	$(info Do not extract the toolchain inside the compsys-ex02 repository.)
	@$(FAIL)
else
	$(info Toolchain source: $(TOOLCHAIN_SOURCE))
	$(info Toolchain directory: $(RISCV_TOOLCHAIN_ROOT))
	$(info GCC: $(RISCV_GCC))
	$(info objdump: $(RISCV_OBJDUMP))
	$(info readelf: $(RISCV_READELF))
	$(info GDB: $(RISCV_GDB))
	$(info Required package: xPack GNU RISC-V Embedded GCC 15.2.0-1)
	$(info ISA: RV32I / ABI: ILP32 / optimization: -O1 / C11)
	$(call check_version,$(RISCV_GCC),^riscv-none-elf-gcc \(xPack GNU RISC-V Embedded GCC.*\) 15\.2\.0$$,xPack GCC 15.2.0)
	$(call check_version,$(RISCV_OBJDUMP),^GNU objdump \(xPack GNU RISC-V Embedded GCC.*\) 2\.45$$,xPack objdump 2.45)
	$(call check_version,$(RISCV_READELF),^GNU readelf \(xPack GNU RISC-V Embedded GCC.*\) 2\.45$$,xPack readelf 2.45)
	$(call check_version,$(RISCV_GDB),^GNU gdb \(xPack GNU RISC-V Embedded GCC.*\) 16\.3$$,xPack GDB 16.3)
	@$(PROBE_C) | "$(RISCV_GCC)" $(COURSE_CFLAGS) -x c -c - -o "$(NULL_DEVICE)" || (echo Minimal RV32I/ILP32 compile: FAILED. && $(FAIL))
	@echo Minimal RV32I/ILP32 compile: OK.
endif

check-qemu:
ifeq ($(QEMU_BIN),)
	$(info QEMU for RISC-V was not found.)
	$(info Place the extracted folder at: $(STANDARD_PARENT)/$(QEMU_PACKAGE))
	$(info Expected executable: $(STANDARD_PARENT)/$(QEMU_PACKAGE)/bin/$(QEMU_PROGRAM)$(EXE))
	@$(FAIL)
else
	$(info QEMU source: $(QEMU_SOURCE))
	$(info QEMU: $(RISCV_QEMU))
	$(call check_version,$(RISCV_QEMU),^xPack QEMU emulator version 9\.2\.4$$,xPack QEMU 9.2.4)
	@echo quit | "$(RISCV_QEMU)" $(QEMU_MACHINE) -monitor stdio > "$(NULL_DEVICE)" || (echo Paused QEMU virt startup: FAILED. && $(FAIL))
	@echo Paused QEMU virt startup: OK.
endif

all: example task

example: build/example.s build/example.o build/example.dump build/example.elf build/example.elf.dump
	@echo Ready: build/example.s build/example.o build/example.dump build/example.elf build/example.elf.dump

task: build/task.s build/task.o build/task.dump build/task.elf build/task.elf.dump
	@echo Ready: build/task.s build/task.o build/task.dump build/task.elf build/task.elf.dump

build:
ifeq ($(OS),Windows_NT)
	@if not exist "build" mkdir "build"
else
	@mkdir -p "build"
endif

build/%.s: src/%.c Makefile | check-toolchain build
	"$(RISCV_GCC)" $(COURSE_CFLAGS) -S "$<" -o "$@"

build/%.o: build/%.s Makefile | check-toolchain
	"$(RISCV_GCC)" $(TARGET_FLAGS) -c "$<" -o "$@"

build/%_start.o: tools/%_start.S Makefile | check-toolchain build
	"$(RISCV_GCC)" $(TARGET_FLAGS) -c "$<" -o "$@"

build/%.dump: build/%.o Makefile | check-toolchain
	"$(RISCV_OBJDUMP)" $(OBJECT_DUMP_FLAGS) "$<" > "$@"

# .sから作った同じ.oをリンクする．relaxationは通常の有効状態を使う．
build/%.elf: build/%.o build/%_start.o tools/link.ld Makefile | check-toolchain
	"$(RISCV_GCC)" $(COURSE_LDFLAGS) "build/$*_start.o" "$<" -o "$@"

build/%.elf.dump: build/%.elf Makefile | check-toolchain
	"$(RISCV_OBJDUMP)" $(ELF_DUMP_FLAGS) "$<" > "$@"

# 正常時はGDBファイル内でkill・quit 0する．途中エラーなら後続のkill・quit 1で失敗にする．
# vKillの応答待ちを避け，単一CPUのQEMUを従来のkパケットで終了する．
trace-example: build/example.elf tools/trace-example.gdb | check-qemu
	@"$(RISCV_GDB)" -nx -q --batch "build/example.elf" -ex "set confirm off" \
	  -ex "set remotetimeout 5" -ex "set remote multiprocess-feature-packet off" -ex "set remote kill-packet off" \
	  -ex $(GDB_CONNECT) -x tools/trace-example.gdb -ex kill -ex "quit 1"

clean:
ifeq ($(OS),Windows_NT)
	@powershell.exe -NoProfile -NonInteractive -Command "if (Test-Path -LiteralPath 'build') { Get-ChildItem -LiteralPath 'build' -Force | Where-Object { $$_.Name -ne '.gitkeep' } | Remove-Item -Recurse -Force -ErrorAction Stop }"
else
	@if test -d build; then find build -mindepth 1 -maxdepth 1 ! -name .gitkeep -exec rm -rf {} +; fi
endif
	@echo Clean complete.
