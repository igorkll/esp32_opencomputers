#include <esp_vfs.h>
#include <esp_vfs_fat.h>
#include "filesystem.h"

void filesystem_init() {
	static wl_handle_t s_wl_handle = WL_INVALID_HANDLE;
    esp_vfs_fat_mount_config_t storage_mount_config = {
        .max_files = 4,
        .format_if_mount_failed = false,
        .allocation_unit_size = CONFIG_WL_SECTOR_SIZE
    };

    ESP_ERROR_CHECK(esp_vfs_fat_spiflash_mount_rw_wl("/storage", "storage", &storage_mount_config, &s_wl_handle));
}