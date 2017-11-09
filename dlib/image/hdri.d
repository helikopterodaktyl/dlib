/*
Copyright (c) 2014-2017 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dlib.image.hdri;

private
{
    import core.stdc.string;
    import std.math;
    import dlib.core.memory;
    import dlib.image.image;
    import dlib.image.color;
    import dlib.math.vector;
    import dlib.math.utils;
}

abstract class SuperHDRImage: SuperImage
{
    override @property PixelFormat pixelFormat()
    {
        return PixelFormat.RGBA_FLOAT;
    }
}

class HDRImage: SuperHDRImage
{
    public:

    @property uint width()
    {
        return _width;
    }

    @property uint height()
    {
        return _height;
    }

    @property uint bitDepth()
    {
        return _bitDepth;
    }

    @property uint channels()
    {
        return _channels;
    }

    @property uint pixelSize()
    {
        return _pixelSize;
    }

    @property ubyte[] data()
    {
        return _data;
    }

    @property SuperImage dup()
    {
        auto res = new HDRImage(_width, _height);
        res.data[] = data[];
        return res;
    }

    SuperImage createSameFormat(uint w, uint h)
    {
        return new HDRImage(w, h);
    }

    this(uint w, uint h)
    {
        _width = w;
        _height = h;
        _bitDepth = 32;
        _channels = 4;
        _pixelSize = (_bitDepth / 8) * _channels;
        allocateData();

        //pixelCost = 1.0f / (_width * _height);
        //progress = 0.0f;
    }

    Color4f opIndex(int x, int y)
    {
        while(x >= _width) x = _width-1;
        while(y >= _height) y = _height-1;
        while(x < 0) x = 0;
        while(y < 0) y = 0;

        float r, g, b, a;
        auto dataptr = data.ptr + (y * _width + x) * _pixelSize;
        memcpy(&r, dataptr, 4);
        memcpy(&g, dataptr + 4, 4);
        memcpy(&b, dataptr + 4 * 2, 4);
        memcpy(&a, dataptr + 4 * 3, 4);
        return Color4f(r, g, b, a);
    }

    Color4f opIndexAssign(Color4f c, int x, int y)
    {
        while(x >= _width) x = _width-1;
        while(y >= _height) y = _height-1;
        while(x < 0) x = 0;
        while(y < 0) y = 0;

        auto dataptr = data.ptr + (y * _width + x) * _pixelSize;
        memcpy(dataptr, &c.arrayof[0], 4);
        memcpy(dataptr + 4, &c.arrayof[1], 4);
        memcpy(dataptr + 4 * 2, &c.arrayof[2], 4);
        memcpy(dataptr + 4 * 3, &c.arrayof[3], 4);

        return c;
    }

    protected void allocateData()
    {
        _data = new ubyte[_width * _height * _pixelSize];
    }

    void free()
    {
        // Do nothing, let GC delete the object
    }

    protected:

    uint _width;
    uint _height;
    uint _bitDepth;
    uint _channels;
    uint _pixelSize;
    ubyte[] _data;
}

SuperImage clamp(SuperImage img, float minv, float maxv)
{
    foreach(x; 0..img.width)
    foreach(y; 0..img.height)
    {
        img[x, y] = img[x, y].clamped(minv, maxv);
    }

    return img;
}

interface SuperHDRImageFactory
{
    SuperHDRImage createImage(uint w, uint h);
}

class HDRImageFactory: SuperHDRImageFactory
{
    SuperHDRImage createImage(uint w, uint h)
    {
        return new HDRImage(w, h);
    }
}

private SuperHDRImageFactory _defaultHDRImageFactory;

SuperHDRImageFactory defaultHDRImageFactory()
{
    if (!_defaultHDRImageFactory)
        _defaultHDRImageFactory = new HDRImageFactory();
    return _defaultHDRImageFactory;
}

class UnmanagedHDRImage: HDRImage
{
    override @property SuperImage dup()
    {
        auto res = New!(UnmanagedHDRImage)(_width, _height);
        res.data[] = data[];
        return res;
    }

    override SuperImage createSameFormat(uint w, uint h)
    {
        return New!(UnmanagedHDRImage)(w, h);
    }

    this(uint w, uint h)
    {
        super(w, h);
    }

    ~this()
    {
        Delete(_data);
    }

    protected override void allocateData()
    {
        _data = New!(ubyte[])(_width * _height * _pixelSize);
    }

    override void free()
    {
        Delete(this);
    }
}

class UnmanagedHDRImageFactory: SuperHDRImageFactory
{
    SuperHDRImage createImage(uint w, uint h)
    {
        return New!UnmanagedHDRImage(w, h);
    }
}

SuperImage hdrTonemapGamma(SuperHDRImage img, float gamma)
{
    return hdrTonemapGamma(img, null, gamma);
}

SuperImage hdrTonemapGamma(SuperHDRImage img, SuperImage output, float gamma)
{
    SuperImage res;
    if (output)
        res = output;
    else
        res = image(img.width, img.height, img.channels);

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        Color4f c = img[x, y];
        float r = c.r ^^ gamma;
        float g = c.g ^^ gamma;
        float b = c.b ^^ gamma;
        res[x, y] = Color4f(r, g, b, c.a);
    }

    return res;
}

SuperImage hdrTonemapReinhard(SuperHDRImage img, float exposure, float gamma)
{
    return hdrTonemapReinhard(img, null, exposure, gamma);
}

SuperImage hdrTonemapReinhard(SuperHDRImage img, SuperImage output, float exposure, float gamma)
{
    SuperImage res;
    if (output)
        res = output;
    else
        res = image(img.width, img.height, img.channels);

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        Color4f c = img[x, y];
        Vector3f v = c * exposure;
        v = v / (v + 1.0f);
        float r = v.r ^^ gamma;
        float g = v.g ^^ gamma;
        float b = v.b ^^ gamma;
        res[x, y] = Color4f(r, g, b, c.a);
    }

    return res;
}

SuperImage hdrTonemapHable(SuperHDRImage img, float exposure, float gamma)
{
    return hdrTonemapHable(img, null, exposure, gamma);
}

SuperImage hdrTonemapHable(SuperHDRImage img, SuperImage output, float exposure, float gamma)
{
    SuperImage res;
    if (output)
        res = output;
    else
        res = image(img.width, img.height, img.channels);

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        Color4f c = img[x, y];
        Vector3f v = c * exposure;
        Vector3f one = Vector3f(1.0f, 1.0f, 1.0f);
        Vector3f W = Vector3f(11.2f, 11.2f, 11.2f);
        v = hableFunc(v * 2.0f) * (one / hableFunc(W));
        float r = v.r ^^ gamma;
        float g = v.g ^^ gamma;
        float b = v.b ^^ gamma;
        res[x, y] = Color4f(r, g, b, c.a);
    }

    return res;
}

Vector3f hableFunc(Vector3f x)
{
   return ((x * (x * 0.15f + 0.1f * 0.5f) + 0.2f * 0.02f) / (x * (x * 0.15f + 0.5f) + 0.2f * 0.3f)) - 0.02f / 0.3f;
}

SuperImage hdrTonemapAverageLuminance(SuperHDRImage img, float a, float gamma)
{
    return hdrTonemapAverageLuminance(img, null, a, gamma);
}

SuperImage hdrTonemapAverageLuminance(SuperHDRImage img, SuperImage output, float a, float gamma)
{
    SuperImage res;
    if (output)
        res = output;
    else
        res = image(img.width, img.height, img.channels);

    float sumLuminance = 0.0f;

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        sumLuminance += log(EPSILON + img[x, y].luminance);        
    }

    float N = img.width * img.height;
    float lumAverage = exp(sumLuminance / N); 

    float aOverLumAverage = a / lumAverage;

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        auto col = img[x, y];
        float Lw = col.luminance;
        float L = Lw * aOverLumAverage;
        float Ld = L / (1.0f + L);
        Color4f nRGB = col / Lw;
        Color4f dRGB = nRGB * Ld;
        float r = dRGB.r ^^ gamma;
        float g = dRGB.g ^^ gamma;
        float b = dRGB.b ^^ gamma;
        res[x, y] = Color4f(r, g, b, col.a);
    }

    return res;
}

