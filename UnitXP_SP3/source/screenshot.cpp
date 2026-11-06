#include <string>
#include <sstream>
#include <random>
#include <cstdlib>
#include <cstring>
#include <utility>
#include <thread>
#include <filesystem>
#include <cstdio>

#include "screenshot.h"
#include "utf8_to_utf16.h"
#include "stb_image_write.h"
#include "Vanilla1121_functions.h"


CTGAFILE_WRITE_0x5a4810 p_CTgaFile_Write_0x5a4810 = reinterpret_cast<CTGAFILE_WRITE_0x5a4810>(0x5a4810);
CTGAFILE_WRITE_0x5a4810 p_original_CTgaFile_Write_0x5a4810 = NULL;

SCREENSHOT_FILETYPE screenshot_filetype = SCREENSHOT_FILETYPE::jpg;

static const int bpp = 3;
static const int quality = 95;

static void threadedScreenshot(uint8_t* const data, const int width, const int height, const std::string fileName, const SCREENSHOT_FILETYPE fileType) {
    // The idea of using another thread to process/write file is contributed by MarcelineVQ
    // It adds a full image copy. However as memcpy() is done in memory, it still result in better responsiveness

    {
        // Swap color channel from BGR to RGB fitting stb_image_write
        uint8_t* p = data;
        const unsigned int total = static_cast<unsigned int>(width) * static_cast<unsigned int>(height);
        for (unsigned int i = 0; i < total; ++i) {
            std::swap(p[0], p[2]);
            p += 3;
        }
    }

    if (screenshot_filetype == SCREENSHOT_FILETYPE::png) {
        stbi_write_png(fileName.c_str(), width, height, bpp, data, width * bpp);
    }
    else {
        stbi_write_jpg(fileName.c_str(), width, height, bpp, data, quality);
    }

    delete[] data;
}

int __fastcall detoured_CTgaFile_Write_0x5a4810(uint32_t self, void* ignored, char* TGAfilename) {
    uint8_t additionalHeaderLength = *reinterpret_cast<uint8_t*>(self + 0x8);
    uint8_t colorMapType = *reinterpret_cast<uint8_t*>(self + 0x9);
    uint8_t imageType = *reinterpret_cast<uint8_t*>(self + 0xa);
    uint32_t tgaByteSize = *reinterpret_cast<uint32_t*>(self + 0x3c);
    uint32_t tgaHeaderAddr = self + 0x8;
    uint32_t tgaDataAddr = *reinterpret_cast<uint32_t*>(self + 0x4);
    uint32_t tgaFooterAddr = self + 0x20;

    if (tgaDataAddr == NULL || TGAfilename == NULL || imageType != 2 || additionalHeaderLength != 0 || colorMapType != 0) {
        return p_original_CTgaFile_Write_0x5a4810(self, TGAfilename);
    }

    namespace fs = std::filesystem;

    fs::path screenshotDirectory{};
    fs::path screenshotFilename{};
    {
        fs::path tgaPath(TGAfilename);
        if (tgaPath.has_parent_path() && tgaPath.has_stem()) {
            screenshotDirectory = tgaPath.parent_path();
            screenshotFilename = tgaPath.stem();
        }
        else {
            return p_original_CTgaFile_Write_0x5a4810(self, TGAfilename);
        }
    }

    // Add a counter component to the filename
    // so that the player can have multiple screenshots in the same second
    {
        screenshotFilename += "_";

        static int counter = 0;
        counter++;
        if (counter > 999) {
            counter = 1;
        }

        std::stringstream ss{};
        ss << std::setw(3) << std::setfill('0') << counter;

        screenshotFilename += ss.str();
    }

    fs::path writeTo{};
    {
        if (screenshot_filetype == SCREENSHOT_FILETYPE::png) {
            screenshotFilename += ".png";
        }
        else {
            screenshotFilename += ".jpg";
        }
        writeTo = screenshotDirectory / screenshotFilename;
    }

    uint16_t width = *reinterpret_cast<uint16_t*>(tgaHeaderAddr + 0xc);
    uint16_t height = *reinterpret_cast<uint16_t*>(tgaHeaderAddr + 0xc + 2);
    size_t s = static_cast<size_t>(bpp) * static_cast<size_t>(width) * static_cast<size_t>(height);

    uint8_t* data = new (std::nothrow)uint8_t[s];
    if (data == nullptr) {
        return p_original_CTgaFile_Write_0x5a4810(self, TGAfilename);
    }
    std::memcpy(data, reinterpret_cast<void*>(tgaDataAddr), s);

    try {
        std::thread t(threadedScreenshot, data, width, height, writeTo.u8string(), screenshot_filetype);
        if (t.joinable()) {
            t.detach();
        }
    }
    catch (...) {
        delete[] data;
        return p_original_CTgaFile_Write_0x5a4810(self, TGAfilename);
    }

    // We don't wait for the new thread to work so we don't know the result. Return 1 anyway.
    return 1;
}
