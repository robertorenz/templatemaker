using BarcodeCore;
using Xunit;
using ZXing;
using ZXing.Common;

namespace BarcodeCore.Tests;

public class Pdf417Tests
{
    static string? Decode(bool[,] m)
    {
        const int scale = 3, rowH = 9, quiet = 4;            // each barcode row is one matrix row, drawn taller
        int rows = m.GetLength(0), cols = m.GetLength(1);
        int w = (cols + 2 * quiet) * scale;
        int h = rows * rowH + 2 * quiet * rowH;
        var gray = new byte[w * h];
        Array.Fill(gray, (byte)255);
        for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++)
                if (m[r, c])
                    for (int dy = 0; dy < rowH; dy++)
                        for (int dx = 0; dx < scale; dx++)
                            gray[(quiet * rowH + r * rowH + dy) * w + (quiet * scale + c * scale + dx)] = 0;
        var src = new RGBLuminanceSource(gray, w, h, RGBLuminanceSource.BitmapFormat.Gray8);
        var reader = new BarcodeReaderGeneric
        {
            Options = new DecodingOptions
            {
                PossibleFormats = new List<BarcodeFormat> { BarcodeFormat.PDF_417 },
                TryHarder = true,
                PureBarcode = true,
            }
        };
        return reader.Decode(src)?.Text;
    }

    [Theory]
    [InlineData("HELLO")]
    [InlineData("PDF417")]
    [InlineData("12345678")]
    [InlineData("ABC-123-XYZ")]
    [InlineData("https://example.com/order/4471")]
    [InlineData("The quick brown fox jumps over the lazy dog.")]
    public void RoundTrips(string text)
        => Assert.Equal(text, Decode(Pdf417.Encode(text)));
}
