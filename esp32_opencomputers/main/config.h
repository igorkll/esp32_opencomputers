// ---------------------------------------------- render settings

#define RENDER_RESOLUTION_X 80
#define RENDER_RESOLUTION_Y 25
#define RENDER_PIXEL_PERFECT false

// ---------------------------------------------- control settings

//allows you to simulate right-click when long-pressing on the touchscreen
#define CONTROL_SECONDARY_PRESS_ON_LONG_TOUCH_TIME 1 //optional

// ---------------------------------------------- environment settings

#define ENV_EEPROM_SIZE     32 * 1024
#define ENV_EEPROM_DATASIZE 4 * 1024
#define ENV_EEPROM_READONLY true

#define ENV_KEYBOARD_ENABLED false

// ---------------------------------------------- bsod settings

#define BSOD_RESOLUTION_X 50
#define BSOD_RESOLUTION_Y 16
#define BSOD_COLOR_BG       0x0000ff
#define BSOD_COLOR_TEXT     0xffffff
#define BSOD_COLOR_TITLE_BG 0xffffff
#define BSOD_COLOR_TITLE    0x0000ff

// ---------------------------------------------- sound settings

#define SOUND_DAC //it says that we are going to use DAC for audio output. please comment if you don't need audio output
#define SOUND_MASTER_VOLUME 16 //0-255
#define SOUND_FREQ 40000 //how often will the hardware timer responsible for sound generation work
#define SOUND_OUTPUT 0 //DAC CHANNEL

// ---------------------------------------------- leds settings (all leds are optional, comment the define that you don't need)

#define LEDS_POWER_PIN 18 //optional
#define LEDS_POWER_INVERT false
#define LEDS_POWER_LIGHT_ON  100 //0-255
#define LEDS_POWER_LIGHT_OFF 0   //0-255

#define LEDS_ERROR_ALIAS_POWER //the error LED can be assigned to the same physical LED as the power
//#define LEDS_ERROR_PIN 17 //optional
//#define LEDS_ERROR_INVERT false
//#define LEDS_ERROR_NO_BLINK //uncomment if your LED is blinking on its own
//#define LEDS_ERROR_LIGHT_ON  200 //0-255
//#define LEDS_ERROR_LIGHT_OFF 0   //0-255

#define LEDS_HDD_PIN 19 //optional
#define LEDS_HDD_INVERT false
#define LEDS_HDD_LIGHT_ON  24  //0-255
#define LEDS_HDD_LIGHT_OFF 0   //0-255

// ---------------------------------------------- power settings

//implements power self-locking. you can make a non-locking button that turns on the device and add a relay or transistor that supplies power and is opened by a control signal from the microcontroller. in this case, when calling computer.shutdown the power supply is physically cut off.
#define POWER_POWERLOCK 32 //optional
//select the operating modes of the self-locking power. what will be the value for a specific trigger condition. VOID (pin is hanging in the air) HIGH or LOW
//if you have implemented the self-locking of the power supply in a different way (for example, using a relay), you can set other states for the locked and unlocked power supply
#define POWER_POWERLOCK_LOCKED_MODE   PL_MODE_LOW  //when turned on, the pin will be connected to the ground
#define POWER_POWERLOCK_UNLOCKED_MODE PL_MODE_VOID //when the power is turned off, the pin will hang in the air.

//if this option is enabled, then when power is applied to the microcontroller, the emulated computer will be in the off state
//this can be useful if your device does not have a self-locking power supply, but has a physical power switch and a power button
//this option should not be used with a self-locking power supply, because when the emulated computer is turned off, the self-locking power supplies are in the UNLOCKED state
#define POWER_DEFAULT_DISABLED false

// ---------------------------------------------- button settings (all buttons are optional, comment the define that you don't need)

#define BUTTON_DEBOUNCE 100
#define BUTTON_HOLDTIME 1000

//starts the emulated computer if it was turned off, shutdown with an error, or has not yet been turned on (the POWER_DEFAULT_DISABLED option is enabled)
//if you are using a self-locking power supply, then assemble the circuit so that this button also activates a transistor or relay to supply power to the microcontroller
#define BUTTON_WAKEUP_PIN 34
#define BUTTON_WAKEUP_INVERT true
#define BUTTON_WAKEUP_NEEDHOLD false
#define BUTTON_WAKEUP_PULL PULL_NONE

//it turns off the computer when triggered
#define BUTTON_SHUTDOWN_ALIAS_WAKEUP
//#define BUTTON_SHUTDOWN_PIN 34
//#define BUTTON_SHUTDOWN_INVERT true
//#define BUTTON_SHUTDOWN_NEEDHOLD false
//#define BUTTON_SHUTDOWN_PULL PULL_NONE

//when triggered, it restarts the computer. it works when the computer is turned on or off with an error
#define BUTTON_REBOOT_PIN 35
#define BUTTON_REBOOT_INVERT true
#define BUTTON_REBOOT_NEEDHOLD true
#define BUTTON_REBOOT_PULL PULL_NONE

// ---------------------------------------------- display settings

#define DISPLAY_FREQ 80000000
#define DISPLAY_HOST SPI2_HOST
#define DISPLAY_MISO 12 //optional
#define DISPLAY_MOSI 13
#define DISPLAY_CLK  14
#define DISPLAY_DC   21
#define DISPLAY_CS   22 //optional
#define DISPLAY_RST  33 //optional. comment if you connected this pin to the microcontroller RST
#define DISPLAY_BL   4  //optional

#define DISPLAY_WIDTH   480
#define DISPLAY_HEIGHT  320

#define DISPLAY_SWAP_ENDIAN  true
#define DISPLAY_SWAP_RGB     true
#define DISPLAY_INVERT       true
#define DISPLAY_INVERT_BL    false

#define DISPLAY_FLIP_X    true
#define DISPLAY_FLIP_Y    false
#define DISPLAY_SWAP_XY   false
#define DISPLAY_ROTATION  1
#define DISPLAY_OFFSET_X  0
#define DISPLAY_OFFSET_Y  0

// ---------------------------------------------- touchscreen settings

#define TOUCHSCREEN_FT6336U
#define TOUCHSCREEN_SDA   5
#define TOUCHSCREEN_SCL   27
#define TOUCHSCREEN_HOST  I2C_NUM_0
#define TOUCHSCREEN_ADDR  0x38
#define TOUCHSCREEN_RST   23 //optional

#define TOUCHSCREEN_WIDTH   320 //required parameters. the width and height of the touchscreen in pixels
#define TOUCHSCREEN_HEIGHT  480

#define TOUCHSCREEN_MUL_X 1
#define TOUCHSCREEN_MUL_Y 1

#define TOUCHSCREEN_FLIP_X    false
#define TOUCHSCREEN_FLIP_Y    false
#define TOUCHSCREEN_SWAP_XY   false
#define TOUCHSCREEN_ROTATION  1
#define TOUCHSCREEN_OFFSET_X  0
#define TOUCHSCREEN_OFFSET_Y  0

// ---------------------------------------------- keyboard settings

//keyboard input methods have not been implemented yet

// ---------------------------------------------- other

//why is there a delay?
//the fact is that after flashing the controller, it starts immediately, and the esp-idf port monitor opens immediately.
//the esp-idf port monitor reboots the controller, and sometimes this happened exactly at the time of writing to fatfs
//which in turn sometimes leads to fatfs being broken
//the delay is triggered only at the first initialization after the firmware, which gives time to start the port monitor so that a reboot does not occur during writing
#define FIRST_INIT_DELAY 1000 //optional