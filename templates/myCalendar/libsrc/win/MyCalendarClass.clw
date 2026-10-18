! ============================================================================
!  MyCalendarClass - implementation.   See MyCalendarClass.inc for the overview.
!
!  This file must be stored ANSI, with CRLF line endings.
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      cdModuleFile( LONG hModule, *CSTRING lpFilename, ULONG nSize ),ULONG,RAW,PASCAL,NAME('GetModuleFileNameA')
    END
  END

  INCLUDE('MyCalendarClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

Cal:CharW          EQUATE(4)                    ! text cell metrics, dialog units
Cal:CharH          EQUATE(9)

! ############################################################################
!  Lifetime
! ############################################################################
MyCalendarClass.Construct PROCEDURE
  CODE
  SELF.DatePicture = '@d17'
  SELF.Reset()


MyCalendarClass.Reset PROCEDURE
  CODE
  SELF.Date1    = 0
  SELF.Date2    = 0
  SELF.Anchor   = TODAY()
  SELF.Dragging = 0
  SELF.DragFrom = 0


! ############################################################################
!  Theme
! ############################################################################
!  Reads the CapeSoft Makeover style file into the colours, so the pop-up looks
!  like the windows around it:
!    paper / ink        <- ListColor / ListFontColor
!    month name, picked <- [BandSection] BarStartColor, the theme's own colour;
!                          else AccentFontColor, optional (picked text = the paper)
!    weekends, day names<- InactiveTabFontColor
!    rules              <- GridColor
!    range              <- 25 % of the way from the paper to the accent
!    window, prompt     <- BackgroundColor, TextFontColor
!    buttons            <- FlatButtons, ButtonFontColor (else TextFontColor)
!    top band           <- [BandSection] BgColor (half way to BgColorEnd) /
!                          FontColor, when a section is named
!  A key the theme does not have keeps the colour it had.
MyCalendarClass.LoadTheme PROCEDURE()
sty          CSTRING(261)
sect         CSTRING(80)
dflt         CSTRING(80)
  CODE
  SELF.Themed = 0
  sty = CLIP(LEFT(SELF.StyleFile))
  IF ~sty THEN RETURN 0 .
  IF ~EXISTS(sty) THEN RETURN 0 .
  dflt = CHOOSE(CLIP(SELF.StyleSet) <> '',CLIP(SELF.StyleSet),'Basic3')
  sect = dflt & ' ' & CHOOSE(CLIP(SELF.StyleType) <> '',CLIP(SELF.StyleType),'Window')
  dflt = dflt & ' Default'
  SELF.BackColor     = SELF.StyColor(sty,sect,dflt,'ListColor',SELF.BackColor)
  SELF.InkColor      = SELF.StyColor(sty,sect,dflt,'ListFontColor', |
                       SELF.StyColor(sty,sect,dflt,'TextFontColor',SELF.InkColor))
  SELF.TitleColor    = SELF.StyColor(sty,sect,dflt,'AccentFontColor',SELF.TitleColor)
  SELF.MutedColor    = SELF.StyColor(sty,sect,dflt,'InactiveTabFontColor',SELF.MutedColor)
  SELF.LineColor     = SELF.StyColor(sty,sect,dflt,'GridColor',SELF.LineColor)
  SELF.WinColor      = SELF.StyColor(sty,sect,dflt,'BackgroundColor',SELF.WinColor)
  SELF.TextColor     = SELF.StyColor(sty,sect,dflt,'TextFontColor',SELF.TextColor)
  SELF.ButtonColor   = SELF.StyColor(sty,sect,dflt,'ButtonFontColor',SELF.TextColor)
  SELF.FlatButtons   = SELF.StyColor(sty,sect,dflt,'FlatButtons',SELF.FlatButtons)
  IF CLIP(SELF.BandSection)                                 ! a header gradient: the band takes its middle
    SELF.BandColor     = SELF.StyColor(sty,SELF.BandSection,'','BgColor',SELF.BandColor)
    IF SELF.BandColor <> -1
      SELF.BandColor   = SELF.Blend(SELF.BandColor, |
                         SELF.StyColor(sty,SELF.BandSection,'','BgColorEnd',SELF.BandColor),50)
    END
    SELF.BandFontColor = SELF.StyColor(sty,SELF.BandSection,'','FontColor',SELF.BandFontColor)
    SELF.TitleColor    = SELF.StyColor(sty,SELF.BandSection,'','BarStartColor',SELF.TitleColor)
  END
  SELF.SelColor      = SELF.TitleColor
  SELF.SelTextColor  = SELF.BackColor
  SELF.RangeColor    = SELF.Blend(SELF.BackColor,SELF.SelColor,25)
  SELF.Themed = 1
  RETURN 1


!  One key from the style file: from pSect, else from pDflt. #RRGGBB (as the
!  STY writes it) or a plain number. Absent, invalid or -1 returns pCurrent.
!  pKeyC, not pKey: KEYCODES.CLW has PKey EQUATE(0050H) (labels ignore case).
MyCalendarClass.StyColor PROCEDURE(STRING pSty,STRING pSect,STRING pDflt,STRING pKeyC,LONG pCurrent)
v            CSTRING(41)
i            LONG,AUTO
d            LONG,AUTO
n            LONG,AUTO
  CODE
  v = CLIP(LEFT(GETINI(pSect,pKeyC,'',pSty)))
  IF ~v AND CLIP(pDflt) THEN v = CLIP(LEFT(GETINI(pDflt,pKeyC,'',pSty))) .
  IF ~v THEN RETURN pCurrent .
  IF v[1] = '#' AND LEN(v) = 7                              ! #RRGGBB -> Clarion 00BBGGRRh
    n = 0
    LOOP i = 2 TO 7
      d = INSTRING(UPPER(v[i]),'0123456789ABCDEF',1,1) - 1
      IF d < 0 THEN RETURN pCurrent .
      n = n * 16 + d
    END
    RETURN BOR(BOR(BSHIFT(BAND(n,0FFh),16),BAND(n,0FF00h)),BAND(BSHIFT(n,-16),0FFh))
  ELSIF NUMERIC(v)
    IF v = -1 THEN RETURN pCurrent .
    RETURN v
  END
  RETURN pCurrent


!  Mixes two colours channel by channel.
MyCalendarClass.Blend PROCEDURE(LONG pFrom,LONG pTo,LONG pPct)
r            LONG(0)
i            LONG,AUTO
a            LONG,AUTO
b            LONG,AUTO
  CODE
  LOOP i = 0 TO 16 BY 8
    a = BAND(BSHIFT(pFrom,-i),0FFh)
    b = BAND(BSHIFT(pTo,-i),0FFh)
    r = BOR(r,BSHIFT(a + INT((b - a) * pPct / 100),i))
  END
  RETURN r


! ############################################################################
!  Dates
! ############################################################################
!  Clarion stores a date as days since 1800-12-28, and date % 7 gives the day
!  of the week with 0 = Sunday. (Verified: 1801-01-01 was a Thursday and its
!  value 4 % 7 = 4.)
MyCalendarClass.DayOfWeek PROCEDURE(LONG pDate)
  CODE
  RETURN pDate % 7


