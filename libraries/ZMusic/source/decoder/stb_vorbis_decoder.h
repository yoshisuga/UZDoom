#ifndef STB_VORBIS_DECODER_H
#define STB_VORBIS_DECODER_H

#include "zmusic/sounddecoder.h"

struct stb_vorbis;

class StbVorbisDecoder : public SoundDecoder
{
public:
    virtual ~StbVorbisDecoder();
    virtual bool open(MusicIO::FileInterface *reader) override;
    virtual void getInfo(int *samplerate, ChannelConfig *chans, SampleType *type) override;
    virtual size_t read(char *buffer, size_t bytes) override;
    virtual bool seek(size_t ms_offset, bool ms, bool mayrestart) override;
    virtual size_t getSampleOffset() override;
    virtual size_t getSampleLength() override;

private:
    stb_vorbis *Vorbis = nullptr;
    std::vector<uint8_t> FileData;
    int SampleRate = 0;
    int Channels = 0;
    unsigned int TotalSamples = 0;
};

#endif // STB_VORBIS_DECODER_H
