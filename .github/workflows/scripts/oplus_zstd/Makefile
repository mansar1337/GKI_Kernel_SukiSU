# Adapted from OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8850
# branch oneplus/sm8850_b_16.0.0_oneplus_15, path vendor/oplus/kernel/mm/zstd_o/Makefile.
# Object list verbatim; only the ccflags include path is adjusted from
# mm/oplus_mm/hybridswap_zram/zstd_o/include to our drivers/oplus_zstd/include.
# (Upstream has no Kconfig for this tree - it builds unconditionally via Bazel;
# see ../oplus_zstd/Kconfig, project-created.)

obj-$(CONFIG_CRYPTO_ZSTDN) += crypto_zstdn_o.o

ccflags-y  += -I$(srctree)/drivers/oplus_zstd/include
# PORTING ADDITION (this project): the helper objects below (xxhash,
# entropy_common, fse_decompress, ...) define globals that also exist in
# the in-tree lib/xxhash.o and lib/zstd/*.o. Built-in (=y) that is a
# fatal duplicate-symbol at vmlinux link; as a module (=m, like upstream
# OP15's own DDK build) it would instead fail at insmod against the
# in-tree lib/xxhash exports. -fvisibility=hidden keeps every helper
# module-local so neither link nor load can collide.
ccflags-y  += -fvisibility=hidden
crypto_zstdn_o-y := \
		crypto_zstd.o \
		zstd_compress_module.o \
		xxhash.o \
		common/debug.o \
		common/entropy_common.o \
		common/error_private.o \
		common/fse_decompress.o \
		common/zstd_common.o \
		compress/fse_compress.o \
		compress/hist.o \
		compress/huf_compress.o \
		compress/zstd_compress.o \
		compress/zstd_compress_literals.o \
		compress/zstd_compress_sequences.o \
		compress/zstd_compress_superblock.o \
		compress/zstd_double_fast.o \
		compress/zstd_fast.o \
		compress/zstd_lazy.o \
		compress/zstd_ldm.o \
		compress/zstd_opt.o \
		zstd_decompress_module.o \
		decompress/huf_decompress.o \
		decompress/zstd_ddict.o \
		decompress/zstd_decompress.o \
		decompress/zstd_decompress_block.o
