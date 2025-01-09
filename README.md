# Content Filtering + (DoH) for OpenVPN Clients via BIND-DNSCrypt

A robust solution to secure and filter DNS traffic for OpenVPN clients using **BIND**, **DNSCrypt**, and **Cloudflare (DoH)**. This repository includes configuration steps, bash scripts, and guidelines for enabling content filtering and monitoring OpenVPN client traffic.

---

## Overview

This project demonstrates how to:
- Secure DNS traffic with **DNSCrypt** using encrypted DNS-over-HTTPS (DoH).
- Enable content filtering with **Cloudflare Family DNS** for OpenVPN clients.
- Integrate **BIND** as an authoritative and recursive DNS server.
- Push filtered, secure DNS configurations to OpenVPN clients.
- Optionally monitor OpenVPN client HTTP traffic using logging techniques.

The tutorial assumes you have prior knowledge of:
- Installing and configuring OpenVPN, BIND, and DNSCrypt.
- System administration and handling advanced DNS setups.

---

## Features
- **Content Filtering**: Block adult and other restricted content via Cloudflare Family DNS.
- **DNS-over-HTTPS (DoH)**: Encrypt DNS traffic for privacy and security.
- **OpenVPN Integration**: Push secure DNS to OpenVPN clients for consistent filtering.
- **Traffic Monitoring**: Includes a sample script, `spy_vpn.sh`, to analyze OpenVPN client traffic.

---

## Files
- **`spy_vpn.sh`**: A script to monitor OpenVPN client HTTP activity.

---

## Getting Started

### Prerequisites
- OpenVPN installed and configured with a functional TUN/TAP interface.
- BIND set up as an authoritative primary DNS server.
- DNSCrypt-proxy configured to use **Cloudflare (DoH)**.

### Setup Steps
Refer to the full tutorial: [Content Filtering + (DoH) for OpenVPN Clients via BIND-DNSCrypt](https://www.psauxit.com/secured-openvpn-clients-dnscrypt/).

### Key Points
1. **DNSCrypt Setup**:
   - Listen on a secondary loopback address (e.g., `127.0.2.1:53`).
   - Configure caching and logging for optimal performance and debugging.

2. **BIND Integration**:
   - Forward DNS queries to DNSCrypt-proxy.
   - Separate OpenVPN client DNS traffic using BIND views.

3. **OpenVPN Configuration**:
   - Push filtered DNS to OpenVPN clients using `push "dhcp-option DNS <bind-listen-IP>"`.
   - Enable logging for query tracking and debugging.

4. **Traffic Monitoring**:
   - Use `spy_vpn.sh` to analyze OpenVPN client DNS and HTTP traffic.

---

## Testing the Setup
1. Connect an OpenVPN client.
2. Verify DNS-over-HTTPS (DoH) using Cloudflare's [DoH Test](https://1.1.1.1/help).
3. Check logs:
   - DNSCrypt: `/var/log/dnscrypt-proxy/query.log`
   - BIND: `/var/log/named/queries.log`
4. Analyze traffic using tools like `tcpdump`.

---

## Resources
- Full Tutorial: [PSAUXIT Tutorial](https://www.psauxit.com/secured-openvpn-clients-dnscrypt/)
- Cloudflare DoH Service: [1.1.1.1/help](https://1.1.1.1/help)

---

## Contributing
Feel free to submit issues or contribute to the repository by opening pull requests.

---

## Author
Created by [Hasan ÇALIŞIR](https://github.com/hsntgm) at [PSAUXIT](https://www.psauxit.com/)


