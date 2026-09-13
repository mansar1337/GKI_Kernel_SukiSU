#!/usr/bin/env bash
# check-release.sh - is it safe to bump the SukiSU-Ultra / susfs4ksu pins yet?
#
# Answers three questions without building anything:
#   1. Is there a SukiSU tag newer than the one we pin, and what UAPI does it carry?
#   2. Has susfs4ksu caught up with it?
#   3. Would 10_enable_susfs_for_ksu.patch apply cleanly to that combination?
#
# The third question is the one that matters. A build can succeed with SUSFS
# only half-applied, so "it compiled" is not evidence. This dry-runs the patch
# and reports which FILES fail, because the file decides the verdict:
#   - only kernel/core/init.c    -> _recover_susfs_init_c handles it -> GO
#   - anything else              -> no recovery exists               -> STOP
#
# Read-only. Clones into a cache dir, never touches the build workspace.

set -uo pipefail

# ---- current pins (keep in sync with what you actually build) ----------------
PINNED_KSU_REF="v4.2.0"
PINNED_KSU_VERSION_CODE="40901"   # what the paired manager reports
declare -A PINNED_SUSFS=(
    [gki-android13-5.15]="bca0d2333c1a7d717e7278b019d7af7ba1d16005"
    [gki-android14-6.1]="4fc9c1898ea66f51847cdbc0d1473ea4ef525a70"
    [gki-android15-6.6]="937215cb3a1b1f333d764c366c7a49972fa8e7a0"
)
# Branch checked in depth. Others are only reported, not patch-tested.
PRIMARY_BRANCH="gki-android13-5.15"

# Files that _recover_susfs_init_c knows how to finish by hand.
RECOVERABLE="kernel/core/init.c"

SUKI_URL="https://github.com/SukiSU-Ultra/SukiSU-Ultra.git"
SUSFS_URL="https://github.com/ShirkNeko/susfs4ksu.git"
CACHE="${GKI_CHECK_CACHE:-$HOME/.cache/gki-check}"

TAG_COUNT=4
while [ $# -gt 0 ]; do
    case "$1" in
        --tags) TAG_COUNT="$2"; shift 2 ;;
        --branch) PRIMARY_BRANCH="$2"; shift 2 ;;
        --cache) CACHE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--tags N] [--branch gki-android13-5.15] [--cache DIR]"
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [ -t 1 ]; then
    R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi
ok()   { echo "  ${G}OK${N}    $*"; }
warn() { echo "  ${Y}WARN${N}  $*"; }
bad()  { echo "  ${R}STOP${N}  $*"; }
hdr()  { echo; echo "${B}=== $* ===${N}"; }

command -v git   >/dev/null || { echo "git not found" >&2; exit 1; }
command -v patch >/dev/null || { echo "patch not found" >&2; exit 1; }

mkdir -p "$CACHE"
SUKI="$CACHE/SukiSU-Ultra"
SUSFS="$CACHE/susfs4ksu"

sync_repo() {   # $1=url $2=dir $3=label
    if [ -d "$2/.git" ]; then
        echo "Updating $3..."
        git -C "$2" fetch -q --tags --prune origin || {
            echo "  fetch failed - using cached copy" >&2; return 0; }
    else
        echo "Cloning $3..."
        git clone -q --filter=blob:none --no-checkout "$1" "$2" || return 1
    fi
}
sync_repo "$SUKI_URL"  "$SUKI"  "SukiSU-Ultra" || exit 1
sync_repo "$SUSFS_URL" "$SUSFS" "susfs4ksu"    || exit 1

uapi_of() {     # $1=ref -> prints the number, or nothing
    git -C "$SUKI" show "$1:uapi/supercall.h" 2>/dev/null \
        | grep -m1 -oE "KERNEL_SU_UAPI_VERSION = [0-9]+" | grep -oE "[0-9]+$"
}

# ---- 1. SukiSU tags and UAPI -------------------------------------------------
hdr "SukiSU-Ultra: tags and UAPI version"

PINNED_UAPI="$(uapi_of "$PINNED_KSU_REF")"
MAIN_UAPI="$(uapi_of origin/main)"
: "${PINNED_UAPI:=?}" ; : "${MAIN_UAPI:=?}"

printf "  %-14s %-12s %s\n" "REF" "DATE" "UAPI"
NEWER_TAG=""
for t in $(git -C "$SUKI" tag --sort=-creatordate | head -n "$TAG_COUNT"); do
    d="$(git -C "$SUKI" log -1 --format=%cs "$t" 2>/dev/null)"
    u="$(uapi_of "$t")"; : "${u:=-}"
    mark=""
    [ "$t" = "$PINNED_KSU_REF" ] && mark="  <- current pin"
    # a tag is interesting only if it is newer than our pin AND raises UAPI
    if [ -z "$NEWER_TAG" ] && [ "$t" != "$PINNED_KSU_REF" ] \
       && [ "$u" != "-" ] && [ "$PINNED_UAPI" != "?" ] && [ "$u" -gt "$PINNED_UAPI" ] 2>/dev/null; then
        NEWER_TAG="$t"; mark="  <- candidate"
    fi
    printf "  %-14s %-12s %s%s\n" "$t" "$d" "$u" "$mark"
