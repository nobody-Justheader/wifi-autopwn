# WiFi Auto-PWN v1.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/nobody-Justheader/wifi-autopwn)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)
[![WiFi Standards](https://img.shields.io/badge/WiFi-1%20to%207-green.svg)](https://www.wi-fi.org/)
[![Language](https://img.shields.io/badge/language-Bash-89e051.svg)](https://www.gnu.org/software/bash/)

> **🔓 Advanced Multi-Generation WiFi Penetration Testing Framework**

A comprehensive, modular WiFi security testing tool implementing traditional and cutting-edge attack techniques based on the latest security research and IEEE 802.11 specifications. Features complete coverage from legacy WiFi 1 (802.11b) to modern WiFi 7 (802.11be).

## 🎯 Key Features

### 📊 Quick Stats

| Category | Details |
|----------|---------|
| **WiFi Generations** | WiFi 1-7 (802.11a/b/g/n/ac/ax/be) |
| **Frequency Bands** | 2.4GHz, 5GHz, 6GHz |
| **Attack Vectors** | 12+ implemented techniques |
| **Security Protocols** | WEP, WPA, WPA2, WPA3 |
| **Modules** | 20 modular components |
| **Executable Size** | 84KB single file |
| **Research References** | 30+ CVEs, papers, tools |

### Core Attack Modules

- **PMKID Attack** - Clientless WPA/WPA2 cracking (2018)
- **Handshake Capture** - Traditional WPA/WPA2 4-way handshake
- **WPS Attacks** - Pixie Dust, PIN brute-force, Null PIN
- **WEP Attacks** - ARP replay, chopchop, fragmentation, Caffe Latte
- **Evil Twin** - Captive portal with credential harvesting
- **Novel Attacks** - Dragonblood, KRACK, FragAttacks, SSID Confusion

### Advanced Features

- **GPU Acceleration** - Hashcat integration with multiple attack modes
- **Country-Specific Patterns** - Geographic password pattern generation
- **Batch Mode** - Automated multi-target attacks
- **Statistics Tracking** - Session analytics and success rates
- **Modular Architecture** - 20 modules, single executable output
- **Zero Configuration** - No external config files required

## Installation

### Prerequisites

```bash
# Core tools (required)
sudo apt install aircrack-ng

# Optional tools (enables advanced features)
sudo apt install hcxtools hashcat reaver bully macchanger hostapd dnsmasq

# Wordlists
sudo apt install wordlists seclists
```

### Build

```bash
cd wifi
make build

# Output: bin/wifi-autopwn
```

## Usage

### Basic Usage

```bash
# Interactive mode (recommended)
sudo ./bin/wifi-autopwn

# With specific interface
sudo ./bin/wifi-autopwn -i wlan0

# Custom wordlist
sudo ./bin/wifi-autopwn -w /path/to/wordlist.txt

# Batch mode (attack all networks)
sudo ./bin/wifi-autopwn -b
```

### Attack Mode Selection

When run, the tool presents attack options:

1. **PMKID Attack** - Fastest, clientless (30-60 seconds)
2. **Handshake Capture** - Traditional method (requires client)
3. **WPS Attack** - Exploit WPS vulnerabilities
4. **WEP Attack** - Legacy protocol attacks
5. **Evil Twin** - Social engineering via captive portal
6. **Novel Attacks** - Research-based exploits
7. **Auto** - Intelligent attack selection (PMKID → WPS → Handshake)

## Architecture

### Module Structure

```
wifi/
├── src/
│   ├── core/               # Core functionality
│   │   ├── globals.sh      # Configuration & variables
│   │   ├── utilities.sh    # Logging & helpers
│   │   ├── dependencies.sh # Tool checking
│   │   ├── country_patterns.sh  # Geographic patterns
│   │   ├── interface.sh    # Monitor mode management
│   │   ├── network_scan.sh # WiFi scanning & target selection
│   │   ├── statistics.sh   # Analytics & reporting
│   │   └── batch_mode.sh   # Multi-target automation
│   ├── attacks/            # Attack implementations
│   │   ├── handshake.sh    # WPA/WPA2 handshake capture
│   │   ├── pmkid.sh        # PMKID attack
│   │   ├── wps.sh          # WPS attacks (Pixie Dust, PIN)
│   │   ├── wep.sh          # WEP attacks (chopchop, frag, etc.)
│   │   ├── evil_twin.sh    # Rogue AP & captive portal
│   │   └── novel_attacks.sh # Research-based exploits
│   ├── cracking/           # Password cracking
│   │   ├── aircrack.sh     # Aircrack-ng integration
│   │   ├── hashcat.sh      # GPU-accelerated cracking
│   │   └── format_conversion.sh # CAP → HC22000
│   ├── session/            # State management
│   │   └── config.sh       # Session save/restore
│   └── main.sh             # Entry point
├── Makefile                # Build system
└── bin/wifi-autopwn        # Compiled executable
```

### Build System

The Makefile concatenates all modules in dependency order, creating a single portable executable:

```bash
make build    # Compile executable
make test     # Syntax check all modules
make info     # Show module status
make clean    # Remove build artifacts
```

## Research & References

This tool implements techniques from peer-reviewed security research and official specifications:

### PMKID Attack (2018)
- **Original Research**: [Hashcat Forum - PMKID Attack](https://hashcat.net/forum/thread-7717.html)
- **Tools**: [hcxdumptool](https://github.com/ZerBea/hcxdumptool), [hcxtools](https://github.com/ZerBea/hcxtools)
- **Description**: Clientless WPA/WPA2 attack extracting PMKID from RSN IE

### WPS Attacks
- **Pixie Dust** (2014): [Dominique Bongard's Research](https://github.com/wiire-a/pixiewps)
- **Reaver Fork**: [t6x/reaver-wps-fork-t6x](https://github.com/t6x/reaver-wps-fork-t6x)
- **Bully**: [GitHub - kimocoder/bully](https://github.com/kimocoder/bully)
- **Description**: Exploits weak WPS nonce randomization for offline PIN recovery

### WEP Attacks
- **FMS Attack** (2001): [Fluhrer, Mantin, Shamir](https://dl.acm.org/doi/10.5555/646557.694759)
- **PTW Attack** (2007): [Pyshkin, Tews, Weinmann](https://eprint.iacr.org/2007/120.pdf)
- **Chopchop**: [Aircrack-ng Documentation](https://www.aircrack-ng.org/doku.php?id=chopchop)
- **Caffe Latte** (2007): [Vivek Ramachandran](https://www.aircrack-ng.org/doku.php?id=cafe-latte)

### Evil Twin & Captive Portal
- **Fluxion**: [FluxionNetwork/fluxion](https://github.com/FluxionNetwork/fluxion)
- **Wifiphisher**: [wifiphisher/wifiphisher](https://github.com/wifiphisher/wifiphisher)
- **Technical**: hostapd + dnsmasq DNS hijacking

### Novel WiFi Attack Vectors

#### WPA3 Dragonblood (2019)
- **CVE**: CVE-2019-13377, CVE-2019-13456
- **Research Paper**: [Dragonblood: Analyzing WPA3's SAE Handshake](https://papers.mathyvanhoef.com/dragonblood.pdf)
- **Website**: [wpa3.mathyvanhoef.com](https://wpa3.mathyvanhoef.com/)
- **Authors**: Mathy Vanhoef, Eyal Ronen
- **Exploits**: Side-channel leaks, downgrade attacks, DoS

#### KRACK - Key Reinstallation Attack (2017)
- **CVE**: CVE-2017-13077 through CVE-2017-13088
- **Research Paper**: [Key Reinstallation Attacks](https://papers.mathyvanhoef.com/ccs2017.pdf)
- **Website**: [krackattacks.com](https://www.krackattacks.com/)
- **Author**: Mathy Vanhoef
- **Impact**: Decrypt/inject packets in WPA2 networks

#### FragAttacks (2021)
- **CVE**: CVE-2020-24586, CVE-2020-24587, CVE-2020-24588
- **Research Paper**: [Fragment and Forge](https://papers.mathyvanhoef.com/usenix2021.pdf)
- **Website**: [fragattacks.com](https://www.fragattacks.com/)
- **Author**: Mathy Vanhoef
- **Impact**: Affects all WiFi versions (WEP through WPA3)

#### SSID Confusion Attack (2024)
- **CVE**: CVE-2023-52424
- **Research**: [Top10VPN WiFi Vulnerability Report](https://www.top10vpn.com/research/wifi-vulnerability/)
- **Impact**: Trick clients into connecting to less secure networks

#### PrInS - Preamble Injection/Spoofing
- **Research Paper**: [PrInS Attacks](https://arxiv.org/pdf/2309.15025.pdf)
- **Institution**: UC San Diego
- **Impact**: Exploit 802.11 preamble vulnerabilities

### Standards & Specifications

- **IEEE 802.11**: [IEEE Standards Association](https://standards.ieee.org/ieee/802.11/7028/)
- **WPA Specification**: Wi-Fi Alliance
- **RFC 5996**: Internet Key Exchange (IKEv2) Protocol

### Security Tools

- **Aircrack-ng**: [aircrack-ng.org](https://www.aircrack-ng.org/)
- **Hashcat**: [hashcat.net](https://hashcat.net/)
- **hcxtools**: [ZerBea/hcxtools](https://github.com/ZerBea/hcxtools)

## Legal & Ethical Notice

⚠️ **CRITICAL WARNING** ⚠️

This tool is designed for **AUTHORIZED SECURITY TESTING ONLY**.

### Legal Requirements

- **Explicit Written Authorization** required before testing ANY network
- **Unauthorized network access is ILLEGAL** in all jurisdictions  
- **Penalties may include**:
  - Criminal prosecution
  - Heavy fines
  - Imprisonment
  - Civil liability

### Acceptable Use Cases

✅ Testing your own networks  
✅ Authorized penetration testing with written consent  
✅ Educational purposes in controlled lab environments  
✅ Security research with proper authorization

### Unacceptable Use

❌ Any unauthorized network access  
❌ Testing without explicit permission  
❌ Malicious use of captured credentials  
❌ Disrupting network services

**By using this tool, you agree to take full responsibility for compliance with all applicable laws and regulations.**

## Contributing

This project implements well-documented attack techniques. Contributions welcome for:

- Additional attack modules with research references
- Performance optimizations
- Extended WiFi standard coverage (802.11ax/WiFi 6, 802.11be/WiFi 7)
- Documentation improvements

## License

Educational and research use only. See LICENSE file.

## Version

**v1.0** - Comprehensive WiFi Penetration Testing Framework  
Build Date: 2025-12-29  
Modules: 20 | Lines: 4625+ | Size: 74KB

## Author

WiFi Auto-PWN Framework  
Advanced WiFi Security Research & Implementation

---

**Disclaimer**: The authors and maintainers of this tool are not responsible for any misuse or damage caused by this program. Use at your own risk and ensure compliance with all applicable laws.
