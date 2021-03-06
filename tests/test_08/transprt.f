












































































c=======================================================================
c
c    \\\\\\\\\\      B E G I N   S U B R O U T I N E      //////////
c    //////////              T R A N S P R T              \\\\\\\\\\
c
c                            Developed by
c                Laboratory of Computational Astrophysics
c               University of Illinois at Urbana-Champaign
c
c=======================================================================
c
       subroutine transprt
c
c    mln:zeus3d.transprt <------------------ controls the transport step
c                                                          october, 1987
c
c    written by: Mike Norman
c    modified 1: June, 1988 by Jim Stone; incorporated into ZEUS2D
c    modified 2: February, 1990 by David Clarke; incorporated into
c                ZEUS3D
c    modified 3: Feb. 15, 1996 by Robert Fiedler; completely
c                rewritten for ZEUS-MP.
c    modified 4: Dec. 20, 1996 by Robert Fiedler; added radiation.
c    modified 5: Jan. 21, 1997 by Robert Fiedler; NO_TRANSPORT switch
c    modified 6: Dec. 30, 1999 by PSLi; added update of momenta.
c
c  PURPOSE: This subroutine transports the field variables through the
c  mesh in a directionally split manner.  In each succesive call to
c  TRANSPRT, the order of the directions is permuted (resulting in
c  ...YXZ...YZX...ZYX...ZXY...XZY......etc.).  This MAY be better
c  than leaving the order the same each time (......etc), and
c  seems to be better than unsplit schemes (Hawley).  Momenta are
c  computed from velocities in "avisc" and then transported.  Velocities
c  are not updated until the end of the transport step.  
c
c  The magnetic field components are updated by CT which is a merger (as
c  implemented by Jim Stone) of the method of characteristics and a
c  variant of the constrained transport algorithm of Evans and Hawley.
c
c  Note that the order in which variables are transported is important
c  (especially d).  
c
c  LOCAL VARIABLES:
c
c  EXTERNALS:
c    CT
c    ADVX1   , ADVX2   , ADVX3
c
c-----------------------------------------------------------------------
c
       implicit NONE




      integer in, jn, kn, ijkn, neqm
      parameter(in =           128+5
     &        , jn =           128+5
     &        , kn =           128+5)
      parameter(ijkn =   128+5)
      parameter(neqm = 1)
c
      integer nbvar
      parameter(nbvar = 14)

c
      real*8    pi, tiny, huge
      parameter(pi   = 3.14159265358979324)
      parameter(tiny =          1.000d-99 )
      parameter(huge =          1.000d+99 )
c
      real*8    zro, one, two, haf
      parameter(zro  = 0.0 )
      parameter(one  = 1.0 )
      parameter(two  = 2.0 )
      parameter(haf  = 0.5 )
c
      integer nbuff,mreq
      parameter(nbuff = 40, mreq=300)

      real*8
     . b1floor   ,b2floor   ,b3floor   ,ciso      
     .,courno    ,dfloor
     .,dtal    ,dtcs    ,dtv1    ,dtv2    ,dtv3
     .,dtqq    ,dtnew

     .,dtrd
     .,dt        ,dtdump 
     .,dthdf     ,dthist    ,dtmin     ,dttsl
CJH  .,dtqqi2 
     .,dtqqi2    ,dtnri2    ,dtrdi2    ,dtimrdi2
     .,dtusr
     .,efloor    ,erfloor   ,gamma     ,gamm1
     .,qcon      ,qlin 
     .,tdump
     .,thdf      ,thist     ,time      ,tlim      ,cpulim
     .,trem      ,tsave     ,ttsl
     .,tused     ,tusr

     .,v1floor   ,v2floor   ,v3floor 
     .,emf1floor ,emf2floor ,emf3floor 
     .,gpfloor

      integer

     . ifsen(6)

     .,idebug
     .,iordb1    ,iordb2    ,iordb3    ,iordd
     .,iorde     ,iorder    ,iords1    ,iords2
     .,iords3
     .,istpb1    ,istpb2    ,istpb3    ,istpd     ,istpe     ,istper
     .,istps1    ,istps2    ,istps3
C     .,isymm
     .,ix1x2x3   ,jx1x2x3
     .,nhy       ,nlim      ,nred      ,mbatch
     .,nwarn     ,nseq      ,flstat
