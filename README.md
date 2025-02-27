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

## warnings
* the project can only be compiled by the GCC compiler
* you need an esp32 with external memory (PSRAM/SPIRAM) or a large amount of HEAP in order for you to have enough memory for lua. otherwise, you can forget about running any operating system
* the project was designed to work with the display on the st77xx controller. if you have a display with another controller, then you need to edit the esp32_opencomputers/main/hal.c file for your display

## additional functions
* computer.print - alias to standard print in lua. it is needed to output information to the microcontroller debugging console

## configuration a project
1. open esp32_opencomputers/main/config.h - set up the display, touchscreen and other project settings (do not change your SPI pins if you do not know what you are doing!!)
2. you may need to change the code in open esp32_opencomputers/main/hal.c to work with your hardware (for example, a display with a different touchscreen or a different controller)
3. place the files of the desired operating system in the "esp32_opencomputers/filesystem/system" folder (you can take one to choose from from the "operating_systems" folder)
4. flash the code into the microcontroller and connect all the peripherals according to the settings in esp32_opencomputers/main/config.h

## available components
* eeprom
* screen
* filesystem
* keyboard
* gpu
* beep (beep card from the computronics addon)