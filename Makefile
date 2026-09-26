# HHBIOS-213L — rebuild DOS .COM modules with JWasm (MASM-compatible)
# Sources are GB2312/GBK under src/: do not convert them to UTF-8.
#
# Requires a JWasm built with tools/jwasm-m510.patch applied
# (Baron-von-Riedesel/JWasm, commit 7f6f32e). Stock -Zm is not enough.
# See README.md.
#
#   jwasm -Zm  = MASM 5.x compatibility
#   jwasm -bin = emit raw binary (.COM) for ORG 100H sources

JWASM ?= jwasm
JWFLAGS ?= -q -Zm -bin
SRC := src
BUILD := build

ASMS := $(wildcard $(SRC)/*.ASM)
INCS := $(wildcard $(SRC)/*.INC)
COMS := $(patsubst $(SRC)/%.ASM,$(BUILD)/%.COM,$(ASMS))

.PHONY: all clean check vbeprobe qa-smoke qa-test qa-dos qa-application qa-all qa-mutate qa-legacy qa-smoke-usage
QA_PYTHON ?= python3

all: $(COMS)

$(BUILD):
	mkdir -p $(BUILD)

# R16.COM is the stub with READ3..READ6 appended (R16 /S).
$(BUILD)/R16.COM: $(SRC)/R16.ASM $(BUILD)/READ3.COM $(BUILD)/READ4.COM $(BUILD)/READ5.COM $(BUILD)/READ6.COM | $(BUILD)
	env -u JWASM "$(JWASM)" $(JWFLAGS) -I$(SRC) -Fo$(BUILD)/R16.stub -Fw$(BUILD)/R16.err $(SRC)/R16.ASM
	rm -f $(BUILD)/R16.err
	python3 tools/joinr16.py $(BUILD)/R16.stub $(BUILD)/READ3.COM $(BUILD)/READ4.COM $(BUILD)/READ5.COM $(BUILD)/READ6.COM $@

$(BUILD)/%.COM: $(SRC)/%.ASM $(INCS) | $(BUILD)
	env -u JWASM "$(JWASM)" $(JWFLAGS) -I$(SRC) -Fo$@ -Fw$(BUILD)/$*.err $<
	rm -f $(BUILD)/$*.err

# Confirm every src/*.ASM produced a non-empty build/*.COM.
check: all
	@python3 tools/cmpcoms.py

clean:
	rm -rf $(BUILD)

# 16-bit DOS VBE probe. Needs Open Watcom (wcl). Does not run as part of `all`.
vbeprobe: $(BUILD)/VBEPROBE.COM

$(BUILD)/VBEPROBE.COM: src/c/vbeprobe.c tools/build-vbeprobe.sh
	bash tools/build-vbeprobe.sh

# Fast production-assembly contracts. No network or GUI dependency.
qa-test:
	"$(QA_PYTHON)" qa/run.py unit

# Explicit DOSBox layer: required tools must be configured, never skipped.
qa-dos:
	"$(QA_PYTHON)" qa/run.py dos

qa-application:
	"$(QA_PYTHON)" qa/run.py application

qa-all:
	"$(QA_PYTHON)" qa/run.py all

qa-mutate:
	"$(QA_PYTHON)" qa/mutate.py

qa-smoke:
	"$(QA_PYTHON)" qa/run.py dos -k mixed_frames

# Historical marker/screenshot scripts, retained for comparison only.
qa-legacy:
	bash qa/run-suite.sh

# Usage smokes under qa/smoke-usage/. Missing qa/guest/ files skip the case.
qa-smoke-usage:
	bash qa/run-suite.sh --root qa/smoke-usage --label qa-smoke-usage
