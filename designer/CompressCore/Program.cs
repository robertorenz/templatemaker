// ============================================================================
//  CompressCore - the golden-vector oracle for the myCompress Clarion template.
//
//  myCompress implements DEFLATE / zlib / gzip in pure Clarion (CompressClass).
//  Clarion cannot be run from CI, so - exactly like QrCodeCore / BarcodeCore -
//  this small .NET tool is the independent reference. .NET's own GZipStream /
//  ZLibStream / DeflateStream ARE the validated encoder/decoder, so there is no
//  algorithm to re-implement here; the tool just (1) emits golden vectors the
//  Clarion side must round-trip, and (2) verifies Clarion-produced output by
//  decompressing it with .NET. That closes the loop in both directions:
//
//     INFLATE test : .NET compresses  -> Clarion DecompressFile -> must match
//     DEFLATE test : Clarion compresses -> .NET decompresses     -> must match
//
//  Commands:
//     dotnet run -- vectors <dir>     write caseN.bin + caseN.bin.gz/.zz/.raw + manifest
//     dotnet run -- verify  <dir>     decompress each caseN.bin.cgz (Clarion gzip) and compare
//     dotnet run -- check   <file>    decompress one gzip file; print length + CRC32
//     dotnet run -- selfcheck         in-memory round-trip of every case (sanity)
// ============================================================================
using System.IO.Compression;
using System.Text;

static byte[] Gzip(byte[] raw)
{
    using var ms = new MemoryStream();
    using (var gz = new GZipStream(ms, CompressionLevel.Optimal, leaveOpen: true)) gz.Write(raw);
    return ms.ToArray();
}
static byte[] Zlib(byte[] raw)
{
    using var ms = new MemoryStream();
    using (var z = new ZLibStream(ms, CompressionLevel.Optimal, leaveOpen: true)) z.Write(raw);
    return ms.ToArray();
}
static byte[] RawDeflate(byte[] raw)
{
    using var ms = new MemoryStream();
    using (var d = new DeflateStream(ms, CompressionLevel.Optimal, leaveOpen: true)) d.Write(raw);
    return ms.ToArray();
}
static byte[] Gunzip(byte[] comp)
{
    using var ms = new MemoryStream(comp);
    using var gz = new GZipStream(ms, CompressionMode.Decompress);
    using var outMs = new MemoryStream();
    gz.CopyTo(outMs);
    return outMs.ToArray();
}
static uint Crc32(byte[] data)
{
    Span<uint> tab = stackalloc uint[256];
    for (uint n = 0; n < 256; n++)
    {
        uint c = n;
        for (int k = 0; k < 8; k++) c = ((c & 1) != 0) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        tab[(int)n] = c;
    }
    uint crc = 0xFFFFFFFFu;
    foreach (var b in data) crc = (crc >> 8) ^ tab[(int)((crc ^ b) & 0xFF)];
    return crc ^ 0xFFFFFFFFu;
}

// ---- the test corpus: each pair exercises a different code path ------------
static (string name, byte[] data)[] Cases()
{
    var rnd = new Random(12345);                       // fixed seed -> reproducible
    var random = new byte[20000]; rnd.NextBytes(random);
    var runs = new byte[8000]; for (int i = 0; i < runs.Length; i++) runs[i] = (byte)('A' + (i / 500) % 5);
    var sb = new StringBuilder();
    for (int i = 0; i < 400; i++) sb.Append("The quick brown fox jumps over the lazy dog. ");
    return new (string, byte[])[]
    {
        ("empty",      Array.Empty<byte>()),                                  // 0-length -> one empty stored/EOB
        ("one",        new byte[]{ 0x42 }),                                   // single byte
        ("text",       Encoding.ASCII.GetBytes(sb.ToString())),              // long, very compressible (LZ77)
        ("repeat",     runs),                                                 // long runs -> long matches
        ("binary",     Enumerable.Range(0, 1024).Select(i => (byte)(i & 0xFF)).ToArray()), // 0..255 incl. NULs
        ("random",     random),                                               // incompressible -> stored-ish
        ("nulls",      new byte[5000]),                                        // all zero -> max run matches
    };
}

