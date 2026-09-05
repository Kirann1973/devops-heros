# 🌐 Session 4 — Networking Fundamentals: Commands Output

---

## 📌 Overview

This document contains the output of essential **networking commands** executed on a Windows machine. These commands help diagnose connectivity, trace network paths, verify file integrity, inspect IP configurations, monitor active connections, and perform DNS lookups.

---

## 🛠️ Commands Used

| Command      | Description                                                    |
|--------------|----------------------------------------------------------------|
| `ping`       | Test connectivity to a remote host and measure latency         |
| `tracert`    | Trace the route packets take to reach a destination            |
| `certutil`   | Compute the checksum (hash) of a file for integrity checks    |
| `ipconfig`   | Display IP address, subnet mask, gateway, and DNS info         |
| `netstat`    | Show active network connections, listening ports, and states   |
| `nslookup`   | Query DNS servers to resolve domain names to IP addresses      |

---

## 1️⃣ Ping Output

> **Purpose:** Verify network connectivity to `google.com` and measure round-trip latency.

```
Pinging google.com [142.250.134.102] with 32 bytes of data:
Reply from 142.250.134.102: bytes=32 time=24ms TTL=113
Reply from 142.250.134.102: bytes=32 time=27ms TTL=113
Reply from 142.250.134.102: bytes=32 time=28ms TTL=113
Reply from 142.250.134.102: bytes=32 time=30ms TTL=113

Ping statistics for 142.250.134.102:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 24ms, Maximum = 30ms, Average = 27ms
```

**📊 Key Observations:**
- ✅ All 4 packets received — **0% packet loss**
- ⏱️ Average round-trip time: **27ms**
- 🔢 TTL = 113 (indicates the packet crossed ~17 hops)

---

## 2️⃣ Tracert Output

> **Purpose:** Trace the network path from the local machine to `google.com`, showing each hop along the route.

```
Tracing route to google.com [142.250.134.102]
over a maximum of 30 hops:

  1     6 ms     3 ms     1 ms  wifi.height8tech.com [100.129.160.1]
  2     5 ms     3 ms     3 ms  202.131.133.5.convergentindia.com [202.131.133.5]
  3     6 ms     4 ms     4 ms  115.117.125.189.static-mumbai.vsnl.net.in [115.117.125.189]
  4     *        *        *     Request timed out.
  5     9 ms     9 ms     8 ms  115.112.15.114
  6    14 ms    16 ms    10 ms  142.251.227.217
  7    15 ms    11 ms     9 ms  142.251.230.70
  8    24 ms    23 ms    23 ms  216.239.49.47
  9    32 ms    23 ms    38 ms  192.178.254.238
 10    31 ms    24 ms    28 ms  142.251.251.55
 11    24 ms    23 ms    23 ms  192.178.45.162
 12     *        *        *     Request timed out.
 13     *        *        *     Request timed out.
 14     *        *        *     Request timed out.
 15     *        *        *     Request timed out.
 16     *        *        *     Request timed out.
 17     *        *        *     Request timed out.
 18   105 ms    43 ms    32 ms  fx-in-f102.1e100.net [142.250.134.102]

Trace complete.
```

**📊 Key Observations:**
- 🏠 Hop 1 — Local gateway: `wifi.height8tech.com`
- 🌍 Route passes through ISP (`convergentindia.com`) → VSNL Mumbai → Google's network
- ⚠️ Hops 4, 12–17 timed out (routers configured to drop ICMP)
- 🏁 Reached destination at **Hop 18** (`fx-in-f102.1e100.net`)
- 📏 Total of **18 hops** to reach Google

---

## 3️⃣ Checksum (CertUtil) Output

> **Purpose:** Compute the SHA-256 hash of `testfile.txt` to verify file integrity.

```
C:\Users\nsama\testfile.txt:
9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08

CertUtil: -hashfile command completed successfully.
```

**📊 Key Observations:**
- 🔐 Algorithm: **SHA-256**
- 🧾 Hash: `9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08`
- ✅ Command completed successfully — file integrity verified

---

## 4️⃣ IPConfig Output

> **Purpose:** Display detailed IP configuration for all network adapters on the system.

```
Windows IP Configuration

   Host Name . . . . . . . . . . . . : mayank
   Primary Dns Suffix  . . . . . . . :
   Node Type . . . . . . . . . . . . : Hybrid
   IP Routing Enabled. . . . . . . . : No
   WINS Proxy Enabled. . . . . . . . : No
```

### Active Adapters Summary

