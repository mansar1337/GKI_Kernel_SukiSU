#!/system/bin/sh
# oplusnize modules - loads the loadable oplus .ko files at boot.
# service.sh (late_start) is enough: plain insmod, no firmware and no
# mount-namespace subtleties involved.
#
# Order matters only for readability: every module is independent
# (no inter-module dependencies), each registers its own hooks.

MODDIR=${0%/*}

for m in crypto_zstdn_o oplus_bsp_kshrink_lruvecd oplus_bsp_kshrink_slabd oplus_bsp_pcppages_opt oplus_bsp_abort_mm_opt oplus_bsp_look_around oplus_bsp_mapped_protect; do
	lsmod 2>/dev/null | grep -q "^$m " && continue
	KO="$MODDIR/modules/$m.ko"
	[ -f "$KO" ] || continue
	insmod "$KO" 2>/dev/null
done
