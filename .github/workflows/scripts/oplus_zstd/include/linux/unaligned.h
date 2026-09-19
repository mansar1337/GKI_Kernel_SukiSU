/* Project-created compat shim: include/linux/unaligned.h does not exist on
 * 5.15 (it appeared upstream later). The zstd sources include it for
 * get/put_unaligned and the le/be variants - all provided on 5.15 via
 * <asm/unaligned.h> (auto-generated from asm-generic/unaligned.h), which
 * is exactly what upstream's own linux/unaligned.h wraps on newer trees.
 * Resolved through this module's -I$(srctree)/drivers/oplus_zstd/include
 * ccflag, so the 54 vendored zstd files stay byte-identical.
 */
#ifndef _OPLUS_LINUX_UNALIGNED_H
#define _OPLUS_LINUX_UNALIGNED_H

#include <asm/unaligned.h>

#endif /* _OPLUS_LINUX_UNALIGNED_H */
