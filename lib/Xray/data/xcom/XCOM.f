      PROGRAM XCOM
C
C       Version 3.1, 23 June 1999.  
C       
C       Copyright 1999, Martin J. Berger. Permission is given to
C       use the program for non-commercial purposes. 
C
C       A descripton of the program is available in National Bureau of
C       Standards Report NBSIR-87 by M. J. Berger and J. H. Hubbell. 
C       The authors can be reached at the National Institute of
C       Standards and Technology, Gaithersburg, MD 20899, Phone: (301)
C       975-5550.
C
C       XCOM3 calculates tables of cross sections for the interactions
C       of photons with any element, compound or mixture, for photons
C       with energies between 1 keV and 100 GeV.
C      
C       Files MDATX3.001, MDATX3.002,..., MDATX3.100 contain input data
C       for each or the elements. 
C
C       XCOM3 uses the following subroutines:
C       SPEC, FORM, MERGE, REV, SCOF, BSPOL and BLIN.
C
      CHARACTER PSOR*30,INPUT*10,XFIL1*30,XFIL2*30,SUB*72,
     1 IND(100)*3,FF*1
      PARAMETER (ME=1500,MEA=600,MEB=1800)                              SMS
      DIMENSION E(108),AFIT(108),BFIT(108),CFIT(108),DFIT(108),
     1 SCATCO(108),SCATIN(108),PHOT(108),PAIRAT(108),PAIREL(108),
     2 SATCO(94),SATIN(94),POT(94),PDIF(94),PAIRT(94),PAIRL(94),
     3 PR1(55),PR2(51),PHC(35,14),WEIGHT(100),NZ(100),
     4 JM(MEA),JZ(MEA),KM(ME),KZ(ME),LM(14),LZ(14),JDG(MEA),LEN(MEA),   SMS
     5 SCTCO(ME),SCTIN(ME),PHT(ME),PHDIF(ME),ENB(80),ATWTS(100),
     6 PRAT(ME),PREL(ME),AT(ME),ATNC(ME),EN(ME),ENL(ME),EAD(MEA),
     7 IDG(14),EDGEN(14),ADG(14),EDGE(94),ALAB(ME),X(MEB,8),            SMS
     8 ENG(35,14),ENGL(35),PHCL(35),KMX(14)
      DATA  NENG/80/,AVOG/0.60221367/
      DATA EPAIR1/1.022007E+06/,EPAIR2/2.044014E+06/
      INCLUDE 'ENB.DAT'
      INCLUDE 'INDEX.DAT'
      INCLUDE 'ATWTS.DAT'
    5 FORMAT(A)
   10 FORMAT(1H )
      FF=CHAR(12)
      PRINT *,' Program XCOM, Version 3.1'                              SMS
      PRINT *,' M.J.Berger and J.H.Hubbell, 23 June 1999'               SMS
      PRINT 10
      CALL SPEC(SUB,NF,KMAX,NZ,WEIGHT,JENG,EAD,NEGO,PSOR)
      DO 11 J=1,30
      IF(PSOR(J:J).NE.' ') GO TO 12
   11 CONTINUE
   12 JBEG=J
      DO 13 J=30,1,-1
      IF(PSOR(J:J).NE.' ') GO TO 14
   13 CONTINUE
   14 JFIN=J
      GO TO (60,30,15),NEGO
   15 NENG=JENG
      DO 20 N=1,NENG
      EN(N)=EAD(N)
      KZ(N)=-1
   20 KM(N)=0
      MMAX=1
      LEN(1)=NENG
      GO TO 220
   30 DO 40 N=1,NENG
      EN(N)=ENB(N)
      KZ(N)=0
   40 KM(N)=N
      DO 50 J=1,JENG
      JZ(J)=-1
   50 JM(J)=0
      CALL MERGE(EN,KZ,KM,NENG,EAD,JZ,JM,JENG)
      GO TO 75
   60 DO 70 N=1,NENG
      EN(N)=ENB(N)
      KZ(N)=0
   70 KM(N)=N
   75 DO 110 K=1,KMAX
      KV=NZ(K)
      INPUT=PSOR(JBEG:JFIN)//IND(KV)
      OPEN (UNIT=7,FILE=INPUT)
      READ (7,76) IZ,ATWT
   76 FORMAT(I6,F12.6)
      READ (7,77) MAXEDG,MAXE
   77 FORMAT(12I6)
      IF(MAXEDG)100,100,80
   80 READ (7,77) (IDG(I),I=MAXEDG,1,-1)
      READ (7,81) (ADG(I),I=1,MAXEDG)
   81 FORMAT(14(1X,A2))
      READ (7,82) (EDGEN(I),I=MAXEDG,1,-1)
   82 FORMAT(8F9.1)
      DO 90 I=1,MAXEDG
      LZ(I)=IZ
   90 LM(I)=I+80
      CALL MERGE(EN,KZ,KM,NENG,EDGEN,LZ,LM,MAXEDG)
  100 CLOSE (UNIT=7)
  110 CONTINUE
      KOUNT=0                                                           SMS
      IF(KZ(2))130,130,120
  120 KOUNT=KOUNT+1
      EAD(KOUNT)=SQRT(EN(1)*EN(2))
  130 DO 150 N=2,NENG
      IF(KZ(N))150,150,140
  140 IF(KZ(N-1))150,150,141
  141 KOUNT=KOUNT+1
      IF(EN(N)-EN(N-1))143,142,143
  142 EAD(KOUNT)=EN(N)
      EN(N-1)=EN(N-1)*0.99995
      EN(N)=EN(N)*1.00005
      GO TO 150
  143 EAD(KOUNT)=SQRT(EN(N)*EN(N-1))
  150 CONTINUE
      IF(KOUNT)180,180,160
  160 DO 170 J=1,KOUNT
      JZ(J)=-2
  170 JM(J)=0
      CALL MERGE(EN,KZ,KM,NENG,EAD,JZ,JM,KOUNT)
  180 MX=0
      DO 200 N=1,NENG
      IF(KZ(N))200,200,190
  190 MX=MX+1
      JDG(MX)=N
  200 CONTINUE
      MMAX=MX+1
      IF(MMAX-1)201,201,205
  201 LEN(1)=NENG
      GO TO 220
  205 MXED=MX
      LEN(1)=JDG(1)
      DO 210 M=2,MX
  210 LEN(M)=JDG(M)-JDG(M-1)+1
      LEN(MMAX)=NENG-JDG(MXED)+1
  220 DO 230 N=1,NENG
      ENL(N)=LOG(EN(N))
      SCTCO(N)=0.0
      SCTIN(N)=0.0
      PHT(N)=0.0
      PRAT(N)=0.0
  230 PREL(N)=0.0
      DO 610 K=1,KMAX
      KV=NZ(K)
      INPUT=PSOR(JBEG:JFIN)//IND(KV)
      OPEN (UNIT=7,FILE=INPUT)
      READ (7,76) IZ,ATWT1
      ATWT=ATWTS(KV)
      READ (7,77) MAXEDG,MAXE
      IF(MAXEDG)250,250,240
  240 READ (7,77) (IDG(I),I=MAXEDG,1,-1)
      READ (7,81) (ADG(I),I=1,MAXEDG)
      READ (7,82) (EDGEN(I),I=MAXEDG,1,-1)
  250 READ (7,251) (E(M),M=1,MAXE)
  251 FORMAT(1P6E13.5)
      READ (7,252) (SCATCO(M),M=1,MAXE)
  252 FORMAT(1P8E10.3)
      READ (7,252) (SCATIN(M),M=1,MAXE)
      READ (7,252) (PHOT(M), M=1,MAXE)
      READ (7,252) (PAIRAT(M),M=1,MAXE)
      READ (7,252) (PAIREL(M),M=1,MAXE)
      MAXK=0
      IF(MAXEDG)280,280,260
  260 MAXK=MAXE-IDG(MAXEDG)+1
      READ (7,*) LAX
      READ (7,*) (KMX(L),L=1,LAX)
      DO 265 L=1,LAX
      IMAX=KMX(L)
      READ (7,*) (ENG(I,L),I=1,IMAX)
  265 CONTINUE
      DO 270 L=1,LAX
      IMAX=KMX(L)
      READ (7,*) (PHC(I,L),I=1,IMAX)
  270 CONTINUE
  280 CLOSE (UNIT=7)
      IF(MAXEDG)290,290,310
  290 DO 300 M=1,MAXE 
      SATCO(M)=SCATCO(M)
      SATIN(M)=SCATIN(M)
      POT(M)=PHOT(M)
      PDIF(M)=0.0 
      PAIRT(M)=PAIRAT(M)
  300 PAIRL(M)=PAIREL(M)
      GO TO 395 
  310 IRV=MAXEDG
      DO 325 I=1,MAXEDG 
      IG=IDG(I) 
      IP=I+80 
      SATCO(IP)=SCATCO(IG)
      SATIN(IP)=SCATIN(IG)
      POT(IP)=PHOT(IG)
      PDIF(IP)=PHOT(IG)-PHOT(IG-1)
      PAIRT(IP)=PAIRAT(IG)
      PAIRL(IP)=PAIREL(IG)
      EDGE(IP)=ADG(IRV) 
  325 IRV=IRV-1 
      MB=0
      DO 340 M=1,MAXE 
      DO 335 I=1,MAXEDG 
      IF(M-IDG(I)+1)330,340,330 
  330 IF(M-IDG(I))335,340,335 
  335 CONTINUE
      MB=MB+1 
      SATCO(MB)=SCATCO(M) 
      SATIN(MB)=SCATIN(M) 
      POT(MB)=PHOT(M) 
      PDIF(MB)=0.0
      PAIRT(MB)=PAIRAT(M) 
      PAIRL(MB)=PAIREL(M) 
  340 CONTINUE
      MS=0
      DO 360 M=1,MAXE 
      DO 350 I=1,MAXEDG 
      IF(M-IDG(I)+1)350,360,350 
  350 CONTINUE
      MS=MS+1 
      E(MS)=E(M)
      SCATCO(MS)=SCATCO(M)
      SCATIN(MS)=SCATIN(M)
      PHOT(MS)=PHOT(M)
      PAIRAT(MS)=PAIRAT(M)
      PAIREL(MS)=PAIREL(M)
  360 CONTINUE
      MAXE=MS
  395 CALL REV(MAXE,E)
      CALL REV(MAXE,SCATCO) 
      CALL REV(MAXE,SCATIN) 
      CALL REV(MAXE,PHOT)
      CALL REV(MAXE,PAIRAT) 
      CALL REV(MAXE,PAIREL) 
      E(51)=EPAIR2
      E(55)=EPAIR1
      DO 420 M=1,54 
      TERM=(E(M)-EPAIR1)/E(M) 
  420 PR1(M)=LOG(PAIRAT(M)/(TERM**3)) 
      PR1(55)=3.006275*PR1(54)-2.577757*PR1(53)+0.571482*PR1(52)
      DO 425 M=1,50 
      TERM=(E(M)-EPAIR2)/E(M) 
  425 PR2(M)=LOG(PAIREL(M)/(TERM**3)) 
      PR2(51)=3.006275*PR2(50)-2.577757*PR2(49)+0.571482*PR2(48)
      DO 430 M=1,MAXE 
      E(M)=LOG(E(M))
      SCATCO(M)=LOG(SCATCO(M))
      SCATIN(M)=LOG(SCATIN(M))
  430 PHOT(M)=LOG(PHOT(M))
      GO TO (436,436,437), NF
  436 FRAC=1.0
      GO TO 438
  437 FRAC=AVOG*WEIGHT(K)/ATWT
  438 ECUT=0.0
      IF (MAXEDG.GT.0) ECUT=EDGEN(MAXEDG)
      IF(NENG-80)460,440,460
  440 IF (NEGO.EQ.3) GO TO 460                                          SMS
      DO 450 N=1,NENG
      SCTCO(N)=SCTCO(N)+FRAC*SATCO(N)
      SCTIN(N)=SCTIN(N)+FRAC*SATIN(N)
      PHT(N)=PHT(N)+FRAC*POT(N)
      PRAT(N)=PRAT(N)+FRAC*PAIRT(N)
  450 PREL(N)=PREL(N)+FRAC*PAIRL(N)
      GO TO 610
  460 IMP=1
      DO 600 N=1,NENG
      IF(KZ(N))500,490,470
  470 IF(KZ(N)-IZ)500,480,500 
  480 NN=KM(N)
      PHDIF(N)=FRAC*PDIF(NN)
      ALAB(N)=EDGE(NN)
  490 NN=KM(N)
      SCTCO(N)=SCTCO(N)+FRAC*SATCO(NN)
      SCTIN(N)=SCTIN(N)+FRAC*SATIN(NN)
      PHT(N)=PHT(N)+FRAC*POT(NN)
      PRAT(N)=PRAT(N)+FRAC*PAIRT(NN)
      PREL(N)=PREL(N)+FRAC*PAIRL(NN)
      GO TO 600
  500 T=EN(N)
      TL=ENL(N)
      CALL SCOF(E,SCATCO,MAXE,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,MAXE,RES)
      SCTCO(N)=SCTCO(N)+FRAC*EXP(RES)
      CALL SCOF(E,SCATIN,MAXE,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,MAXE,RES)
      SCTIN(N)=SCTIN(N)+FRAC*EXP(RES)
      IF(T-EPAIR1)530,530,510 
  510 TERM=(T-EPAIR1)/T
      CALL SCOF(E,PR1,55,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,55,RES) 
      PRAT(N)=PRAT(N)+FRAC*(TERM**3)*EXP(RES)
      IF(T-EPAIR2)530,530,520 
  520 TERM=(T-EPAIR2)/T
      CALL SCOF(E,PR2,51,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,51,RES) 
      PREL(N)=PREL(N)+FRAC*(TERM**3)*EXP(RES)
  530 IF(MAXEDG)540,540,550
  540 CALL SCOF(E,PHOT,MAXE,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,MAXE,RES)
      PHT(N)=PHT(N)+FRAC*EXP(RES)
      GO TO 600
  550 IF(T-ECUT)570,560,560
  560 CALL SCOF(E,PHOT,MAXK,AFIT,BFIT,CFIT,DFIT)
      CALL BSPOL(TL,E,AFIT,BFIT,CFIT,DFIT,MAXK,RES)
      PHT(N)=PHT(N)+FRAC*EXP(RES)
      GO TO 600
  570 IF(T-EDGEN(IMP))590,580,580
  580 IMP=IMP+1
      GO TO 570
  590 MAXX=KMX(IMP)
      DO 592 M=1,MAXX
      ENGL(M)=LOG(1.0E+06)+LOG(ENG(M,IMP))
  592 PHCL(M)=LOG(PHC(M,IMP))
      CALL BLIN(TL,ENGL,PHCL,MAXX,RES)
      PHT(N)=PHT(N)+FRAC*EXP(RES)
  600 CONTINUE
  610 CONTINUE
      DO 622 N=1,NENG
      ATNC(N)=SCTIN(N)+PHT(N)+PRAT(N)+PREL(N)
      AT(N)=ATNC(N)+SCTCO(N)
      GO TO (622,621,622), NF
  621 AT(N)=AVOG*AT(N)/ATWT
      ATNC(N)=AVOG*ATNC(N)/ATWT
  622 CONTINUE
      PRINT *,' Specify file on which output (cross section table)'
      PRINT *,' is to be stored. (Specification can include drive'
      PRINT *,' and path): '
      READ 5, XFIL1
      OPEN (UNIT=8,FILE=XFIL1)
      NN=1
      JTAL=0
      DO 880 N=1,NENG
      IF(JTAL)640,640,805
  640 IF(N-1)650,650,645
  645 WRITE (8,*) FF
  650 WRITE (8,660) SUB
  660 FORMAT(8X,A)
      WRITE (8,10)
      WRITE (8,662)
  662 FORMAT(8X,'Constituents (Atomic Number:Fraction by Weight)')
      WRITE (8,665) (NZ(K),WEIGHT(K),K=1,KMAX)
  665 FORMAT((8X,6(1X,I3,':',F7.5)))                                    SMS
      WRITE (8,10)
      GO TO (670,675,690), NF
  670 WRITE (8,672)
  672 FORMAT(8X,'Cross Sections')
      WRITE (8,685)
      GO TO 710
  675 WRITE (8,680)
  680 FORMAT(8X,'Cross Sections and Attenuation Coefficients')
      WRITE (8,685)
  685 FORMAT(8X,'(Note that 1 b(arn) = 10**(-24) cm2)')
      GO TO 710
  690 WRITE (8,700)
  700 FORMAT(8X,'Partial Interaction Coefficients',
     1' and Total Attenuation Coefficients')
  710 WRITE (8,10)
      GO TO (711,715,715), NF
  711 WRITE (8,712)
