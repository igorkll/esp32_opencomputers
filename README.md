# ESP32 - opencomputer emulator
* emulates opencomputers on esp32
* the original opencomputers font
* sound is supported
* support screen backlight control via screen.turnOff / screen.turnOn
* screen.getAspectRatio returns the actual aspect ratio of the display

## warnings
* the project can only be compiled by the GCC compiler
* you need an esp32 with external memory (PSRAM/SPIRAM) or a large amount of HEAP in order for you to have enough memory for lua. otherwise, you can forget about running any operating system

## additional functions
* computer.print - alias to standard print in lua. it is needed to output information to the microcontroller debugging console

## configuration a project
1. open esp32_opencomputers/main/hal.h - set up the display and touch screen pins
2. you may need to change the code in open esp32_opencomputers/main/hal.c to work with your hardware (for example, a display with a different touchscreen or a different matrix controller)
3. place the files of the desired operating system in the "esp32_opencomputers/filesystem/system" folder (you can take one to choose from from the "operating_systems" folder)
4. flash the code into the microcontroller and connect all the peripherals according to the settings in esp32_opencomputers/main/hal.h

## available components
* eeprom
* screen
* filesystem
* keyboard
* gpu