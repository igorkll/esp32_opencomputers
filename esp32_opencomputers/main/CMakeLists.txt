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

fatfs_create_spiflash_image(storage ../filesystem FLASH_IN_PROJECT)