C 712 FORMAT(8X,'PHOTON',6X,'SCATTERING',
C    16X,'PHOTO-',4X,'PAIR PRODUCTION',
C    22X,'TOT.CROSS SECTION')
  712 FORMAT(9X,'PHOTON',7X,'SCATTERING',                               SMS
     17X,'PHOTO-',5X,'PAIR PRODUCTION',                                 SMS
     24X,'TOT.CROSS SECTION')                                           SMS
      GO TO 724
  715 WRITE (8,720)
C 720 FORMAT(8X,'PHOTON',6X,'SCATTERING',
C    16X,'PHOTO-',4X,'PAIR PRODUCTION',
C    22X,'TOTAL ATTENUATION')
  720 FORMAT(9X,'PHOTON',7X,'SCATTERING',                               SMS
     17X,'PHOTO-',5X,'PAIR PRODUCTION',                                 SMS
     24X,'TOTAL ATTENUATION')                                           SMS
  724 WRITE (8,730)
C 730 FORMAT(8X,'ENERGY',3X,'COHERENT INCOHER. ELECTRIC',
C    14X,'IN',7X,'IN',7X,'WITH',3X,'WITHOUT')
  730 FORMAT(9X,'ENERGY',3X,'COHERENT  INCOHER.  ELECTRIC',             SMS
     15X,'IN',8X,'IN',8X,'WITH',4X,'WITHOUT')                           SMS
      WRITE (8,740)
