// ---------------------------------------------- render settings

#define RENDER_RESOLUTION_X 80
#define RENDER_RESOLUTION_Y 25
#define RENDER_PIXEL_PERFECT false

// ---------------------------------------------- sound settings

#define SOUND_DAC //it says that we are going to use DAC for audio output. please comment if you don't need audio output
#define SOUND_MASTER_VOLUME 16 //0-255
#define SOUND_FREQ 40000 //how often will the hardware timer responsible for sound generation work
#define SOUND_OUTPUT 0 //DAC CHANNEL

// ---------------------------------------------- leds settings (all leds are optional, comment the define that you don't need)

#define LEDS_POWER_PIN 18 //optional
#define LEDS_POWER_INVERT false

#define LEDS_ERROR_ALIAS_POWER //the error LED can be assigned to the same physical LED as the power
//#define LEDS_ERROR_PIN 17 //optional
//#define LEDS_ERROR_INVERT false
//#define LEDS_ERROR_NO_BLINK //uncomment if your LED is blinking on its own

#define LEDS_LED_HDD_PIN 19 //optional
#define LEDS_HDD_INVERT false

// ---------------------------------------------- hardware settings

//implements power self-locking. you can make a non-locking button that turns on the device and add a relay or transistor that supplies power and is opened by a control signal from the microcontroller. in this case, when calling computer.shutdown the power supply is physically cut off.
#define HARDWARE_POWERLOCK 32 //optional
//select the operating modes of the self-locking power. what will be the value for a specific trigger condition. VOID (pin is hanging in the air) HIGH or LOW
#define HARDWARE_POWERLOCK_LOCKED_MODE   PL_MODE_LOW  //when turned on, the pin will be connected to the ground
#define HARDWARE_POWERLOCK_UNLOCKED_MODE PL_MODE_VOID //when the power is turned off, the pin will hang in the air.

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

#define TOUCHSCREEN_MUL_X 0 // if 0, it is counted as 1
#define TOUCHSCREEN_MUL_Y 0

#define TOUCHSCREEN_FLIP_X    false
#define TOUCHSCREEN_FLIP_Y    false
#define TOUCHSCREEN_SWAP_XY   false
#define TOUCHSCREEN_ROTATION  1
#define TOUCHSCREEN_OFFSET_X  0
#define TOUCHSCREEN_OFFSET_Y  0