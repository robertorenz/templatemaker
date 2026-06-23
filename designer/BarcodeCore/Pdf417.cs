namespace BarcodeCore;

/// <summary>
/// PDF417 encoder — Byte compaction, Reed–Solomon over the prime field GF(929) (generator computed at run
/// time), automatic columns/rows + error-correction level, and the 17-module codeword patterns
/// (<see cref="Pdf417Table"/>, extracted from ZXing). Returns a stacked module matrix [row, col] where
/// <c>true</c> = dark and each matrix row is one module tall (the caller draws rows taller). Validated by
/// decoding the output with ZXing.
/// </summary>
public static class Pdf417
{
    const int MOD = 929;

    public static bool[,] Encode(string text)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(text ?? "");
        var comp = ByteCompaction(bytes);                 // mode latch + data codewords

        int d = comp.Count;
        int level = d <= 40 ? 2 : d <= 160 ? 3 : d <= 320 ? 4 : 5;
        int ec = 1 << (level + 1);
        int total = d + 1 + ec;                           // descriptor + data + EC (minimum)

        int cols = 0, rows = 0, best = int.MaxValue;
        for (int c = 1; c <= 30; c++)
        {
            int r = (total + c - 1) / c;
            if (r < 3) r = 3;
            if (r > 90) continue;
            if (c * r - ec > 928 || c * r - ec < d + 1) continue;
            int score = c * r - total + Math.Abs(r - c * 2);   // small waste, roughly 2:1 (rows:cols)
            if (score < best) { best = score; cols = c; rows = r; }
        }
        if (cols == 0) throw new ArgumentException("PDF417: data too large for a single symbol.");

        int region = rows * cols - ec;                    // data region size (incl. descriptor + pad)
        var data = new int[region];
        data[0] = region;                                 // symbol length descriptor
        for (int i = 0; i < d; i++) data[i + 1] = comp[i];
        for (int i = d + 1; i < region; i++) data[i] = 900;   // pad

        var ecc = ComputeEc(data, ec);
        var all = new int[rows * cols];
        Array.Copy(data, all, region);
        Array.Copy(ecc, 0, all, region, ec);

        int width = 17 + 17 + cols * 17 + 17 + 18;
        var m = new bool[rows, width];
        for (int r = 0; r < rows; r++)
        {
            int cluster = r % 3;
            int t = 30 * (r / 3);
            int left = cluster switch
            {
                0 => t + (rows - 1) / 3,
                1 => t + 3 * level + (rows - 1) % 3,
                _ => t + (cols - 1),
            };
            int right = cluster switch
            {
                0 => t + (cols - 1),
                1 => t + (rows - 1) / 3,
                _ => t + 3 * level + (rows - 1) % 3,
            };
            int x = 0;
            x = Emit(m, r, x, Pdf417Table.Start, 17);
            x = Emit(m, r, x, Pdf417Table.Cw[cluster][left], 17);
            for (int c = 0; c < cols; c++) x = Emit(m, r, x, Pdf417Table.Cw[cluster][all[r * cols + c]], 17);
            x = Emit(m, r, x, Pdf417Table.Cw[cluster][right], 17);
            x = Emit(m, r, x, Pdf417Table.Stop, 18);
        }
        return m;
    }

    static int Emit(bool[,] m, int row, int x, int pattern, int bits)
    {
        for (int i = bits - 1; i >= 0; i--) { m[row, x] = ((pattern >> i) & 1) != 0; x++; }
        return x;
    }

    // ---- Byte compaction: 6 bytes -> 5 codewords (base 900); leftover -> 1 codeword each ----
    static List<int> ByteCompaction(byte[] b)
    {
        var cw = new List<int> { b.Length % 6 == 0 ? 924 : 901 };
        int i = 0;
        while (i + 6 <= b.Length)
        {
            long t = 0;
            for (int j = 0; j < 6; j++) t = t * 256 + b[i + j];
            var c = new int[5];
            for (int j = 4; j >= 0; j--) { c[j] = (int)(t % 900); t /= 900; }
            cw.AddRange(c);
            i += 6;
        }
        while (i < b.Length) cw.Add(b[i++]);
        return cw;
    }

    // ---- GF(929) Reed–Solomon: generator = product(x - 3^i), i=1..k ----
    static int[] GenCoeffs(int k)
    {
        var g = new int[] { 1 };
        int root = 1;
        for (int i = 1; i <= k; i++)
        {
            root = root * 3 % MOD;
            var ng = new int[g.Length + 1];
            for (int j = 0; j < g.Length; j++)
            {
                ng[j + 1] = (ng[j + 1] + g[j]) % MOD;                       // x * g[j]
                ng[j] = (ng[j] + (MOD - g[j] * root % MOD)) % MOD;          // (-root) * g[j]
            }
            g = ng;
        }
        var coeffs = new int[k];                                            // c_0 .. c_{k-1} (monic, drop x^k)
        for (int j = 0; j < k; j++) coeffs[j] = g[j];
        return coeffs;
    }

    static int[] ComputeEc(int[] data, int k)
    {
        var coeffs = GenCoeffs(k);
        var e = new int[k];
        foreach (int dd in data)
        {
            int t1 = (dd + e[k - 1]) % MOD;
            for (int j = k - 1; j >= 1; j--) e[j] = (e[j - 1] + (MOD - t1 * coeffs[j] % MOD)) % MOD;
            e[0] = (MOD - t1 * coeffs[0] % MOD) % MOD;
        }
        var ec = new int[k];
        for (int j = k - 1, idx = 0; j >= 0; j--, idx++) ec[idx] = e[j] != 0 ? MOD - e[j] : 0;
        return ec;
    }
}
