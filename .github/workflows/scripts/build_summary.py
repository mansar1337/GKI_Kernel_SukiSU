#!/usr/bin/env python3
"""Single-sourced post-build summary template (oplusnize).

Every place that announces a finished build - console (build.py),
Telegram (telegram_notify.py) - renders the same lines:

    ✅ New Build

    ℹ️ 5.15.216-android13_@oplusnize-lts
    ℹ️ Thin LTO

The kernel release string mirrors KernelBuilder._write_scmversion exactly
(-android[-rNN][_@oplusnize][-lts]), so the announced version can never
drift from what was actually built. Dependency-free on purpose (plain
values in, strings out) so telegram_notify.py can import it without
pulling config.py's network calls.
"""


def kernel_release_string(kernel_version, sub_level, android_version,
                          respin=None, is_lts=False, oplus=False):
    """Assemble the on-device kernel release string.

    kernel_version is "5.15" style (without sub level); sub_level is
    "216" style. respin is "r00" style or None (SHA-pinned LTS builds
    have no respin number).
    """
    suffix = f"-{android_version}"
    if respin:
        suffix += f"-{respin}"
    if oplus and "@oplusnize" not in suffix:
        suffix += "_@oplusnize"
    if is_lts:
        suffix += "-lts"
    return f"{kernel_version}.{sub_level}{suffix}"


def lto_label(lto_mode):
    return "Full LTO" if lto_mode == "full" else "Thin LTO"


def render_text(kernel_release, lto_mode):
    return f"✅ New Build\n\nℹ️ {kernel_release}\nℹ️ {lto_label(lto_mode)}"


def render_html(kernel_release, lto_mode):
    return (f"✅ <b>New Build</b>\n\n"
            f"ℹ️ <code>{kernel_release}</code>\n"
            f"ℹ️ {lto_label(lto_mode)}")


# Patch-status keys that are infrastructure/checks, not user features -
# never listed in the report even when applied.
SKIP_FEATURE_KEYS = {
    "effective_config", "image_ikconfig", "safemode_disable",
    "ksu_version_code", "bbg_genheaders_path",
    "susfs_kernelsu_integration", "selinux_hide_guards",
    "oplus_modules", "ath9k_modules",
    "bazel_check_defconfig", "bazel_post_defconfig_cmds",
    "defconfig_canonicalization",
}

# Curated display order; anything applied but unlisted here is appended
# alphabetically (raw key) so new features never vanish silently.
FEATURE_ORDER = [
    "sukisu_ref", "susfs", "baseband_guard", "droidspaces", "bbrv3",
    "ntsync", "zram_lz4kd", "vendor_module_blacklist",
    "ptrace_leak_fix", "unicode_bypass_fix", "task_mmu_fixes",
    "sukisu_hide_stuff", "ath9k",
    "oplus_binder", "oplus_kswapd", "oplus_waker", "oplus_patch",
    "oplus_zstd", "oplus_pcompact", "oplus_uprobe", "oplus_nize",
    "oplus_mm", "micro_opts",
]
FEATURE_LABELS = {
    "susfs": "SUSFS",
    "baseband_guard": "BBG",
    "droidspaces": "Droidspaces",
    "bbrv3": "BBRv3",
    "ntsync": "NTSync",
    "zram_lz4kd": "ZRAM+LZ4KD",
    "vendor_module_blacklist": "vendor blacklist",
    "ptrace_leak_fix": "ptrace fix",
    "unicode_bypass_fix": "unicode fix",
    "task_mmu_fixes": "task_mmu fixes",
    "sukisu_hide_stuff": "hide stuff",
    "ath9k": "ath9k_htc",
    "oplus_binder": "binder PRIO_SKIP",
    "oplus_kswapd": "kswapd_opt",
    "oplus_waker": "waker_identify",
    "oplus_patch": "kprobe framework",
    "oplus_zstd": "zstdn_o",
    "oplus_pcompact": "proactive_compact",
    "oplus_uprobe": "uprobe tracer",
    "oplus_nize": "nize bridge",
    "oplus_mm": "mm family (6)",
    "micro_opts": "micro-opts (22)",
}


