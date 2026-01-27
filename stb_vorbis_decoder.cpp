/*
** stb_vorbis_decoder.cpp
** OGG Vorbis decoder using stb_vorbis
**
** Uses Sean Barrett's public domain stb_vorbis decoder
** https://github.com/nothings/stb
*/

#include "decoder/stb_vorbis_decoder.h"
#include "zmusic/fileio.h"

// Configure stb_vorbis before including
#define STB_VORBIS_NO_STDIO
#define STB_VORBIS_NO_PUSHDATA_API
#include "../thirdparty/stb_vorbis.c"

StbVorbisDecoder::~StbVorbisDecoder()
{
    if (Vorbis)
    {
        stb_vorbis_close(Vorbis);
        Vorbis = nullptr;
    }
}

bool StbVorbisDecoder::open(MusicIO::FileInterface *reader)
{
    // Read entire file into memory (stb_vorbis needs the whole file)
    long fileLen = reader->filelength();
    if (fileLen <= 0)
        return false;

    FileData.resize(fileLen);
    reader->seek(0, SEEK_SET);
    long bytesRead = reader->read(FileData.data(), fileLen);
    if (bytesRead != fileLen)
        return false;

    // Check OGG signature
    if (fileLen < 4 || FileData[0] != 'O' || FileData[1] != 'g' || FileData[2] != 'g' || FileData[3] != 'S')
        return false;

    int error = 0;
    Vorbis = stb_vorbis_open_memory(FileData.data(), (int)FileData.size(), &error, nullptr);
    if (!Vorbis)
        return false;

    stb_vorbis_info info = stb_vorbis_get_info(Vorbis);
    SampleRate = info.sample_rate;
    Channels = info.channels;
    TotalSamples = stb_vorbis_stream_length_in_samples(Vorbis);

    // Only support mono and stereo
    if (Channels != 1 && Channels != 2)
    {
        stb_vorbis_close(Vorbis);
        Vorbis = nullptr;
        return false;
    }

    reader->close();  // We've copied the data, don't need the reader anymore
    return true;
}

void StbVorbisDecoder::getInfo(int *samplerate, ChannelConfig *chans, SampleType *type)
{
    *samplerate = SampleRate;
    *chans = (Channels == 2) ? ChannelConfig_Stereo : ChannelConfig_Mono;
    *type = SampleType_Int16;
}

size_t StbVorbisDecoder::read(char *buffer, size_t bytes)
{
    if (!Vorbis)
        return 0;

    // stb_vorbis_get_samples_short_interleaved returns number of samples per channel
    int numFrames = (int)(bytes / (Channels * sizeof(short)));
    int framesRead = stb_vorbis_get_samples_short_interleaved(Vorbis, Channels, (short*)buffer, numFrames * Channels);
    return framesRead * Channels * sizeof(short);
}

bool StbVorbisDecoder::seek(size_t ms_offset, bool ms, bool /*mayrestart*/)
{
    if (!Vorbis)
        return false;

    unsigned int sample_offset;
    if (ms)
        sample_offset = (unsigned int)((double)ms_offset / 1000.0 * SampleRate);
    else
        sample_offset = (unsigned int)ms_offset;

    return stb_vorbis_seek(Vorbis, sample_offset) != 0;
}

size_t StbVorbisDecoder::getSampleOffset()
{
    if (!Vorbis)
        return 0;
    return stb_vorbis_get_sample_offset(Vorbis);
}

size_t StbVorbisDecoder::getSampleLength()
{
    return TotalSamples;
}
