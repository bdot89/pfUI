param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\plates"))
# Draws pfUI Octo's nameplate art (modules/plates.lua). Our own drawings:
# Plater's textures are All Rights Reserved, so none of them is used.
#   bar-flat / soft / gloss / glass / split  256 x 32  health and cast bar fills
#   arrow      64 x 64  target arrow, points right (the left one is mirrored)
#   chevron    64 x 64  double arrow, points right
#   corner     32 x 32  an L in the top left corner (turned for the others)
#   underglow 256 x 64  soft light under the target's bar
#   spark      32 x 64  the bright edge of a filling cast bar
#   star       32 x 32  elite / rare mark, dark outline
#   skull      32 x 32  boss mark, dark outline
#   tick        8 x 32  execute marker on the bar
# White (grey shading) + alpha, tinted in game. Uncompressed 32-bit TGA,
# bottom-left origin, 4 x 4 samples per pixel. Same output every run.
#   powershell -ExecutionPolicy Bypass -File tools\MakePlateArt.ps1

$src = @"
using System;
using System.IO;
public static class Art {
  static bool Poly(double[] p, double x, double y) {
    bool c = false;
    int n = p.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = p[2 * i], yi = p[2 * i + 1], xj = p[2 * j], yj = p[2 * j + 1];
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) c = !c;
    }
    return c;
  }
  static bool Circle(double x, double y, double cx, double cy, double r) {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
  }
  static double[] Star() {
    double[] p = new double[20];
    for (int i = 0; i < 10; i++) {
      double r = (i % 2 == 0) ? 0.46 : 0.19;
      double a = Math.PI / 2 + i * Math.PI / 5;
      p[2 * i] = 0.5 + r * Math.Cos(a);
      p[2 * i + 1] = 0.47 + r * Math.Sin(a);
    }
    return p;
  }
  static readonly double[] STAR = Star();
  static readonly double[] ARROW = { 0.12, 0.14, 0.88, 0.5, 0.12, 0.86, 0.34, 0.5 };
  static readonly double[] CHEV1 = { 0.06, 0.12, 0.26, 0.12, 0.54, 0.5, 0.26, 0.88, 0.06, 0.88, 0.34, 0.5 };
  static readonly double[] CHEV2 = { 0.40, 0.12, 0.60, 0.12, 0.88, 0.5, 0.60, 0.88, 0.40, 0.88, 0.68, 0.5 };

  // a shape grown around (cx, cy): the outline is "grown but not the shape"
  static bool StarAt(double x, double y, double s) { return Poly(STAR, 0.5 + (x - 0.5) / s, 0.47 + (y - 0.47) / s); }
  static bool Skull(double x, double y, double s) {
    x = 0.5 + (x - 0.5) / s; y = 0.5 + (y - 0.5) / s;
    bool head = Circle(x, y, 0.5, 0.58, 0.33);
    bool jaw = x >= 0.32 && x <= 0.68 && y >= 0.14 && y <= 0.36;
    return head || jaw;
  }
  static bool SkullHole(double x, double y) {
    bool eye = Circle(x, y, 0.37, 0.55, 0.095) || Circle(x, y, 0.63, 0.55, 0.095);
    bool nose = Poly(new double[] { 0.5, 0.45, 0.45, 0.36, 0.55, 0.36 }, x, y);
    bool teeth = y >= 0.14 && y <= 0.27 && (Math.Abs(x - 0.42) < 0.018 || Math.Abs(x - 0.5) < 0.018 || Math.Abs(x - 0.58) < 0.018);
    return eye || nose || teeth;
  }

  // one sample: u, v in 0..1 (v up); lum 0..1 (shading), a 0..1 (cover)
  public static void Sample(string kind, double u, double v, double pw, double ph, out double lum, out double a) {
    lum = 1; a = 1;
    switch (kind) {
      case "bar-flat":
        lum = v > 1 - ph ? 1.0 : (v < ph ? 0.72 : 0.9);
        return;
      case "bar-soft":
        lum = 0.68 + 0.32 * v;
        return;
      case "bar-gloss":
        lum = v >= 0.5 ? 1.0 - 0.12 * (v - 0.5) * 2 : 0.70 + 0.12 * v * 2;
        if (v > 1 - ph) lum = 1.0;
        return;
      case "bar-glass": {
        double hl = Math.Exp(-Math.Pow((v - 0.72) / 0.09, 2));
        lum = Math.Min(1.0, 0.80 + 0.20 * hl - (v < 0.25 ? (0.25 - v) * 0.6 : 0));
        return;
      }
      case "bar-split":
        lum = v > 0.58 ? 1.0 : (v > 0.52 ? 0.78 + (v - 0.52) / 0.06 * 0.22 : 0.78);
        return;
      case "arrow":
        a = Poly(ARROW, u, v) ? 1 : 0;
        lum = 0.82 + 0.18 * v;
        return;
      case "chevron":
        a = (Poly(CHEV1, u, v) || Poly(CHEV2, u, v)) ? 1 : 0;
        lum = 0.82 + 0.18 * v;
        return;
      case "corner": {
        double t = 0.16;
        a = ((v >= 1 - t) || (u <= t)) ? 1 : 0;
        return;
      }
      case "underglow": {
        double dx = (u - 0.5) / 0.36, dy = (v - 0.5) / 0.30;
        a = Math.Exp(-(dx * dx + dy * dy) * 2.2);
        return;
      }
      case "spark": {
        double dx = (u - 0.5) / 0.16, dy = (v - 0.5) / 0.5;
        a = Math.Exp(-dx * dx * 2.5) * Math.Max(0, 1 - Math.Pow(Math.Abs(dy), 3));
        return;
      }
      case "star":
        if (StarAt(u, v, 1.0)) { lum = 0.75 + 0.25 * v; a = 1; }
        else if (StarAt(u, v, 1.16)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      case "skull":
        if (Skull(u, v, 1.0)) { if (SkullHole(u, v)) { lum = 0; a = 1; } else { lum = 0.8 + 0.2 * v; a = 1; } }
        else if (Skull(u, v, 1.12)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      case "tick":
        a = 1;
        lum = Math.Abs(u - 0.5) < 0.2 ? 1.0 : 0.0;
        return;
    }
  }

  public static void Write(string path, string kind, int w, int h) {
    using (var f = new BinaryWriter(File.Create(path))) {
      f.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      f.Write((ushort)w); f.Write((ushort)h);
      f.Write((byte)32); f.Write((byte)8);
      int n = 4;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          double sa = 0, sl = 0;
          for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
              double lum, a;
              Sample(kind, (x + (i + 0.5) / n) / w, (y + (j + 0.5) / n) / h, 1.0 / h, 1.0 / h, out lum, out a);
              sa += a; sl += lum * a;
            }
          }
          double alpha = sa / (n * n);
          double l = sa > 0 ? sl / sa : 0;
          byte c = (byte)Math.Round(Math.Max(0, Math.Min(1, l)) * 255);
          f.Write(c); f.Write(c); f.Write(c); f.Write((byte)Math.Round(alpha * 255));
        }
      }
    }
  }
}
"@
Add-Type -TypeDefinition $src

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$list = @(
  @("bar-flat", 256, 32), @("bar-soft", 256, 32), @("bar-gloss", 256, 32), @("bar-glass", 256, 32), @("bar-split", 256, 32),
  @("arrow", 64, 64), @("chevron", 64, 64), @("corner", 32, 32), @("underglow", 256, 64), @("spark", 32, 64),
  @("star", 32, 32), @("skull", 32, 32), @("tick", 8, 32)
)
foreach ($t in $list) {
  [Art]::Write((Join-Path $OutDir ($t[0] + ".tga")), $t[0], $t[1], $t[2])
}
Get-ChildItem $OutDir -Filter *.tga | ForEach-Object { "{0,-16} {1,7} bytes" -f $_.Name, $_.Length }
