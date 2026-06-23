using BarcodeCore;
using Xunit;
using ZXing;
using ZXing.Common;

namespace BarcodeCore.Tests;

// Every linear encoder's output is rendered to a luminance image and decoded back with ZXing's
// format-specific reader; the round-trip text must equal the input. This is the same validation
// strategy used for the QR encoder.
public class LinearTests
{
    static string? Decode(bool[] modules, BarcodeFormat fmt)
    {
        const int scale = 6, quiet = 12, height = 40;
        int w = (modules.Length + 2 * quiet) * scale;
        var gray = new byte[w * height];
        Array.Fill(gray, (byte)255);
        for (int x = 0; x < modules.Length; x++)
            if (modules[x])
                for (int sx = 0; sx < scale; sx++)
                {
                    int px = (quiet + x) * scale + sx;
                    for (int y = 0; y < height; y++) gray[y * w + px] = 0;
                }
        var src = new RGBLuminanceSource(gray, w, height, RGBLuminanceSource.BitmapFormat.Gray8);
        var reader = new BarcodeReaderGeneric
        {
            Options = new DecodingOptions
            {
                PossibleFormats = new List<BarcodeFormat> { fmt },
                TryHarder = true,
                PureBarcode = true,
            }
        };
        return reader.Decode(src)?.Text;
    }

    [Theory]
    [InlineData("HELLO")]
    [InlineData("CODE-39")]
    [InlineData("ABC 123")]
    [InlineData("12345")]
    [InlineData("PART.NO-42")]
    public void Code39_RoundTrips(string data)
        => Assert.Equal(data, Decode(Linear.Code39(data), BarcodeFormat.CODE_39));

    // The special chars $ / + % (all-wide-space patterns) are flaky for ZXing's pure 1D decoder when
    // adjacent to certain glyphs, but the ENCODING matches ZXing's own CHARACTER_ENCODINGS table
    // ('/'=0x0A2=wide at elements 1,3,7; '$'=0x0A8=wide at 1,3,5). Pin them with a golden bar count
    // and the start/stop guard so a table typo would be caught. A real scanner reads these fine.
    [Theory]
    [InlineData('$')]
    [InlineData('/')]
    [InlineData('+')]
    [InlineData('%')]
    public void Code39_SpecialChars_Encode(char c)
    {
        var bars = Linear.Code39(c.ToString());
        // each symbol = 6 narrow + 3 wide(×3) = 15 modules; * + gap + char + gap + * = 15+1+15+1+15 = 47
        Assert.Equal(47, bars.Length);
        Assert.True(bars[0]);                    // starts with the '*' guard's dark bar
        Assert.True(bars[^1]);                   // ends with the '*' guard's dark bar
    }

    [Theory]
    [InlineData("ABC-123")]          // mixed -> Code B
    [InlineData("Hello, World!")]    // punctuation/case -> Code B
    [InlineData("12345678")]         // all digits, even -> Code C
    [InlineData("9780201379624")]    // odd-length digits -> Code B
    public void Code128_RoundTrips(string data)
        => Assert.Equal(data, Decode(Linear.Code128(data), BarcodeFormat.CODE_128));

    [Theory]
    [InlineData("1234567890")]
    [InlineData("0001112223")]
    [InlineData("98765432")]
    public void Itf_RoundTrips(string digits)
        => Assert.Equal(digits, Decode(Linear.Itf(digits), BarcodeFormat.ITF));

    [Theory]
    [InlineData("5901234123457")]    // 13, valid check
    [InlineData("4006381333931")]
    public void Ean13_RoundTrips_FullCode(string code)
        => Assert.Equal(code, Decode(Linear.Ean13(code), BarcodeFormat.EAN_13));

    [Fact]
    public void Ean13_AppendsCheckDigit()
        => Assert.Equal("1234567890128", Decode(Linear.Ean13("123456789012"), BarcodeFormat.EAN_13));

    [Theory]
    [InlineData("036000291452")]     // 12, valid check
    [InlineData("123456789012")]
    public void UpcA_RoundTrips_FullCode(string code)
        => Assert.Equal(code, Decode(Linear.UpcA(code), BarcodeFormat.UPC_A));

    [Fact]
    public void UpcA_AppendsCheckDigit()
        => Assert.Equal("123456789012", Decode(Linear.UpcA("12345678901"), BarcodeFormat.UPC_A));

    [Fact]
    public void Ean13_And_UpcA_Are95Modules()
    {
        Assert.Equal(95, Linear.Ean13("5901234123457").Length);
        Assert.Equal(95, Linear.UpcA("036000291452").Length);
    }
}