C 740 FORMAT(34X,'ABSORPTION NUCLEAR ELECTRON  COHERENT COHERENT')
  740 FORMAT(37X,'ABSORPTION  NUCLEAR  ELECTRON   COHERENT  COHERENT')  SMS
      WRITE (8,750)
C 750 FORMAT(46X,'FIELD',4X,'FIELD',4X,'SCATT.',3X,'SCATT.')
  750 FORMAT(50X,'FIELD',5X,'FIELD',5X,'SCATT.',4X,'SCATT.')            SMS
      GO TO (791,780,760), NF
  760 WRITE (8,770)
C 770 FORMAT(9X,'(MeV)',2X,7(2X,'(cm2/g)'))
  770 FORMAT(10X,'(MeV)',1X,7(3X,'(cm2/g)'))                            SMS
      GO TO 800
  780 WRITE (8,790)
C 790 FORMAT(9X,'(MeV)',3X,5('(b/atom) '),2X,'(cm2/g)',2X,'(cm2/g)')
  790 FORMAT(10X,'(MeV)',2X,5(1X,'(b/atom) '),2(3X,'(cm2/g)'))          SMS
      GO TO 800
  791 WRITE (8,792)
C 792 FORMAT(9X,'(MeV)',3x,7('(b/atom) '))
  792 FORMAT(10X,'(MeV)',2X,5(1X,'(b/atom) '),1X,2(1X,'(b/atom) '))     SMS
  800 WRITE (8,10)
  805 ENN=EN(N)*(1.0E-06)
      IF(KZ(N))870,870,810
  810 PHT1=PHT(N)-PHDIF(N)
      GO TO (812,811,812), NF
