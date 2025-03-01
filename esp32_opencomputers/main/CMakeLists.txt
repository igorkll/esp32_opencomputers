file(GLOB_RECURSE FILES "*.c")
file(GLOB_RECURSE LUA_FILES "../lua/src/*.c")
file(GLOB_RECURSE MAP_FILES "../c-hashmap/*.c")

idf_component_register(
	SRCS
		${FILES}
		${LUA_FILES}
		${MAP_FILES}

    INCLUDE_DIRS
		"."
		"../lua/src"
		"../c-hashmap"
)

if(EXISTS "../storage")
	fatfs_create_spiflash_image(storage ../storage FLASH_IN_PROJECT)
else()
	fatfs_create_spiflash_image(storage ../other/defaultStorage FLASH_IN_PROJECT)
endif()
spiffs_create_partition_image(rom ../rom FLASH_IN_PROJECT)