int Vectors(string dir)
{
    Directory.CreateDirectory(dir);
    using var man = new StreamWriter(Path.Combine(dir, "manifest.txt"));
    man.WriteLine("# name  origLen  crc32(hex)  gzipLen  zlibLen  rawLen");
    foreach (var (name, data) in Cases())
    {
        File.WriteAllBytes(Path.Combine(dir, name + ".bin"), data);
        var gz = Gzip(data); var zz = Zlib(data); var rw = RawDeflate(data);
        File.WriteAllBytes(Path.Combine(dir, name + ".bin.gz"), gz);
        File.WriteAllBytes(Path.Combine(dir, name + ".bin.zz"), zz);
        File.WriteAllBytes(Path.Combine(dir, name + ".bin.raw"), rw);
        man.WriteLine($"{name}  {data.Length}  {Crc32(data):X8}  {gz.Length}  {zz.Length}  {rw.Length}");
        Console.WriteLine($"  {name,-8} orig={data.Length,-6} gz={gz.Length,-6} zlib={zz.Length,-6} raw={rw.Length}");
    }
    Console.WriteLine($"Wrote golden vectors to {Path.GetFullPath(dir)}");
    Console.WriteLine("Clarion side: DecompressFile each .bin.gz and compare to .bin (INFLATE test);");
    Console.WriteLine("then CompressFile each .bin to .bin.cgz and run 'verify' here (DEFLATE test).");
    return 0;
}

int Verify(string dir)
{
    int fail = 0, ran = 0;
    foreach (var (name, _) in Cases())
    {
        var orig = Path.Combine(dir, name + ".bin");
        var cgz = Path.Combine(dir, name + ".bin.cgz");          // Clarion-produced gzip
        if (!File.Exists(orig) || !File.Exists(cgz)) continue;
        ran++;
        try
        {
            var back = Gunzip(File.ReadAllBytes(cgz));
            var want = File.ReadAllBytes(orig);
            bool ok = back.AsSpan().SequenceEqual(want);
            Console.WriteLine($"  {name,-8} {(ok ? "PASS" : "FAIL")}  (clarion gzip {new FileInfo(cgz).Length} B -> {back.Length} B)");
            if (!ok) fail++;
        }
        catch (Exception e) { Console.WriteLine($"  {name,-8} FAIL  ({e.Message})"); fail++; }
    }
    if (ran == 0) { Console.WriteLine("No caseN.bin.cgz files found - run the Clarion CompressFile pass first."); return 2; }
    Console.WriteLine(fail == 0 ? $"All {ran} Clarion gzip outputs verified." : $"{fail}/{ran} FAILED.");
    return fail == 0 ? 0 : 1;
}

int Check(string file)
{
    var back = Gunzip(File.ReadAllBytes(file));
    Console.WriteLine($"{file}: {new FileInfo(file).Length} B compressed -> {back.Length} B  CRC32={Crc32(back):X8}");
    return 0;
}

int SelfCheck()
{
    int fail = 0;
    foreach (var (name, data) in Cases())
    {
        var ok = Gunzip(Gzip(data)).AsSpan().SequenceEqual(data);
        Console.WriteLine($"  {name,-8} {(ok ? "ok" : "BAD")}  ({data.Length} B, crc {Crc32(data):X8})");
        if (!ok) fail++;
    }
    Console.WriteLine(fail == 0 ? "selfcheck ok" : $"selfcheck {fail} BAD");
    return fail;
}

string cmd = args.Length > 0 ? args[0].ToLowerInvariant() : "selfcheck";
switch (cmd)
{
    case "vectors":   return Vectors(args.Length > 1 ? args[1] : "vectors");
    case "verify":    return Verify(args.Length > 1 ? args[1] : "vectors");
    case "check":     return Check(args[1]);
    case "selfcheck": return SelfCheck();
    default:
        Console.WriteLine("commands: vectors <dir> | verify <dir> | check <file> | selfcheck");
        return 1;
}
