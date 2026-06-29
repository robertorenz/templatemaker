  PROGRAM
! ============================================================================
!  GaugePlusTest - headless render of a full GaugePlusClass gauge to a PNG,
!  so we can eyeball the real thing (face, ticks, labels, zones, needle, text)
!  before wiring it into a template/window.
! ============================================================================
  INCLUDE('GaugePlusClass.INC'),ONCE
  MAP
  END

G    GaugePlusClass
out  CSTRING(260)
  CODE
  out = 'C:\dev\clarion12\templatemaker\examples\myGaugePlus\gaugeplus_out.png'
  G.SetRange(0, 220)
  G.Preset(GaugeP:Arc270)
  G.MajorTicks = 11
  G.MinorTicks = 1
  G.AddZone(0,   80,  02CA02Ch)                              ! green
  G.AddZone(80,  170, 020C0F0h)                              ! amber
  G.AddZone(170, 220, 02020E0h)                              ! red
  G.Title = 'SPEED'
  G.Units = 'km/h'
  G.SetValue(146)
  IF G.Cv.BeginCanvas(300, 300)
    G.Render(300, 300)
    G.Cv.SavePng(out)
    G.Cv.EndCanvas()
  END
  PUTINI('r','err', G.Cv.LastError(), 'C:\dev\clarion12\templatemaker\examples\myGaugePlus\gaugeplus_result.ini')
