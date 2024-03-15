#!/usr/bin/env sh
if ! swaymsg -t get_outputs | grep -q HEADLESS-1
then
  swaymsg create_output
fi
swaymsg output "HEADLESS-1" enable
sleep 1
