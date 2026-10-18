!ABCIncludeFile(MYCALENDAR)
! ============================================================================
!  MyCalendarClass - a pop-up date picker for Clarion.
!
!    * One month, two, three, six, or a whole year on screen at once
!    * Pick a single date, or DRAG a from/to range across any of the months
!    * Previous / next month and year, a month and year drop list, and Today
!    * Week numbers, first day of the week, weekends blocked, min/max limits
!    * English or Spanish
!
!  Press Accept and the date lands in the field the button sits beside - or,
!  for a range, the two fields you nominated.
!
!  Pure Clarion. No DLL, no OCX, nothing to deploy.
!
!  HOW IT DRAWS
!  ------------
!  The months are drawn with native BOX / LINE / SHOW into an IMAGE control
!  (the 2-arg SETTARGET(window, ?image), so 0,0 is the image's top-left), and a
!  transparent REGION with IMM sits over the top to collect the mouse. The
!  region reports MouseDown / MouseMove / MouseUp with MOUSEX() / MOUSEY() in
!  the same dialog units as PROP:Xpos, so a hit test is plain arithmetic - and
!  dragging a range works the way you would expect.
!
!  USAGE (the myCalendar template does all of this for you)
!    INCLUDE('MyCalendarClass.INC'),ONCE
!    Cal1  MyCalendarClass
!
!      IF Cal1.AskFor(ORD:DueDate)             ! one date
!        DISPLAY(?ORD:DueDate)
!      END
!
!      IF Cal1.AskRange(LOC:From, LOC:To)      ! a from/to pair, drag-selected
!        DISPLAY
!      END
!
!  FILES: MyCalendarClass.inc + MyCalendarClass.clw on the redirection path,
!         ANSI, CRLF.
! ============================================================================

! ---- how many months are on screen ----------------------------------------
Cal:OneMonth       EQUATE(1)
Cal:TwoMonths      EQUATE(2)
Cal:ThreeMonths    EQUATE(3)
Cal:SixMonths      EQUATE(6)
Cal:Year           EQUATE(12)

! ---- what the user is picking ---------------------------------------------
Cal:Single         EQUATE(0)                   ! one date, into one field
Cal:Range          EQUATE(1)                   ! from/to, into two fields

! ---- languages ------------------------------------------------------------
Cal:English        EQUATE(1)
Cal:Spanish        EQUATE(2)

! ---- how the month blocks are stacked -------------------------------------
Cal:Across         EQUATE(0)                   ! 2 -> 2x1, 3 -> 3x1, 6 -> 3x2, 12 -> 4x3
Cal:Down           EQUATE(1)                   ! 2 -> 1x2, 3 -> 1x3, 6 -> 2x3, 12 -> 3x4

! ---- the first column of the week -----------------------------------------
Cal:Sunday         EQUATE(0)
Cal:Monday         EQUATE(1)

! ---- every word the window shows ------------------------------------------
CTx:Calendar       EQUATE(1)
CTx:View           EQUATE(2)
CTx:OneMonth       EQUATE(3)
CTx:TwoMonths      EQUATE(4)
CTx:ThreeMonths    EQUATE(5)
CTx:SixMonths      EQUATE(6)
CTx:Year           EQUATE(7)
CTx:Today          EQUATE(8)
CTx:Accept         EQUATE(9)
CTx:Cancel         EQUATE(10)
CTx:Clear          EQUATE(11)
CTx:From           EQUATE(12)
CTx:To             EQUATE(13)
CTx:Date           EQUATE(14)
CTx:HintSingle     EQUATE(15)
CTx:HintRange      EQUATE(16)
CTx:Days           EQUATE(17)                  ! "n days"
CTx:PrevYear       EQUATE(18)
CTx:PrevMonth      EQUATE(19)
CTx:NextMonth      EQUATE(20)
CTx:NextYear       EQUATE(21)
CTx:Week           EQUATE(22)                  ! the week-number column head
CTx:NothingPicked  EQUATE(23)
CTx:OutOfRange     EQUATE(24)
CTx:Layout         EQUATE(25)
CTx:Across         EQUATE(26)
CTx:Down           EQUATE(27)

! ---- geometry, in dialog units --------------------------------------------
Cal:CellW          EQUATE(18)                  ! one day cell
Cal:CellH          EQUATE(12)
Cal:TitleH         EQUATE(13)                  ! the "July 2026" strip
Cal:DayH           EQUATE(10)                  ! the Mo Tu We row
Cal:WeekW          EQUATE(16)                  ! the week-number gutter
Cal:Weeks          EQUATE(6)                   ! rows of days per month
Cal:Gap            EQUATE(10)                  ! between month blocks

! ---- what the navigation strip needs, which is what sets the window width --
!  On one row the nav is three times as wide as a single month, and it used to
!  drag the whole window out with it. Below Cal:NavOneRow the strip wraps onto
!  two rows instead, and the window can close right down on the calendar.
Cal:NavOneRow      EQUATE(462)                 ! << < month year > >> Today View Layout
Cal:NavTwoRow      EQUATE(196)                 ! the same, stacked two deep
Cal:NavRowH        EQUATE(16)                  ! one row of nav controls

MyCalendarClass      CLASS,TYPE,MODULE('MyCalendarClass.CLW'),LINK('MyCalendarClass.CLW')
! ---- what the caller sets -------------------------------------------------
Months               BYTE(1)                   ! 1, 2, 3, 6 or 12
Orient               BYTE(0)                   ! Cal:Across / Cal:Down
Selection            BYTE(0)                   ! Cal:Single / Cal:Range
Date1                LONG                      ! the date, or the FROM of a range
Date2                LONG                      ! the TO of a range
Anchor               LONG                      ! any date in the first month shown
FirstDay             BYTE(0)                   ! Cal:Sunday / Cal:Monday
ShowWeekNo           BYTE(0)
ShowToday            BYTE(1)                   ! ring today's date
NoWeekends           BYTE(0)                   ! Saturdays and Sundays cannot be picked
MinDate              LONG(0)                   ! 0 = no limit
MaxDate              LONG(0)
Title                CSTRING(64)
Language             BYTE(1)
DatePicture          CSTRING(16)               ! how dates read back, default @d17
! ---- remembering the last session -----------------------------------------
Persist              BYTE(0)
Profile              CSTRING(65)
IniFile              CSTRING(261)
! ---- results --------------------------------------------------------------
Accepted             BYTE
! ---- colours (Clarion BGR longs) ------------------------------------------
BackColor            LONG(0FFFFFFH)            ! the paper
TitleColor           LONG(0603A1FH)            ! month name
InkColor             LONG(03B3023H)            ! weekday numbers
MutedColor           LONG(0A3968AH)            ! weekend numbers, day names
LineColor            LONG(0EAE3DCH)            ! rules
SelColor             LONG(0603A1FH)            ! a picked day
SelTextColor         LONG(0FFFFFFH)
RangeColor           LONG(0F7E9DCH)            ! days between the two ends
TodayColor           LONG(03DA3E8H)            ! the ring around today
! ---- following a CapeSoft Makeover theme (.STY) ------------------------------
!  Ask() calls LoadTheme(), which reads the theme into the colours above and
!  the pop-up colours below. No theme found = the built-in colours, unchanged.
!  StyleFile '' = no theme. Keys come from [<StyleSet> <StyleType>], else
!  [<StyleSet> Default]. The top band reads BgColor / BgColorEnd / FontColor
!  from BandSection, when one is named, and the accent (month names, the
!  picked day, the range) is its BarStartColor. Without a band section the
!  accent is the optional AccentFontColor key, else the built-in TitleColor.
!  The myCalendar global template fills these in before every Ask().
StyleFile            CSTRING(261)              ! the .STY; '' = no theme
StyleSet             CSTRING(33)               ! '' = Basic3
StyleType            CSTRING(33)               ! '' = Window
BandSection          CSTRING(65)               ! '' = the band keeps its own colours
WinColor             LONG(-1)                  ! pop-up background; -1 = leave as is
TextColor            LONG(-1)                  ! the View prompt
BandColor            LONG(-1)                  ! the top band
BandFontColor        LONG(-1)                  ! title and subtitle on the band
ButtonColor          LONG(-1)                  ! button text (flat buttons only)
FlatButtons          BYTE(0)
Themed               BYTE,PROTECTED            ! LoadTheme found a theme
! ---- internals ------------------------------------------------------------
!  Layout() fills these in. They are public because Draw() will happily paint
!  into an IMAGE on a window of your own, and then you need the size.
GridCols             LONG                      ! month blocks across / down
GridRows             LONG
BlockW               LONG                      ! one month block
BlockH               LONG
CanvasW              LONG                      ! what Draw() needs to paint into
CanvasH              LONG
! ---- strictly internal ----------------------------------------------------
Canvas               SIGNED,PROTECTED          ! the IMAGE being drawn into
WinRef               &WINDOW,PROTECTED
Dragging             BYTE,PROTECTED
DragFrom             LONG,PROTECTED
Loaded               BYTE,PROTECTED

! ---- lifecycle ------------------------------------------------------------
Construct            PROCEDURE
Reset                PROCEDURE                 ! back to today, nothing picked

! ---- the pop-up -----------------------------------------------------------
Ask                  PROCEDURE(),BYTE,VIRTUAL  ! modal; 1 = the user accepted
AskFor               PROCEDURE(*? pDate),BYTE,PROC          ! one date, in and out
AskRange             PROCEDURE(*? pFrom,*? pTo),BYTE,PROC   ! a from/to pair

! ---- driving it from code -------------------------------------------------
SetDate              PROCEDURE(LONG pDate)
SetRange             PROCEDURE(LONG pFrom,LONG pTo)
GoToday              PROCEDURE
GoMonth              PROCEDURE(LONG pDelta)    ! -1 / +1 month, and any multiple
GoYear               PROCEDURE(LONG pDelta)
Pick                 PROCEDURE(LONG pDate)     ! as if the user clicked that day
Days                 PROCEDURE(),LONG          ! how many days the selection spans
Pickable             PROCEDURE(LONG pDate),BYTE! inside the limits, and not a blocked weekend

! ---- dates ----------------------------------------------------------------
FirstOfMonth         PROCEDURE(LONG pDate),LONG
AddMonths            PROCEDURE(LONG pDate,LONG pCount),LONG
DaysInMonth          PROCEDURE(LONG pMonth,LONG pYear),LONG
DayOfWeek            PROCEDURE(LONG pDate),LONG! 0 = Sunday .. 6 = Saturday
ColumnOf             PROCEDURE(LONG pDate),LONG! 0..6, honouring FirstDay
WeekNumber           PROCEDURE(LONG pDate),LONG! ISO-8601 week
MonthName            PROCEDURE(LONG pMonth),STRING
DayName              PROCEDURE(LONG pCol),STRING
DateText             PROCEDURE(LONG pDate),STRING   ! the date as the user sees it

! ---- drawing and hit testing ----------------------------------------------
Layout               PROCEDURE                 ! work out the grid for Months
Draw                 PROCEDURE(WINDOW pWin,SIGNED pImage)   ! the whole canvas
DateAt               PROCEDURE(LONG pX,LONG pY),LONG        ! the day under a point, or 0
CellAt               PROCEDURE(LONG pDate,*LONG pX,*LONG pY),BYTE  ! and the reverse; 0 = off screen
InSelection          PROCEDURE(LONG pDate),BYTE             ! 0 no, 1 an end, 2 between

! ---- drawing ONE day, so a drag does not repaint the world -----------------
!  A full Draw() of a year is 12 months x ~30 cells x 3 drawing calls, and a
!  drag would do that on every mouse move. DrawChanged repaints only the cells
!  whose selection state actually differs from the range it is given - one or
!  two of them, for a drag of one day - which is what makes sweeping smooth.
DrawDay              PROCEDURE(WINDOW pWin,SIGNED pImage,LONG pDate)
DrawChanged          PROCEDURE(WINDOW pWin,SIGNED pImage,LONG pOldFrom,LONG pOldTo),LONG,PROC

! ---- words ----------------------------------------------------------------
Txt                  PROCEDURE(LONG pId),STRING

! ---- theme ----------------------------------------------------------------
LoadTheme            PROCEDURE(),BYTE,PROC,VIRTUAL    ! 1 = a theme was found and loaded
StyColor             PROCEDURE(STRING pSty,STRING pSect,STRING pDflt,STRING pKeyC,LONG pCurrent),LONG  ! pKeyC: pKey clashes with KEYCODES PKey
Blend                PROCEDURE(LONG pFrom,LONG pTo,LONG pPct),LONG   ! pPct % of the way to pTo

! ---- remembering ----------------------------------------------------------
LoadSettings         PROCEDURE()
SaveSettings         PROCEDURE()
ForgetSettings       PROCEDURE()

! ---- internals (protected) ------------------------------------------------
DrawMonth            PROCEDURE(LONG pFirst,LONG pX,LONG pY),PROTECTED
DrawCell             PROCEDURE(LONG pDate,LONG pX,LONG pY,BYTE pErase),PROTECTED
Ink                  PROCEDURE(LONG pColor),PROTECTED   ! pen AND text colour for what follows
StateIn              PROCEDURE(LONG pDate,LONG pFrom,LONG pTo),BYTE,PROTECTED
IniPath              PROCEDURE(),STRING,PROTECTED
IniSection           PROCEDURE(),STRING,PROTECTED
                   END