def feature_list(patches):
    """Human-readable applied-feature labels from a PATCH_STATUS patches
    dict, in curated order. sukisu_ref carries its version."""
    if not isinstance(patches, dict):
        return []
    applied = {k for k, e in patches.items()
               if isinstance(e, dict) and e.get("status") == "applied"
               and k not in SKIP_FEATURE_KEYS}
    out = []
    for key in FEATURE_ORDER:
        if key not in applied:
            continue
        if key == "sukisu_ref":
            detail = patches[key].get("detail", "") or ""
            ver = detail.split()[0] if detail.split() else ""
            out.append(f"SukiSU-Ultra {ver}".rstrip())
        else:
            out.append(FEATURE_LABELS.get(key, key))
    for key in sorted(applied - set(FEATURE_ORDER)):
        out.append(FEATURE_LABELS.get(key, key))
    return out


def format_date(ts=None):
    import datetime as _dt
    if ts is None:
        ts = _dt.datetime.now(_dt.timezone.utc).timestamp()
    return _dt.datetime.fromtimestamp(ts, _dt.timezone.utc).strftime("%Y-%m-%d")


def format_duration(seconds):
    try:
        s = int(seconds)
    except (TypeError, ValueError):
        return ""
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if h:
        return f"{h}h {m}m {s}s"
    if m:
        return f"{m}m {s}s"
    return f"{s}s"


def render_full_text(kernel_release, lto_mode, date=None, features=None,
                     artifacts=None, build_time=None):
    lines = ["✅ New Build", "",
             f"ℹ️ Version: {kernel_release}",
             f"ℹ️ LTO: {lto_label(lto_mode)} | Date: {date or format_date()}"]
    if features:
        lines.append(f"ℹ️ Features ({len(features)}): " + ", ".join(features))
    if artifacts:
        names = [a.rsplit("/", 1)[-1] for a in artifacts]
        lines.append(f"📦 Artifacts ({len(names)}): " + ", ".join(names))
    if build_time:
        dur = format_duration(build_time)
        if dur:
            lines.append(f"⏱ Build time: {dur}")
    return "\n".join(lines)


def render_full_html(kernel_release, lto_mode, date=None, features=None,
                     artifacts=None, build_time=None):
    lines = ["✅ <b>New Build</b>", "",
             f"ℹ️ <b>Version:</b> <code>{kernel_release}</code>",
             f"ℹ️ <b>LTO:</b> {lto_label(lto_mode)} | <b>Date:</b> {date or format_date()}"]
    if features:
        lines.append(f"ℹ️ <b>Features ({len(features)}):</b> " + ", ".join(features))
    if artifacts:
        names = [a.rsplit("/", 1)[-1] for a in artifacts]
        lines.append("📦 <b>Artifacts (%d):</b> " % len(names)
                     + ", ".join(f"<code>{n}</code>" for n in names))
    if build_time:
        dur = format_duration(build_time)
        if dur:
            lines.append(f"⏱ <b>Build time:</b> {dur}")
    return "\n".join(lines)


def report_values(report):
    """Pull (kernel_release, lto_mode) out of a PATCH_STATUS.json dict,
    or (None, None) if the report doesn't have what it takes."""
    try:
        lto_mode = report.get("lto_mode") or "thin"
        is_lts = bool(report.get("is_lts", False))
        respin = (report.get("kernel_respin") or "").strip() or None
        android = report.get("android_version")
        kernel = report.get("kernel_version")
        sub = str(report.get("sub_level", ""))
        if not (android and kernel and sub):
            return None, None
        # "oplus" is written by KernelBuilder._write_patch_status from the
        # same predicate _write_scmversion uses; fall back to scanning
        # applied oplus_* entries for older reports that predate it.
        patches = report.get("patches") or {}
        if "oplus" in report:
            oplus = bool(report.get("oplus"))
        else:
            oplus = any(k.startswith("oplus_") and
                        isinstance(e, dict) and e.get("status") == "applied"
                        for k, e in patches.items())
        release = kernel_release_string(kernel, sub, android,
                                        respin=respin, is_lts=is_lts,
                                        oplus=oplus)
        return release, lto_mode
    except Exception:
        return None, None
