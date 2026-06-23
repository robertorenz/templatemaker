using System.Text;

namespace BarcodeCore;

/// <summary>
/// Linear (1D) barcode encoders. Each returns a <c>bool[]</c> of modules at the narrowest-element
/// resolution where <c>true</c> = dark bar, <c>false</c> = light space, with NO quiet zone (the caller
/// draws that). This is a reference implementation to port to a Clarion drawing template; every encoder
/// is validated by decoding its output with ZXing.Net.
/// </summary>
public static class Linear
{
    static void Run(List<bool> o, bool dark, int n) { for (int i = 0; i < n; i++) o.Add(dark); }

    // ===================== Code 39 (3 of 9) =====================
    // 9 elements per char (bar,space,... starting with bar), 3 of them wide; self-checking.
    static readonly Dictionary<char, string> C39 = new()
    {
        {'0',"nnnwwnwnn"},{'1',"wnnwnnnnw"},{'2',"nnwwnnnnw"},{'3',"wnwwnnnnn"},
        {'4',"nnnwwnnnw"},{'5',"wnnwwnnnn"},{'6',"nnwwwnnnn"},{'7',"nnnwnnwnw"},
        {'8',"wnnwnnwnn"},{'9',"nnwwnnwnn"},{'A',"wnnnnwnnw"},{'B',"nnwnnwnnw"},
        {'C',"wnwnnwnnn"},{'D',"nnnnwwnnw"},{'E',"wnnnwwnnn"},{'F',"nnwnwwnnn"},
        {'G',"nnnnnwwnw"},{'H',"wnnnnwwnn"},{'I',"nnwnnwwnn"},{'J',"nnnnwwwnn"},
        {'K',"wnnnnnnww"},{'L',"nnwnnnnww"},{'M',"wnwnnnnwn"},{'N',"nnnnwnnww"},
        {'O',"wnnnwnnwn"},{'P',"nnwnwnnwn"},{'Q',"nnnnnnwww"},{'R',"wnnnnnwwn"},
        {'S',"nnwnnnwwn"},{'T',"nnnnwnwwn"},{'U',"wwnnnnnnw"},{'V',"nwwnnnnnw"},
        {'W',"wwwnnnnnn"},{'X',"nwnnwnnnw"},{'Y',"wwnnwnnnn"},{'Z',"nwwnwnnnn"},
        {'-',"nwnnnnwnw"},{'.',"wwnnnnwnn"},{' ',"nwwnnnwnn"},{'$',"nwnwnwnnn"},
        {'/',"nwnwnnnwn"},{'+',"nwnnnwnwn"},{'%',"nnnwnwnwn"},{'*',"nwnnwnwnn"},
    };

    /// <summary>Code 39. Data is upper-cased; <c>*</c> start/stop is added automatically.</summary>
    public static bool[] Code39(string data, int wide = 3)
    {
        data = (data ?? "").ToUpperInvariant();
        var o = new List<bool>();
        void Sym(char c)
        {
            var p = C39[c];
            for (int i = 0; i < 9; i++) Run(o, i % 2 == 0, p[i] == 'w' ? wide : 1);
        }
        Sym('*');
        foreach (var c in data)
        {
            if (c == '*' || !C39.ContainsKey(c)) throw new ArgumentException($"Code39: invalid character '{c}'");
            Run(o, false, 1);   // narrow inter-character gap
            Sym(c);
        }
        Run(o, false, 1);
        Sym('*');
        return o.ToArray();
    }

    // ===================== Interleaved 2 of 5 (ITF) =====================
    static readonly string[] ItfDigit =
        { "nnwwn", "wnnnw", "nwnnw", "wwnnn", "nnwnw", "wnwnn", "nwwnn", "nnnww", "wnnwn", "nwnwn" };

    /// <summary>Interleaved 2 of 5 — digits only, even count (a leading 0 is added if odd).</summary>
    public static bool[] Itf(string digits, int wide = 3)
    {
        digits ??= "";
        foreach (var c in digits) if (c < '0' || c > '9') throw new ArgumentException("ITF: digits only");
        if (digits.Length % 2 == 1) digits = "0" + digits;
        var o = new List<bool>();
        Run(o, true, 1); Run(o, false, 1); Run(o, true, 1); Run(o, false, 1);    // start nnnn
        for (int i = 0; i < digits.Length; i += 2)
        {
            var b = ItfDigit[digits[i] - '0'];        // bars carry the first digit of the pair
            var s = ItfDigit[digits[i + 1] - '0'];    // spaces carry the second
            for (int k = 0; k < 5; k++)
            {
                Run(o, true, b[k] == 'w' ? wide : 1);
                Run(o, false, s[k] == 'w' ? wide : 1);
            }
        }
        Run(o, true, wide); Run(o, false, 1); Run(o, true, 1);                    // stop: wide,narrow,narrow
        return o.ToArray();
    }