C 811 AT1=AT(N)-0.6022045*PHDIF(N)/ATWT
  811 AT1=AT(N)-AVOG*PHDIF(N)/ATWT                                      SMS
      ATNC1=ATNC(N)-AVOG*PHDIF(N)/ATWT
      GO TO 815
  812 AT1=AT(N)-PHDIF(N)
      ATNC1=ATNC(N)-PHDIF(N)
  815 WRITE(8,820) ENN,SCTCO(N),SCTIN(N),PHT1,
     1 PRAT(N),PREL(N),AT1,ATNC1
C 820 FORMAT(7X,1PE10.3,1P7E9.2)
  820 FORMAT(7X,1PE10.3,1P7E10.3)                                       SMS
      WRITE (8,10)
      X(NN,1)=ENN
      X(NN,2)=SCTCO(N)
      X(NN,3)=SCTIN(N)
      X(NN,4)=PHT1
      X(NN,5)=PRAT(N)
      X(NN,6)=PREL(N)
      X(NN,7)=AT1
      X(NN,8)=ATNC1
      NN=NN+1
      WRITE(8,840) KZ(N),ALAB(N),ENN,SCTCO(N),SCTIN(N),PHT(N),
     1 PRAT(N),PREL(N),AT(N),ATNC(N)
C 840 FORMAT(1X,I2,1X,A2,1X,1PE10.3,1P7E9.2)
  840 FORMAT(I3,1X,A2,1X,1PE10.3,1P7E10.3)                              SMS
      X(NN,1)=ENN
      X(NN,2)=SCTCO(N)
      X(NN,3)=SCTIN(N)
      X(NN,4)=PHT(N)
      X(NN,5)=PRAT(N)
      X(NN,6)=PREL(N)
      X(NN,7)=AT(N)
      X(NN,8)=ATNC(N)
      NN=NN+1
      JTAL=JTAL+3
  850 IF(JTAL-43)880,880,860
  860 JTAL=0
      GO TO 880
  870 WRITE (8,820) ENN,SCTCO(N),SCTIN(N),PHT(N),PRAT(N),PREL(N),
     1 AT(N),ATNC(N)
      X(NN,1)=ENN
      X(NN,2)=SCTCO(N)
      X(NN,3)=SCTIN(N)
      X(NN,4)=PHT(N)
      X(NN,5)=PRAT(N)
      X(NN,6)=PREL(N)
      X(NN,7)=AT(N)
      X(NN,8)=ATNC(N)
      NN=NN+1
      JTAL=JTAL+1
      GO TO 850
  880 CONTINUE
      CLOSE (8)
      PRINT 890, XFIL1
  890 FORMAT(' Cross-section table with headings has been stored',
     1' in file ',A)
      PRINT *,' Options for further output:'
      PRINT *,'     1. No more output'
      PRINT *,'     2. Selected arrays stored on disk'
      PRINT *,' Enter choice: '
      READ *, NOUT
      GO TO (1020,920), NOUT
  920 PRINT *,'  '
      PRINT *,' Specify file on which selected arrays are to be stored.'
      PRINT *,' (Specification can include drive and path): ' 
      READ 5, XFIL2
      OPEN (UNIT=9,FILE=XFIL2)
      WRITE (9,5) SUB
      WRITE (9,940) KMAX
  940 FORMAT(12I6)
      WRITE (9,940) (NZ(K),K=1,KMAX)
      WRITE (9,950) (WEIGHT(K),K=1,KMAX)
  950 FORMAT(6F9.6)
      WRITE (9,940) MMAX
      WRITE (9,940) (LEN(M),M=1,MMAX)
  960 PRINT *,' Options for array to be stored on on disk:'
      PRINT *,'     0. Quit'
      PRINT *,'     1. Energy list'
      PRINT *,'     2. Coherent scattering cross section'
      PRINT *,'     3. Incoherent scattering cross section'
      PRINT *,'     4. Photoelectric absorption cross section'
      PRINT *,'     5. Pair prod. cross section (atomic nucleus)'
      PRINT *,'     6. Pair prod. cross section (atomic electrons)'
      PRINT *,'     7. Total attenuation coeff.(or cross section)'
      PRINT *,'     8. Attenuation coeff.(or cross section)'
      PRINT *,'        without contribution from coherent scattering'
      PRINT *,'  Enter choice: '
      READ *, MAR
      IF(MAR)1000,1000,970
  970 L1=1
      GO TO (971,973,975,977,979,981,983,988), MAR
  971 WRITE (9,972)
  972 FORMAT(' ENERGY LIST')
      GO TO 993
  973 WRITE (9,974)
  974 FORMAT(' COHERENT SCATTERING CROSS SECTION')
      GO TO 993
  975 WRITE (9,976)
  976 FORMAT(' INCOHERENT SCATTERING CROSS SECTION')
      GO TO 993
  977 WRITE (9,978)
  978 FORMAT(' PHOTOELECTRIC ABSORPTION CROSS SECTION')
      GO TO 993
  979 WRITE (9,980)
  980 FORMAT(' PAIR PROD. CROSS SECTION (ATOMIC NUCLEUS)')
      GO TO 993
  981 WRITE (9,982)
  982 FORMAT(' PAIR PROD. CROSS SECTION (ATOMIC ELECTRONS)')
      GO TO 993
  983 GO TO (984,986,986), NF
  984 WRITE (9,985)
  985 FORMAT(' TOTAL CROSS SECTION')
      GO TO 993
  986 WRITE (9,987)
  987 FORMAT(' TOTAL ATTENUATION COEFFICIENT')
      GO TO 993
  988 GO TO (989,991,991), NF
  989 WRITE (9,990)
  990 FORMAT(' TOTAL CROSS SECTION WITHOUT COH. SCATTERING')
      GO TO 993
  991 WRITE (9,992)
  992 FORMAT(' TOTAL ATTENUATION COEFF. WITHOUT COH. SCATTERING')
  993 DO 995 M=1,MMAX
      L2=L1+LEN(M)-1
      WRITE (9,994) (X(L,MAR),L=L1,L2)
  994 FORMAT(1P6E12.4)
  995 L1=L2+1
      PRINT *,' Make next selection or quit.'
      GO TO 960
 1000 PRINT 1010, XFIL2
 1010 FORMAT(' Selected cross section arrays have been stored',
     1' on file ',A)
 1020 PRINT *,' Calculation is finished.'
      STOP
      END 

      SUBROUTINE SPEC(SUBST,NFORM,MMAX,JZ,WT,JING,EADD,NELL,SOURCE)
