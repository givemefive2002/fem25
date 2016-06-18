C
C     --------------------------------------------------------------------
C     Conjugate Gradient methods for solving unconstrained nonlinear
C     optimization problems, as described in the paper:
C
C     Gilbert, J.C. and Nocedal, J. (1992). "Global Convergence Properties 
C     of Conjugate Gradient Methods", SIAM Journal on Optimization, Vol. 2,
C     pp. 21-42. 
C
C     A web-based Server which solves unconstrained nonlinear optimization
C     problems using this Conjugate Gradient code can be found at:
C
C       http://www-neos.mcs.anl.gov/neos/solvers/UCO:CGPLUS/
C
C     --------------------------------------------------------------------
C
      SUBROUTINE CGFAM(N,X,F,G,D,GOLD,IPRINT,EPS,W,
     *                  IFLAG,IREST,METHOD,FINISH, MPIN,LPIN )
C
C Subroutine parameters
C
      REAL*4 X(N),G(N),D(N),GOLD(N),W(N),F,EPS
      INTEGER N,IPRINT(2),IFLAG,IREST,METHOD,IM,NDES
C
C     N      =  NUMBER OF VARIABLES
C     X      =  ITERATE
C     F      =  FUNCTION VALUE
C     G      =  GRADIENT VALUE
C     GOLD   =  PREVIOUS GRADIENT VALUE
C     IPRINT =  FREQUENCY AND TYPE OF PRINTING
C               IPRINT(1) < 0 : NO OUTPUT IS GENERATED
C               IPRINT(1) = 0 : OUTPUT ONLY AT FIRST AND LAST ITERATION
C               IPRINT(1) > 0 : OUTPUT EVERY IPRINT(1) ITERATIONS
C               IPRINT(2)     : SPECIFIES THE TYPE OF OUTPUT GENERATED;
C                               THE LARGER THE VALUE (BETWEEN 0 AND 3),
C                               THE MORE INFORMATION
C               IPRINT(2) = 0 : NO ADDITIONAL INFORMATION PRINTED
C 		IPRINT(2) = 1 : INITIAL X AND GRADIENT VECTORS PRINTED
C		IPRINT(2) = 2 : X VECTOR PRINTED EVERY ITERATION
C		IPRINT(2) = 3 : X VECTOR AND GRADIENT VECTOR PRINTED 
C				EVERY ITERATION 
C     EPS    =  CONVERGENCE CONSTANT
C     W      =  WORKING ARRAY
C     IFLAG  =  CONTROLS TERMINATION OF CODE, AND RETURN TO MAIN
C               PROGRAM TO EVALUATE FUNCTION AND GRADIENT
C               IFLAG = -3 : IMPROPER INPUT PARAMETERS
C               IFLAG = -2 : DESCENT WAS NOT OBTAINED
C               IFLAG = -1 : LINE SEARCH FAILURE
C               IFLAG =  0 : INITIAL ENTRY OR 
C                            SUCCESSFUL TERMINATION WITHOUT ERROR   
C               IFLAG =  1 : INDICATES A RE-ENTRY WITH NEW FUNCTION VALUES
C               IFLAG =  2 : INDICATES A RE-ENTRY WITH A NEW ITERATE
C     IREST  =  0 (NO RESTARTS); 1 (RESTART EVERY N STEPS)
C     METHOD =  1 : FLETCHER-REEVES 
C               2 : POLAK-RIBIERE
C               3 : POSITIVE POLAK-RIBIERE ( BETA=MAX{BETA,0} )
C
C Local variables
C
      REAL*4 GTOL,ONE,ZERO,GNORM,SDOT,STP1,FTOL,XTOL,STPMIN,
     .       STPMAX,STP,BETA,BETAFR,BETAPR,DG0,GG,GG0,DGOLD,
     .       DGOUT,DG,DG1
      INTEGER MP,LP,ITER,NFUN,MAXFEV,INFO,I,NFEV,NRST,IDES
      LOGICAL NEW,FINISH
C
C     THE FOLLOWING PARAMETERS ARE PLACED IN COMMON BLOCKS SO THEY
C     CAN BE EASILY ACCESSED ANYWHERE IN THE CODE
C
C     MP = UNIT NUMBER WHICH DETERMINES WHERE TO WRITE REGULAR OUTPUT
C     LP = UNIT NUMBER WHICH DETERMINES WHERE TO WRITE ERROR OUPUT
      COMMON /CGDD/MP,LP
C
C     ITER: KEEPS TRACK OF THE NUMBER OF ITERATIONS
C     NFUN: KEEPS TRACK OF THE NUMBER OF FUNCTION/GRADIENT EVALUATIONS
      COMMON /RUNINF/ITER,NFUN
      SAVE
      DATA ONE,ZERO/1.0E+0,0.0E+0/

      MP = MPIN
      LP = LPIN 
C
C IFLAG = 1 INDICATES A RE-ENTRY WITH NEW FUNCTION VALUES
      IF(IFLAG.EQ.1) GO TO 72
C
C IFLAG = 2 INDICATES A RE-ENTRY WITH A NEW ITERATE
      IF(IFLAG.EQ.2) GO TO 80
C
C     INITIALIZE
C     ----------
C
C
C     IM =   NUMBER OF TIMES BETAPR WAS NEGATIVE FOR METHOD 2 OR
C            NUMBER OF TIMES BETAPR WAS 0 FOR METHOD 3
C
C     NDES = NUMBER OF LINE SEARCH ITERATIONS AFTER WOLFE CONDITIONS
C            WERE SATISFIED
C
      ITER= 0
      IF(N.LE.0) GO TO 96
      NFUN= 1
      NEW=.TRUE.
      NRST= 0
      IM=0
      NDES=0
