// SPDX-License-Identifier: GPL-2.0-only
/*
 * oplusnize kernel-to-app bridge.
 *
 * Exposes /proc/oplusnize/{version,features,modules}, world-readable,
 * so the oplusnize manager app can verify kernel features WITHOUT root:
 * compiled-in state comes from IS_ENABLED() (same symbols the build
 * enables), loaded-module state from find_module().
 *
 * Deliberately boring: no hooks, no structs, no exports, no writable
 * nodes. Idle cost is zero (nothing runs until a file is read).
 */

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/utsname.h>

#define OPLUSNIZE_PROC_DIR	"oplusnize"

static struct proc_dir_entry *oplusnize_dir;

static int version_show(struct seq_file *m, void *v)
{
	seq_printf(m, "%s\n", utsname()->release);
	return 0;
}

/* One NAME=0/1 line per feature. Compiled-in state only: these symbols
 * cannot switch at runtime, so "compiled in" == "active" here (modulo
 * the .ko modules below, which report loaded state separately).
 * IS_ENABLED() on an undefined symbol is plain 0 - no warning. */
static int features_show(struct seq_file *m, void *v)
{
	seq_printf(m, "oplusnize=1\n");
	seq_printf(m, "sukisu=%d\n", IS_ENABLED(CONFIG_KSU));
	seq_printf(m, "susfs=%d\n", IS_ENABLED(CONFIG_KSU_SUSFS));
	seq_printf(m, "kpm=%d\n", IS_ENABLED(CONFIG_KPM));
	seq_printf(m, "bbg=%d\n", IS_ENABLED(CONFIG_BBG));
	seq_printf(m, "wireguard=%d\n", IS_ENABLED(CONFIG_WIREGUARD));
	seq_printf(m, "cifs=%d\n", IS_ENABLED(CONFIG_CIFS));
	seq_printf(m, "zram=%d\n", IS_ENABLED(CONFIG_ZRAM));
	seq_printf(m, "lz4kd=%d\n", IS_ENABLED(CONFIG_CRYPTO_LZ4KD));
	seq_printf(m, "mglru=%d\n", IS_ENABLED(CONFIG_LRU_GEN));
	seq_printf(m, "psi=%d\n", IS_ENABLED(CONFIG_PSI));
	seq_printf(m, "ntsync=%d\n", IS_ENABLED(CONFIG_NTSYNC));
	seq_printf(m, "lto_full=%d\n", IS_ENABLED(CONFIG_LTO_CLANG_FULL));
	seq_printf(m, "lto_thin=%d\n", IS_ENABLED(CONFIG_LTO_CLANG_THIN));
	seq_printf(m, "rd_lzma=%d\n", IS_ENABLED(CONFIG_RD_LZMA));
	seq_printf(m, "ath9k=%d\n", IS_ENABLED(CONFIG_ATH9K_HTC));
	seq_printf(m, "bbr3=%d\n", IS_ENABLED(CONFIG_TCP_CONG_BBR3));
	seq_printf(m, "kprobes=%d\n", IS_ENABLED(CONFIG_KPROBES));
	seq_printf(m, "uprobes=%d\n", IS_ENABLED(CONFIG_UPROBES));
	seq_printf(m, "ipset=%d\n", IS_ENABLED(CONFIG_IP_SET));
	seq_printf(m, "binder=%d\n", IS_ENABLED(CONFIG_OPLUS_BINDER_STRATEGY));
	seq_printf(m, "binder_prio_skip=%d\n", IS_ENABLED(CONFIG_OPLUS_BINDER_PRIO_SKIP));
	seq_printf(m, "kswapd=%d\n", IS_ENABLED(CONFIG_OPLUS_FEATURE_KSWAPD_OPT));
	seq_printf(m, "waker=%d\n", IS_ENABLED(CONFIG_OPLUS_FEATURE_WAKER_IDENTIFY));
	seq_printf(m, "kprobe_fw=%d\n", IS_ENABLED(CONFIG_OPLUS_PATCH));
	seq_printf(m, "zstdn=%d\n", IS_ENABLED(CONFIG_CRYPTO_ZSTDN));
	seq_printf(m, "pcompact=%d\n", IS_ENABLED(CONFIG_OPLUS_FEATURE_PROACTIVE_COMPACT));
	seq_printf(m, "uprobe=%d\n", IS_ENABLED(CONFIG_OPLUS_FEATURE_OPLUS_UPROBE));
	seq_printf(m, "storage_log=%d\n", IS_ENABLED(CONFIG_OPLUS_FEATURE_STORAGE_LOG));
	return 0;
}

/* Loadable oplus modules, one loaded name per line (empty when none).
 * find_module() carries its own locking; proc read context sleeps fine. */
static const char * const oplus_modules[] = {
	"crypto_zstdn_o",
	"oplus_bsp_kshrink_lruvecd",
	"oplus_bsp_kshrink_slabd",
	"oplus_bsp_pcppages_opt",
	"oplus_bsp_abort_mm_opt",
	"oplus_bsp_look_around",
	"oplus_bsp_mapped_protect",
};

static int modules_show(struct seq_file *m, void *v)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(oplus_modules); i++) {
		if (find_module(oplus_modules[i]))
			seq_printf(m, "%s\n", oplus_modules[i]);
	}
	return 0;
}

#define OPLUSNIZE_PROC_ENTRY(name)					\
static int name##_open(struct inode *inode, struct file *file)		\
{									\
	return single_open(file, name##_show, NULL);			\
}									\
									\
static const struct proc_ops name##_proc_ops = {			\
	.proc_open	= name##_open,					\
	.proc_read	= seq_read,					\
	.proc_lseek	= seq_lseek,					\
	.proc_release	= single_release,				\
}

OPLUSNIZE_PROC_ENTRY(version)
OPLUSNIZE_PROC_ENTRY(features)
OPLUSNIZE_PROC_ENTRY(modules)

static int __init oplusnize_init(void)
{
	oplusnize_dir = proc_mkdir(OPLUSNIZE_PROC_DIR, NULL);
	if (!oplusnize_dir) {
		pr_err("oplusnize: failed to create /proc/" OPLUSNIZE_PROC_DIR "\n");
		return -ENOMEM;
	}
	/* 0444: the whole point is unprivileged reads from the app. */
	proc_create("version", 0444, oplusnize_dir, &version_proc_ops);
	proc_create("features", 0444, oplusnize_dir, &features_proc_ops);
	proc_create("modules", 0444, oplusnize_dir, &modules_proc_ops);
	pr_info("oplusnize: /proc/oplusnize ready\n");
	return 0;
}

static void __exit oplusnize_exit(void)
{
	remove_proc_entry("version", oplusnize_dir);
	remove_proc_entry("features", oplusnize_dir);
	remove_proc_entry("modules", oplusnize_dir);
	remove_proc_entry(OPLUSNIZE_PROC_DIR, NULL);
}

module_init(oplusnize_init);
module_exit(oplusnize_exit);
MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("oplusnize kernel-to-app bridge (rootless feature checks)");
