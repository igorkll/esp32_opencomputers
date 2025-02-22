#include "functions.h"
#include <math.h>

int nRound(float num) {
    return (int)(num < 0 ? (num - 0.5) : (num + 0.5));
}

float clamp(float n, float lower, float upper) {
    return fmax(lower, fmin(n, upper));
}


int map(int value, int low, int high, int low_2, int high_2) {
    return fmap(value, low, high, low_2, high_2);
}

float fmap(float value, float low, float high, float low_2, float high_2) {
    float relative_value = (value - low) / (high - low);
    float scaled_value = low_2 + (high_2 - low_2) * relative_value;
    return scaled_value;
}

int rmap(int value, int low, int high, int low_2, int high_2) {
    return nRound(fmap(value, low, high, low_2, high_2));
}