    // ===================== Code 128 =====================
    // 0..105 are 6-element symbols (sum 11); 106 is the 7-element stop (sum 13).
    static readonly string[] C128 =
    {
        "212222","222122","222221","121223","121322","131222","122213","122312","132212","221213",
        "221312","231212","112232","122132","122231","113222","123122","123221","223211","221132",
        "221231","213212","223112","312131","311222","321122","321221","312212","322112","322211",
        "212123","212321","232121","111323","131123","131321","112313","132113","132311","211313",
        "231113","231311","112133","112331","132131","113123","113321","133121","313121","211331",
        "231131","213113","213311","213131","311123","311321","331121","312113","312311","332111",
        "314111","221411","431111","111224","111422","121124","121421","141122","141221","112214",
        "112412","122114","122411","142112","142211","241211","221114","413111","241112","134111",
        "111242","121142","121241","114212","124112","124211","411212","421112","421211","212141",
        "214121","412121","111143","111341","131141","114113","114311","411113","411311","113141",
        "114131","311141","411131","211412","211214","211232","2331112"
    };

    /// <summary>
    /// Code 128. All-digit, even-length data uses Code C (numeric, compact); everything else uses Code B
    /// (ASCII 32–126). One code set for the whole string — correct, if not maximally optimal.
    /// </summary>
    public static bool[] Code128(string data)
    {
        data ??= "";
        var values = new List<int>();
        bool numericC = data.Length >= 2 && data.Length % 2 == 0 && data.All(char.IsDigit);
        if (numericC)
        {
            values.Add(105);                                              // Start C
            for (int i = 0; i < data.Length; i += 2) values.Add((data[i] - '0') * 10 + (data[i + 1] - '0'));
        }
        else
        {
            values.Add(104);                                             // Start B
            foreach (var c in data)
            {
                if (c < 32 || c > 126) throw new ArgumentException($"Code128(B): unsupported character 0x{(int)c:X2}");
                values.Add(c - 32);
            }
        }
        long sum = values[0];
        for (int i = 1; i < values.Count; i++) sum += (long)i * values[i];
        values.Add((int)(sum % 103));                                    // checksum
        values.Add(106);                                                 // Stop

        var o = new List<bool>();
        foreach (var v in values)
        {
            var p = C128[v];
            for (int i = 0; i < p.Length; i++) Run(o, i % 2 == 0, p[i] - '0');   // starts with a bar
        }
        return o.ToArray();
    }

    // ===================== EAN-13 / UPC-A =====================
    static readonly string[] L = { "0001101","0011001","0010011","0111101","0100011","0110001","0101111","0111011","0110111","0001011" };
    static readonly string[] G = { "0100111","0110011","0011011","0100001","0011101","0111001","0000101","0010001","0001001","0010111" };
    static readonly string[] R = { "1110010","1100110","1101100","1000010","1011100","1001110","1010000","1000100","1001000","1110100" };
    static readonly string[] Parity = { "LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG","LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL" };

    static char EanCheck(string d12) { int s = 0; for (int i = 0; i < 12; i++) { int n = d12[i] - '0'; s += (i % 2 == 0) ? n : n * 3; } return (char)('0' + (10 - s % 10) % 10); }
    static char UpcCheck(string d11) { int s = 0; for (int i = 0; i < 11; i++) { int n = d11[i] - '0'; s += (i % 2 == 0) ? n * 3 : n; } return (char)('0' + (10 - s % 10) % 10); }

    /// <summary>EAN-13 — 12 digits (check appended) or 13 (used as-is). 95 modules.</summary>
    public static bool[] Ean13(string digits)
    {
        digits ??= "";
        if (digits.Any(c => c < '0' || c > '9')) throw new ArgumentException("EAN-13: digits only");
        if (digits.Length == 12) digits += EanCheck(digits);
        else if (digits.Length != 13) throw new ArgumentException("EAN-13: needs 12 or 13 digits");

        var o = new List<bool>();
        void Bits(string s) { foreach (var ch in s) o.Add(ch == '1'); }
        var par = Parity[digits[0] - '0'];
        Bits("101");                                                     // left guard
        for (int i = 1; i <= 6; i++) { int d = digits[i] - '0'; Bits(par[i - 1] == 'L' ? L[d] : G[d]); }
        Bits("01010");                                                   // centre guard
        for (int i = 7; i <= 12; i++) Bits(R[digits[i] - '0']);
        Bits("101");                                                     // right guard
        return o.ToArray();
    }

    /// <summary>UPC-A — 11 digits (check appended) or 12. Encoded as EAN-13 with a leading 0 (same bars).</summary>
    public static bool[] UpcA(string digits)
    {
        digits ??= "";
        if (digits.Any(c => c < '0' || c > '9')) throw new ArgumentException("UPC-A: digits only");
        if (digits.Length == 11) digits += UpcCheck(digits);
        else if (digits.Length != 12) throw new ArgumentException("UPC-A: needs 11 or 12 digits");
        return Ean13("0" + digits);
    }
}
