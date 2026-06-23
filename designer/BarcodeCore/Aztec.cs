namespace BarcodeCore;

/// <summary>
/// Aztec Code encoder — binary high-level encoding, compact and full symbols, Reed–Solomon over the
/// variable Galois field GF(2^wordSize) (6/8/10/12 bits by layer count), the central bullseye + mode
/// message, and the spiral data placement (with the full-symbol reference grid). Returns a square module
/// matrix [row, col] where <c>true</c> = dark. Validated by decoding the output with ZXing.
/// </summary>
public static class Aztec
{
    static readonly int[] WordSize =
        { 4, 6, 6, 8, 8, 8, 8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10,
          10, 10, 10, 10, 10, 10, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12 };

    public static bool[,] Encode(string text)
    {
        var data = System.Text.Encoding.UTF8.GetBytes(text ?? "");
        var bits = HighLevel(data);
        int eccBits = bits.Count * 23 / 100 + 11;
        int totalSizeBits = bits.Count + eccBits;

        bool compact = true; int layers = 0, totalBitsInLayers = 0, wordSize = 0;
        List<bool>? stuffed = null;
        for (int i = 0; ; i++)
        {
            if (i > 32) throw new ArgumentException("Aztec: data too large.");
            compact = i <= 3;
            layers = compact ? i + 1 : i;
            totalBitsInLayers = ((compact ? 88 : 112) + 16 * layers) * layers;
            if (totalBitsInLayers < totalSizeBits) continue;
            if (stuffed == null || wordSize != WordSize[layers])
            {
                wordSize = WordSize[layers];
                stuffed = StuffBits(bits, wordSize);
            }
            int usable = totalBitsInLayers - totalBitsInLayers % wordSize;
            if (compact && stuffed.Count > wordSize * 64) continue;
            if (stuffed.Count + eccBits > usable) continue;
            break;
        }

        var messageBits = GenerateCheckWords(stuffed!, totalBitsInLayers, wordSize);
        int messageSizeInWords = stuffed!.Count / wordSize;

        // ---- matrix geometry ----
        int baseMatrixSize = (compact ? 11 : 14) + layers * 4;
        var alignmentMap = new int[baseMatrixSize];
        int matrixSize;
        if (compact)
        {
            matrixSize = baseMatrixSize;
            for (int i = 0; i < baseMatrixSize; i++) alignmentMap[i] = i;
        }
        else
        {
            matrixSize = baseMatrixSize + 1 + 2 * ((baseMatrixSize / 2 - 1) / 15);
            int origCenter = baseMatrixSize / 2, ctr = matrixSize / 2;
            for (int i = 0; i < origCenter; i++)
            {
                int newOffset = i + i / 15;
                alignmentMap[origCenter - i - 1] = ctr - newOffset - 1;
                alignmentMap[origCenter + i] = ctr + newOffset + 1;
            }
        }

        var m = new bool[matrixSize, matrixSize];
        void Set(int x, int y) => m[y, x] = true;     // ZXing matrix.set(x=col, y=row)

        // ---- data spiral ----
        int rowOffset = 0;
        for (int i = 0; i < layers; i++)
        {
            int rowSize = (layers - i) * 4 + (compact ? 9 : 12);
            for (int j = 0; j < rowSize; j++)
            {
                int columnOffset = j * 2;
                for (int k = 0; k < 2; k++)
                {
                    if (messageBits[rowOffset + columnOffset + k]) Set(alignmentMap[i * 2 + k], alignmentMap[i * 2 + j]);
                    if (messageBits[rowOffset + rowSize * 2 + columnOffset + k]) Set(alignmentMap[i * 2 + j], alignmentMap[baseMatrixSize - 1 - i * 2 - k]);
                    if (messageBits[rowOffset + rowSize * 4 + columnOffset + k]) Set(alignmentMap[baseMatrixSize - 1 - i * 2 - k], alignmentMap[baseMatrixSize - 1 - i * 2 - j]);
                    if (messageBits[rowOffset + rowSize * 6 + columnOffset + k]) Set(alignmentMap[baseMatrixSize - 1 - i * 2 - j], alignmentMap[i * 2 + k]);
                }
            }
            rowOffset += rowSize * 8;
        }

        // ---- mode message ----
        var mode = ModeMessage(compact, layers, messageSizeInWords);
        int center = matrixSize / 2;
        if (compact)
            for (int i = 0; i < 7; i++)
            {
                int off = center - 3 + i;
                if (mode[i]) Set(off, center - 5);
                if (mode[i + 7]) Set(center + 5, off);
                if (mode[20 - i]) Set(off, center + 5);
                if (mode[27 - i]) Set(center - 5, off);
            }
        else
            for (int i = 0; i < 10; i++)
            {
                int off = center - 5 + i + i / 5;
                if (mode[i]) Set(off, center - 7);
                if (mode[i + 10]) Set(center + 7, off);
                if (mode[29 - i]) Set(off, center + 7);
                if (mode[39 - i]) Set(center - 7, off);
            }

        // ---- bullseye + orientation, and the full-symbol reference grid ----
        int sz = compact ? 5 : 7;
        for (int i = 0; i < sz; i += 2)
            for (int j = center - i; j <= center + i; j++)
            { Set(j, center - i); Set(j, center + i); Set(center - i, j); Set(center + i, j); }
        Set(center - sz, center - sz); Set(center - sz + 1, center - sz); Set(center - sz, center - sz + 1);
        Set(center + sz, center - sz); Set(center + sz, center - sz + 1);
        Set(center + sz, center + sz - 1);
        if (!compact)
            for (int i = 0, j = 0; i < baseMatrixSize / 2 - 1; i += 15, j += 16)
                for (int k = (matrixSize / 2) & 1; k < matrixSize; k += 2)
                {
                    Set(center - j, k); Set(center + j, k); Set(k, center - j); Set(k, center + j);
                }

        return m;
    }

