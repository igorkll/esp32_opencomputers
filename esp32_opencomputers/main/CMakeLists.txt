file(GLOB_RECURSE FILES "*.c")
file(GLOB_RECURSE LUA_FILES "../lua/src/*.c")

idf_component_register(
	SRCS
		${FILES}
		${LUA_FILES}

    INCLUDE_DIRS
		"."
		"../lua/src"
)

fatfs_create_spiflash_image(storage ../filesystem FLASH_IN_PROJECT)