C
      DO 5 I=1,N
 5    D(I)= -G(I)
      GNORM= SQRT(SDOT(N,G,1,G,1))
      STP1= ONE/GNORM
C
C     PARAMETERS FOR LINE SEARCH ROUTINE
C     ----------------------------------
C
C     FTOL AND GTOL ARE NONNEGATIVE INPUT VARIABLES. TERMINATION
C       OCCURS WHEN THE SUFFICIENT DECREASE CONDITION AND THE
C       DIRECTIONAL DERIVATIVE CONDITION ARE SATISFIED.
C
C     XTOL IS A NONNEGATIVE INPUT VARIABLE. TERMINATION OCCURS
C       WHEN THE RELATIVE WIDTH OF THE INTERVAL OF UNCERTAINTY
C       IS AT MOST XTOL.
C
C     STPMIN AND STPMAX ARE NONNEGATIVE INPUT VARIABLES WHICH
C       SPECIFY LOWER AND UPPER BOUNDS FOR THE STEP.
C
C     MAXFEV IS A POSITIVE INTEGER INPUT VARIABLE. TERMINATION
C       OCCURS WHEN THE NUMBER OF CALLS TO FCN IS AT LEAST
C       MAXFEV BY THE END OF AN ITERATION.

      FTOL= 1.0E-4
      GTOL= 1.0E-1
      IF(GTOL.LE.1.E-04) THEN
        IF(LP.GT.0) WRITE(LP,145)
        GTOL=1.E-02
      ENDIF
      XTOL= 1.0E-17
      STPMIN= 1.0E-20
      STPMAX= 1.0E+20
      MAXFEV= 40
C
      IF(IPRINT(1).GE.0) CALL CGBD(IPRINT,ITER,NFUN,
     *   GNORM,N,X,F,G,STP,FINISH,NDES,IM,BETAFR,BETAPR,BETA)
C
C     MAIN ITERATION LOOP
C    ---------------------
C
 8    ITER= ITER+1
C     WHEN NRST>N AND IREST=1 THEN RESTART
      NRST= NRST+1
      INFO=0
C
C
C     CALL THE LINE SEARCH ROUTINE OF MOR'E AND THUENTE
C     (modified for our CG method)
C     -------------------------------------------------
C
C       JJ Mor'e and D Thuente, "Linesearch Algorithms with Guaranteed
C       Sufficient Decrease". ACM Transactions on Mathematical
C       Software 20 (1994), pp 286-307.
C
      NFEV=0
      DO 70 I=1,N
  70  GOLD(I)= G(I)
      DG= SDOT(N,D,1,G,1)
      DGOLD=DG
      STP=ONE
C
C Shanno-Phua's Formula For Trial Step
C
      IF(.NOT.NEW) STP= DG0/DG
      IF (ITER.EQ.1) STP=STP1
      IDES=0
      new=.false.
  72  CONTINUE
C
C     write(6,*) 'step= ', stp
C
C Call to the line search subroutine
C
      CALL CVSMOD(N,X,F,G,D,STP,FTOL,GTOL,
     *            XTOL,STPMIN,STPMAX,MAXFEV,INFO,NFEV,W,DG,DGOUT)

C       INFO IS AN INTEGER OUTPUT VARIABLE SET AS FOLLOWS:
C         INFO = 0  IMPROPER INPUT PARAMETERS.
C         INFO =-1  A RETURN IS MADE TO COMPUTE THE FUNCTION AND GRADIENT.
C         INFO = 1  THE SUFFICIENT DECREASE CONDITION AND THE
C                   DIRECTIONAL DERIVATIVE CONDITION HOLD.
C         INFO = 2  RELATIVE WIDTH OF THE INTERVAL OF UNCERTAINTY
C                   IS AT MOST XTOL.
C         INFO = 3  NUMBER OF CALLS TO FCN HAS REACHED MAXFEV.
C         INFO = 4  THE STEP IS AT THE LOWER BOUND STPMIN.
C         INFO = 5  THE STEP IS AT THE UPPER BOUND STPMAX.
C         INFO = 6  ROUNDING ERRORS PREVENT FURTHER PROGRESS.
C                   THERE MAY NOT BE A STEP WHICH SATISFIES THE
C                   SUFFICIENT DECREASE AND CURVATURE CONDITIONS.
C                   TOLERANCES MAY BE TOO SMALL.

      IF (INFO .EQ. -1) THEN
C       RETURN TO FETCH FUNCTION AND GRADIENT
        IFLAG=1
        RETURN
      ENDIF
      IF (INFO .NE. 1) GO TO 90
C
C     TEST IF DESCENT DIRECTION IS OBTAINED FOR METHODS 2 AND 3
C     ---------------------------------------------------------
C
      GG= SDOT(N,G,1,G,1)
      GG0= SDOT(N,G,1,GOLD,1)
      BETAPR= (GG-GG0)/GNORM**2
      IF (IREST.EQ.1.AND.NRST.GT.N) THEN
        NRST=0
        NEW=.TRUE.
        GO TO 75
      ENDIF 
C
      IF (METHOD.EQ.1) THEN
        GO TO 75
      ELSE
        DG1=-GG + BETAPR*DGOUT
        IF (DG1.lt. 0.0e0 ) GO TO 75
        IF (IPRINT(1).GE.0) write(6,*) 'no descent'
        IDES= IDES + 1
        IF(IDES.GT.5) GO TO 95
        GO TO 72
      ENDIF
