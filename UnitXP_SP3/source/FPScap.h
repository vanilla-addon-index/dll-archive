#pragma once

#include <cstdint>
#include <string>

void FPScap();

void initFPScap();
void endFPScap();
std::string debugFPScap();

extern LARGE_INTEGER targetFrameInterval;
extern LARGE_INTEGER backgroundFrameInterval;