MyCalendarClass.ColumnOf PROCEDURE(LONG pDate)
d  LONG,AUTO
  CODE
  d = pDate % 7                                             ! 0 = Sunday
  IF SELF.FirstDay = Cal:Monday THEN RETURN (d + 6) % 7 .   ! 0 = Monday
  RETURN d


MyCalendarClass.FirstOfMonth PROCEDURE(LONG pDate)
  CODE
  IF ~pDate THEN RETURN 0 .
  RETURN DATE(MONTH(pDate),1,YEAR(pDate))


!  The next month's first day minus this one's gives the length, and it copes
!  with leap years and the December wrap without a table.
MyCalendarClass.DaysInMonth PROCEDURE(LONG pMonth,LONG pYear)
  CODE
  IF pMonth >= 12 THEN RETURN DATE(1,1,pYear+1) - DATE(12,1,pYear) .
  RETURN DATE(pMonth+1,1,pYear) - DATE(pMonth,1,pYear)


MyCalendarClass.AddMonths PROCEDURE(LONG pDate,LONG pCount)
m   LONG,AUTO
y   LONG,AUTO
d   LONG,AUTO
n   LONG,AUTO
  CODE
  IF ~pDate THEN pDate = TODAY() .
  m = MONTH(pDate) + pCount
  y = YEAR(pDate)
  LOOP WHILE m > 12
    m -= 12
    y += 1
  END
  LOOP WHILE m < 1
    m += 12
    y -= 1
  END
  IF y < 1801 THEN y = 1801 .
  d = DAY(pDate)
  n = SELF.DaysInMonth(m,y)
  IF d > n THEN d = n .                                     ! 31 Jan + 1 month = 28/29 Feb
  RETURN DATE(m,d,y)


!  ISO-8601: the week belongs to the year that owns its Thursday.
MyCalendarClass.WeekNumber PROCEDURE(LONG pDate)
mon  LONG,AUTO
thu  LONG,AUTO
jan1 LONG,AUTO
  CODE
  IF ~pDate THEN RETURN 0 .
  mon  = (pDate % 7 + 6) % 7                                ! 0 = Monday
  thu  = pDate - mon + 3
  jan1 = DATE(1,1,YEAR(thu))
  RETURN INT((thu - jan1) / 7) + 1


MyCalendarClass.DateText PROCEDURE(LONG pDate)
  CODE
  IF ~pDate THEN RETURN '' .
  IF ~SELF.DatePicture THEN RETURN CLIP(LEFT(FORMAT(pDate,@d17))) .
  RETURN CLIP(LEFT(FORMAT(pDate,CLIP(SELF.DatePicture))))


! ############################################################################
!  Words
! ############################################################################
MyCalendarClass.MonthName PROCEDURE(LONG pMonth)
  CODE
  IF SELF.Language = Cal:Spanish
    CASE pMonth
    OF  1 ; RETURN 'Enero'
    OF  2 ; RETURN 'Febrero'
    OF  3 ; RETURN 'Marzo'
    OF  4 ; RETURN 'Abril'
    OF  5 ; RETURN 'Mayo'
    OF  6 ; RETURN 'Junio'
    OF  7 ; RETURN 'Julio'
    OF  8 ; RETURN 'Agosto'
    OF  9 ; RETURN 'Septiembre'
    OF 10 ; RETURN 'Octubre'
    OF 11 ; RETURN 'Noviembre'
    OF 12 ; RETURN 'Diciembre'
    END
    RETURN ''
  END
  CASE pMonth
  OF  1 ; RETURN 'January'
  OF  2 ; RETURN 'February'
  OF  3 ; RETURN 'March'
  OF  4 ; RETURN 'April'
  OF  5 ; RETURN 'May'
  OF  6 ; RETURN 'June'
  OF  7 ; RETURN 'July'
  OF  8 ; RETURN 'August'
  OF  9 ; RETURN 'September'
  OF 10 ; RETURN 'October'
  OF 11 ; RETURN 'November'
  OF 12 ; RETURN 'December'
  END
  RETURN ''


!  pCol is a screen column, so it already honours FirstDay.
MyCalendarClass.DayName PROCEDURE(LONG pCol)
d  LONG,AUTO
  CODE
  d = pCol
  IF SELF.FirstDay = Cal:Monday THEN d = (pCol + 1) % 7 .   ! back to 0 = Sunday
  IF SELF.Language = Cal:Spanish
    CASE d
    OF 0 ; RETURN 'Do'
    OF 1 ; RETURN 'Lu'
    OF 2 ; RETURN 'Ma'
    OF 3 ; RETURN 'Mi'
    OF 4 ; RETURN 'Ju'
    OF 5 ; RETURN 'Vi'
    OF 6 ; RETURN 'Sa'
    END
    RETURN ''
  END
  CASE d
  OF 0 ; RETURN 'Su'
  OF 1 ; RETURN 'Mo'
  OF 2 ; RETURN 'Tu'
  OF 3 ; RETURN 'We'
  OF 4 ; RETURN 'Th'
  OF 5 ; RETURN 'Fr'
  OF 6 ; RETURN 'Sa'
  END
  RETURN ''


!  The Spanish strings spell their accents as Clarion <nnn> escapes rather
!  than raw high bytes: 225 = a-acute, 237 = i-acute, 241 = n-tilde,
!  243 = o-acute. That keeps this file pure ASCII, so no editor can quietly
!  rewrite it as UTF-8 and turn every accent into a question mark.
MyCalendarClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Cal:Spanish
    CASE pId
    OF CTx:Calendar      ; RETURN 'Calendario'
    OF CTx:View          ; RETURN '&Vista:'
    OF CTx:OneMonth      ; RETURN 'Un mes'
    OF CTx:TwoMonths     ; RETURN 'Dos meses'
    OF CTx:ThreeMonths   ; RETURN 'Tres meses'
    OF CTx:SixMonths     ; RETURN 'Seis meses'
    OF CTx:Year          ; RETURN 'Un a<241>o'
    OF CTx:Today         ; RETURN 'Ho&y'
    OF CTx:Accept        ; RETURN '&Aceptar'
    OF CTx:Cancel        ; RETURN 'Cancelar'
    OF CTx:Clear         ; RETURN '&Limpiar'
    OF CTx:From          ; RETURN 'Desde'
    OF CTx:To            ; RETURN 'hasta'
    OF CTx:Date          ; RETURN 'Fecha'
    OF CTx:HintSingle    ; RETURN 'Haz clic en un d<237>a.   Esc = cerrar'
    OF CTx:HintRange     ; RETURN 'Arrastra para marcar un rango.   Esc = cerrar'
    OF CTx:Days          ; RETURN 'd<237>as'
    OF CTx:PrevYear      ; RETURN 'A<241>o anterior'
    OF CTx:PrevMonth     ; RETURN 'Mes anterior'
    OF CTx:NextMonth     ; RETURN 'Mes siguiente'
    OF CTx:NextYear      ; RETURN 'A<241>o siguiente'
    OF CTx:Week          ; RETURN 'Sm'
    OF CTx:NothingPicked ; RETURN 'Elige una fecha primero.'
    OF CTx:OutOfRange    ; RETURN 'Esa fecha est<225> fuera de los l<237>mites permitidos.'
    OF CTx:Layout        ; RETURN 'Disposici<243>n'
    OF CTx:Across        ; RETURN 'En fila'
    OF CTx:Down          ; RETURN 'En columna'
    END
    RETURN ''
  END
  CASE pId
  OF CTx:Calendar      ; RETURN 'Calendar'
  OF CTx:View          ; RETURN '&View:'
  OF CTx:OneMonth      ; RETURN 'One month'
  OF CTx:TwoMonths     ; RETURN 'Two months'
  OF CTx:ThreeMonths   ; RETURN 'Three months'
  OF CTx:SixMonths     ; RETURN 'Six months'
  OF CTx:Year          ; RETURN 'Full year'
  OF CTx:Today         ; RETURN 'Toda&y'
  OF CTx:Accept        ; RETURN '&Accept'
  OF CTx:Cancel        ; RETURN 'Cancel'
  OF CTx:Clear         ; RETURN 'C&lear'
  OF CTx:From          ; RETURN 'From'
  OF CTx:To            ; RETURN 'to'
  OF CTx:Date          ; RETURN 'Date'
  OF CTx:HintSingle    ; RETURN 'Click a day.   Esc = close'
  OF CTx:HintRange     ; RETURN 'Drag to mark a range.   Esc = close'
  OF CTx:Days          ; RETURN 'days'
  OF CTx:PrevYear      ; RETURN 'Previous year'
  OF CTx:PrevMonth     ; RETURN 'Previous month'
  OF CTx:NextMonth     ; RETURN 'Next month'
  OF CTx:NextYear      ; RETURN 'Next year'
  OF CTx:Week          ; RETURN 'Wk'
  OF CTx:NothingPicked ; RETURN 'Pick a date first.'
  OF CTx:OutOfRange    ; RETURN 'That date is outside the range you are allowed to pick.'
  OF CTx:Layout        ; RETURN 'Layout'
  OF CTx:Across        ; RETURN 'Across'
  OF CTx:Down          ; RETURN 'Down'
  END
  RETURN ''