c output file handles (efh 04/15/99)
     .,ioinp     ,iotsl     ,iolog     ,iohst     ,iomov     ,iores
     .,ioshl

      common /rootr/ 
     . b1floor ,b2floor ,b3floor ,ciso    ,courno
     .,dfloor
     .,dtal    ,dtcs    ,dtv1    ,dtv2    ,dtv3
     .,dtqq    ,dtnew

     .,dtrd
     .,dt      ,dtdump  ,dthdf
     .,dthist  ,dtmin   ,dttsl
CJH  .,dtqqi2  ,dtusr
     .,dtqqi2  ,dtusr   ,dtnri2  ,dtrdi2  ,dtimrdi2
     .,efloor  ,erfloor ,gamma   ,gamm1
     .,qcon    ,qlin
     .,tdump   ,thdf    ,thist
     .,time    ,tlim    ,cpulim  ,trem    ,tsave
     .,tused   ,tusr    ,ttsl    

     .,v1floor ,v2floor ,v3floor
     .,emf1floor ,emf2floor ,emf3floor
     .,gpfloor

      common /rooti/ 
     . ifsen   ,idebug
     .,iordb1  ,iordb2
     .,iordb3  ,iordd   ,iorde   ,iorder  ,iords1
     .,iords2  ,iords3 
     .,istpb1  ,istpb2  ,istpb3  ,istpd   ,istpe   ,istper
     .,istps1  ,istps2  ,istps3
C     .,isymm   
     .,ix1x2x3 ,jx1x2x3
     .,nhy     ,nlim    ,nred    ,mbatch
     .,nwarn   ,nseq    ,flstat
     .,ioinp   ,iotsl   ,iolog   ,iohst   ,iomov   ,iores
     .,ioshl

      character*2  id
      character*15 hdffile, hstfile, resfile, usrfile

      character*8  tslfile

      common /chroot2/  id
      common /chroot1/  hdffile, hstfile, resfile, usrfile

     .,tslfile

       integer is, ie, js, je, ks, ke
     &       , ia, ja, ka, igcon
       integer nx1z, nx2z, nx3z
c
       common /gridcomi/
     &   is, ie, js, je, ks, ke
     & , ia, ja, ka, igcon
     & , nx1z, nx2z, nx3z
c
       real*8  x1a   (in),  x2a   (jn),  x3a   (kn)
     &     , x1ai  (in),  x2ai  (jn),  x3ai  (kn)
     &     ,dx1a   (in), dx2a   (jn), dx3a   (kn)
     &     ,dx1ai  (in), dx2ai  (jn), dx3ai  (kn)
     &     ,vol1a  (in), vol2a  (jn), vol3a  (kn)
     &     ,dvl1a  (in), dvl2a  (jn), dvl3a  (kn)
     &     ,dvl1ai (in), dvl2ai (jn), dvl3ai (kn)
       real*8  g2a   (in), g31a   (in), dg2ad1 (in)
     &     , g2ai  (in), g31ai  (in), dg31ad1(in)
       real*8  g32a  (jn), g32ai  (jn), dg32ad2(jn)
     &     , g4 a  (jn)
c
       real*8  x1b   (in),  x2b   (jn),  x3b   (kn)
     &     , x1bi  (in),  x2bi  (jn),  x3bi  (kn)
     &     ,dx1b   (in), dx2b   (jn), dx3b   (kn)
     &     ,dx1bi  (in), dx2bi  (jn), dx3bi  (kn)
     &     ,vol1b  (in), vol2b  (jn), vol3b  (kn)
     &     ,dvl1b  (in), dvl2b  (jn), dvl3b  (kn)
     &     ,dvl1bi (in), dvl2bi (jn), dvl3bi (kn)
       real*8  g2b   (in), g31b   (in), dg2bd1 (in) 
     &     , g2bi  (in), g31bi  (in), dg31bd1(in)
       real*8  g32b  (jn), g32bi  (jn), dg32bd2(jn)
     &     , g4 b  (jn)
c
       real*8   vg1  (in),   vg2  (jn),   vg3  (kn)
       real*8 x1fac, x2fac, x3fac
