#!/usr/bin/env bash
# WCC -5 tunes for Pentium while retaining the 386 instruction-set floor.
cpu_target=${1:-8086}
case "$cpu_target" in
    8086) cpu_flag=0;;
    386) cpu_flag=3;;
    586) cpu_flag=5;;
    *) echo "Unsupported CPU: $cpu_target (use 8086, 386, or 586)" >&2; exit 2;;
esac
common_c_flags=(-q -"$cpu_flag" -bt=dos -ms -zu -s -os -ol -oi -oe=100 -zl -zlf)