! ############################################################################
!  Selecting
! ############################################################################
MyCalendarClass.Pickable PROCEDURE(LONG pDate)
d  LONG,AUTO
  CODE
  IF ~pDate THEN RETURN 0 .
  IF SELF.MinDate AND pDate < SELF.MinDate THEN RETURN 0 .
  IF SELF.MaxDate AND pDate > SELF.MaxDate THEN RETURN 0 .
  IF SELF.NoWeekends
    d = pDate % 7
    IF d = 0 OR d = 6 THEN RETURN 0 .                       ! Sunday or Saturday
  END
  RETURN 1


MyCalendarClass.SetDate PROCEDURE(LONG pDate)
  CODE
  SELF.Date1 = pDate
  SELF.Date2 = 0
  IF pDate THEN SELF.Anchor = pDate .


MyCalendarClass.SetRange PROCEDURE(LONG pFrom,LONG pTo)
t  LONG,AUTO
  CODE
  IF pFrom AND pTo AND pTo < pFrom                          ! accept them either way round
    t = pFrom ; pFrom = pTo ; pTo = t
  END
  SELF.Date1 = pFrom
  SELF.Date2 = pTo
  IF pFrom THEN SELF.Anchor = pFrom .


MyCalendarClass.GoToday PROCEDURE
  CODE
  SELF.Anchor = TODAY()


MyCalendarClass.GoMonth PROCEDURE(LONG pDelta)
  CODE
  SELF.Anchor = SELF.AddMonths(SELF.Anchor,pDelta)


MyCalendarClass.GoYear PROCEDURE(LONG pDelta)
  CODE
  SELF.Anchor = SELF.AddMonths(SELF.Anchor,pDelta * 12)


!  A click. In single mode it just moves the date; in range mode the first
!  click starts a range and the second closes it.
MyCalendarClass.Pick PROCEDURE(LONG pDate)
  CODE
  IF ~SELF.Pickable(pDate) THEN RETURN .
  IF SELF.Selection = Cal:Single
    SELF.Date1 = pDate
    SELF.Date2 = 0
    RETURN
  END
  IF ~SELF.Date1 OR SELF.Date2                              ! start a fresh range
    SELF.Date1 = pDate
    SELF.Date2 = 0
  ELSE
    SELF.SetRange(SELF.Date1,pDate)                         ! close it, either way round
  END


MyCalendarClass.Days PROCEDURE()
  CODE
  IF ~SELF.Date1 THEN RETURN 0 .
  IF ~SELF.Date2 THEN RETURN 1 .
  RETURN SELF.Date2 - SELF.Date1 + 1


MyCalendarClass.InSelection PROCEDURE(LONG pDate)
  CODE
  RETURN SELF.StateIn(pDate,SELF.Date1,SELF.Date2)


!  The same question against an arbitrary pair, so DrawChanged can ask what a
!  day USED to look like after Date1/Date2 have already moved on.
MyCalendarClass.StateIn PROCEDURE(LONG pDate,LONG pFrom,LONG pTo)
  CODE
  IF ~pDate OR ~pFrom THEN RETURN 0 .
  IF pDate = pFrom OR pDate = pTo THEN RETURN 1 .
  IF pTo AND pDate > pFrom AND pDate < pTo THEN RETURN 2 .
  RETURN 0


! ############################################################################
!  Layout, drawing and hit testing
! ############################################################################
MyCalendarClass.Layout PROCEDURE
sw  LONG,AUTO
  CODE
  CASE SELF.Months
  OF  1 ; SELF.GridCols = 1 ; SELF.GridRows = 1
  OF  2 ; SELF.GridCols = 2 ; SELF.GridRows = 1
  OF  3 ; SELF.GridCols = 3 ; SELF.GridRows = 1
  OF  6 ; SELF.GridCols = 3 ; SELF.GridRows = 2
  OF 12 ; SELF.GridCols = 4 ; SELF.GridRows = 3
  ELSE
    SELF.Months   = 1
    SELF.GridCols = 1
    SELF.GridRows = 1
  END
  IF SELF.Orient = Cal:Down AND SELF.Months > 1             ! stack them the other way:
    sw            = SELF.GridCols                           ! 2 -> 1x2, 3 -> 1x3,
    SELF.GridCols = SELF.GridRows                           ! 6 -> 2x3, 12 -> 3x4
    SELF.GridRows = sw
  END
  SELF.BlockW  = 7 * Cal:CellW + CHOOSE(SELF.ShowWeekNo = 1,Cal:WeekW,0)
  SELF.BlockH  = Cal:TitleH + Cal:DayH + Cal:Weeks * Cal:CellH
  SELF.CanvasW = SELF.GridCols * SELF.BlockW + (SELF.GridCols - 1) * Cal:Gap
  SELF.CanvasH = SELF.GridRows * SELF.BlockH + (SELF.GridRows - 1) * Cal:Gap