    // ---- binary high-level encoding (B/S of the whole input) ----
    static List<bool> HighLevel(byte[] data)
    {
        var bits = new List<bool>();
        void Append(int v, int n) { for (int i = n - 1; i >= 0; i--) bits.Add(((v >> i) & 1) != 0); }
        Append(31, 5);                                  // B/S in Upper mode
        if (data.Length <= 31) Append(data.Length, 5);
        else { Append(0, 5); Append(data.Length - 31, 11); }
        foreach (var b in data) Append(b, 8);
        return bits;
    }

    static List<bool> StuffBits(List<bool> bits, int wordSize)
    {
        var outv = new List<bool>();
        int n = bits.Count;
        int mask = (1 << wordSize) - 2;
        for (int i = 0; i < n; i += wordSize)
        {
            int word = 0;
            for (int j = 0; j < wordSize; j++)
                if (i + j >= n || bits[i + j]) word |= 1 << (wordSize - 1 - j);
            if ((word & mask) == mask) { Append(outv, word & mask, wordSize); i--; }
            else if ((word & mask) == 0) { Append(outv, word | 1, wordSize); i--; }
            else Append(outv, word, wordSize);
        }
        return outv;
    }

    static void Append(List<bool> b, int v, int n) { for (int i = n - 1; i >= 0; i--) b.Add(((v >> i) & 1) != 0); }

    static List<bool> GenerateCheckWords(List<bool> stuffed, int totalBits, int wordSize)
    {
        int messageWords = stuffed.Count / wordSize;
        int totalWords = totalBits / wordSize;
        var words = new int[totalWords];
        for (int i = 0; i < messageWords; i++)
        {
            int w = 0;
            for (int j = 0; j < wordSize; j++) if (stuffed[i * wordSize + j]) w |= 1 << (wordSize - 1 - j);
            words[i] = w;
        }
        var gf = GetGF(wordSize);
        var msg = new int[messageWords];
        Array.Copy(words, msg, messageWords);
        var ec = RsEcc(gf, msg, totalWords - messageWords);
        Array.Copy(ec, 0, words, messageWords, ec.Length);

        var mb = new List<bool>();
        Append(mb, 0, totalBits % wordSize);
        foreach (var w in words) Append(mb, w, wordSize);
        return mb;
    }

    static List<bool> ModeMessage(bool compact, int layers, int words)
    {
        int[] mw; int ecLen;
        if (compact) { int v = ((layers - 1) << 6) | (words - 1); mw = new[] { (v >> 4) & 0xF, v & 0xF }; ecLen = 5; }
        else { int v = ((layers - 1) << 11) | (words - 1); mw = new[] { (v >> 12) & 0xF, (v >> 8) & 0xF, (v >> 4) & 0xF, v & 0xF }; ecLen = 6; }
        var gf16 = GetGF(4);
        var ec = RsEcc(gf16, mw, ecLen);
        var bits = new List<bool>();
        foreach (var w in mw) Append(bits, w, 4);
        foreach (var w in ec) Append(bits, w, 4);
        return bits;
    }

    // ---- Galois fields ----
    sealed class GF { public int[] Exp = null!; public int[] Log = null!; public int Size; }
    static readonly Dictionary<int, GF> Fields = new();
    static GF GetGF(int wordSize)
    {
        if (Fields.TryGetValue(wordSize, out var f)) return f;
        int prim = wordSize switch { 4 => 0x13, 6 => 0x43, 8 => 0x12D, 10 => 0x409, _ => 0x1069 };
        int size = 1 << wordSize;
        var gf = new GF { Size = size, Exp = new int[size * 2], Log = new int[size] };
        int x = 1;
        for (int i = 0; i < size - 1; i++) { gf.Exp[i] = x; gf.Log[x] = i; x <<= 1; if ((x & size) != 0) x ^= prim; }
        for (int i = size - 1; i < size * 2; i++) gf.Exp[i] = gf.Exp[i - (size - 1)];
        Fields[wordSize] = gf;
        return gf;
    }
    static int Mul(GF gf, int a, int b) => (a == 0 || b == 0) ? 0 : gf.Exp[gf.Log[a] + gf.Log[b]];

    static int[] RsEcc(GF gf, int[] data, int ecLen)
    {
        // generator g(x) = product(x - a^i), i=1..ecLen (base 1) — same structure as the proven QR encoder
        var g = new int[] { 1 };
        for (int i = 0; i < ecLen; i++)
        {
            var ng = new int[g.Length + 1];
            for (int j = 0; j < g.Length; j++) { ng[j] ^= g[j]; ng[j + 1] ^= Mul(gf, g[j], gf.Exp[i + 1]); }
            g = ng;
        }
        var coeffs = new int[ecLen];
        Array.Copy(g, 1, coeffs, 0, ecLen);
        var res = new int[ecLen];
        foreach (var d in data)
        {
            int factor = d ^ res[0];
            Array.Copy(res, 1, res, 0, ecLen - 1);
            res[ecLen - 1] = 0;
            for (int i = 0; i < ecLen; i++) res[i] ^= Mul(gf, coeffs[i], factor);
        }
        return res;
    }
}
