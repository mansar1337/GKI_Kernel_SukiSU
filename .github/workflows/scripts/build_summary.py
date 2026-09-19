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