MyCalendarClass.Draw PROCEDURE(WINDOW pWin,SIGNED pImage)
i      LONG,AUTO
first  LONG,AUTO
  CODE
  SELF.Layout()
  SELF.Canvas = pImage
  SETTARGET(pWin,pImage)                                    ! 0,0 is the image's top-left
  SETPENCOLOR(SELF.BackColor)                               ! BOX outlines in the current pen
  BOX(0,0,SELF.CanvasW,SELF.CanvasH,SELF.BackColor)         ! clear, or the old month shows through
  first = SELF.FirstOfMonth(CHOOSE(SELF.Anchor <> 0,SELF.Anchor,TODAY()))
  LOOP i = 0 TO SELF.Months - 1
    SELF.DrawMonth(SELF.AddMonths(first,i), |
                   (i % SELF.GridCols) * (SELF.BlockW + Cal:Gap), |
                   INT(i / SELF.GridCols) * (SELF.BlockH + Cal:Gap))
  END
  SETTARGET()


MyCalendarClass.DrawMonth PROCEDURE(LONG pFirst,LONG pX,LONG pY)
m     LONG,AUTO
y4    LONG,AUTO
n     LONG,AUTO
col0  LONG,AUTO
dd    LONG,AUTO
d     LONG,AUTO
idx   LONG,AUTO
row   LONG,AUTO
col   LONG,AUTO
cx    LONG,AUTO
cy    LONG,AUTO
gx    LONG,AUTO
sel   BYTE,AUTO
dow   LONG,AUTO
lastrow LONG(-1)
t     CSTRING(48)
  CODE
  m    = MONTH(pFirst)
  y4   = YEAR(pFirst)
  n    = SELF.DaysInMonth(m,y4)
  col0 = SELF.ColumnOf(pFirst)
  gx   = pX + CHOOSE(SELF.ShowWeekNo = 1,Cal:WeekW,0)       ! where the day columns start

! ---- the month name -------------------------------------------------------
  t = CLIP(SELF.MonthName(m)) & ' ' & y4
!  SHOW() writes in the window's FONT colour, not the pen's - see Ink().
  SELF.Ink(SELF.TitleColor)
  SHOW(pX + INT(SELF.BlockW / 2) - INT(LEN(t) * Cal:CharW / 2), pY + 2, t)

! ---- the day-name row -----------------------------------------------------
  SELF.Ink(SELF.MutedColor)
  LOOP col = 0 TO 6
    t = SELF.DayName(col)
    SHOW(gx + col * Cal:CellW + INT((Cal:CellW - LEN(t) * Cal:CharW) / 2), pY + Cal:TitleH, t)
  END
  IF SELF.ShowWeekNo
    t = SELF.Txt(CTx:Week)
    SHOW(pX + 2, pY + Cal:TitleH, t)
  END
  SETPENCOLOR(SELF.LineColor)
  LINE(pX, pY + Cal:TitleH + Cal:DayH - 2, SELF.BlockW, 0)

! ---- the days -------------------------------------------------------------
  LOOP dd = 1 TO n
    d   = pFirst + dd - 1
    idx = col0 + dd - 1
    row = INT(idx / 7)
    col = idx % 7
    cx  = gx + col * Cal:CellW
    cy  = pY + Cal:TitleH + Cal:DayH + row * Cal:CellH
    SELF.DrawCell(d, cx, cy, 0)                             ! 0 = no erase, Draw cleared already
!   One number per week row, keyed off the first day DRAWN in that row - the
!   opening row may have no Monday at all, and it still needs its number.
    IF SELF.ShowWeekNo AND row <> lastrow
      lastrow = row
      SELF.Ink(SELF.MutedColor)
      t = SELF.WeekNumber(d)
      t = CLIP(LEFT(t))
      SHOW(pX + Cal:WeekW - 3 - LEN(t) * Cal:CharW, cy + 2, t)
    END
  END


!  One day cell, at a coordinate the caller worked out. Everything that makes a
!  day look the way it does lives here, so the full repaint and the one-cell
!  repaint can never drift apart.
!    pErase - 1 when painting over a cell that is already on screen. The full
!             Draw() clears the whole canvas first and passes 0, which saves a
!             BOX per cell over a year.
MyCalendarClass.DrawCell PROCEDURE(LONG pDate,LONG pX,LONG pY,BYTE pErase)
sel  BYTE,AUTO
dow  LONG,AUTO
t    CSTRING(12)
  CODE
  sel = SELF.InSelection(pDate)
!  BOX outlines the rectangle in the CURRENT pen, so the pen has to be set
!  every time - otherwise a cell borrows whatever colour the last thing drawn
!  left behind, and the same day comes out differently depending on what was
!  painted before it. Pen = fill gives a clean edge-to-edge wash.
  IF pErase
    SETPENCOLOR(SELF.BackColor)
    BOX(pX, pY, Cal:CellW, Cal:CellH, SELF.BackColor)
  END
  IF sel = 2
    SETPENCOLOR(SELF.RangeColor)
    BOX(pX, pY, Cal:CellW, Cal:CellH, SELF.RangeColor)
  ELSIF sel = 1
    SETPENCOLOR(SELF.SelColor)
    BOX(pX, pY, Cal:CellW, Cal:CellH, SELF.SelColor)
  END
  IF SELF.ShowToday AND pDate = TODAY()                     ! a ring, so it survives a fill
    SETPENCOLOR(SELF.TodayColor)
    LINE(pX, pY, Cal:CellW - 1, 0)
    LINE(pX, pY + Cal:CellH - 1, Cal:CellW - 1, 0)
    LINE(pX, pY, 0, Cal:CellH - 1)
    LINE(pX + Cal:CellW - 1, pY, 0, Cal:CellH - 1)
  END
  dow = pDate % 7
  IF sel = 1
    SELF.Ink(SELF.SelTextColor)
  ELSIF ~SELF.Pickable(pDate) OR dow = 0 OR dow = 6
    SELF.Ink(SELF.MutedColor)
  ELSE
    SELF.Ink(SELF.InkColor)
  END
  t = DAY(pDate)
  t = CLIP(LEFT(t))
  SHOW(pX + Cal:CellW - 3 - LEN(t) * Cal:CharW, pY + 2, t)


!  The colour for what is drawn next. SETPENCOLOR covers LINE and the BOX
!  edges only: SHOW() writes in the window's current FONT, so text needs the
!  font colour too. SETFONT(0,...) sets the window's default font, which leaves
!  existing controls alone; every argument is passed, because an omitted one
!  falls back to the system font, not to the window's.
MyCalendarClass.Ink PROCEDURE(LONG pColor)
  CODE
  SETPENCOLOR(pColor)
  SETFONT(0,TARGET{PROP:FontName},TARGET{PROP:FontSize},pColor, |
          TARGET{PROP:FontStyle},TARGET{PROP:FontCharSet})


!  Where a date's cell is on the canvas - the exact reverse of DateAt, and the
!  same arithmetic Draw uses. Returns 0 if that date is not on screen.
MyCalendarClass.CellAt PROCEDURE(LONG pDate,*LONG pX,*LONG pY)
first LONG,AUTO
bi    LONG,AUTO
idx   LONG,AUTO
gx    LONG,AUTO
  CODE
  pX = 0
  pY = 0
  IF ~pDate THEN RETURN 0 .
  SELF.Layout()
  first = SELF.FirstOfMonth(CHOOSE(SELF.Anchor <> 0,SELF.Anchor,TODAY()))
  bi    = (YEAR(pDate) - YEAR(first)) * 12 + MONTH(pDate) - MONTH(first)
  IF bi < 0 OR bi >= SELF.Months THEN RETURN 0 .            ! not one of the months shown
  gx  = (bi % SELF.GridCols) * (SELF.BlockW + Cal:Gap) + |
        CHOOSE(SELF.ShowWeekNo = 1,Cal:WeekW,0)
  idx = SELF.ColumnOf(SELF.FirstOfMonth(pDate)) + DAY(pDate) - 1
  pX  = gx + (idx % 7) * Cal:CellW
  pY  = INT(bi / SELF.GridCols) * (SELF.BlockH + Cal:Gap) + |
        Cal:TitleH + Cal:DayH + INT(idx / 7) * Cal:CellH
  RETURN 1


