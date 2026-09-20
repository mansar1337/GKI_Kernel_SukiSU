#!/system/bin/sh
# Install-time check. The modules hook into this exact kernel's structures
# via vendor hooks - on a kernel without them insmod fails cleanly, but
# better to find out now than after a reboot.

SKIPUNZIP=0

ui_print ""
ui_print "  oplusnize modules"
ui_print "  kernel: $(uname -r)"
ui_print ""

if [ -d /proc/oplusnize ]; then
	ui_print "  + oplusnize bridge present (/proc/oplusnize)"
else
	ui_print "  ! /proc/oplusnize missing - this does not look like an"
	ui_print "  ! oplusnize kernel. The modules will likely fail to load."
	ui_print "  ! Continuing anyway; remove the module if they don't."
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