C     2 Apr 87. Reads various input parameters. 
      CHARACTER*72 FORMLA,FRM(100),SUBST
      CHARACTER*30 ENGIN,SOURCE
      CHARACTER  RESP*1                                                 SMS
      PARAMETER (MEA=1200)                                              SMS
      DIMENSION JZ(100),WT(100),JZ1(100),WT1(100),LH(100),WATE(100),
     1 FRAC(100),EADD(MEA)
      NFORM=3
   10 FORMAT(1H )
   12 FORMAT(A)
      PRINT *,' Enter name of substance: '
      READ 12, SUBST
      PRINT 10
      PRINT *,' Options for characterization of substance:'
      PRINT *,'    1. Elemental substance, specified by atomic number'
      PRINT *,'    2. Elemental substance, specified by chemical symbol'
      PRINT *,'    3. Compound, specified by chemical formula'
      PRINT *,'    4. Mixture of elements and/or compounds'
      PRINT *,' Enter choice: '
      READ *,NSUB
      PRINT 10
      GO TO(15,20,50,55),NSUB
   15 PRINT *,' Enter atomic number of element: '
      READ *, JZ(1)
      MMAX=1
      WT(1)=1.0
      GO TO 22
   20 PRINT *,' Enter chemical symbol for element: '
      READ 12,FORMLA
      PRINT 10
      CALL FORM(FORMLA,MMAX,JZ,WT)
   22 PRINT *,' Options for output quantities:'
      PRINT *,'     1. Cross sections in barns/atom'
      PRINT *,'     2. Cross sections in barns/atom, and'
      PRINT *,'        attenuation coefficients in cm2/g'
      PRINT *,'     3. Partial interaction coefficients and'
      PRINT *,'        attenuation coefficients in cm2/g'
      PRINT *,' Enter choice: '
      READ *,NFORM
      PRINT 10
   25 MAX=MMAX-1
      DO 40 M=1,MAX
      MP1=M+1
      DO 40 N=MP1,MMAX
      IF(JZ(M)-JZ(N))40,40,30
   30 JZTEMP=JZ(M)
      WTTEMP=WT(M)
      JZ(M)=JZ(N)
      WT(M)=WT(N)
      JZ(N)=JZTEMP
      WT(N)=WTTEMP
   40 CONTINUE