!  Repaint a single day where it sits, leaving the rest of the canvas alone.
MyCalendarClass.DrawDay PROCEDURE(WINDOW pWin,SIGNED pImage,LONG pDate)
cx LONG,AUTO
cy LONG,AUTO
  CODE
  IF ~SELF.CellAt(pDate,cx,cy) THEN RETURN .
  SELF.Canvas = pImage
  SETTARGET(pWin,pImage)
  SELF.DrawCell(pDate,cx,cy,1)
  SETTARGET()


!  The selection has just changed from (pOldFrom,pOldTo) to whatever Date1 and
!  Date2 now say. Repaint ONLY the days that look different because of it, and
!  return how many that was.
!
!  This is the whole reason a drag across a year is smooth: dragging the end of
!  a range by one day repaints one or two cells instead of the ~1,100 drawing
!  calls a full Draw() of a twelve-month canvas costs.
MyCalendarClass.DrawChanged PROCEDURE(WINDOW pWin,SIGNED pImage,LONG pOldFrom,LONG pOldTo)
lo LONG(0)
hi LONG(0)
a  LONG,AUTO
b  LONG,AUTO
d  LONG,AUTO
n  LONG(0)
cx LONG,AUTO
cy LONG,AUTO
  CODE
  IF pOldFrom                                               ! the span the old range covered
    lo = pOldFrom
    hi = CHOOSE(pOldTo <> 0,pOldTo,pOldFrom)
  END
  IF SELF.Date1                                             ! ...widened by the new one
    a = SELF.Date1
    b = CHOOSE(SELF.Date2 <> 0,SELF.Date2,SELF.Date1)
    IF ~lo OR a < lo THEN lo = a .
    IF b > hi         THEN hi = b .
  END
  IF ~lo THEN RETURN 0 .                                    ! nothing was selected either way
  SELF.Canvas = pImage
  SETTARGET(pWin,pImage)
  LOOP d = lo TO hi
    IF SELF.StateIn(d,pOldFrom,pOldTo) <> SELF.StateIn(d,SELF.Date1,SELF.Date2)
      IF SELF.CellAt(d,cx,cy)                               ! skip anything scrolled off
        SELF.DrawCell(d,cx,cy,1)
        n += 1
      END
    END
  END
  SETTARGET()
  RETURN n


!  x,y are relative to the image's top-left, the same space Draw uses.
MyCalendarClass.DateAt PROCEDURE(LONG pX,LONG pY)
i      LONG,AUTO
first  LONG,AUTO
ox     LONG,AUTO
oy     LONG,AUTO
gx     LONG,AUTO
lx     LONG,AUTO
ly     LONG,AUTO
col    LONG,AUTO
row    LONG,AUTO
idx    LONG,AUTO
dd     LONG,AUTO
mfirst LONG,AUTO
  CODE
  IF pX < 0 OR pY < 0 OR pX >= SELF.CanvasW OR pY >= SELF.CanvasH THEN RETURN 0 .
  first = SELF.FirstOfMonth(CHOOSE(SELF.Anchor <> 0,SELF.Anchor,TODAY()))
  LOOP i = 0 TO SELF.Months - 1
    ox = (i % SELF.GridCols) * (SELF.BlockW + Cal:Gap)
    oy = INT(i / SELF.GridCols) * (SELF.BlockH + Cal:Gap)
    IF pX < ox OR pX >= ox + SELF.BlockW THEN CYCLE .
    IF pY < oy OR pY >= oy + SELF.BlockH THEN CYCLE .
    gx = ox + CHOOSE(SELF.ShowWeekNo = 1,Cal:WeekW,0)
    lx = pX - gx
    ly = pY - (oy + Cal:TitleH + Cal:DayH)
    IF lx < 0 OR ly < 0 THEN RETURN 0 .                     ! the title or day-name strip
    col = INT(lx / Cal:CellW)
    row = INT(ly / Cal:CellH)
    IF col > 6 OR row >= Cal:Weeks THEN RETURN 0 .
    mfirst = SELF.AddMonths(first,i)
    mfirst = SELF.FirstOfMonth(mfirst)
    idx = row * 7 + col
    dd  = idx - SELF.ColumnOf(mfirst) + 1
    IF dd < 1 OR dd > SELF.DaysInMonth(MONTH(mfirst),YEAR(mfirst)) THEN RETURN 0 .
    RETURN mfirst + dd - 1
  END
  RETURN 0


