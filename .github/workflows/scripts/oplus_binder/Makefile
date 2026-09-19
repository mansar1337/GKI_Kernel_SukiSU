# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2018-2020 Oplus. All rights reserved.
# Vendored from OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8550
# branch oneplus/sm8550_t_13.1.0_oneplus11 @ 21da51cc, path
# vendor/oplus/kernel/ipc/Makefile. trans_ctrl.o deliberately dropped:
# OnePlus's own kalama_GKI.config leaves CONFIG_OPLUS_BINDER_TRANS_CTRL
# off, and it is a 938-line procfs/miscdevice surface we don't need for
# the PRIO_SKIP strategy ported here.

LINUXINCLUDE += -I$(srctree)/

obj-$(CONFIG_OPLUS_BINDER_STRATEGY) += oplus_binder_strategy.o
oplus_binder_strategy-y += binder_main.o
oplus_binder_strategy-y += binder_sched.o