C     GO TO 150                                                         SMS
C        NOW THAT IN ASCENDING ORDER, COMBINE IDENTICAL Zs              SMS
      M=0                                                               SMS
   42 M=M+1                                                             SMS
      IF (M.GE.MMAX) GO TO 150                                          SMS
   44 IF (JZ(M).NE.JZ(M+1)) GO TO 42                                    SMS
      WT(M)=WT(M)+WT(M+1)                                               SMS
      MMAX=MMAX-1                                                       SMS
      IF (M.EQ.MMAX) GO TO 150                                          SMS
      DO 46 MM=M+1,MMAX                                                 SMS
      JZ(MM)=JZ(MM+1)                                                   SMS
   46 WT(MM)=WT(MM+1)                                                   SMS
      GO TO 44                                                          SMS
   50 PRINT *,'Enter chemical formula for compound: '
      READ 12,FORMLA
      PRINT 10
      CALL FORM(FORMLA,MMAX,JZ,WT)
      GO TO 25
   55 PRINT *,' How many components in mixture? Enter number: '
      READ *,NCOMP
      PRINT 10
      DO 65 N=1,NCOMP
      PRINT 60,N
   60 FORMAT(' Enter chemical symbol or formula for component',
     1 I3,': ')
      READ 12, FRM(N)
      PRINT 61,N
   61 FORMAT(' Enter fraction by weight for component',I3,': ')
      READ *, FRAC(N)
   65 CONTINUE
      PRINT 10
      SUMF=0.0
      DO 70 N=1,NCOMP
   70 SUMF=SUMF+FRAC(N)
      PRINT 72
   72 FORMAT('   Component    Fraction')
      PRINT 73
   73 FORMAT('               by Weight')
      PRINT 10
      DO 75 N=1,NCOMP
      PRINT 74,N,FRAC(N),FRM(N)
   74 FORMAT(I12,F12.6,6X,A)
   75 CONTINUE
      PRINT 10
      PRINT 80, SUMF
   80 FORMAT(6X,'Sum = ',F12.6)
      PRINT 10
      PRINT *,' Options for accepting or rejecting composition data:'
      PRINT *,'     1. Accept, but let program normalize fractions'
      PRINT *,'        by weight so that their sum is unity'
      PRINT *,'     2. Reject, and enter different set of fractions'
      PRINT *,' Enter choice: '
      READ *,MSUMGO
      PRINT 10
      GO TO (85,55), MSUMGO
   85 DO 90 N=1,NCOMP
   90 FRAC(N)=FRAC(N)/SUMF
      DO 95 L=1,100
   95 LH(L)=0
      DO 120 N=1,NCOMP
      CALL FORM (FRM(N),MAX,JZ1,WT1)
      DO 120 M=1,MAX
      IN=JZ1(M)
      IF(LH(IN))100,100,110
  100 LH(IN)=1
      WATE(IN)=FRAC(N)*WT1(M)
      GO TO 120
  110 WATE(IN)=WATE(IN)+FRAC(N)*WT1(M)
  120 CONTINUE
      LL=0
      DO 140 L=1,100
      IF(LH(L))140,140,130
  130 LL=LL+1
      JZ(LL)=L
      WT(LL)=WATE(L)
  140 CONTINUE
      MMAX=LL
  150 PRINT *,' Options for energy list for output data:'
      PRINT *,'     1. Standard energy grid only'
      PRINT *,'     2. Standard grid plus additional energies'
      PRINT *,'     3. Additional energies only'
      PRINT *,' Enter choice: '
      READ *,NELL
      PRINT 10
      GO TO (240,190,190), NELL
  190 PRINT *,' Modes of entering additional energies:'
      PRINT *,'     1. Entry from keyboard'
      PRINT *,'     2. Entry from prepared input file'
      PRINT *,' Enter choice: '
      READ *, INEN
      GO TO (200,210), INEN
  200 PRINT *,' How many additional energies are wanted? '
      READ *,JING
      PRINT 10
      DO 205 J=1,JING
      IF(J-1)201,201,202
  201 PRINT *,' Enter first energy (in MeV): '
      GO TO 203
  202 PRINT *,' Enter next energy (in MeV): '
  203 READ *, EADD(J)
  205 CONTINUE
      PRINT 10
      PRINT *,' Save additional energies in file? (Y/N): '              SMS
      READ *,RESP                                                       SMS
      IF (RESP.NE.'Y'.AND.RESP.NE.'y') GO TO 220                        SMS
      PRINT *,' Specify file name to save this energy list.'            SMS
      PRINT *,' (Specification can include drive and path): '           SMS
      READ 12, ENGIN                                                    SMS
      PRINT 10                                                          SMS
      OPEN (UNIT=7,FILE=ENGIN)                                          SMS
      WRITE (7,207) JING                                                SMS
  207 FORMAT (I6)                                                       SMS
      WRITE (7,208) (EADD(J),J=1,JING)                                  SMS
  208 FORMAT (1P6E12.5)                                                 SMS
      CLOSE (7)                                                         SMS
      GO TO 220
  210 PRINT *,' Specify file that contains input energy list.'
      PRINT *,' (Specification can include drive and path): '
      READ 12, ENGIN
      PRINT 10
      OPEN (UNIT=7,FILE=ENGIN)
      READ (7,*) JING,(EADD(J),J=1,JING)
      CLOSE (7)
  220 DO 230 J=1,JING
  230 EADD(J)=EADD(J)*1.0E+06
      CALL SORT (JING,EADD)                                             SMS
  240 CONTINUE                                                          SMS