! ############################################################################
!  Remembering the last session
! ############################################################################
!  The view, the first day of the week and the week-number gutter are all
!  things the user changes in the window, so they come back next time.
!  Language is NOT saved - it is a developer setting from the template, and
!  remembering it would let an old value shadow whatever the template says.
MyCalendarClass.IniPath PROCEDURE()
nm  CSTRING(261)
n   ULONG,AUTO
i   LONG,AUTO
cut LONG(0)
  CODE
  IF CLIP(LEFT(SELF.IniFile)) THEN RETURN CLIP(LEFT(SELF.IniFile)) .
  nm = ''
  n  = cdModuleFile(0,nm,260)
  IF ~n THEN RETURN '' .
  LOOP i = LEN(nm) TO 1 BY -1
    IF nm[i] = '\' OR nm[i] = '/' THEN BREAK .
    IF nm[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN nm = SUB(nm,1,cut-1) .
  RETURN CLIP(nm) & '.INI'


MyCalendarClass.IniSection PROCEDURE()
p  CSTRING(65)
  CODE
  p = CLIP(LEFT(SELF.Profile))
  IF ~p THEN p = 'Default' .
  RETURN 'myCalendar_' & p


MyCalendarClass.LoadSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  SELF.Loaded = 1
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  SELF.Months     = GETINI(sect,'Months',SELF.Months,f)
  SELF.Orient     = GETINI(sect,'Orient',SELF.Orient,f)
  SELF.FirstDay   = GETINI(sect,'FirstDay',SELF.FirstDay,f)
  SELF.ShowWeekNo = GETINI(sect,'ShowWeekNo',SELF.ShowWeekNo,f)
  SELF.ShowToday  = GETINI(sect,'ShowToday',SELF.ShowToday,f)
  CASE SELF.Months                                          ! never restore rubbish
  OF 1 OROF 2 OROF 3 OROF 6 OROF 12
  ELSE
    SELF.Months = 1
  END
  IF SELF.FirstDay > 1 THEN SELF.FirstDay = 0 .
  IF SELF.Orient   > 1 THEN SELF.Orient   = 0 .


MyCalendarClass.SaveSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Months',SELF.Months,f)
  PUTINI(sect,'Orient',SELF.Orient,f)
  PUTINI(sect,'FirstDay',SELF.FirstDay,f)
  PUTINI(sect,'ShowWeekNo',SELF.ShowWeekNo,f)
  PUTINI(sect,'ShowToday',SELF.ShowToday,f)


MyCalendarClass.ForgetSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Months','',f)
  PUTINI(sect,'Orient','',f)
  PUTINI(sect,'FirstDay','',f)
  PUTINI(sect,'ShowWeekNo','',f)
  PUTINI(sect,'ShowToday','',f)
  SELF.Loaded = 0


! ############################################################################
!  Seed from fields, and put the answer back
! ############################################################################
MyCalendarClass.AskFor PROCEDURE(*? pDate)
  CODE
  SELF.Selection = Cal:Single
  SELF.SetDate(pDate)
  IF ~SELF.Ask() THEN RETURN 0 .
  pDate = SELF.Date1
  RETURN 1


MyCalendarClass.AskRange PROCEDURE(*? pFrom,*? pTo)
  CODE
  SELF.Selection = Cal:Range
  SELF.SetRange(pFrom,pTo)
  IF ~SELF.Ask() THEN RETURN 0 .
  pFrom = SELF.Date1
  pTo   = CHOOSE(SELF.Date2 <> 0,SELF.Date2,SELF.Date1)     ! one day picked = a one-day range
  RETURN 1
! ############################################################################
!  The pop-up
! ############################################################################
!  One window serves every view: Relayout resizes the canvas and the window to
!  whatever Layout() worked out, and moves the footer down to meet it.
!
!  The IMAGE is what gets drawn into; the REGION on top of it (IMM) is what
!  reports the mouse. MOUSEX/MOUSEY are window-relative in the same dialog
!  units as PROP:Xpos, so subtracting the canvas position gives the exact
!  coordinate space Draw() used - and the hit test is plain arithmetic.
MyCalendarClass.Ask PROCEDURE()
MonQ         QUEUE,PRE(MOQ)
MOName         STRING(20)
             END
ViewQ        QUEUE,PRE(VWQ)
VWName         STRING(20)
VWCount        LONG
             END
LayQ         QUEUE,PRE(LYQ)
LYName         STRING(20)
LYId           LONG
             END
i            LONG,AUTO
d            LONG,AUTO
hover        LONG(0)
moved        BYTE(0)
pend         LONG(0)
of1          LONG(0)                                        ! the selection before the mouse
of2          LONG(0)                                        ! touched it - see the Touched routine
anc          LONG(0)                                        ! the view's anchor, held still while dragging
winW         LONG,AUTO
cx           LONG,AUTO
cy           LONG,AUTO
fy           LONG,AUTO
navr         LONG,AUTO                                      ! rows the nav strip is wrapped onto
tf           LONG,AUTO                                      ! a control, in the Theme routine
CYear        LONG
CalWnd WINDOW('Calendar'),AT(,,372,252),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI), |
         CENTER,GRAY,SYSTEM,MODAL,ALRT(EscKey)
           PANEL,AT(0,0,372,32),USE(?CBand),FILL(0603A1FH)
           STRING(''),AT(12,5),USE(?CTitle),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
           STRING(''),AT(12,18),USE(?CSub),FONT('Segoe UI',8,0D8C8B4H),TRN
           BUTTON('<<<<'),AT(10,38,16,12),USE(?CPY)
           BUTTON('<<'),AT(28,38,14,12),USE(?CPM)
           LIST,AT(45,39,76,10),USE(?CMonth),DROP(12),FROM(MonQ),FORMAT('72L(2)@s20@')
           SPIN(@n4),AT(124,39,34,10),USE(CYear),RANGE(1801,2500),STEP(1)
           BUTTON('>'),AT(162,38,14,12),USE(?CNM)
           BUTTON('>>'),AT(178,38,16,12),USE(?CNY)
           BUTTON(''),AT(200,38,42,12),USE(?CToday)
           PROMPT(''),AT(250,40),USE(?CViewP)
           LIST,AT(278,39,82,10),USE(?CView),DROP(6),FROM(ViewQ),FORMAT('78L(2)@s20@')
           LIST,AT(278,39,66,10),USE(?CLay),DROP(3),FROM(LayQ),FORMAT('62L(2)@s20@')
           IMAGE,AT(12,58,126,95),USE(?CCanvas)
           REGION,AT(12,58,126,95),USE(?CHot),IMM
           PANEL,AT(12,160,348,1),USE(?CRule),FILL(00D4D0CCH)
           STRING(''),AT(12,167,250,10),USE(?CPick),FONT('Segoe UI',9,0603A1FH,FONT:bold),TRN
           STRING(''),AT(12,178,250,10),USE(?CHint),FONT('Segoe UI',8,00808080H),TRN
           BUTTON(''),AT(196,192,44,14),USE(?CClear)
           BUTTON(''),AT(244,192,54,14),USE(?COk)
           BUTTON(''),AT(302,192,54,14),USE(?CCancel)
         END
  CODE
  IF SELF.Language <> Cal:Spanish THEN SELF.Language = Cal:English .
  IF SELF.Persist AND ~SELF.Loaded THEN SELF.LoadSettings() .
  IF ~SELF.Anchor THEN SELF.Anchor = TODAY() .
  SELF.Accepted = 0
  SELF.Dragging = 0
  LOOP i = 1 TO 12
    MOQ:MOName = SELF.MonthName(i)
    ADD(MonQ)
  END
  VWQ:VWName = SELF.Txt(CTx:OneMonth)    ; VWQ:VWCount = 1  ; ADD(ViewQ)
  VWQ:VWName = SELF.Txt(CTx:TwoMonths)   ; VWQ:VWCount = 2  ; ADD(ViewQ)
  VWQ:VWName = SELF.Txt(CTx:ThreeMonths) ; VWQ:VWCount = 3  ; ADD(ViewQ)
  VWQ:VWName = SELF.Txt(CTx:SixMonths)   ; VWQ:VWCount = 6  ; ADD(ViewQ)
  VWQ:VWName = SELF.Txt(CTx:Year)        ; VWQ:VWCount = 12 ; ADD(ViewQ)
  LYQ:LYName = SELF.Txt(CTx:Across) ; LYQ:LYId = Cal:Across ; ADD(LayQ)
  LYQ:LYName = SELF.Txt(CTx:Down)   ; LYQ:LYId = Cal:Down   ; ADD(LayQ)
  SELF.LoadTheme()
  OPEN(CalWnd)
  DO Theme
  ?CTitle{PROP:Text}  = CHOOSE(CLIP(SELF.Title) <> '',CLIP(SELF.Title),SELF.Txt(CTx:Calendar))
  0{PROP:Text}        = ?CTitle{PROP:Text}
  ?CViewP{PROP:Text}  = SELF.Txt(CTx:View)
  ?CToday{PROP:Text}  = SELF.Txt(CTx:Today)
  ?COk{PROP:Text}     = SELF.Txt(CTx:Accept)
  ?CCancel{PROP:Text} = SELF.Txt(CTx:Cancel)
  ?CClear{PROP:Text}  = SELF.Txt(CTx:Clear)
  ?CPY{PROP:Tip}      = SELF.Txt(CTx:PrevYear)
  ?CPM{PROP:Tip}      = SELF.Txt(CTx:PrevMonth)
  ?CNM{PROP:Tip}      = SELF.Txt(CTx:NextMonth)
  ?CNY{PROP:Tip}      = SELF.Txt(CTx:NextYear)
  ?CLay{PROP:Tip}     = SELF.Txt(CTx:Layout)
  ?CHint{PROP:Text}   = CHOOSE(SELF.Selection = Cal:Range, |
                               SELF.Txt(CTx:HintRange),SELF.Txt(CTx:HintSingle))
  ?CSub{PROP:Text}    = CHOOSE(SELF.Selection = Cal:Range, |
                               SELF.Txt(CTx:HintRange),SELF.Txt(CTx:HintSingle))
  DO Relayout
  DO SyncNav
  DO Repaint
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Repaint                                            ! paint once the window is really up
    OF EVENT:AlertKey
      IF KEYCODE() = EscKey THEN POST(EVENT:CloseWindow) .
    END
    CASE FIELD()
