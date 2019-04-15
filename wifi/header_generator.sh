#!/bin/bash

if [ ! -e "$@" ] || [ -z "$@" ]; then
  echo "Usage: ./header_generator.sh WCNSS_qcom_cfg.ini"
  exit 1
fi

echo "static const char wlan_cfg[] = {" > wlan_hdd_cfg.h
cat "$@" | grep -ve '^$\|^#' | sed 's@\"@\\\\"@g' | while read line; do printf '\t\"%s\\n\"\n' "$line"; done >> wlan_hdd_cfg.h
echo "};" >> wlan_hdd_cfg.h

ls -al wlan_hdd_cfg.h