c
       common /gridcomr/
     &       x1a   ,  x2a   ,  x3a   
     &     , x1ai  ,  x2ai  ,  x3ai  
     &     ,dx1a   , dx2a   , dx3a   
     &     ,dx1ai  , dx2ai  , dx3ai  
     &     ,vol1a  , vol2a  , vol3a  
     &     ,dvl1a  , dvl2a  , dvl3a  
     &     ,dvl1ai , dvl2ai , dvl3ai 
     &     , g2a   , g31a   , dg2ad1 
     &     , g2ai  , g31ai  , dg31ad1
     &     , g32a  , g32ai  , dg32ad2
     &     , g4 a
c
       common /gridcomr/
     &       x1b   ,  x2b   ,  x3b   
     &     , x1bi  ,  x2bi  ,  x3bi  
     &     ,dx1b   , dx2b   , dx3b   
     &     ,dx1bi  , dx2bi  , dx3bi  
     &     ,vol1b  , vol2b  , vol3b  
     &     ,dvl1b  , dvl2b  , dvl3b  
     &     ,dvl1bi , dvl2bi , dvl3bi 
     &     , g2b   , g31b   , dg2bd1  
     &     , g2bi  , g31bi  , dg31bd1
     &     , g32b  , g32bi  , dg32bd2
     &     , g4 b
c
       common /gridcomr/
     &        vg1  ,   vg2  ,   vg3  
     &     , x1fac , x2fac  , x3fac