C 240 PRINT *,' Options for entry of Database files:'
C     PRINT *,'    1. Read files from floppy-disk drive A'
C     PRINT *,'    2. Read files from floppy-disk drive B'
C     PRINT *,'    3. Read files from CURRENT directory on hard disk'
C     PRINT *,' Enter choice: '
C     READ *, INDAT
C     GO TO (241,242,243),INDAT
C 241 SOURCE='A:MDATX3.'
C     RETURN
C 242 SOURCE='B:MDATX3.'
C     RETURN
  243 SOURCE='MDATX3.'
      RETURN
      END
 
      SUBROUTINE FORM (W,MMAX,JZ,WT)
C     24 Mar 87. Reads element symbols or chemical formulas.
      CHARACTER*72,W
      DIMENSION MASH1(26),MASH2(418),IC(72),K(72),JZ(100),NZ(100),
     1 MS(100),ATWTS(100),WT(100)
      INCLUDE 'HASH1.DAT'
      INCLUDE 'HASH2.DAT'
      INCLUDE 'ATWTS.DAT'
      DO 116 L=1,72
      IC(L)=ICHAR(W(L:L))
      IF(IC(L)-32)101,102,103
  101 K(L)=1
      GO TO 116
  102 K(L)=2
      GO TO 116
  103 IF(IC(L)-48)104,105,105
  104 K(L)=1
      GO TO 116
  105 IF(IC(L)-58)106,107,107
  106 K(L)=3
      GO TO 116
  107 IF(IC(L)-65)108,109,109
  108 K(L)=1
      GO TO 116
  109 IF(IC(L)-91)110,111,111
  110 K(L)=4
      GO TO 116
  111 IF(IC(L)-97)112,113,113
  112 K(L)=1
      GO TO 116
  113 IF(IC(L)-123)114,115,115
  114 K(L)=5
      GO TO 116
  115 K(L)=1
  116 CONTINUE
      L=1
      M=0
  117 IF(K(L)-2)118,118,119
  118 L=L+1
      GO TO 117
  119 LMIN=L
  120 KG=K(L)
      IF(L-LMIN)130,130,140
  130 GO TO (150,150,150,160,150), KG
  140 GO TO (150,470,150,160,150), KG
  150 STOP 1
  160 KG1=K(L+1)
      GO TO (170,180,180,180,240), KG1
  170 STOP 2
  180 ICC=IC(L)-64
      JT=MASH1(ICC)
      IF(JT)190,190,200
  190 STOP 3
  200 M=M+1
      JZ(M)=JT
      GO TO (170,210,230,220,240), KG1
  210 NZ(M)=1
      GO TO 470
  220 NZ(M)=1
      L=L+1
      GO TO 120
  230 IN=L+1
      GO TO 390
  240 ICC=9*IC(L+1)-10*IC(L)+9
      IF(ICC-1)310,250,250
  250 IF(ICC-418)260,260,310
  260 IF(ICC-208)300,270,300
  270 M=M+1
      IF(IC(L)-71)290,280,290
  280 JZ(M)=32
      GO TO 330
  290 JZ(M)=84
      GO TO 330
  300 JT=MASH2(ICC)
      IF(JT)310,310,320
  310 STOP 4
  320 M=M+1
      JZ(M)=JT
  330 KG2=K(L+2)
      GO TO (340,350,380,360,370), KG2
  340 STOP 5
  350 NZ(M)=1
      GO TO 470
  360 NZ(M)=1
      L=L+2
      GO TO 120
  370 STOP 6
  380 IN=L+2
  390 INN=IN
      IS=0
      NZ(M)=0
  400 IF(K(INN)-3)420,410,420
  410 IS=IS+1
      MS(IS)=IC(INN)-48
      INN=INN+1
      GO TO 400
  420 ISM=IS
      KFAC=1
  430 NZ(M)=NZ(M)+KFAC*MS(IS)
      KFAC=10*KFAC
      IS=IS-1
      IF(IS)440,440,430
  440 IF(NZ(M))450,450,460
  450 STOP 7
  460 L=IN+ISM
      GO TO 120
  470 MMAX=M
      ASUM=0.0
      DO 480 M=1,MMAX
      JM=JZ(M)
  480 ASUM=ASUM+ATWTS(JM)*REAL(NZ(M))
      DO 490 M=1,MMAX
      JM=JZ(M)
  490 WT(M)=ATWTS(JM)*REAL(NZ(M))/ASUM
      RETURN
      END

      SUBROUTINE SORT (NMAX,E)                                          SMS