C
C     DETERMINE CORRECT BETA VALUE FOR METHOD CHOSEN
C     ----------------------------------------------
C
C     IM =   NUMBER OF TIMES BETAPR WAS NEGATIVE FOR METHOD 2 OR
C            NUMBER OF TIMES BETAPR WAS 0 FOR METHOD 3
C
C     NDES = NUMBER OF LINE SEARCH ITERATIONS AFTER WOLFE CONDITIONS
C            WERE SATISFIED
C
  75  NFUN= NFUN + NFEV
      NDES= NDES + IDES
      BETAFR= GG/GNORM**2
      IF (NRST.EQ.0) THEN
        BETA= ZERO
      ELSE
        IF (METHOD.EQ.1) BETA=BETAFR
        IF (METHOD.EQ.2) BETA=BETAPR
        IF ((METHOD.EQ.2.OR.METHOD.EQ.3).AND.BETAPR.LT.0.0) IM=IM+1
        IF (METHOD.EQ.3) BETA=MAX(ZERO,BETAPR)
      ENDIF
C
C     COMPUTE THE NEW DIRECTION
C     --------------------------
C
      DO 78 I=1,N
  78  D(I) = -G(I) +BETA*D(I)
      DG0= DGOLD*STP
C
C     RETURN TO DRIVER FOR TERMINATION TEST
C     -------------------------------------
C
      GNORM=SQRT(SDOT(N,G,1,G,1))
      IFLAG=2
      RETURN

  80  CONTINUE
C
C Call subroutine for printing output
C
      IF(IPRINT(1).GE.0) CALL CGBD(IPRINT,ITER,NFUN,
     *     GNORM,N,X,F,G,STP,FINISH,NDES,IM,BETAFR,BETAPR,BETA)
      IF (FINISH) THEN
         IFLAG = 0
         RETURN
      END IF
      GO TO 8
C
C     ----------------------------------------
C     END OF MAIN ITERATION LOOP. ERROR EXITS.
C     ----------------------------------------
C
  90  IFLAG=-1
      IF(LP.GT.0) WRITE(LP,100) INFO
      RETURN
  95  IFLAG=-2
      IF(LP.GT.0) WRITE(LP,135) I
      RETURN
  96  IFLAG= -3
      IF(LP.GT.0) WRITE(LP,140)
C
C     FORMATS
C     -------
C
 100  FORMAT(/' IFLAG= -1 ',/' LINE SEARCH FAILED. SEE'
     .          ' DOCUMENTATION OF ROUTINE CVSMOD',/' ERROR RETURN'
     .          ' OF LINE SEARCH: INFO= ',I2,/
     .          ' POSSIBLE CAUSE: FUNCTION OR GRADIENT ARE INCORRECT')
 135  FORMAT(/' IFLAG= -2',/' DESCENT WAS NOT OBTAINED')
 140  FORMAT(/' IFLAG= -3',/' IMPROPER INPUT PARAMETERS (N',
     .       ' IS NOT POSITIVE)')
 145  FORMAT(/'  GTOL IS LESS THAN OR EQUAL TO 1.D-04',
     .       / ' IT HAS BEEN RESET TO 1.D-02')
      RETURN
      END
C
C     LAST LINE OF ROUTINE CGFAM
C     ***************************
C
C
C**************************************************************************
      SUBROUTINE CGBD(IPRINT,ITER,NFUN,
     *           GNORM,N,X,F,G,STP,FINISH,NDES,IM,BETAFR,BETAPR,BETA)
C
C     ---------------------------------------------------------------------
C     THIS ROUTINE PRINTS MONITORING INFORMATION. THE FREQUENCY AND AMOUNT
C     OF OUTPUT ARE CONTROLLED BY IPRINT.
C     ---------------------------------------------------------------------
C
      REAL*4 X(N),G(N),F,GNORM,STP,BETAFR,BETAPR,BETA
      INTEGER IPRINT(2),ITER,NFUN,LP,MP,N,NDES,IM
      LOGICAL FINISH
      COMMON /CGDD/MP,LP
C
      IF (ITER.EQ.0)THEN
           PRINT*
           WRITE(MP,10)
           WRITE(MP,20) N
           WRITE(MP,30) F,GNORM
                 IF (IPRINT(2).GE.1)THEN
                     WRITE(MP,40)
                     WRITE(MP,50) (X(I),I=1,N)
                     WRITE(MP,60)
                     WRITE(MP,50) (G(I),I=1,N)
                 ENDIF
           WRITE(MP,10)
           WRITE(MP,70)
      ELSE
          IF ((IPRINT(1).EQ.0).AND.(ITER.NE.1.AND..NOT.FINISH))RETURN
          IF (IPRINT(1).NE.0)THEN
               IF(MOD(ITER-1,IPRINT(1)).EQ.0.OR.FINISH)THEN
                     IF(IPRINT(2).GT.1.AND.ITER.GT.1) WRITE(MP,70)
                     WRITE(MP,80)ITER,NFUN,F,GNORM,STP,BETA
               ELSE
                     RETURN
               ENDIF
          ELSE
               IF( IPRINT(2).GT.1.AND.FINISH) WRITE(MP,70)
               WRITE(MP,80)ITER,NFUN,F,GNORM,STP,BETA
          ENDIF
          IF (IPRINT(2).EQ.2.OR.IPRINT(2).EQ.3)THEN
                  WRITE(MP,40)
                  WRITE(MP,50)(X(I),I=1,N)
              IF (IPRINT(2).EQ.3)THEN
                  WRITE(MP,60)
                  WRITE(MP,50)(G(I),I=1,N)
              ENDIF
          ENDIF
          IF (FINISH) WRITE(MP,100)
      ENDIF
