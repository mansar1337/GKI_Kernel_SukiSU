#!/system/bin/sh
# Best-effort unload on module removal. KernelSU removes the files
# afterwards; a reboot fully restores the stock (module-free) state.
for m in oplus_bsp_mapped_protect oplus_bsp_look_around oplus_bsp_abort_mm_opt oplus_bsp_pcppages_opt oplus_bsp_kshrink_slabd oplus_bsp_kshrink_lruvecd crypto_zstdn_o; do
	rmmod "$m" 2>/dev/null
done