!  ---- the canvas: click to pick, drag to sweep a range --------------------
    OF ?CHot
      CASE EVENT()
      OF EVENT:MouseDown
        pend  = SELF.DateAt(MOUSEX() - ?CCanvas{PROP:Xpos},MOUSEY() - ?CCanvas{PROP:Ypos})
        moved = 0
        hover = 0
        IF pend AND SELF.Pickable(pend)
!         Pressing on a day STARTS OVER. Whatever was marked before is gone and
!         this day is the anchor - so a sweep never leaves a stale range behind
!         and the user always ends up with exactly what they just dragged.
          SELF.Dragging = CHOOSE(SELF.Selection = Cal:Range,1,0)
          of1           = SELF.Date1
          of2           = SELF.Date2
          SELF.Date1    = pend
          SELF.Date2    = 0
          DO Touched
        ELSE
          pend = 0
        END
      OF EVENT:MouseMove
        IF SELF.Dragging AND pend
          d = SELF.DateAt(MOUSEX() - ?CCanvas{PROP:Xpos},MOUSEY() - ?CCanvas{PROP:Ypos})
          IF d AND d <> hover
            hover = d
            moved = 1
            of1   = SELF.Date1
            of2   = SELF.Date2
            anc   = SELF.Anchor
            SELF.SetRange(pend,d)                           ! live, while the button is down;
            SELF.Anchor = anc                               ! backwards is fine, SetRange sorts
!           SetRange moves the anchor to the start of the range, and the anchor
!           is what decides which month is drawn first. Put it back, or sweeping
!           up from a later month scrolls the view out from under the mouse.
            DO Touched                                      ! only the cells that changed
          END
        END
      OF EVENT:MouseUp
        IF SELF.Dragging
          SELF.Dragging = 0                                 ! MouseDown already anchored it,
        END                                                 ! so a click with no sweep is one day
        pend = 0
      END
!  ---- navigation -----------------------------------------------------------
    OF ?CPY
      IF EVENT() = EVENT:Accepted
        SELF.GoYear(-1)
        DO Moved
      END
    OF ?CPM
      IF EVENT() = EVENT:Accepted
        SELF.GoMonth(-1)
        DO Moved
      END
    OF ?CNM
      IF EVENT() = EVENT:Accepted
        SELF.GoMonth(1)
        DO Moved
      END
    OF ?CNY
      IF EVENT() = EVENT:Accepted
        SELF.GoYear(1)
        DO Moved
      END
    OF ?CToday
      IF EVENT() = EVENT:Accepted
        SELF.GoToday()
        DO Moved
      END
    OF ?CMonth
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        i = CHOICE(?CMonth)
        IF i AND CYear
          SELF.Anchor = DATE(i,1,CYear)
          DO Repaint
        END
      END
    OF ?CYear
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        IF CYear >= 1801 AND CYear <= 2500
          SELF.Anchor = DATE(CHOOSE(CHOICE(?CMonth) > 0,CHOICE(?CMonth),MONTH(SELF.Anchor)),1,CYear)
          DO Repaint
        END
      END
    OF ?CView
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        i = CHOICE(?CView)
        IF i
          GET(ViewQ,i)
          IF ~ERRORCODE() AND VWQ:VWCount <> SELF.Months
            SELF.Months = VWQ:VWCount
            DO Relayout
            DO Repaint
          END
        END
      END
    OF ?CLay
      IF EVENT() = EVENT:Accepted OR EVENT() = EVENT:NewSelection
        i = CHOICE(?CLay)
        IF i
          GET(LayQ,i)
          IF ~ERRORCODE() AND LYQ:LYId <> SELF.Orient
            SELF.Orient = LYQ:LYId
            DO Relayout
            DO Repaint
          END
        END
      END
!  ---- footer ---------------------------------------------------------------
    OF ?CClear
      IF EVENT() = EVENT:Accepted
        of1        = SELF.Date1
        of2        = SELF.Date2
        SELF.Date1 = 0
        SELF.Date2 = 0
        DO Touched
      END
    OF ?COk
      IF EVENT() = EVENT:Accepted
        IF ~SELF.Date1
          Message(SELF.Txt(CTx:NothingPicked),SELF.Txt(CTx:Calendar), |
                  ICON:Exclamation,BUTTON:OK,BUTTON:OK,0)
          CYCLE
        END
        SELF.Accepted = 1
        POST(EVENT:CloseWindow)
      END
    OF ?CCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  CLOSE(CalWnd)
  IF SELF.Persist THEN SELF.SaveSettings() .
  RETURN SELF.Accepted

!  ---- the window grows and shrinks with the view --------------------------
Relayout ROUTINE
  SELF.Layout()
  winW = SELF.CanvasW + 24
!  The NAV STRIP is what makes this window wide, not the calendar. All on one
!  row it wants 462 units - three times a single month - so a one-month view or
!  a Down stack used to open in a window mostly full of empty space. When the
!  canvas is narrower than that, wrap the strip onto two rows and let the window
!  close down on the calendar instead.
  IF winW >= Cal:NavOneRow
    navr = 1
  ELSE
    navr = 2
    IF winW < Cal:NavTwoRow THEN winW = Cal:NavTwoRow .
  END
  IF navr = 1
!   << < [month] [year] > >> [Today] .......... View: [view] [layout]
    ?CPY{PROP:Xpos}    =  10 ; ?CPY{PROP:Ypos}    = 38
    ?CPM{PROP:Xpos}    =  28 ; ?CPM{PROP:Ypos}    = 38
    ?CMonth{PROP:Xpos} =  45 ; ?CMonth{PROP:Ypos} = 39 ; ?CMonth{PROP:Width} = 76
    ?CYear{PROP:Xpos}  = 124 ; ?CYear{PROP:Ypos}  = 39 ; ?CYear{PROP:Width}  = 34
    ?CNM{PROP:Xpos}    = 162 ; ?CNM{PROP:Ypos}    = 38
    ?CNY{PROP:Xpos}    = 178 ; ?CNY{PROP:Ypos}    = 38
    ?CToday{PROP:Xpos} = 200 ; ?CToday{PROP:Ypos} = 38 ; ?CToday{PROP:Width} = 42
    ?CViewP{PROP:Xpos} = winW - 206 ; ?CViewP{PROP:Ypos} = 40
    ?CView{PROP:Xpos}  = winW - 182 ; ?CView{PROP:Ypos}  = 39 ; ?CView{PROP:Width} = 82
    ?CLay{PROP:Xpos}   = winW -  78 ; ?CLay{PROP:Ypos}   = 39 ; ?CLay{PROP:Width}  = 66
    UNHIDE(?CViewP)
  ELSE
