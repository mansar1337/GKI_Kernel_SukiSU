// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2020 Oplus. All rights reserved.
 *
 * Vendored from OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8550
 * branch oneplus/sm8550_t_13.1.0_oneplus11 @ 21da51cc, path
 * vendor/oplus/kernel/ipc/binder_main.c. Verbatim.
 */

#define pr_fmt(fmt) "oplus_binder_strategy:" fmt

#include <linux/sched.h>
#include <linux/module.h>

#include "binder_main.h"

static int __init oplus_binder_strategy_init(void)
{
	int ret = 0;

	oplus_binder_sched_init();

#ifdef CONFIG_OPLUS_BINDER_TRANS_CTRL
	ret = oplus_trans_ctrl_init();
	if (ret != 0) {
		pr_err("failed to init binder transaction control moduler\n");
		return ret;
	}
#endif

	return ret;
}

module_init(oplus_binder_strategy_init);
MODULE_DESCRIPTION("Oplus Binder Strategy Vender Hooks Driver");
MODULE_LICENSE("GPL v2");