c


      real*8   d (in,jn,kn), e (in,jn,kn),
     1       v1(in,jn,kn), v2(in,jn,kn), v3(in,jn,kn)

      real*8   b1(in,jn,kn), b2(in,jn,kn), b3(in,jn,kn)




      common /fieldr/  d, e, v1, v2, v3

      common /fieldr/  b1, b2, b3




      real*8     fiis(nbvar),  fois(nbvar)
     &      ,  fijs(nbvar),  fojs(nbvar)
     &      ,  fiks(nbvar),  foks(nbvar)
      integer  niis( 3),  nois( 3)
     &      ,  nijs( 3),  nojs( 3)
     &      ,  niks( 3),  noks( 3)
      integer  bvstat(6,nbvar)

      integer  niib(jn,kn), niib2(jn,kn), niib3(jn,kn), niib23(jn,kn)
     &      ,  noib(jn,kn), noib2(jn,kn), noib3(jn,kn), noib23(jn,kn)
     &      ,  nijb(in,kn), nijb3(in,kn), nijb1(in,kn), nijb31(in,kn)
     &      ,  nojb(in,kn), nojb3(in,kn), nojb1(in,kn), nojb31(in,kn)
     &      ,  nikb(in,jn), nikb1(in,jn), nikb2(in,jn), nikb12(in,jn)
     &      ,  nokb(in,jn), nokb1(in,jn), nokb2(in,jn), nokb12(in,jn)


      real*8    diib(jn,kn,3),  doib(jn,kn,3)
     &     ,  dijb(in,kn,3),  dojb(in,kn,3)
     &     ,  dikb(in,jn,3),  dokb(in,jn,3)
      real*8    eiib(jn,kn,2),  eoib(jn,kn,2)
     &     ,  eijb(in,kn,2),  eojb(in,kn,2)
     &     ,  eikb(in,jn,2),  eokb(in,jn,2)
      real*8   v1iib(jn,kn,2), v1oib(jn,kn,2)
     &     , v1ijb(in,kn,2), v1ojb(in,kn,2)
     &     , v1ikb(in,jn,2), v1okb(in,jn,2)
      real*8   v2iib(jn,kn,2), v2oib(jn,kn,2)
     &     , v2ijb(in,kn,2), v2ojb(in,kn,2)
     &     , v2ikb(in,jn,2), v2okb(in,jn,2)
      real*8   v3iib(jn,kn,2), v3oib(jn,kn,2)
     &     , v3ijb(in,kn,2), v3ojb(in,kn,2)
     &     , v3ikb(in,jn,2), v3okb(in,jn,2)

      real*8   b1iib(jn,kn,2), b1oib(jn,kn,2)
     &     , b1ijb(in,kn,2), b1ojb(in,kn,2)
     &     , b1ikb(in,jn,2), b1okb(in,jn,2)
      real*8   b2iib(jn,kn,2), b2oib(jn,kn,2)
     &     , b2ijb(in,kn,2), b2ojb(in,kn,2)
     &     , b2ikb(in,jn,2), b2okb(in,jn,2)
      real*8   b3iib(jn,kn,2), b3oib(jn,kn,2)
     &     , b3ijb(in,kn,2), b3ojb(in,kn,2)
     &     , b3ikb(in,jn,2), b3okb(in,jn,2)
      real*8   emf1iib(jn,kn,3), emf1oib(jn,kn,3)
     &     , emf1ijb(in,kn,3), emf1ojb(in,kn,3)
     &     , emf1ikb(in,jn,3), emf1okb(in,jn,3)
      real*8   emf2iib(jn,kn,3), emf2oib(jn,kn,3)
     &     , emf2ijb(in,kn,3), emf2ojb(in,kn,3)
     &     , emf2ikb(in,jn,3), emf2okb(in,jn,3)
      real*8   emf3iib(jn,kn,3), emf3oib(jn,kn,3)
     &     , emf3ijb(in,kn,3), emf3ojb(in,kn,3)
     &     , emf3ikb(in,jn,3), emf3okb(in,jn,3)




      common /bndryr/
     &   fiis,  fois,  fijs,  fojs,  fiks,  foks
     & , diib,  doib,  dijb,  dojb,  dikb,  dokb
     & , eiib,  eoib,  eijb,  eojb,  eikb,  eokb
     & ,v1iib, v1oib, v1ijb, v1ojb, v1ikb, v1okb
     & ,v2iib, v2oib, v2ijb, v2ojb, v2ikb, v2okb
     & ,v3iib, v3oib, v3ijb, v3ojb, v3ikb, v3okb

     & ,b1iib, b1oib, b1ijb, b1ojb, b1ikb, b1okb
     & ,b2iib, b2oib, b2ijb, b2ojb, b2ikb, b2okb
     & ,b3iib, b3oib, b3ijb, b3ojb, b3ikb, b3okb
     & ,emf1iib, emf1oib, emf1ijb, emf1ojb, emf1ikb, emf1okb
     & ,emf2iib, emf2oib, emf2ijb, emf2ojb, emf2ikb, emf2okb
     & ,emf3iib, emf3oib, emf3ijb, emf3ojb, emf3ikb, emf3okb




      common /bndryi/   niis,   nois,   nijs,   nojs,   niks,   noks
     &      ,  bvstat
     &      ,  niib, niib2, niib3, niib23
     &      ,  noib, noib2, noib3, noib23
     &      ,  nijb, nijb3, nijb1, nijb31
     &      ,  nojb, nojb3, nojb1, nojb31
     &      ,  nikb, nikb1, nikb2, nikb12
     &      ,  nokb, nokb1, nokb2, nokb12


      real*8  w1da(ijkn    ) , w1db(ijkn    ) , w1dc(ijkn    )
     &,     w1dd(ijkn    ) , w1de(ijkn    ) , w1df(ijkn    )
     &,     w1dg(ijkn    ) , w1dh(ijkn    ) , w1di(ijkn    )
     &,     w1dj(ijkn    ) , w1dk(ijkn    ) , w1dl(ijkn    )
     &,     w1dm(ijkn    ) , w1dn(ijkn    ) , w1do(ijkn    )
     &,     w1dp(ijkn    ) , w1dq(ijkn    ) , w1dr(ijkn    )
     &,     w1ds(ijkn    ) , w1dt(ijkn    ) , w1du(ijkn    )

c added 1D arrays w1dk through w1du for   M-MML 4 Mar 98

      real*8  w3da(in,jn,kn) , w3db(in,jn,kn) , w3dc(in,jn,kn)
     &,     w3dd(in,jn,kn) , w3de(in,jn,kn) , w3df(in,jn,kn)
     &,     w3dg(in,jn,kn)
     &,     w3di(in,jn,kn) , w3dj(in,jn,kn)


      common /scratch/  w1da,w1db,w1dc,w1dd,w1de,w1df
     &,                 w1dg,w1dh,w1di,w1dj,w1dk,w1dl,w1dm
     &,                 w1dn,w1do,w1dp,w1dq,w1dr,w1ds,w1dt
     &,                 w1du
      common /scratch/  w3da,w3db,w3dc,w3dd,w3de,w3df,w3dg
     &,                 w3di,w3dj

c

       integer i,j,k
c
c      External statements
c

       external      ct

       external      advx1, advx2, advx3
c
c-----------------------------------------------------------------------

c
c      Transport the three components of B using Constrained Transport.
c
       call ct