done
printf "  %-14s %-12s %s\n" "main" \
    "$(git -C "$SUKI" log -1 --format=%cs origin/main)" "$MAIN_UAPI"

echo
if [ -n "$NEWER_TAG" ]; then
    ok "New tag with a higher UAPI: ${B}$NEWER_TAG${N} (UAPI $(uapi_of "$NEWER_TAG"), pin is $PINNED_UAPI)"
    CANDIDATE="$NEWER_TAG"
elif [ "$MAIN_UAPI" != "?" ] && [ "$PINNED_UAPI" != "?" ] && [ "$MAIN_UAPI" -gt "$PINNED_UAPI" ]; then
    warn "main is at UAPI $MAIN_UAPI but the newest tag is still UAPI $PINNED_UAPI."
    echo "        The manager built from main will demand UAPI $MAIN_UAPI and root will not"
    echo "        work against a tag-built kernel. Keep using the release manager for"
    echo "        $PINNED_KSU_REF (version code $PINNED_KSU_VERSION_CODE) until they tag."
    CANDIDATE="origin/main"
    echo "        Testing against main below anyway, for information only."
else
    ok "Nothing newer than the current pin. No action needed."
    CANDIDATE="$PINNED_KSU_REF"
fi

# ---- 2. susfs branch state ---------------------------------------------------
hdr "susfs4ksu: pinned vs branch HEAD"
printf "  %-22s %-10s %-10s %s\n" "BRANCH" "PINNED" "HEAD" "BEHIND"
for br in "${!PINNED_SUSFS[@]}"; do
    pin="${PINNED_SUSFS[$br]}"
    if ! git -C "$SUSFS" rev-parse --verify -q "origin/$br" >/dev/null; then
        printf "  %-22s %-10s %s\n" "$br" "${pin:0:7}" "(branch missing on this fork)"
        continue
    fi
    head="$(git -C "$SUSFS" rev-parse "origin/$br")"
    behind="$(git -C "$SUSFS" rev-list --count "$pin..origin/$br" 2>/dev/null || echo '?')"
    printf "  %-22s %-10s %-10s %s\n" "$br" "${pin:0:7}" "${head:0:7}" "$behind"
done

# ---- 3. the decisive test ----------------------------------------------------
hdr "Patch dry-run: does SUSFS apply to the candidate SukiSU?"

WORKTREE="$(mktemp -d)"
cleanup() {
    git -C "$SUKI" worktree remove --force "$WORKTREE" >/dev/null 2>&1
    rm -rf "$WORKTREE"
}
trap cleanup EXIT

test_combo() {  # $1=suki-ref $2=susfs-ref $3=label -> sets FAILED_FILES, FAIL_COUNT
    FAILED_FILES=""; FAIL_COUNT=0
    local pf; pf="$(mktemp)"
    if ! git -C "$SUSFS" show \
        "$2:kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" > "$pf" 2>/dev/null; then
        FAILED_FILES="(patch not found at $2)"; FAIL_COUNT=-1; rm -f "$pf"; return
    fi
    git -C "$SUKI" worktree remove --force "$WORKTREE" >/dev/null 2>&1
    rm -rf "$WORKTREE"
    if ! git -C "$SUKI" worktree add -q --detach "$WORKTREE" "$1" >/dev/null 2>&1; then
        FAILED_FILES="(cannot check out $1)"; FAIL_COUNT=-1; rm -f "$pf"; return
    fi
    local out
    out="$(cd "$WORKTREE" && patch -p1 --fuzz=3 --dry-run < "$pf" 2>&1)"
    FAIL_COUNT="$(printf '%s\n' "$out" | grep -cE '^Hunk.*FAILED')"
    FAILED_FILES="$(printf '%s\n' "$out" \
        | awk '/^checking file /{f=$3} /FAILED/{if(f!=""){print f; f=""}}' \
        | sort -u | tr '\n' ' ')"
    rm -f "$pf"
}

PRIMARY_PIN="${PINNED_SUSFS[$PRIMARY_BRANCH]:-}"
PRIMARY_HEAD="$(git -C "$SUSFS" rev-parse "origin/$PRIMARY_BRANCH" 2>/dev/null)"

echo "  Branch under test: $PRIMARY_BRANCH"
echo
printf "  %-26s %-26s %-8s %s\n" "SUKISU" "SUSFS" "FAILED" "FILES"

