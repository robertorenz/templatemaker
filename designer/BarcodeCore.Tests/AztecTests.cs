using BarcodeCore;
using Xunit;
using ZXing;
using ZXing.Common;

namespace BarcodeCore.Tests;

public class AztecTests
{
    static string? Decode(bool[,] m)
    {
        const int scale = 8, quiet = 4;
        int n = m.GetLength(0);
        int dim = (n + 2 * quiet) * scale;
        var gray = new byte[dim * dim];
        Array.Fill(gray, (byte)255);
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                if (m[r, c])
                    for (int dy = 0; dy < scale; dy++)
                        for (int dx = 0; dx < scale; dx++)
                            gray[((r + quiet) * scale + dy) * dim + ((c + quiet) * scale + dx)] = 0;
        var src = new RGBLuminanceSource(gray, dim, dim, RGBLuminanceSource.BitmapFormat.Gray8);
        var reader = new BarcodeReaderGeneric
        {
            Options = new DecodingOptions
            {
                PossibleFormats = new List<BarcodeFormat> { BarcodeFormat.AZTEC },
                TryHarder = true,
                PureBarcode = true,
            }
        };
        return reader.Decode(src)?.Text;
    }

    [Theory]
    [InlineData("HELLO")]
    [InlineData("Aztec Code")]
    [InlineData("12345678")]
    [InlineData("ABC-123-XYZ")]
    [InlineData("https://example.com/x")]
    [InlineData("The quick brown fox jumps over the lazy dog")]
    public void RoundTrips(string text)
        => Assert.Equal(text, Decode(Aztec.Encode(text)));
}