c
c      Momentum densities were computed from velocities in the
c      artificial viscosity substep (which must therefore not be
c      skipped, even if qcon = 0.)  Momentum density boundary
c      values are not needed.
c
CPS 
      DO k=ks,ke
         DO j=js,je
           DO i=is,ie
             w3da(i,j,k) = v1(i,j,k) * 0.5 * (d(i-1,j  ,k  ) + d(i,j,k))
             w3db(i,j,k) = v2(i,j,k) * 0.5 * (d(i  ,j-1,k  ) + d(i,j,k))
     1                     * g2b(i)
             w3dc(i,j,k) = v3(i,j,k) * 0.5 * (d(i  ,j  ,k-1) + d(i,j,k))
     1                     * g31b(i) * g32b(j)
           ENDDO
         ENDDO
       ENDDO
C
c---------------- directional split in X1-X2-X3 fashion ----------------
c
c in /root/
       nseq = 0  
       if (ix1x2x3 .eq. 1) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,ero,ern
c     &                  ,mflx,s1,s2,s3)
c        
         call advx1 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 1: w3db =',1pd13.5)")w3db(3,3,3)
         call advx2 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 2: w3db =',1pd13.5)")w3db(3,3,3)
         call advx3 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 3: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 2
         goto 10
c
c---------------- directional split in X2-X1-X3 fashion ----------------
c
       else if (ix1x2x3 .eq. 2) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,mflx,s1,s2,s3)
c
         call advx2 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 4: w3db =',1pd13.5)")w3db(3,3,3)
         call advx1 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 5: w3db =',1pd13.5)")w3db(3,3,3)
         call advx3 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 6: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 3
         goto 10
c
c---------------- directional split in X2-X3-X1 fashion ----------------
c
       else if (ix1x2x3 .eq. 3) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,mflx,s1,s2,s3)
c
         call advx2 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 7: w3db =',1pd13.5)")w3db(3,3,3)
         call advx3 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 8: w3db =',1pd13.5)")w3db(3,3,3)
         call advx1 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 9: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 4
         goto 10
c
c---------------- directional split in X3-X2-X1 fashion ----------------
c
       else if (ix1x2x3 .eq. 4) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,mflx,s1,s2,s3)
c
         call advx3 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 10: w3db =',1pd13.5)")w3db(3,3,3)
         call advx2 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 11: w3db =',1pd13.5)")w3db(3,3,3)
         call advx1 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 12: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 5
         goto 10
c
c---------------- directional split in X3-X1-X2 fashion ----------------
c
       else if (ix1x2x3 .eq. 5) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,mflx,s1,s2,s3)
c
         call advx3 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 13: w3db =',1pd13.5)")w3db(3,3,3)
         call advx1 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 14: w3db =',1pd13.5)")w3db(3,3,3)
         call advx2 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 15: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 6
         goto 10
c
c---------------- directional split in X1-X3-X2 fashion ----------------
c
       else 
c if (ix1x2x3 .eq. 6) then
c
c       subroutine advx1 (dlo,den
c     &                  ,eod,edn
c     &                  ,mflx,s1,s2,s3)
c
         call advx1 (w3dd,d   

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 16: w3db =',1pd13.5)")w3db(3,3,3)
         call advx3 (d   ,w3dd

     &              ,w3dg,w3de


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 17: w3db =',1pd13.5)")w3db(3,3,3)
         call advx2 (w3dd,d

     &              ,w3de,w3dg


     &              ,w3df,w3da,w3db,w3dc)
c     write(*,"('check 18: w3db =',1pd13.5)")w3db(3,3,3)
c
         ix1x2x3 = 1
         goto 10
       endif
c
c-----------------------------------------------------------------------
c
10     continue
c
c Mark momentum density (velocity) boundary values out of date.  
c The d and e boundary values were maked out of date in advx*.
c
       do 20 i=1,6
c v1, v2, v3
         bvstat(i,3) = 0  
         bvstat(i,4) = 0  
         bvstat(i,5) = 0  
20     continue
c
c The velocities need to be computed from momentum densities.
c This will be done in nudt/newdt.
c

       return
       end
c
c=======================================================================
c
c    \\\\\\\\\\        E N D   S U B R O U T I N E        //////////
c    //////////              T R A N S P R T              \\\\\\\\\\
c
c=======================================================================
c