C     16 Jun 99. Sorts into monotonically increasing order.             SMS
      DIMENSION E(1)                                                    SMS
      DATA  EBIG/1.0E20/                                                SMS
      DO 20 M=1,NMAX-1                                                  SMS
      EMIN=EBIG                                                         SMS
      DO 10 N=M,NMAX                                                    SMS
      IF (E(N).GT.EMIN) GO TO 10                                        SMS
      EMIN=E(N)                                                         SMS
      NS=N                                                              SMS
   10 CONTINUE                                                          SMS
      E(NS)=E(M)                                                        SMS
      E(M)=EMIN                                                         SMS
   20 CONTINUE                                                          SMS
      RETURN                                                            SMS
      END                                                               SMS

      SUBROUTINE MERGE(E1,K1,L1,MMAX,E2,K2,L2,NMAX)
C     24 Mar 87. Merges energy lists.
      DIMENSION E1(1),K1(1),L1(1),E2(1),K2(1),L2(1)
      DATA MLIM/200/
      DO 50 N=1,NMAX
      M=2
   10 IF(E2(N)-E1(M))30,30,20
   20 M=M+1
      GO TO 10
   30 MC=M
      MF=M+1
      MMAX=MMAX+1
      IF(MMAX-MLIM)35,35,32
   32 PRINT 33,MMAX,MLIM
   33 FORMAT(6H MMAX=,I3,3X,6H MLIM=,I3)
      STOP
   35 DO 40 M=MMAX,MF,-1
      E1(M)=E1(M-1)
      K1(M)=K1(M-1)
   40 L1(M)=L1(M-1)
      E1(MC)=E2(N)
      K1(MC)=K2(N)
   50 L1(MC)=L2(N)
      RETURN
      END

      SUBROUTINE REV(NMAX,X)
C     24 Mar 87. Reverses the order of lists.
      DIMENSION X(1)
      NH=NMAX/2 
      DO 10 N=1,NH
      N1=NMAX-N+1 
      T=X(N1) 
      X(N1)=X(N)
   10 X(N)=T
      RETURN
      END 
       
      SUBROUTINE SCOF(X,F,NMAX,A,B,C,D) 
C     22 Feb 83. Fits F as a function of X, and calculates 
C                cubic spline coefficients A,B,C and D.
      DIMENSION X(1),F(1),A(1),B(1),C(1),D(1) 
      M1=2
      M2=NMAX-1 
      S=0.0 
      DO 10 M=1,M2
      D(M)=X(M+1)-X(M)
      R=(F(M+1)-F(M))/D(M)
      C(M)=R-S
   10 S=R 
      S=0.0 
      R=0.0 
      C(1)=0.0
      C(NMAX)=0.0 
      DO 20 M=M1,M2 
      C(M)=C(M)+R*C(M-1)
      B(M)=(X(M-1)-X(M+1))*2.0-R*S
      S=D(M)
   20 R=S/B(M)
      MR=M2 
      DO 30 M=M1,M2 
      C(MR)=(D(MR)*C(MR+1)-C(MR))/B(MR) 
   30 MR=MR-1 
      DO 40 M=1,M2
      S=D(M)
      R=C(M+1)-C(M) 
      D(M)=R/S
      C(M)=C(M)*3.0 
      B(M)=(F(M+1)-F(M))/S-(C(M)+R)*S 
   40 A(M)=F(M) 
      RETURN
      END 
       
      SUBROUTINE BSPOL(S,X,A,B,C,D,N,G)
C     22 Feb 83. Evaluates cubic spline as function of S, to obtain
C                fitted result G.
      DIMENSION X(1),A(1),B(1),C(1),D(1)
      IF (X(1).GT.X(N)) GO TO 10
      IDIR=0
      MLB=0 
      MUB=N 
      GO TO 20
   10 IDIR=1
      MLB=N 
      MUB=0 
   20 IF (S.GE.X(MUB+IDIR)) GO TO 60
      IF (S.LE.X(MLB+1-IDIR)) GO TO 70
      ML=MLB
      MU=MUB
      GO TO 40
   30 IF (IABS(MU-ML).LE.1) GO TO 80
   40 MAV=(ML+MU)/2 
      IF (S.LT.X(MAV)) GO TO 50 
      ML=MAV
      GO TO 30
   50 MU=MAV
      GO TO 30
   60 MU=MUB+2*IDIR-1 
      GO TO 90
   70 MU=MLB-2*IDIR+1 
      GO TO 90
   80 MU=MU+IDIR-1
   90 Q=S-X(MU) 
      G=((D(MU)*Q+C(MU))*Q+B(MU))*Q+A(MU) 
      RETURN
      END 
       
      SUBROUTINE BLIN(S,X,Y,N,T)
C     12 Apr 87. Linear interpolation routine
      DIMENSION X(1000),Y(1000)
      IF (X(1).GT.X(N)) GO TO 10
      IDIR=0
      MLB=0 
      MUB=N 
      GO TO 20
   10 IDIR=1
      MLB=N 
      MUB=0 
   20 IF (S.GE.X(MUB+IDIR)) GO TO 60
      IF (S.LE.X(MLB+1-IDIR)) GO TO 70
      ML=MLB
      MU=MUB
      GO TO 40
   30 IF (IABS(MU-ML).LE.1) GO TO 80
   40 MAV=(ML+MU)/2 
      IF (S.LT.X(MAV)) GO TO 50 
      ML=MAV
      GO TO 30
   50 MU=MAV
      GO TO 30
   60 MU=MUB+2*IDIR-1 
      GO TO 90
   70 MU=MLB-2*IDIR+1 
      GO TO 90
   80 MU=MU+IDIR-1
   90 Q=S-X(MU) 
      T=Y(MU)+Q*(Y(MU+1)-Y(MU))/(X(MU+1)-X(MU)) 
      RETURN
      END 
