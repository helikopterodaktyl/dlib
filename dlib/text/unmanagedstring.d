/*
Copyright (c) 2018-2020 Timur Gafarov

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

module dlib.text.unmanagedstring;

import dlib.core.memory;
import dlib.container.array;
import dlib.text.utf8;
import dlib.coding.hash;
import dlib.core.stream;

/*
    GC-free UTF8 string type based on DynamicArray.
    Stores up to 128 bytes without dynamic memory allocation,
    so short strings are processed very fast.
    String is always zero-terminated and directly compatible with C.
 */
struct String
{  
    DynamicArray!(char, 128) data;
    
    private void addZero()
    {
        data.insertBack('\0');
    }
    
    private void removeZero()
    {
        data.removeBack(1);
    }

    // Construct from D string
    this(string s)
    {
        data.insertBack(s);
        addZero();
    }

    // Construct from zero-terminated C string (ASCII or UTF8)
    this(const(char)* cStr)
    {
        size_t offset = 0;
        while(cStr[offset] != 0)
        {
            offset++;
        }
        if (offset > 0)
            data.insertBack(cStr[0..offset]);
        addZero();
    }

    // Construct from zero-terminated UTF-16 string
    this(const(wchar)* wStr)
    {
        wchar* utf16 = cast(wchar*)wStr;
        wchar utf16char;
        do
        {
            utf16char = *wStr;
            utf16++;

            if (utf16char)
            {
                if (utf16char < 0x80)
                {
                    data.insertBack((utf16char >> 0 & 0x7F) | 0x00);
                }
                else if (utf16char < 0x0800)
                {
                    data.insertBack((utf16char >> 6 & 0x1F) | 0xC0);
                    data.insertBack((utf16char >> 0 & 0x3F) | 0x80);
                }
                else if (utf16char < 0x010000)
                {
                    data.insertBack((utf16char >> 12 & 0x0F) | 0xE0);
                    data.insertBack((utf16char >> 6 & 0x3F) | 0x80);
                    data.insertBack((utf16char >> 0 & 0x3F) | 0x80);
                }
                else if (utf16char < 0x110000)
                {
                    data.insertBack((utf16char >> 18 & 0x07) | 0xF0);
                    data.insertBack((utf16char >> 12 & 0x3F) | 0x80);
                    data.insertBack((utf16char >> 6 & 0x3F) | 0x80);
                    data.insertBack((utf16char >> 0 & 0x3F) | 0x80);
                }
            }
        }
        while(utf16char);
        addZero();
    }

    void free()
    {
        data.free();
    }

    auto opOpAssign(string op)(string s) if (op == "~")
    {
        removeZero();
        data.insertBack(s);
        addZero();
        return this;
    }

    auto opOpAssign(string op)(char c) if (op == "~")
    {
        removeZero();
        data.insertBack(c);
        addZero();
        return this;
    }

    auto opOpAssign(string op)(String s) if (op == "~")
    {
        String s1 = this;
        s1.removeZero();
        s1 ~= s;
        s1.addZero();
        return s1;
    }

    void reserve(size_t amount)
    {
        data.reserve(amount);
    }

    @property size_t length()
    {
        if (data.length == 0)
            return 0;
        else
            return data.length - 1;
    }

    @property string toString()
    {
        if (data.length == 0)
            return "";
        else 
            return cast(string)data.data[0..$-1];
    }

    alias toString this;

    @property char* ptr()
    {
        return data.data.ptr;
    }

    deprecated("use String.ptr instead") @property char* cString()
    {
        return ptr();
    }

    @property bool isDynamic()
    {
        return data.dynamicStorage.length > 0;
    }

    // Range interface that iterates the string by Unicode code point (dchar),
    // i.e., foreach(dchar c; str.byDChar)
    auto byDChar()
    {
        return UTF8Decoder(toString()).byDChar;
    }

    // Creates a String and fills it with the data from an InputStream
    static String fromStream(InputStream istrm)
    {
        String s;
        s.data.resize(cast(size_t)istrm.size, 0);
        istrm.fillArray(s.data.data);
        s.addZero();
        istrm.setPosition(0);
        return s;
    }
}

unittest
{
    String s = "hello";
    s ~= ", world";
    s ~= '!';
    assert(!s.isDynamic);
    string dStr = s;
    assert(dStr == "hello, world!");
    s.free();
    assert(s.length == 0);
}