C
 10   FORMAT('*************************************************')
 20   FORMAT(' N=',I5,//,'INITIAL VALUES:')
 30   FORMAT(' F= ',1PD10.3,'   GNORM= ',1PD10.3)
 40   FORMAT(/,' VECTOR X= ')
 50   FORMAT(6(2X,1PD10.3/))
 60   FORMAT(' GRADIENT VECTOR G= ')
 70   FORMAT(/'   I  NFN',4X,'FUNC',7X,'GNORM',6X,
     *   'STEPLEN',4x,'BETA',/,
     *   ' ----------------------------------------------------')
 80   FORMAT(I4,1X,I3,2X,2(1PD10.3,2X),1PD8.1,2x,1PD8.1)
100   FORMAT(/' SUCCESSFUL CONVERGENCE (NO ERRORS).'
     *          ,/,' IFLAG = 0')
C
      RETURN
      END
C
C
      SUBROUTINE CVSMOD(N,X,F,G,S,STP,FTOL,GTOL,XTOL,
     *           STPMIN,STPMAX,MAXFEV,INFO,NFEV,WA,DGINIT,DGOUT)
      INTEGER N,MAXFEV,INFO,NFEV
      REAL*4 F,STP,FTOL,GTOL,XTOL,STPMIN,STPMAX
      REAL*4 X(N),G(N),S(N),WA(N)
      SAVE
C     **********
C
C     SUBROUTINE CVSMOD
C
C     *** This is a modification of More's line search routine **
C                   * * * * * * 
C     THE PURPOSE OF CVSMOD IS TO FIND A STEP WHICH SATISFIES
C     A SUFFICIENT DECREASE CONDITION AND A CURVATURE CONDITION.
C     THE USER MUST PROVIDE A SUBROUTINE WHICH CALCULATES THE
C     FUNCTION AND THE GRADIENT.
C
C     AT EACH STAGE THE SUBROUTINE UPDATES AN INTERVAL OF
C     UNCERTAINTY WITH ENDPOINTS STX AND STY. THE INTERVAL OF
C     UNCERTAINTY IS INITIALLY CHOSEN SO THAT IT CONTAINS A
C     MINIMIZER OF THE MODIFIED FUNCTION
C
C          F(X+STP*S) - F(X) - FTOL*STP*(GRADF(X)'S).
C
C     IF A STEP IS OBTAINED FOR WHICH THE MODIFIED FUNCTION
C     HAS A NONPOSITIVE FUNCTION VALUE AND NONNEGATIVE DERIVATIVE,
C     THEN THE INTERVAL OF UNCERTAINTY IS CHOSEN SO THAT IT
C     CONTAINS A MINIMIZER OF F(X+STP*S).
C
C     THE ALGORITHM IS DESIGNED TO FIND A STEP WHICH SATISFIES
C     THE SUFFICIENT DECREASE CONDITION
C
C           F(X+STP*S) .LE. F(X) + FTOL*STP*(GRADF(X)'S),
C
C     AND THE CURVATURE CONDITION
C
C           ABS(GRADF(X+STP*S)'S)) .LE. GTOL*ABS(GRADF(X)'S).
C
C     IF FTOL IS LESS THAN GTOL AND IF, FOR EXAMPLE, THE FUNCTION
C     IS BOUNDED BELOW, THEN THERE IS ALWAYS A STEP WHICH SATISFIES
C     BOTH CONDITIONS. IF NO STEP CAN BE FOUND WHICH SATISFIES BOTH
C     CONDITIONS, THEN THE ALGORITHM USUALLY STOPS WHEN ROUNDING
C     ERRORS PREVENT FURTHER PROGRESS. IN THIS CASE STP ONLY
C     SATISFIES THE SUFFICIENT DECREASE CONDITION.
C
C     THE SUBROUTINE STATEMENT IS
C
C        SUBROUTINE CVSMOD(N,X,F,G,S,STP,FTOL,GTOL,XTOL,
C                   STPMIN,STPMAX,MAXFEV,INFO,NFEV,WA,DG,DGOUT)
C     WHERE
C
C       N IS A POSITIVE INTEGER INPUT VARIABLE SET TO THE NUMBER
C         OF VARIABLES.
C
C       X IS AN ARRAY OF LENGTH N. ON INPUT IT MUST CONTAIN THE
C         BASE POINT FOR THE LINE SEARCH. ON OUTPUT IT CONTAINS
C         X + STP*S.
C
C       F IS A VARIABLE. ON INPUT IT MUST CONTAIN THE VALUE OF F
C         AT X. ON OUTPUT IT CONTAINS THE VALUE OF F AT X + STP*S.
C
C       G IS AN ARRAY OF LENGTH N. ON INPUT IT MUST CONTAIN THE
C         GRADIENT OF F AT X. ON OUTPUT IT CONTAINS THE GRADIENT
C         OF F AT X + STP*S.
C
C       S IS AN INPUT ARRAY OF LENGTH N WHICH SPECIFIES THE
C         SEARCH DIRECTION.
C
C       STP IS A NONNEGATIVE VARIABLE. ON INPUT STP CONTAINS AN
C         INITIAL ESTIMATE OF A SATISFACTORY STEP. ON OUTPUT
C         STP CONTAINS THE FINAL ESTIMATE.
C
C       FTOL AND GTOL ARE NONNEGATIVE INPUT VARIABLES. TERMINATION
C         OCCURS WHEN THE SUFFICIENT DECREASE CONDITION AND THE
C         DIRECTIONAL DERIVATIVE CONDITION ARE SATISFIED.
C
C       XTOL IS A NONNEGATIVE INPUT VARIABLE. TERMINATION OCCURS
C         WHEN THE RELATIVE WIDTH OF THE INTERVAL OF UNCERTAINTY
C         IS AT MOST XTOL.
C
C       STPMIN AND STPMAX ARE NONNEGATIVE INPUT VARIABLES WHICH
C         SPECIFY LOWER AND UPPER BOUNDS FOR THE STEP.
C
C       MAXFEV IS A POSITIVE INTEGER INPUT VARIABLE. TERMINATION
C         OCCURS WHEN THE NUMBER OF CALLS TO FCN IS AT LEAST
C         MAXFEV BY THE END OF AN ITERATION.
C
C       INFO IS AN INTEGER OUTPUT VARIABLE SET AS FOLLOWS:
C
C         INFO = 0  IMPROPER INPUT PARAMETERS.
C
C         INFO =-1  A RETURN IS MADE TO COMPUTE THE FUNCTION AND GRADIENT.
C
C         INFO = 1  THE SUFFICIENT DECREASE CONDITION AND THE
C                   DIRECTIONAL DERIVATIVE CONDITION HOLD.
C
C         INFO = 2  RELATIVE WIDTH OF THE INTERVAL OF UNCERTAINTY
C                   IS AT MOST XTOL.
C
C         INFO = 3  NUMBER OF CALLS TO FCN HAS REACHED MAXFEV.
C
C         INFO = 4  THE STEP IS AT THE LOWER BOUND STPMIN.
C
C         INFO = 5  THE STEP IS AT THE UPPER BOUND STPMAX.
C
C         INFO = 6  ROUNDING ERRORS PREVENT FURTHER PROGRESS.
C                   THERE MAY NOT BE A STEP WHICH SATISFIES THE
C                   SUFFICIENT DECREASE AND CURVATURE CONDITIONS.
C                   TOLERANCES MAY BE TOO SMALL.
C
C       NFEV IS AN INTEGER OUTPUT VARIABLE SET TO THE NUMBER OF
C         CALLS TO FCN.
C
C       WA IS A WORK ARRAY OF LENGTH N.
C
C       *** The following two parameters are a modification to the code
C
C       DG IS THE INITIAL DIRECTIONAL DERIVATIVE (IN THE ORIGINAL CODE
C                 IT WAS COMPUTED IN THIS ROUTINE0
C
C       DGOUT IS THE VALUE OF THE DIRECTIONAL DERIVATIVE WHEN THE WOLFE
C             CONDITIONS HOLD, AND AN EXIT IS MADE TO CHECK DESCENT.
C
C     SUBPROGRAMS CALLED
C
C       CSTEPM
C
C       FORTRAN-SUPPLIED...ABS,MAX,MIN
C
C     ARGONNE NATIONAL LABORATORY. MINPACK PROJECT. JUNE 1983
C     JORGE J. MORE', DAVID J. THUENTE
C
C     **********
      INTEGER INFOC,J
      LOGICAL BRACKT,STAGE1
      REAL*4 DG,DGM,DGINIT,DGTEST,DGX,DGXM,DGY,DGYM,
     *       FINIT,FTEST1,FM,FX,FXM,FY,FYM,P5,P66,STX,STY,
     *       STMIN,STMAX,WIDTH,WIDTH1,XTRAPF,ZERO,DGOUT
      DATA P5,P66,XTRAPF,ZERO /0.5E0,0.66E0,4.0E0,0.0E0/
      IF(INFO.EQ.-1) GO TO 45
      IF(INFO.EQ.1) GO TO 321
      INFOC = 1
C
C     CHECK THE INPUT PARAMETERS FOR ERRORS.
C
      IF (N .LE. 0 .OR. STP .LE. ZERO .OR. FTOL .LT. ZERO .OR.
     *    GTOL .LT. ZERO .OR. XTOL .LT. ZERO .OR. STPMIN .LT. ZERO
     *    .OR. STPMAX .LT. STPMIN .OR. MAXFEV .LE. 0) RETURN
C
C     COMPUTE THE INITIAL GRADIENT IN THE SEARCH DIRECTION
C     AND CHECK THAT S IS A DESCENT DIRECTION.
C
      IF (DGINIT .GE. ZERO) RETURN
C
C     INITIALIZE LOCAL VARIABLES.
C
      BRACKT = .FALSE.
      STAGE1 = .TRUE.
      NFEV = 0
      FINIT = F
      DGTEST = FTOL*DGINIT
      WIDTH = STPMAX - STPMIN
      WIDTH1 = WIDTH/P5
      DO 20 J = 1, N
         WA(J) = X(J)
   20    CONTINUE
C
C     THE VARIABLES STX, FX, DGX CONTAIN THE VALUES OF THE STEP,
C     FUNCTION, AND DIRECTIONAL DERIVATIVE AT THE BEST STEP.
C     THE VARIABLES STY, FY, DGY CONTAIN THE VALUE OF THE STEP,
C     FUNCTION, AND DERIVATIVE AT THE OTHER ENDPOINT OF
C     THE INTERVAL OF UNCERTAINTY.
C     THE VARIABLES STP, F, DG CONTAIN THE VALUES OF THE STEP,
C     FUNCTION, AND DERIVATIVE AT THE CURRENT STEP.
C
      STX = ZERO
      FX = FINIT
      DGX = DGINIT
      STY = ZERO
      FY = FINIT
      DGY = DGINIT
C
C     START OF ITERATION.
C
   30 CONTINUE
C
C        SET THE MINIMUM AND MAXIMUM STEPS TO CORRESPOND
C        TO THE PRESENT INTERVAL OF UNCERTAINTY.
C
         IF (BRACKT) THEN
            STMIN = MIN(STX,STY)
            STMAX = MAX(STX,STY)
         ELSE
            STMIN = STX
            STMAX = STP + XTRAPF*(STP - STX)
            END IF
C
C        FORCE THE STEP TO BE WITHIN THE BOUNDS STPMAX AND STPMIN.
C
         STP = MAX(STP,STPMIN)
         STP = MIN(STP,STPMAX)
C
C        IF AN UNUSUAL TERMINATION IS TO OCCUR THEN LET
C        STP BE THE LOWEST POINT OBTAINED SO FAR.
C
         IF ((BRACKT .AND. (STP .LE. STMIN .OR. STP .GE. STMAX))
     *      .OR. NFEV .GE. MAXFEV-1 .OR. INFOC .EQ. 0
     *      .OR. (BRACKT .AND. STMAX-STMIN .LE. XTOL*STMAX)) STP = STX
C
C        EVALUATE THE FUNCTION AND GRADIENT AT STP
C        AND COMPUTE THE DIRECTIONAL DERIVATIVE.
C
         DO 40 J = 1, N
            X(J) = WA(J) + STP*S(J)
   40       CONTINUE
C        Return to compute function value
         INFO=-1
         RETURN
C
   45    INFO=0
         NFEV = NFEV + 1
         DG = ZERO
         DO 50 J = 1, N
            DG = DG + G(J)*S(J)
   50       CONTINUE
         FTEST1 = FINIT + STP*DGTEST
C
C        TEST FOR CONVERGENCE.
C
         IF ((BRACKT .AND. (STP .LE. STMIN .OR. STP .GE. STMAX))
     *      .OR. INFOC .EQ. 0) INFO = 6
         IF (STP .EQ. STPMAX .AND.
     *       F .LE. FTEST1 .AND. DG .LE. DGTEST) INFO = 5
         IF (STP .EQ. STPMIN .AND.
     *       (F .GT. FTEST1 .OR. DG .GE. DGTEST)) INFO = 4
         IF (NFEV .GE. MAXFEV) INFO = 3
         IF (BRACKT .AND. STMAX-STMIN .LE. XTOL*STMAX) INFO = 2
C        More's code has been modified so that at least one new
C        function value is computed during the line search (enforcing
C        at least one interpolation is not easy, since the code may
C        override an interpolation)
         IF (F .LE. FTEST1 .AND. ABS(DG) .LE. GTOL*(-DGINIT).
     *       AND.NFEV.GT.1) INFO = 1
C
C        CHECK FOR TERMINATION.
C
         IF (INFO .NE. 0)THEN
            DGOUT=DG
            RETURN
         ENDIF
 321     continue
C
C        IN THE FIRST STAGE WE SEEK A STEP FOR WHICH THE MODIFIED
C        FUNCTION HAS A NONPOSITIVE VALUE AND NONNEGATIVE DERIVATIVE.
C
         IF (STAGE1 .AND. F .LE. FTEST1 .AND.
     *       DG .GE. MIN(FTOL,GTOL)*DGINIT) STAGE1 = .FALSE.
C
C        A MODIFIED FUNCTION IS USED TO PREDICT THE STEP ONLY IF
C        WE HAVE NOT OBTAINED A STEP FOR WHICH THE MODIFIED
C        FUNCTION HAS A NONPOSITIVE FUNCTION VALUE AND NONNEGATIVE
C        DERIVATIVE, AND IF A LOWER FUNCTION VALUE HAS BEEN
C        OBTAINED BUT THE DECREASE IS NOT SUFFICIENT.
C
         IF (STAGE1 .AND. F .LE. FX .AND. F .GT. FTEST1) THEN
C
C           DEFINE THE MODIFIED FUNCTION AND DERIVATIVE VALUES.
C
            FM = F - STP*DGTEST
            FXM = FX - STX*DGTEST
            FYM = FY - STY*DGTEST
            DGM = DG - DGTEST
            DGXM = DGX - DGTEST
            DGYM = DGY - DGTEST
C
C           CALL CSTEPM TO UPDATE THE INTERVAL OF UNCERTAINTY
C           AND TO COMPUTE THE NEW STEP.
C
            CALL CSTEPM(STX,FXM,DGXM,STY,FYM,DGYM,STP,FM,DGM,
     *                 BRACKT,STMIN,STMAX,INFOC)
C
C           RESET THE FUNCTION AND GRADIENT VALUES FOR F.
C
            FX = FXM + STX*DGTEST
            FY = FYM + STY*DGTEST
            DGX = DGXM + DGTEST
            DGY = DGYM + DGTEST
         ELSE
C
C           CALL CSTEPM TO UPDATE THE INTERVAL OF UNCERTAINTY
C           AND TO COMPUTE THE NEW STEP.
C
            CALL CSTEPM(STX,FX,DGX,STY,FY,DGY,STP,F,DG,
     *                 BRACKT,STMIN,STMAX,INFOC)
            END IF
C
C        FORCE A SUFFICIENT DECREASE IN THE SIZE OF THE
C        INTERVAL OF UNCERTAINTY.
C
         IF (BRACKT) THEN
            IF (ABS(STY-STX) .GE. P66*WIDTH1)
     *         STP = STX + P5*(STY - STX)
            WIDTH1 = WIDTH
            WIDTH = ABS(STY-STX)
            END IF
C
C        END OF ITERATION.
C
         GO TO 30
C
C     LAST CARD OF SUBROUTINE CVSMOD.
C
      END
      SUBROUTINE CSTEPM(STX,FX,DX,STY,FY,DY,STP,FP,DP,BRACKT,
     *                 STPMIN,STPMAX,INFO)
      INTEGER INFO
      REAL*4 STX,FX,DX,STY,FY,DY,STP,FP,DP,STPMIN,STPMAX
      LOGICAL BRACKT,BOUND
C     **********
C
C     SUBROUTINE CSTEPM
C
C     THE PURPOSE OF CSTEPM IS TO COMPUTE A SAFEGUARDED STEP FOR
C     A LINESEARCH AND TO UPDATE AN INTERVAL OF UNCERTAINTY FOR
C     A MINIMIZER OF THE FUNCTION.
C
C     THE PARAMETER STX CONTAINS THE STEP WITH THE LEAST FUNCTION
C     VALUE. THE PARAMETER STP CONTAINS THE CURRENT STEP. IT IS
C     ASSUMED THAT THE DERIVATIVE AT STX IS NEGATIVE IN THE
C     DIRECTION OF THE STEP. IF BRACKT IS SET TRUE THEN A
C     MINIMIZER HAS BEEN BRACKETED IN AN INTERVAL OF UNCERTAINTY
C     WITH ENDPOINTS STX AND STY.
C
C     THE SUBROUTINE STATEMENT IS
C
C       SUBROUTINE CSTEPM(STX,FX,DX,STY,FY,DY,STP,FP,DP,BRACKT,
C                        STPMIN,STPMAX,INFO)
C
C     WHERE
C
C       STX, FX, AND DX ARE VARIABLES WHICH SPECIFY THE STEP,
C         THE FUNCTION, AND THE DERIVATIVE AT THE BEST STEP OBTAINED
C         SO FAR. THE DERIVATIVE MUST BE NEGATIVE IN THE DIRECTION
C         OF THE STEP, THAT IS, DX AND STP-STX MUST HAVE OPPOSITE
C         SIGNS. ON OUTPUT THESE PARAMETERS ARE UPDATED APPROPRIATELY.
C
C       STY, FY, AND DY ARE VARIABLES WHICH SPECIFY THE STEP,
C         THE FUNCTION, AND THE DERIVATIVE AT THE OTHER ENDPOINT OF
C         THE INTERVAL OF UNCERTAINTY. ON OUTPUT THESE PARAMETERS ARE
C         UPDATED APPROPRIATELY.
C
C       STP, FP, AND DP ARE VARIABLES WHICH SPECIFY THE STEP,
C         THE FUNCTION, AND THE DERIVATIVE AT THE CURRENT STEP.
C         IF BRACKT IS SET TRUE THEN ON INPUT STP MUST BE
C         BETWEEN STX AND STY. ON OUTPUT STP IS SET TO THE NEW STEP.
C
C       BRACKT IS A LOGICAL VARIABLE WHICH SPECIFIES IF A MINIMIZER
C         HAS BEEN BRACKETED. IF THE MINIMIZER HAS NOT BEEN BRACKETED
C         THEN ON INPUT BRACKT MUST BE SET FALSE. IF THE MINIMIZER
C         IS BRACKETED THEN ON OUTPUT BRACKT IS SET TRUE.
C
C       STPMIN AND STPMAX ARE INPUT VARIABLES WHICH SPECIFY LOWER
C         AND UPPER BOUNDS FOR THE STEP.
C
C       INFO IS AN INTEGER OUTPUT VARIABLE SET AS FOLLOWS:
C         IF INFO = 1,2,3,4,5, THEN THE STEP HAS BEEN COMPUTED
C         ACCORDING TO ONE OF THE FIVE CASES BELOW. OTHERWISE
C         INFO = 0, AND THIS INDICATES IMPROPER INPUT PARAMETERS.
C
C     SUBPROGRAMS CALLED
C
C       FORTRAN-SUPPLIED ... ABS,MAX,MIN,SQRT
C
C     ARGONNE NATIONAL LABORATORY. MINPACK PROJECT. JUNE 1983
C     JORGE J. MORE', DAVID J. THUENTE
C
C     **********
      REAL*4 GAMMA,P,Q,R,S,SGND,STPC,STPF,STPQ,THETA
      INFO = 0
C
C     CHECK THE INPUT PARAMETERS FOR ERRORS.
C
      IF ((BRACKT .AND. (STP .LE. MIN(STX,STY) .OR.
     *    STP .GE. MAX(STX,STY))) .OR.
     *    DX*(STP-STX) .GE. 0.0 .OR. STPMAX .LT. STPMIN) RETURN
C
C     DETERMINE IF THE DERIVATIVES HAVE OPPOSITE SIGN.
C
      SGND = DP*(DX/ABS(DX))
C
C     FIRST CASE. A HIGHER FUNCTION VALUE.
C     THE MINIMUM IS BRACKETED. IF THE CUBIC STEP IS CLOSER
C     TO STX THAN THE QUADRATIC STEP, THE CUBIC STEP IS TAKEN,
C     ELSE THE AVERAGE OF THE CUBIC AND QUADRATIC STEPS IS TAKEN.
C
      IF (FP .GT. FX) THEN
         INFO = 1
         BOUND = .TRUE.
         THETA = 3.0*(FX - FP)/(STP - STX) + DX + DP
         S = MAX(ABS(THETA),ABS(DX),ABS(DP))
         GAMMA = S*SQRT((THETA/S)**2 - (DX/S)*(DP/S))
         IF (STP .LT. STX) GAMMA = -GAMMA
         P = (GAMMA - DX) + THETA
         Q = ((GAMMA - DX) + GAMMA) + DP
         R = P/Q
         STPC = STX + R*(STP - STX)
         STPQ = STX + ((DX/((FX-FP)/(STP-STX)+DX))/2.0)*(STP - STX)
         IF (ABS(STPC-STX) .LT. ABS(STPQ-STX)) THEN
            STPF = STPC
         ELSE
           STPF = STPC + (STPQ - STPC)/2.0
           END IF
         BRACKT = .TRUE.
C
C     SECOND CASE. A LOWER FUNCTION VALUE AND DERIVATIVES OF
C     OPPOSITE SIGN. THE MINIMUM IS BRACKETED. IF THE CUBIC
C     STEP IS CLOSER TO STX THAN THE QUADRATIC (SECANT) STEP,
C     THE CUBIC STEP IS TAKEN, ELSE THE QUADRATIC STEP IS TAKEN.
C
      ELSE IF (SGND .LT. 0.0) THEN
         INFO = 2
         BOUND = .FALSE.
         THETA = 3.0*(FX - FP)/(STP - STX) + DX + DP
         S = MAX(ABS(THETA),ABS(DX),ABS(DP))
         GAMMA = S*SQRT((THETA/S)**2 - (DX/S)*(DP/S))
         IF (STP .GT. STX) GAMMA = -GAMMA
         P = (GAMMA - DP) + THETA
         Q = ((GAMMA - DP) + GAMMA) + DX
         R = P/Q
         STPC = STP + R*(STX - STP)
         STPQ = STP + (DP/(DP-DX))*(STX - STP)
         IF (ABS(STPC-STP) .GT. ABS(STPQ-STP)) THEN
            STPF = STPC
         ELSE
            STPF = STPQ
            END IF
         BRACKT = .TRUE.
C
C     THIRD CASE. A LOWER FUNCTION VALUE, DERIVATIVES OF THE
C     SAME SIGN, AND THE MAGNITUDE OF THE DERIVATIVE DECREASES.
C     THE CUBIC STEP IS ONLY USED IF THE CUBIC TENDS TO INFINITY
C     IN THE DIRECTION OF THE STEP OR IF THE MINIMUM OF THE CUBIC
C     IS BEYOND STP. OTHERWISE THE CUBIC STEP IS DEFINED TO BE
C     EITHER STPMIN OR STPMAX. THE QUADRATIC (SECANT) STEP IS ALSO
C     COMPUTED AND IF THE MINIMUM IS BRACKETED THEN THE THE STEP
C     CLOSEST TO STX IS TAKEN, ELSE THE STEP FARTHEST AWAY IS TAKEN.
C
      ELSE IF (ABS(DP) .LT. ABS(DX)) THEN
         INFO = 3
         BOUND = .TRUE.
         THETA = 3.0*(FX - FP)/(STP - STX) + DX + DP
         S = MAX(ABS(THETA),ABS(DX),ABS(DP))
C
C        THE CASE GAMMA = 0 ONLY ARISES IF THE CUBIC DOES NOT TEND
C        TO INFINITY IN THE DIRECTION OF THE STEP.
C
         GAMMA = S*SQRT(MAX(0.0E0,(THETA/S)**2 - (DX/S)*(DP/S)))
         IF (STP .GT. STX) GAMMA = -GAMMA
         P = (GAMMA - DP) + THETA
         Q = (GAMMA + (DX - DP)) + GAMMA
         R = P/Q
         IF (R .LT. 0.0 .AND. GAMMA .NE. 0.0) THEN
            STPC = STP + R*(STX - STP)
         ELSE IF (STP .GT. STX) THEN
            STPC = STPMAX
         ELSE
            STPC = STPMIN
            END IF
         STPQ = STP + (DP/(DP-DX))*(STX - STP)
         IF (BRACKT) THEN
            IF (ABS(STP-STPC) .LT. ABS(STP-STPQ)) THEN
               STPF = STPC
            ELSE
               STPF = STPQ
               END IF
         ELSE
            IF (ABS(STP-STPC) .GT. ABS(STP-STPQ)) THEN
               STPF = STPC
            ELSE
               STPF = STPQ
               END IF
            END IF
C
C     FOURTH CASE. A LOWER FUNCTION VALUE, DERIVATIVES OF THE
C     SAME SIGN, AND THE MAGNITUDE OF THE DERIVATIVE DOES
C     NOT DECREASE. IF THE MINIMUM IS NOT BRACKETED, THE STEP
C     IS EITHER STPMIN OR STPMAX, ELSE THE CUBIC STEP IS TAKEN.
C
      ELSE
         INFO = 4
         BOUND = .FALSE.
         IF (BRACKT) THEN
            THETA = 3.0*(FP - FY)/(STY - STP) + DY + DP
            S = MAX(ABS(THETA),ABS(DY),ABS(DP))
            GAMMA = S*SQRT((THETA/S)**2 - (DY/S)*(DP/S))
            IF (STP .GT. STY) GAMMA = -GAMMA
            P = (GAMMA - DP) + THETA
            Q = ((GAMMA - DP) + GAMMA) + DY
            R = P/Q
            STPC = STP + R*(STY - STP)
            STPF = STPC
         ELSE IF (STP .GT. STX) THEN
            STPF = STPMAX
         ELSE
            STPF = STPMIN
            END IF
         END IF
C
C     UPDATE THE INTERVAL OF UNCERTAINTY. THIS UPDATE DOES NOT
C     DEPEND ON THE NEW STEP OR THE CASE ANALYSIS ABOVE.
C
      IF (FP .GT. FX) THEN
         STY = STP
         FY = FP
         DY = DP
      ELSE
         IF (SGND .LT. 0.0) THEN
            STY = STX
            FY = FX
            DY = DX
            END IF
         STX = STP
         FX = FP
         DX = DP
         END IF
C
C     COMPUTE THE NEW STEP AND SAFEGUARD IT.
C
      STPF = MIN(STPMAX,STPF)
      STPF = MAX(STPMIN,STPF)
      STP = STPF
      IF (BRACKT .AND. BOUND) THEN
         IF (STY .GT. STX) THEN
            STP = MIN(STX+0.66*(STY-STX),STP)
         ELSE
            STP = MAX(STX+0.66*(STY-STX),STP)
            END IF
         END IF
      RETURN
C
C     LAST CARD OF SUBROUTINE CSTEPM.
C
      END
