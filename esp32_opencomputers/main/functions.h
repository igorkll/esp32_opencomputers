#pragma once

#define max(a,b) (((a) > (b)) ? (a) : (b))
#define min(a,b) (((a) < (b)) ? (a) : (b))

int nRound(float num);
float clamp(float n, float lower, float upper);

int map(int value, int low, int high, int low_2, int high_2);
float fmap(float value, float low, float high, float low_2, float high_2);
int rmap(int value, int low, int high, int low_2, int high_2);