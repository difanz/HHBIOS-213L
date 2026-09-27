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

SOURCE_DIRS := $(shell find $(SRC) -type d | LC_ALL=C sort)
ASMS := $(foreach dir,$(SOURCE_DIRS),$(wildcard $(dir)/*.ASM))
INCS := $(foreach dir,$(SOURCE_DIRS),$(wildcard $(dir)/*.INC))
COMS := $(addprefix $(BUILD)/,$(notdir $(ASMS:.ASM=.COM)))
ASM_INCLUDES := $(addprefix -I,$(SOURCE_DIRS))
VESA := $(SRC)/video/vesa
vpath %.ASM $(SOURCE_DIRS)

.PHONY: all clean check setup qa-smoke qa-test qa-dos qa-application qa-all qa-mutate
QA_PYTHON ?= python3

all: $(COMS) $(BUILD)/VESA.COM

# Optional 8086 installer using Open Watcom UI. See src/setup/README.md.
# WATCOM and WATCOM_SOURCE are supplied by the developer.
setup:
	bash tools/build-setup.sh --output "$(BUILD)/SETUP.EXE"

$(BUILD)/VESA.COM: $(wildcard $(VESA)/*) $(INCS) tools/build-vesa.sh tools/source-tree.sh | $(BUILD)
	JWASM="$(JWASM)" bash tools/build-vesa.sh "$@" "$(SRC)"

$(BUILD):
	mkdir -p $(BUILD)

# R16.COM is the stub with READ3..READ6 appended (R16 /S).
$(BUILD)/R16.COM: $(SRC)/font/R16.ASM $(BUILD)/READ3.COM $(BUILD)/READ4.COM $(BUILD)/READ5.COM $(BUILD)/READ6.COM | $(BUILD)
	env -u JWASM "$(JWASM)" $(JWFLAGS) $(ASM_INCLUDES) -Fo$(BUILD)/R16.stub -Fw$(BUILD)/R16.err $<
	rm -f $(BUILD)/R16.err
	python3 tools/joinr16.py $(BUILD)/R16.stub $(BUILD)/READ3.COM $(BUILD)/READ4.COM $(BUILD)/READ5.COM $(BUILD)/READ6.COM $@

$(BUILD)/%.COM: %.ASM $(INCS) | $(BUILD)
	env -u JWASM "$(JWASM)" $(JWFLAGS) $(ASM_INCLUDES) -Fo$@ -Fw$(BUILD)/$*.err $<
	rm -f $(BUILD)/$*.err

# Confirm every src/*.ASM produced a non-empty build/*.COM.
check: all
	@bash tools/check-coms.sh "$(SRC)" "$(BUILD)"
	@test -s $(BUILD)/VESA.COM

clean:
	rm -rf $(BUILD)

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
