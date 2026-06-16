    MEMBER()

    MAP
      INCLUDE('myFuncs.inc'),ONCE
    END

!=============================================================================!
!  weekNumber  -  ISO-8601 (European) week number of a date.                  !
!                                                                             !
!  pDate : a Clarion standard date. If omitted (or 0) today's date is used.   !
!  Returns the ISO week number, 1..53.                                        !
!                                                                             !
!  ISO-8601 rules: weeks start on Monday; week 1 is the week that contains    !
!  the year's first Thursday (equivalently, the week containing January 4th). !
!  A date's week therefore belongs to the year of the Thursday in its week.   !
!                                                                             !
!  Weekday math uses Clarion's epoch (standard date 4 = 01-Jan-1801 = a        !
!  Thursday), so  date % 7  gives 0=Sun,1=Mon,...,6=Sat.                       !
!=============================================================================!
weekNumber  PROCEDURE(LONG pDate=0)
loc:Date      LONG                                    ! the date we are working on
loc:M         LONG                                    ! date % 7  (0=Sun .. 6=Sat)
loc:ISODow    LONG                                    ! ISO weekday: Mon=1 .. Sun=7
loc:Thursday  LONG                                    ! the Thursday of loc:Date's week
loc:ISOYear   LONG                                    ! the year that owns this week
loc:Jan1      LONG                                    ! 1st January of loc:ISOYear
  CODE
  loc:Date = pDate
  IF ~loc:Date                                        ! no date passed -> use today
    loc:Date = TODAY()
  END
  loc:M      = loc:Date % 7                            ! 0=Sun,1=Mon,...,6=Sat
  loc:ISODow = CHOOSE(loc:M = 0, 7, loc:M)             ! Sunday(0) -> 7, else Mon..Sat = 1..6
  loc:Thursday = loc:Date + (4 - loc:ISODow)           ! move to Thursday of this ISO week
  loc:ISOYear  = YEAR(loc:Thursday)                    ! the Thursday decides the week's year
  loc:Jan1     = DATE(1, 1, loc:ISOYear)
  RETURN INT((loc:Thursday - loc:Jan1) / 7) + 1
