# homelab

An intentionally overengineered homelab setup.

## What's what

### [makeiso](makeiso/README.md)

Builds an unattended Debian install ISO.

Install the OS without having to interact with the physical machine.
Plug in the usb, turn on the machine and wait for it to appear on network.
Updates all packages, configures pubkey and hardens ssh setup. The resulting installation is minimal yet secure - just enough to handover further configuration to ansible.