!   row 1:  << < [month] [year] > >>
!   row 2:  [Today] [view] [layout]        - the "View:" label goes, the tip stays
    ?CPY{PROP:Xpos}    =  10 ; ?CPY{PROP:Ypos}    = 38
    ?CPM{PROP:Xpos}    =  27 ; ?CPM{PROP:Ypos}    = 38
    ?CMonth{PROP:Xpos} =  44 ; ?CMonth{PROP:Ypos} = 39 ; ?CMonth{PROP:Width} = 66
    ?CYear{PROP:Xpos}  = 113 ; ?CYear{PROP:Ypos}  = 39 ; ?CYear{PROP:Width}  = 32
    ?CNM{PROP:Xpos}    = 148 ; ?CNM{PROP:Ypos}    = 38
    ?CNY{PROP:Xpos}    = 165 ; ?CNY{PROP:Ypos}    = 38
    ?CToday{PROP:Xpos} =  10 ; ?CToday{PROP:Ypos} = 38 + Cal:NavRowH ; ?CToday{PROP:Width} = 40
    ?CView{PROP:Xpos}  =  54 ; ?CView{PROP:Ypos}  = 39 + Cal:NavRowH ; ?CView{PROP:Width}  = 70
    ?CLay{PROP:Xpos}   = 128 ; ?CLay{PROP:Ypos}   = 39 + Cal:NavRowH ; ?CLay{PROP:Width}   = 58
    HIDE(?CViewP)
  END
  cy = 58 + (navr - 1) * Cal:NavRowH                        ! the canvas starts under the strip
  cx = INT((winW - SELF.CanvasW) / 2)
  ?CCanvas{PROP:Xpos}   = cx
  ?CCanvas{PROP:Ypos}   = cy
  ?CCanvas{PROP:Width}  = SELF.CanvasW
  ?CCanvas{PROP:Height} = SELF.CanvasH
  ?CHot{PROP:Xpos}      = cx
  ?CHot{PROP:Ypos}      = cy
  ?CHot{PROP:Width}     = SELF.CanvasW
  ?CHot{PROP:Height}    = SELF.CanvasH
  fy = cy + SELF.CanvasH + 8
  ?CRule{PROP:Ypos}     = fy
  ?CRule{PROP:Width}    = winW - 24
  ?CPick{PROP:Ypos}     = fy + 7  ; ?CPick{PROP:Width} = winW - 24
  ?CHint{PROP:Ypos}     = fy + 18 ; ?CHint{PROP:Width} = winW - 24
  ?CClear{PROP:Ypos}    = fy + 32
  ?COk{PROP:Ypos}       = fy + 32
  ?CCancel{PROP:Ypos}   = fy + 32
  ?CCancel{PROP:Xpos}   = winW - 66
  ?COk{PROP:Xpos}       = winW - 124
  ?CClear{PROP:Xpos}    = winW - 172
  IF SELF.Months > 1                                        ! nothing to stack with one month
    ENABLE(?CLay)
  ELSE
    DISABLE(?CLay)
  END
  LOOP i = 1 TO RECORDS(LayQ)
    GET(LayQ,i)
    IF LYQ:LYId = SELF.Orient
      ?CLay{PROP:Selected} = i
      BREAK
    END
  END
  ?CBand{PROP:Width}    = winW
  0{PROP:Width}         = winW
  0{PROP:Height}        = fy + 32 + 14 + 10
  LOOP i = 1 TO RECORDS(ViewQ)
    GET(ViewQ,i)
    IF VWQ:VWCount = SELF.Months
      ?CView{PROP:Selected} = i
      BREAK
    END
  END

!  ---- the pop-up in the theme's colours (see LoadTheme) -------------------
Theme ROUTINE
  IF ~SELF.Themed THEN EXIT .
  IF SELF.WinColor <> -1 THEN 0{PROP:Color} = SELF.WinColor .
  IF SELF.BandColor <> -1 THEN ?CBand{PROP:Fill} = SELF.BandColor .
  IF SELF.BandFontColor <> -1
    ?CTitle{PROP:FontColor} = SELF.BandFontColor
    ?CSub{PROP:FontColor}   = SELF.BandFontColor
  END
  ?CRule{PROP:Fill}      = SELF.LineColor
  ?CPick{PROP:FontColor} = SELF.TitleColor
  ?CHint{PROP:FontColor} = SELF.MutedColor
  ?CViewP{PROP:Trn}      = 1
  IF SELF.TextColor <> -1 THEN ?CViewP{PROP:FontColor} = SELF.TextColor .
  LOOP i = 1 TO 4                                           ! the drop lists and the year
    tf = CHOOSE(i,?CMonth,?CYear,?CView,?CLay)
    tf{PROP:Color}             = SELF.BackColor
    tf{PROP:FontColor}         = SELF.InkColor
    tf{PROP:SelectedFillColor} = SELF.SelColor
    tf{PROP:SelectedColor}     = SELF.SelTextColor
  END
  IF SELF.FlatButtons                                       ! a 3D button keeps its own face,
    LOOP i = 1 TO 8                                         ! so its text keeps its colour too
      tf = CHOOSE(i,?CPY,?CPM,?CNM,?CNY,?CToday,?CClear,?COk,?CCancel)
      tf{PROP:Flat} = 1
      IF SELF.ButtonColor <> -1 THEN tf{PROP:FontColor} = SELF.ButtonColor .
    END
  END

!  ---- the month / year controls follow wherever we navigated to -----------
SyncNav ROUTINE
  ?CMonth{PROP:Selected} = MONTH(SELF.Anchor)
  CYear = YEAR(SELF.Anchor)
  DISPLAY(?CYear)

Moved ROUTINE
  DO SyncNav
  DO Repaint

Repaint ROUTINE
  SELF.Draw(CalWnd,?CCanvas)
  DO ShowPick

!  The selection moved, and nothing else did. Repaint the handful of cells that
!  look different rather than the whole canvas - this is what keeps a drag
!  smooth on the six-month and full-year views.
Touched ROUTINE
  SELF.DrawChanged(CalWnd,?CCanvas,of1,of2)
  DO ShowPick

ShowPick ROUTINE
  IF ~SELF.Date1
    ?CPick{PROP:Text} = ''
  ELSIF SELF.Selection = Cal:Range AND SELF.Date2
    ?CPick{PROP:Text} = CLIP(SELF.Txt(CTx:From)) & ' ' & SELF.DateText(SELF.Date1) & ' ' & |
                        CLIP(SELF.Txt(CTx:To))   & ' ' & SELF.DateText(SELF.Date2) & |
                        '   (' & SELF.Days() & ' ' & CLIP(SELF.Txt(CTx:Days)) & ')'
  ELSE
    ?CPick{PROP:Text} = CLIP(SELF.Txt(CTx:Date)) & ': ' & SELF.DateText(SELF.Date1)
  END
