# ESP32 - opencomputers emulator
* emulates opencomputers on esp32
* the original opencomputers font
* sound is supported
* support screen backlight control via screen.turnOff / screen.turnOn
* screen.getAspectRatio returns the actual aspect ratio of the display
* all work with esp-idf is done in the "hal.h" and "hal.c" files so that the code can be easily adapted to different platforms and peripherals
* supports unicode
* to simulate the right mouse button, use a long press at one point of the screen
* computer case LEDs are supported
* a large number of settings in config.h
* hardware on/off/reboot buttons are supported
* self-locking power is supported
* the UUIDs of all components are randomly generated when the device is turned on for the first time
* screen precise mode is supported

## in development
* noise card
* sound card
* tape drive
* note block
* iron note block
* modem (via bluetooth)
* internet (via wifi)
* BIOS time setting menu
* the menu for connecting to wifi networks in the BIOS
* wide characters
* keyboard input methods
* gpu video ram buffers

## recommended components
* esp32 with PSRAM: https://aliexpress.ru/item/1005004571486357.html
* 480x320 display (with capacitive touchscreen): https://aliexpress.ru/item/1005008428462644.html

## recommended display resolutions
* 50 x 16 - 400 x 256 (480 x 320)
* 80 x 25 - 640 x 400 (640 x 480)
* 160 x 50 - 1280 x 800

## paths
* /operating_systems - just a few operating systems as an example for an emulator
* /esp32_opencomputers/main/config.h - project configuration
* /esp32_opencomputers/storage/system - disk contents by default (optional)
* /esp32_opencomputers/storage/eeprom.lua - override the default EEPROM content (optional)
* /esp32_opencomputers/storage/eeprom.dat - override the default EEPROM data (optional)
* /esp32_opencomputers/storage/eeprom.lbl - override the default EEPROM label (optional)

## warnings
* the project can only be compiled by the GCC compiler
* you need an esp32 with external memory (PSRAM/SPIRAM) or a large amount of HEAP in order for you to have enough memory
* the project was designed to work with the display on the st77xx controller. if you have a display with another controller, then you need to edit the esp32_opencomputers/main/hal.c file for your display

## configuration a project
1. open esp32_opencomputers/main/config.h - set up the display, touchscreen and other project settings (do not change your SPI pins if you do not know what you are doing!!)
2. you may need to change the code in open esp32_opencomputers/main/hal.c to work with your hardware (for example, a display with a different touchscreen or a different controller)
3. place the files of the desired operating system in the "esp32_opencomputers/storage/system" folder (you can take one to choose from from the "operating_systems" folder)
4. flash the code into the microcontroller and connect all the peripherals according to the settings in esp32_opencomputers/main/config.h

## additional functions (device component)
* device.print(...) - alias to standard print in lua. it is needed to output information to the debugging console
* device.setTime(now:number) - sets a new RTC time
* device.getInternalDiskAddress():string - returns the address of the device's internal disk (regardless of where the boot is from)

## available components
* device (this component is added by the emulator, it contains the emulator API)
* eeprom
* screen
* filesystem
* keyboard (it is conditionally supported, but the input methods have not yet been implemented)
* gpu
* beep (beep card from the computronics addon)