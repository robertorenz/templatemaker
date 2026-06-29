  PROGRAM
! ============================================================================
!  GaugePlusDemo - a real WINDOW with a live antialiased gauge in an IMAGE
!  control, to verify GaugePlusClass.Draw() (pixel-size read, PNG reload,
!  resize, and timer animation) on an actual window. Hand-coded (no AppGen) -
!  the same class the myGaugePlus template wires up.
! ============================================================================
  INCLUDE('GaugePlusClass.INC'),ONCE
  MAP
  END

Win  WINDOW('myGaugePlus - live demo'),AT(,,328,346),CENTER,SYSTEM,GRAY,FONT('Segoe UI',9),RESIZE
       IMAGE,AT(8,8,312,312),USE(?Img)
       BUTTON('&Sweep to 40'),AT(8,326,100,16),USE(?Sweep)
       BUTTON('Sweep to &190'),AT(116,326,100,16),USE(?Sweep2)
       BUTTON('&Quit'),AT(272,326,48,16),USE(?Quit)
     END
G    GaugePlusClass
  CODE
  OPEN(Win)
  G.SetRange(0, 220)
  G.Preset(GaugeP:Arc270)
  G.MajorTicks = 11; G.MinorTicks = 1
  G.AddZone(0,   80,  02CA02Ch)
  G.AddZone(80,  170, 020C0F0h)
  G.AddZone(170, 220, 02020E0h)
  G.Title = 'SPEED'; G.Units = 'km/h'
  G.AnimStepPct = 5
  G.SetValue(146)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow; G.Draw(Win, ?Img)
    OF EVENT:Sized;      G.Draw(Win, ?Img)
    OF EVENT:Timer
      IF G.AnimStep() THEN G.Draw(Win, ?Img).
      IF G.Value = G.Target THEN 0{PROP:Timer} = 0.
    END
    CASE ACCEPTED()
    OF ?Sweep;  G.AnimateTo(40);  0{PROP:Timer} = 4
    OF ?Sweep2; G.AnimateTo(190); 0{PROP:Timer} = 4
    OF ?Quit;   POST(EVENT:CloseWindow)
    END
  END
  CLOSE(Win)
