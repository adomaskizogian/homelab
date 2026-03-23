#!/bin/sh

# adjust boot order for the next startup to boot from usb
efibootmgr -n "$(efibootmgr | grep -i "usb" | head -n 1 | cut -c 5-8)"