| Adapter                      | IPv4 Address      | Subnet Mask     | Default Gateway  | DHCP    |
|------------------------------|-------------------|-----------------|------------------|---------|
| Wi-Fi (MediaTek MT7921)      | 100.129.165.176   | 255.255.240.0   | 100.129.160.1    | Enabled |
| vEthernet (WSL / Hyper-V)    | 172.20.64.1       | 255.255.240.0   | —                | No      |

### Disconnected Adapters

| Adapter                                     | Description                              |
|---------------------------------------------|------------------------------------------|
| Local Area Connection                       | TAP-Windows Adapter V9                   |
| Local Area Connection* 1                    | Microsoft Wi-Fi Direct Virtual Adapter   |
| Local Area Connection* 10                   | Microsoft Wi-Fi Direct Virtual Adapter #2|
| Ethernet                                    | Realtek Gaming GbE Family Controller     |

**📊 Key Observations:**
- 🖥️ Hostname: **mayank**
- 📶 Primary connection: **Wi-Fi** with IP `100.129.165.176`
- 🐧 WSL (Hyper-V) adapter active at `172.20.64.1`
- 🌐 DNS Servers: `100.129.160.1` (local gateway) and `8.8.8.8` (Google DNS)

---

## 5️⃣ Netstat Output

> **Purpose:** Display all active TCP/UDP connections and listening ports.

### Listening Ports (TCP)

| Port    | Address         | Description (Common Use)        |
|---------|-----------------|---------------------------------|
| 135     | 0.0.0.0         | RPC Endpoint Mapper             |
| 445     | 0.0.0.0         | SMB (File Sharing)              |
| 2869    | 0.0.0.0         | UPnP / SSDP                     |
| 3306    | 0.0.0.0         | MySQL Server                    |
| 5040    | 0.0.0.0         | Windows Delivery Optimization   |
| 33060   | 0.0.0.0         | MySQL X Protocol                |

### Established Connections (Sample)

| Local Address              | Foreign Address            | State         |
|----------------------------|----------------------------|---------------|
| 100.129.165.176:49420      | 4.213.25.240:443           | ESTABLISHED   |
| 100.129.165.176:53172      | 104.208.16.94:443          | ESTABLISHED   |
| 100.129.165.176:59185      | 140.82.112.25:443          | ESTABLISHED   |
| 100.129.165.176:59986      | 172.253.134.188:5228       | ESTABLISHED   |
| 100.129.165.176:63611      | 142.251.222.174:443        | ESTABLISHED   |

**📊 Key Observations:**
- 🗄️ **MySQL** is running on port `3306` and `33060`
- 🔒 Most established connections are over **HTTPS (port 443)**
- 🐙 Connection to GitHub detected (`140.82.112.25`)
- 📨 Google push notifications active on port `5228`
- 🔁 Several loopback connections (`127.0.0.1`) for local services

---

## 6️⃣ NSLookup Output

> **Purpose:** Query the DNS server to resolve `google.com` to its IP addresses.

```
Server:  wifi.height8tech.com
Address:  100.129.160.1

Non-authoritative answer:
Name:    google.com
Addresses:  2404:6800:4000:1006::71
          2404:6800:4000:1006::8a
          2404:6800:4000:1006::64
          2404:6800:4000:1006::8b
          142.250.134.138
          142.250.134.100
          142.250.134.102
          142.250.134.101
          142.250.134.139
          142.250.134.113
```

**📊 Key Observations:**
- 🖥️ DNS Server: `wifi.height8tech.com` (`100.129.160.1`)
- 📝 Response type: **Non-authoritative** (cached by local DNS)
- 🌐 **IPv4 addresses** resolved: 6 addresses (e.g., `142.250.134.102`)
- 🆕 **IPv6 addresses** resolved: 4 addresses (e.g., `2404:6800:4000:1006::71`)
- 🔄 Multiple IPs indicate Google's **load balancing** infrastructure

---

## 📝 Summary Table

| Command    | Target        | Result                                          |
|------------|---------------|-------------------------------------------------|
| `ping`     | google.com    | ✅ 4/4 packets received, avg latency 27ms       |
| `tracert`  | google.com    | ✅ 18 hops, route via ISP → VSNL → Google       |
| `certutil` | testfile.txt  | ✅ SHA-256 hash generated successfully           |
| `ipconfig` | All adapters  | ✅ Wi-Fi active at 100.129.165.176               |
| `netstat`  | All ports     | ✅ MySQL, SMB, HTTPS connections active          |
| `nslookup` | google.com    | ✅ 10 IPs resolved (6 IPv4 + 4 IPv6)            |

---

## 👤 Author

**Kiran N** — `24bcs10446`

---

> ✅ **End of Session 4 — Networking Fundamentals: Commands Output**
