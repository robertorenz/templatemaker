using QrCodeCore;
using Xunit;
using Xunit.Abstractions;

namespace QrCodeCore.Tests;

// Golden matrices pin the encoder's EXACT module output for fixed inputs. They are the contract the
// Clarion port (templates/myQRDraw) must reproduce module-for-module — its built-in self-test draws
// "HELLO WORLD" at ECC M, so a phone scan that yields that string proves the port matches this golden.
public class GoldenMatrixTests
{
    readonly ITestOutputHelper _out;
    public GoldenMatrixTests(ITestOutputHelper o) => _out = o;

    static string Dump(bool[,] m)
    {
        int n = m.GetLength(0);
        var rows = new string[n];
        for (int r = 0; r < n; r++)
        {
            var chars = new char[n];
            for (int c = 0; c < n; c++) chars[c] = m[r, c] ? '#' : '.';
            rows[r] = new string(chars);
        }
        return string.Join("\n", rows);
    }

    // Version-1 (21x21) symbol for the canonical "HELLO WORLD" at ECC M. Captured from the
    // ZXing-validated encoder; the Clarion self-test must render exactly this.
    const string HelloWorldM =
        "#######.##..#.#######\n" +
        "#.....#....#..#.....#\n" +
        "#.###.#..#.#..#.###.#\n" +
        "#.###.#.#..#..#.###.#\n" +
        "#.###.#.###.#.#.###.#\n" +
        "#.....#.#..#..#.....#\n" +
        "#######.#.#.#.#######\n" +
        "........#..##........\n" +
        "#...#.######.#####..#\n" +
        "...#....#.###....####\n" +
        "..######..##.##.#..#.\n" +
        "#####...##...#.......\n" +
        "#####.#.#.#.#.##..##.\n" +
        "........#.#.####.#.##\n" +
        "#######.###.#.#.##.#.\n" +
        "#.....#..#.###.##..##\n" +
        "#.###.#.##.#.##...##.\n" +
        "#.###.#..#..#...##.##\n" +
        "#.###.#..###...###...\n" +
        "#.....#....#.#.......\n" +
        "#######.#########.#.#";

    [Fact]
    public void HelloWorld_EccM_MatchesGolden()
    {
        var dump = Dump(QrEncoder.Encode("HELLO WORLD", Ecc.M));
        _out.WriteLine(dump);
        Assert.Equal(HelloWorldM, dump);
    }

    [Fact]
    public void HelloWorld_EccM_IsVersion1()
    {
        Assert.Equal(21, QrEncoder.Encode("HELLO WORLD", Ecc.M).GetLength(0));
    }
}
