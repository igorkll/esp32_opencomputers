#define SOUND_CHANNEL_BEEP 0
#define SOUND_CHANNEL_TAPE 1
#define SOUND_CHANNEL_BEEPCARD 2
#define SOUND_CHANNEL_NOISECARD 2 + 8
#define SOUND_CHANNEL_SOUNDCARD 2 + 8 + 8

// ---------------------------------------------- computer beep

void sound_computer_beep(uint16_t freq, float time);
void sound_computer_beepString(const char* text, size_t len);

// ---------------------------------------------- beep card

void sound_beep_addBeep(uint16_t freq, float time);
void sound_beep_beep();
int sound_beep_getBeepCount();