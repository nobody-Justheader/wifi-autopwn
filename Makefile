.PHONY: all clean build test info help

# Configuration
BUILD_DIR := build
BIN_DIR := bin
SRC_DIR := src
OUTPUT := wifi-autopwn
VERSION := 1.0

# Module order
MODULES := \
	$(SRC_DIR)/core/globals.sh \
	$(SRC_DIR)/core/utilities.sh \
	$(SRC_DIR)/core/dependencies.sh \
	$(SRC_DIR)/core/wifi_generations.sh \
	$(SRC_DIR)/core/country_patterns.sh \
	$(SRC_DIR)/core/interface.sh \
	$(SRC_DIR)/core/network_scan.sh \
	$(SRC_DIR)/session/config.sh \
	$(SRC_DIR)/attacks/handshake.sh \
	$(SRC_DIR)/attacks/pmkid.sh \
	$(SRC_DIR)/attacks/wps.sh \
	$(SRC_DIR)/attacks/wep.sh \
	$(SRC_DIR)/attacks/evil_twin.sh \
	$(SRC_DIR)/attacks/novel_attacks.sh \
	$(SRC_DIR)/cracking/format_conversion.sh \
	$(SRC_DIR)/cracking/aircrack.sh \
	$(SRC_DIR)/cracking/hashcat.sh \
	$(SRC_DIR)/core/statistics.sh \
	$(SRC_DIR)/core/batch_mode.sh \
	$(SRC_DIR)/main.sh

all: build

build:
	@echo "[*] Building WiFi Auto-PWN v$(VERSION)..."
	@mkdir -p $(BUILD_DIR) $(BIN_DIR)
	@echo "#!/bin/bash" > $(BUILD_DIR)/$(OUTPUT)
	@echo "# WiFi Auto-PWN v$(VERSION) - Built $(shell date +%Y%m%d)" >> $(BUILD_DIR)/$(OUTPUT)
	@echo "" >> $(BUILD_DIR)/$(OUTPUT)
	@for module in $(MODULES); do \
		if [ -f $$module ]; then \
			echo "[+] Adding: $$module"; \
			echo "" >> $(BUILD_DIR)/$(OUTPUT); \
			echo "# $$module" >> $(BUILD_DIR)/$(OUTPUT); \
			cat $$module >> $(BUILD_DIR)/$(OUTPUT); \
		fi; \
	done
	@chmod +x $(BUILD_DIR)/$(OUTPUT)
	@cp $(BUILD_DIR)/$(OUTPUT) $(BIN_DIR)/$(OUTPUT)
	@echo "[✓] Build complete: $(BIN_DIR)/$(OUTPUT)"
	@ls -lh $(BIN_DIR)/$(OUTPUT)

test:
	@echo "[*] Syntax checking..."
	@for module in $(MODULES); do \
		if [ -f $$module ]; then \
			bash -n $$module && echo "[✓] $$module" || exit 1; \
		fi; \
	done

info:
	@echo "WiFi Auto-PWN Build System"
	@echo "Version: $(VERSION)"
	@echo "Modules: $(words $(MODULES))"
	@for module in $(MODULES); do \
		if [ -f $$module ]; then \
			echo "  [✓] $$module"; \
		else \
			echo "  [✗] $$module (missing)"; \
		fi; \
	done

clean:
	@rm -rf $(BUILD_DIR) $(BIN_DIR)
	@echo "[✓] Clean"

help:
	@echo "WiFi Auto-PWN Makefile"
	@echo "  make build  - Build executable"
	@echo "  make test   - Syntax check"
	@echo "  make info   - Show status"
	@echo "  make clean  - Remove build files"
