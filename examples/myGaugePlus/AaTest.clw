  PROGRAM
! ============================================================================
!  AaTest - headless proof that AaCanvasClass (GDI+ via gpcanvas.c) renders a
!  genuinely ANTIALIASED image. Draws a mini speedometer and saves a PNG, then
!  writes a one-line result INI so a script can confirm it ran. No window.
! ============================================================================
  INCLUDE('AaCanvasClass.INC'),ONCE
  MAP
  END

Cv     AaCanvasClass
ok     BYTE
saved  BYTE
pngF   CSTRING(260)
iniF   CSTRING(260)
  CODE
  pngF = 'C:\dev\clarion12\templatemaker\examples\myGaugePlus\aatest_out.png'
  iniF = 'C:\dev\clarion12\templatemaker\examples\myGaugePlus\aatest_result.ini'
  IF Cv.BeginCanvas(240, 240)
    Cv.ClearCanvas(Cv.Argb(0FFFFFFH))                       ! white
    ! glossy round face (radial gradient: light centre -> grey rim)
    Cv.FillCircleGrad(120,120, 112, Cv.Argb(0FCFCFCH), Cv.Argb(0D2D2D2H))
    Cv.Circle(120,120, 112, 3, Cv.Argb(08C8C8CH))
    ! empty track, then a coloured value arc + a red zone (GDI+ angles: cw from 3 o'clock)
    Cv.Arc(18,18, 204,204, 135, 270, 16, Cv.Argb(0E0E0E0H))  ! track  (light grey)
    Cv.Arc(18,18, 204,204, 135, 170, 16, Cv.Argb(02CA02CH))  ! value  (green)
    Cv.Arc(18,18, 204,204, 315,  90, 16, Cv.Argb(02020E0H))  ! redline (red)
    ! needle + hub
    Cv.Line(120,120, 62, 58, 6, Cv.Argb(02B2B2BH))
    Cv.FillCircle(120,120, 11, Cv.Argb(02B2B2BH))
    Cv.FillCircle(120,120,  5, Cv.Argb(0DCDCDCH))
    ! antialiased text
    Cv.Text('72',   120,148, 42, Cv.Argb(0202020H),, 1, 1)   ! bold, centred
    Cv.Text('km/h', 120,182, 15, Cv.Argb(0808080H))
    saved = Cv.SavePng(pngF)
    Cv.EndCanvas()
    ok = 1
  END
  PUTINI('result','begin', ok,    iniF)
  PUTINI('result','saved', saved, iniF)
  PUTINI('result','err',   Cv.LastError(), iniF)