declare -a VERDICT_LABEL VERDICT_FILES VERDICT_COUNT
add_row() {
    test_combo "$1" "$2" "$3"
    printf "  %-26s %-26s %-8s %s\n" "$3" "$4" "$FAIL_COUNT" "${FAILED_FILES:-none}"
    VERDICT_LABEL+=("$3 + $4")
    VERDICT_FILES+=("$FAILED_FILES")
    VERDICT_COUNT+=("$FAIL_COUNT")
}

# current combination, as a baseline to compare against
add_row "$PINNED_KSU_REF" "$PRIMARY_PIN" "$PINNED_KSU_REF" "${PRIMARY_PIN:0:7} (pin)"
if [ "$CANDIDATE" != "$PINNED_KSU_REF" ]; then
    add_row "$CANDIDATE" "$PRIMARY_PIN"  "$CANDIDATE" "${PRIMARY_PIN:0:7} (pin)"
    add_row "$CANDIDATE" "$PRIMARY_HEAD" "$CANDIDATE" "${PRIMARY_HEAD:0:7} (HEAD)"
elif [ "$PRIMARY_HEAD" != "$PRIMARY_PIN" ]; then
    add_row "$PINNED_KSU_REF" "$PRIMARY_HEAD" "$PINNED_KSU_REF" "${PRIMARY_HEAD:0:7} (HEAD)"
fi

# ---- verdict -----------------------------------------------------------------
hdr "Verdict"

BEST_IDX=-1
BASELINE_COUNT="${VERDICT_COUNT[0]:-0}"
for i in "${!VERDICT_LABEL[@]}"; do
    files="${VERDICT_FILES[$i]}"
    count="${VERDICT_COUNT[$i]}"
    [ "$count" = "-1" ] && continue
    unrecoverable=""
    for f in $files; do
        [ "$f" = "$RECOVERABLE" ] && continue
        unrecoverable="$unrecoverable $f"
    done
    if [ -z "$files" ]; then
        ok "${VERDICT_LABEL[$i]} - patch applies fully. SUSFS and SukiSU are in sync."
        [ "$i" -gt 0 ] && [ "$BEST_IDX" -lt 0 ] && BEST_IDX=$i
    elif [ -z "$unrecoverable" ]; then
        ok "${VERDICT_LABEL[$i]} - only $RECOVERABLE fails ($count hunks); that file has recovery logic."
        if [ "$i" -gt 0 ] && [ "$count" -gt "$BASELINE_COUNT" ] 2>/dev/null; then
            warn "  ...but $count hunks fail vs $BASELINE_COUNT on the current pin."
            echo "        _recover_susfs_init_c was written for a SPECIFIC set of hunks."
            echo "        An extra failing hunk in the same file is NOT automatically covered."
            echo "        Diff the failing hunk numbers against the current pin before trusting this."
        elif [ "$i" -gt 0 ]; then
            [ "$BEST_IDX" -lt 0 ] && BEST_IDX=$i
        fi
    else
        bad "${VERDICT_LABEL[$i]} - failures outside $RECOVERABLE:$unrecoverable"
        echo "        No recovery logic exists for those. Do not build this combination."
    fi
done

echo
if [ "$CANDIDATE" = "$PINNED_KSU_REF" ]; then
    echo "  Nothing to change. Keep building with:"
    echo "    --ksu-commit $PINNED_KSU_REF \\"
    echo "    --susfs-commit $PRIMARY_PIN \\"
    echo "    --ksu-version-code $PINNED_KSU_VERSION_CODE"
elif [ "$BEST_IDX" -ge 0 ]; then
    echo "  Usable combination: ${VERDICT_LABEL[$BEST_IDX]}"
    case "$CANDIDATE" in
      origin/*) echo "  ${Y}NOTE${N}: this is a moving branch HEAD, not a tag. Pin the exact SHA you"
                echo "        build, and treat it as temporary until upstream tags a release." ;;
    esac
    echo
    echo "  Before building:"
    echo "   1. Install the manager from the $CANDIDATE release page (NOT a CI artifact)"
    echo "      and read its version code from the app - that is your --ksu-version-code."
    echo "   2. Build, then read the log BEFORE flashing:"
    echo "        susfs_kernelsu_integration  -> applied"
    echo "        fs/susfs.o                  -> compiled"
    echo "        image_ikconfig              -> applied, no missing symbols"
    echo "        SukiSU-Ultra version: <code> [$CANDIDATE-...]"
    echo "   3. Keep the current working boot image to hand."
    echo "   4. Update PINNED_* at the top of this script once it boots."
else
    echo "  Nothing safe to move to. Stay on the current pins:"
    echo "    --ksu-commit $PINNED_KSU_REF \\"
    echo "    --susfs-commit $PRIMARY_PIN \\"
    echo "    --ksu-version-code $PINNED_KSU_VERSION_CODE"
fi

echo
echo "  Note: a successful build is NOT evidence that SUSFS applied. patch(1) can"
echo "  leave hunks unapplied and the kernel still compiles. Check PATCH_STATUS.json."
