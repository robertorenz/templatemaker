! ============================================================================
!  Pdf417Class - implementation. PDF417 encoder + drawing.
!  Port of the ZXing-validated C# reference (designer/BarcodeCore/Pdf417.cs).
!  Byte compaction uses base-256 -> base-900 long division (stays in 32-bit
!  LONGs - no 48-bit intermediate). RS is over the prime field GF(929) with the
!  generator computed at run time (so addition is +mod929, not XOR).
!  bare MEMBER + module MAP. This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  MAP
  END

  INCLUDE('Pdf417Class.INC'),ONCE

Pdf417Class.Construct PROCEDURE()
  CODE
  SELF.Init()

Pdf417Class.Destruct PROCEDURE()
  CODE

!=== unpack the 17-bit pattern table (3 base-75 chars per value, cluster-major) =
Pdf417Class.Init PROCEDURE()
i  LONG
cl LONG
cw LONG
v  LONG
p  LONG
  CODE
  IF SELF.Ready = 1 THEN RETURN.
  SELF.PackTbl = 'ELOFIgFmgEIPFH:FltCHmEGvCGX?FgCFs?FGCYrEPSFK]CVsENqFJj?chCUN?bS?tmC]vERI?qnC\IEQV?pIC[X?xqC_l?wDC^y?zgFoOEB]FDfFk?C;<EA8' & |
                  'FCuC9rE@K>vPC9BE?z>v0C8u>ukCBOED_FEa?:kC@uECn?9VC@=ECP?8qC?l?B3CDQEEZ?@YCC`??lCCB?D5CEL?CD?BqC4IE=dFB@C34E<wFAm>hjC2OE<[' & |
                  '>hJC27>h:>h2>qGC6cE>e>p2C5vE>G>oMC5Z>o5>nt>saC7d>rtC7F>rX>tbBz`E;BF@x>awBz0E:q>aWBycE:c>aGByW>a?ByQ>ekC0mE;h>e;C0Q>dnC0C' & |
                  '>db>d\C1H>fN>^XBxFE:1>^8BwyE9n>]sBwm>]kBwg>]g>`2>_e>_Y>\NE9NBvxBvr>\0DrFF75FdLBOYDplF6DBNDDp4F5q=T?BM_=SjBVlDtHF80=cZBUG' & |
                  'DsW=bEBTZ=a`=aH=jmBXnDuC=iHBX2=h[=h?=loBYi=l3=mjE]TFRDFr0E\?FQWFq]Cp5E[ZFQ;Co`E[BFPxCoPE[6BHfDmMF4ZCx]BGQDl`F4<CwHE_6FRr' & |
                  '@[G=F9BFTDl6@ZrCvK@Zb=O6BK5DnN@co=MlBJHDn0@bZCz?E`Q@au=Lo@a]=QPBL6@f>=PcBKc@eQD0Z@e5=RQ@g?=R3@flEXkFOmFphCiBEX;FOQChmEWn' & |
                  'FOCCh]EWbChUChQBD2DjvF3GCm6BCMDjZ@Fn=?FEY\DjL@FN=?6BBt@F>CkxBBn=>u=CZBE?DkQ@Jb=BuBDn@J2CmrBD`@Ie=BQ=BK=DgBEe@Ko=DK@KS=D=' & |
                  '@KE@LJCenEVQFN\CeNEV9FNNCe>EUxCe6EUrCe2Ce0=<GBAcDie@<\=;rBAKDiW@<<Cg0EVo@;w=;ZBA9@;oCfi@;k==lBBD@>6==TBB6@=iCgf@=]==B@=W' & |
                  '@>b@>TCcdEUDFMyCcTEU8CcLEU2CcHCcF=:=B@VDi7@73=9xB@J@6nCdEB@D@6f=9l@6b=9j=:u@7k@7_@7YETcET]CbQB?u=90@4<@48@46AxOD_gExgAw:' & |
                  'D^z<ZvAvUD^^<ZVAv=<ZF<Z><cSAziD`h<b>Az1D`J<aYAy`<aA<a5<emB0j<e5B0L<dd<fn<fPDznF;IFfVBbHDz>F:xBasDyqF:jBacDyeBa[Dy_AsfD]E' & |
                  'EwTBf<As6D\t>8z<ScE0_D\f>8ZBe?Ar]>8J<SK>8B<WwAtsD]k><n<WGE1V><>BfxAtI>;q<Vn>;e<Y9AuN>>0<Xh>=_<XZ<Y_>>VEf1FVXFt:Ee\FV@Fsw' & |
                  'EeLFV4EeDFUyEe@B^tDxTF:8D<xB^TFW9F9uD<XEg>FVvD<HB^<DwuD<@EfwB^6<PdAqLD\4=yh<PDAq4D[qA5p=yHB`6DxrA5PD>:EgtApmA5@=y0B_oA58' & |
                  '<Oq<R>Aqx>0B<QqAqjA7J=zuB`lA72D>p<Q_=zc<Rj>0n<R\A7v>0`EcrFUKFsWEcbFU?EcZFU9EcVEcTB\jDwGF9UD7OB\ZFUaD7?EdSDw5D77B\ND73B\L' & |
                  'D71<NZAp?D[Q=t?<NJAp3@tT=szB]KAox@tDD80<N>@t<=sn<N<=sl<OGApU=tw<O;@uA=tk<O5@u5=te<O]@uWEbmFTjEbeFTdEbaEb_B[eDvfD4`B[]Dv`' & |
                  'D4XEc8D4TB[WD4R<MUAo^=qP<MMAoX@nF=qHB\0@n>D4v<MG@n:=qB@n8=ql@nb@n\FTTEb?DvPB[9B[7<Lx=p3@k?<Lr=oxAf5<8lAeP<8LAe8DUs<8<Adw' & |
                  '<84Adq<<`AgBDVx<<0Afq<;cAfc<;W<;Q<=mAgh<=Q<=C<>HB5wDd0EzqB5WDccB5GDcWB5?DcQB5;<5MAcfDUA<rn<4xDd\DU3<rNB79DdN<r><4`Ac<<r6' & |
                  'B6r<4Z<6rAdG<tH<6ZAd9<t0B7o<so<6H<7S<tt<7E<tfE47F=SFg[E3rF=GE3jF=AE3fE3dB3mDbnBmoB3]DbbBm_E4cDb\BmWB3QBmSB3OBmQ<3CAbY<mE' & |
                  '<33Dc9>KI<m5B4NAbG>K9BnP<2r>K1<lt<2p<lr<40Abo<n2<3o>L6<mq<3i>Ku<mk<4F<nH>LLFXbFu?FXZFu9FXVFXTE32F<rEkJFY3F<lEkBFXxEk>E2o' & |
                  'Ek<B2hDbBBk5B2`Db<DEeBjxE3HDE]Ek`B2ZDEYBjrDEW<2>Aax<jV<26Aar>E;<jNB33AEP>E3BkK<20AEHDF0<jHAED<2Z<jr<2T>EW<jlAEl>EQAEfFX:' & |
                  'FttFX6FX4E2UF<\EixFXHEitE2OEirB2@DawBicB2<DB^Bi_B2:DBZBi]DBX<1aAab<i9B2N>B4<i5<1[A>u>B0<i3A>q>AyA>o<iGA?8FWoEiDEiBBhzDA5' & |
                  'DA3<hP>@VA;bA;`;rg;rGA\[;r7;qz;qv;tA;st;sh;sb;tm;t_AjIAj9DXPAj1DXJAixAiv;p]A[f<DHAk6A[Z<D8Aju<D0Ajo<Cw;p?<Cu;qJA\1<E5AkL' & |
                  '<Dt;q8<Dn;q`<EKDf:Df2DeyDewAiDB;EDfVDWuB;=DfPB;9Ai6B;7;oX<AY;oPA[4=0[<AQ;oL=0S<AM;oJ=0O<AK;ot<Au;on=0w<Ao=0qF>XF>TF>RDe]' & |
                  'E6iF>fE6eDeWE6cAhgDWeB9sDekBr@B9oAhaBr<B9mBr:;o0AZo<@<Ahu<xT<@8;nu>S9<xP<@6>S5<xN;o><@J<xb>SGFugFueF>DFZ0F>BFYyDeIE65DeG' & |
                  'EmXE63EmVAhSB9?AhQBpbB9=DI]FmKG4]FGMFlfG4AFFxFlNG43FFhFlBFF`Fl<FF\FKAFnXG58EN9FJ\Fn<EMdFJDFmyEMTFJ8EMLFJ2EMHEQxFLNFo3C[\' & |
                  'EQHFL2C[<EQ0FKoCZwEPoCZoEPiCZkC_PES:FLt?vWC^kERi?v7C^SER[?urC^G?ujC^A?zKC`]ES`?yfC`A?yNC`3?yB@0XCa8@0<?zyFCyFk1G3LFCYFjd' & |
                  'G3>FCIFjXFCAFjRFC=FC;ECrFESFk]ECRFE;FkOECBFDzEC:FDtEC6EC4CCdEELFF4CCDEE4FEqCC4EDsCBwEDmCBsCBq?CHCE>EEx?BsCDqEEj?BcCDe?B[' & |
                  'CD_?BW?DmCEj?DUCE\?DI?DC?EN?E@FAoFioG2iFA_FicFAWFi]FASFAQE>IFB\Fj:E>9FBPE>1FBJE=xE=vC7HE?6FBrC78E>uC70E>oC6wC6u>tFC85E?L' & |
                  '>t6C7t>syC7n>su>ss>u3C8K>tr>tl>uIF@jFiCF@bFi=F@^F@\E;ZFA;E;RFA5E;NE;LC1:E;vC12E;pC0yC0w>gEC1V>g=C1P>g9>g7>ga>g[F@BFhxF@>' & |
                  'F@<E:=F@PE:9E:7By3E:KBxzBxx>`jByA>`f>`dF?yF?wE9TE9RBwUBwSF6HFd>FzxF5sFcqFzjF5cFceF5[Fc_F5WF5UDs[F7mFdjDs;F7UFd\DrvF7IDrn' & |
                  'F7CDrjDrhBX6Du5F8NBWaDthF8@BWQDt\BWIDtVBWEBWC=l7BY[Dua=kbBYCDuS=kRBY7=kJBY1=kF=m\BZ<=mDBYy=m8=m2=n==mzFq_G6g@ZBFqOG6[@SW' & |
                  'FqGG6U@P<FqCFqAF4>Fc1FzJFRtF3yG72FRdFr@FbjFR\F3mFRXF3kFRVDn2F4vFcGE`SDmmF4jE`CFSUF4dE`;DmaE`7Dm_E`5BKeDnjF5AD0\BKUDn^D0L' & |
                  'Ea4DnXD0DBKID0@BKGD0>=R5BLRDo5@fn=QpBLF@f^D1=BL@@fV=Qd@fR=Qb=RmBLh@g[=Ra@gO=R[@gI=S8FpZG6;@EqFpRG65@BVFpN@@nFpLF39FbPFP:' & |
                  'F31FbJFP2FppFOyF2vFOwDkCF3UEZEDk;F3OEZ=FPPEZ9Dk5EZ7BEWDk_Cn[BEODkYCnSEZ[CnOBEICnM=E4BEs@L<=DwBEm@L4Cnq@L0=Dq@Ky=EP@LX=EJ' & |
                  '@LRFp2G5p@;cFoy@:0FowF2\Fb:FNhFp@FNdF2VFNbDiqF2jEW>DimEW:DikEW8BBPDj4Ch5EWLCh1BBJCgz=>YBB^@>n=>U@>j=>S@>h=>g@?1Foi@6\Fog' & |
                  'F2HFN4F2FFN2Di=EU`Di;EU^B@rCdmB@pCdk=;F@8<=;D@8:Fo_F2>FMeDhnETqB@8Cc>ExKF_]Fx`Ex;F_QEx3F_KEwzEwxD`LEy8F_sD`<ExwD`4ExqD`0' & |
                  'D_yB0NDa9EyNB0>D`xB06D`rB02B00<fRB1;DaO<fBB0z<f:B0t<f6<f4<g?B1Q<g3<fx<gUFfHG12>82Ff@G0w>4bFf<>2zFf:EwFF_1F;aEw>F^vF;YFf^' & |
                  'F;UEw8F;SD]]EwbE1HD]UEw\E1@F;wE1<D]OE1:Au@D]yBgaAu8D]sBgYE1^BgUAu2BgS<YQAu\>>H<YIAuV>>@Bgw>><<YC>>:<Ym>>d<Yg>>^G7lA1LD<4' & |
                  'G7h@y5D:LG7f@wO@v\FekG0g=xoFtFG7zA4w=w<FtBFeeA3DFt@EviF^fF:DEveFWEFtTEvcFWAF:>FW?D\@EvwDyAD\<EhCDy=D\:Eh?Dy;Eh=Ar9D\NBa;' & |
                  'Ar5D??Ba7Ar3D?;Ba5D?9<RvArG>0z<RrA87>0v<RpA83>0tA81<S9>1=G7X@rBD6xG7V@p\@oiFeW=shFs]FeU@t2Fs[EvUF9[EvSFUgF9YFUeD[WDwcD[U' & |
                  'Ee0DwaEdyAp[B]sApYD8XB]qD8V<Oc=uH<Oa@u]=uF@u[G7N@m=@lJFeMFsCEvKF9AFTxD[=DvtEcLAolB\DD5?<N4=qz@np@j`EsrF]GEsjF]AEsfEsdDVj' & |
                  'EtCDVbEt=DV^DV\AgZDW;AgRDW5AgNAgL<>:Agv<>2Agp<=y<=w<>V<>PF`bFy=<quF`^<pBF`\EsJF]1F02EsFEzyEsDEzwDUMEsXDdhDUIDddDUGDdbAdS' & |
                  'DU[B8>AdOB8:AdMB88<7_Ada<u5<7[<u1<7Y<tz<7m<uCG1Z>I7BmMG1X>GQ>F^F`N<lnFgaF`L>JrFg_Es6EzIEs4F=oEzGF=mDTdDc?DTbE5@Dc=E5>Abu' & |
                  'B4vAbsBnxB4tBnv<4L<nN<4J>LR<nL>LPABQDD\A@oDCiA@3A?`G1P>D2G8SADG>C?ACTF`DFgGFuMErwEyzF=5FYADTJDbPE3\EktAb;B3GBk_DFD<2h<k5' & |
                  '>EeA=PDB4A<_A<A>AUA>KA:uA:WA9bEq`Eq\EqZDQyEqnDQuDQsA]`DR<A]\A]Z;tyA]n;tu;ts;u<F]o<CqF]mEqLEu@EqJEu>DQEDXxDQCDXvA\7AkRA\5' & |
                  'AkP;qf<EQ;qd<EOFyQ<zR<y_F]eFaIEqBEtqF19DPvDX>DfdA[HAinB;o;p7<B8=1:>Q_Bqa>Pn>PP<wu>RZAJyDHpAJADHRAIpAIb>O9AKz>NfAK\AHWDG]' & |
                  'AH;AGx>MqAI2AGFAG8AFcDO[DOYAXcAXa;js;jqErGDOADS5AWtA_\;iD;x_<H:=3f=3H>UsBsk>UW>UI=2S>VNAOBDJzANuDJlANiANc>TbAOn>TTAO`AN5' & |
                  'DJLAMtAMn>T4ANKAMTAMN<JD=5p=5b>X2Btp>Wq>Wk=5B>XH>WQ>WKCSTEM<?RcCLqEIl?LECIZEH9?I6CGt?GTG4u?nOCZ_G4m?glCWDG4i?dUCU\G4g?bo' & |
                  'FnpG5F?uZFnhG5@?r?Fnd?pWFnbFLfFoAFL^Fo;FLZFLXESRFM7ESJFM1ESFESDC`uESnC`mEShC`i?7LC?@EBy?0yC;tEAF>xjC:C>w=C9P>vLG3X?>oCBk' & |
                  'G3T?;XCA8G3R?9r?94FkiG3f?BOFke?@gFkcFF@FkwFF<FF:EF9FFNEF5EF3CEvEFGCErCEp>nHC56E=r>k9C3P>iWC2]>hf>hHG2o>r4C6qG2m>pN>o[Fj@' & |
                  '>soFj>FBxFBvE?RE?PC8QC8O>dFC01>bdBz>>as>aUG2U>f<>eIFiQFAIE<9>_EBxT>^T>^6>`@>\j>\L=`;BS]Drb=YhBPFDpz=VYBN`=TwBMm=T;G09=g^' & |
                  'BW=G05=dGBUUG03=ba=anFdvG0G=k>Fdr=iVFdpF8ZFe9F8VF8TDumF8hDuiDugBZHDv0BZDBZBCu^E^AFRR@RjCrOE\[@OkCpmE[h@NFCp1@MYCo^@M==L7' & |
                  'BISDm[@`p=HsBGm@]aCwdBFz@\4=FU@[C=F7@ZpFzP=OnBKCG78FzN@d\=N=G76@bv=MJ@b8FcM=Q^FrhFcK@fLFrfF5GFT2F5EFT0Do;Ea\Do9EaZBLnBLl' & |
                  '@E9Ck\EY<@B:CizEXI@@`Ci>@?sChk@?W@?I=B5BDN@I==@SBC[@G[Cl_@Fj=?D@FLFz6=CvG6I@K3=C8@J@Fb^Fq9F3cFPdDkmEZoBF6@;GCf[EV_@9mCej' & |
                  '@95CeL@8d@8V==4BAq@=I=<C@<X=;p@<:==z@>D@6NCd5@5aCcb@5E@57=:Y@7O=:;@71@3wCbm@3[@3M=9F@4R@2f@2X<`TAy<D_u<]EAwV<[cAvc<Zr<ZT' & |
                  'Fxf<d@AzwFxd<bZ<agF_y<f0F_wEyTEyRDaUDaSB1WB1U>7EBdbE0?>4FBc5DzL>2lBbD>24Baq>1c>1U<VRAt7>;I<TpAsD>9gBee>8v<Sa>8XFxL<XHG1@' & |
                  '>=?<WU><LF_?FfrEwpF<@D^<E1rAujD;cEfiFVf@xHD:>Eex@w3D9QEeZ@vND95@v6D8r@uu=xSB_aDxbA4[=vyB^pA36D<tB^RA2I=upA1x=ubA1j<QQAqZ' & |
                  '=zU<P`A6]=yd<PBA5l=yFA5N<RL>0PA7X@qUD6jEdC@p@D62Ecp@o[D5a@oCD5S@o7@o1=sZB];@so=rmB\h@s7D7M@rf=rC@rX<Nv=t[<NX@tp=t=@tR@ll' & |
                  'D4HEc0@l<D3w@koD3i@kc@k]=q8B[s@my=pg@m]=pY@mO<Mc=q^@nT@jRD37@j:D2t@iy@is=or@k3=od@jp@iED2T@i9@i3=oD@i[@hd@h^<;;AfQ<9YAe^' & |
                  '<8h<8J<=1<<>F]UEtQDWIAh9<qYB6dDd><p4B5s<oGB5U<nv<nh<6:Act<s[<5I<rj<4v<rL<75<tV>HJBm?E4S>G5BlRE45>FPBl6>F8Bks>Ew>Eq<l`B4>' & |
                  '>Jd<ksB3k>Iw<kW>I[<kI>IM<3_<ma<3A>Ke<mC>KGDD@Ek2FXpA@7DC[EjaA?bDCCEjSA?RDC7A?JDC1A?F>CaBjhE3@ACv>C1BjLACFDE1Bj>ABy>BXABm' & |
                  '>BRABg<j>B2v>Dn<imAE8>DR<i_ADg>DDADY<2L<jd>EIAE^A<cDAqEilA<CDAYEi^A<3DAMA;vDAGA;rA;p>AGBiWA>=>@zBiIA=pDBDA=d>@hA=^<hx>As' & |
                  '<hjA>i>AeA>[A:YD@dEi>A:ID@XA:AD@RA:=A:;>@:BhtA;F>?yA;:>?sA;4<hJ>@PA;\A9TD@8A9LD@2A9HA9F>?YA9p>?SA9jA8wD?mA8sA8q>?CA9:;sT' & |
                  'A]6;rc;rE;tO<CcAje<BvAjG<BZ<BL;py<Dd;p[<DF<z6B:xDfH<yQB:\<y9B:N<xx<xr<AAAiR=0C<@p<zr<@b<zd;of<Ag=0i>PrBqSE6]>PRBq;E6O>PB' & |
                  'Bpz>P:Bpt>P6>P4<wgB9g>RL<wOB9Y>R4Bqq>Qs<w=>Qm<@0<xH<?m>Rx<x:>RjDHTEm<FYuDHDEm0DH<EluDH8DH6>NhBpFE5zAK^>NXBp:AKNDI5Bp4AKF' & |
                  '>NLAKB>NJAK@<vZB99>OU<vNALK>OI<vHAL?>OCAL9<?M<vp>OkALaDGOEl[DGGElUDGCDGA>McBoeAHo>M[Bo_AHgDGeAHc>MUAHa<uy>N4<usAI@>MyAI:' & |
                  'DFrElEDFnDFl>M;BoOAGR>M7AGN>M5AGL<uc>MIAG`DF^DF\>LrAFi>LpAFg;j;;ih;whA_@;wL;w>;hs;xC<GwAlo<G_Ala<GS<GM;vW<HX;vI<HJ=3JB=7' & |
                  'DgM=3:B<v=32B<p=2y=2w<FjAlA=47B=M=3v<FX=3p;ut<G5=4MBs]E7bBsUE7\BsQBsO=2EB<V>V@BsyB<P>V8=29>V4=27>V2<F>=2a<F8>V\=2[>VVEnA' & |
                  'FZREn=En;Bs5E7LDK;Bs1DK7BrzDK5=1hB<@>Tn=1dAOz>Tj=1bAOv>ThAOt<Es=1v>U1AP=EmxEmvBrlDJRBrjDJP=1T>T:=1RANQ>T8ANOEmnBrbDJ8=1J' & |
                  '>SkAMb;lE;l7;yrA`E;yf;y`;kb;z=<J6Amt<IyAmn<Iu<Is;yF<JR;y@<JLB><DguB>8B>6<IYAm^=61B>J=5x<IS=5v;y0<Ig=6?E8?E8=B=sBtvB=qBtt' & |
                  '<IE=5H<IC>XN=5F>XLE85B=iBt\<I;=4y>W_;mJ;mD;zwA`m;zs;zq;m4<0:AnQAnO;zc<KO;za<KMDh>'
  LOOP i = 0 TO 2786
    p = i*3 + 1
    v = (VAL(SELF.PackTbl[p])-48)*5625 + (VAL(SELF.PackTbl[p+1])-48)*75 + (VAL(SELF.PackTbl[p+2])-48)
    cl = INT(i/929)
    cw = i - cl*929
    SELF.CwTbl[cl+1, cw+1] = v
  END
  SELF.Ready = 1

Pdf417Class.Modulo PROCEDURE(LONG a,LONG b)
  CODE
  RETURN a - INT(a/b)*b

Pdf417Class.Pat PROCEDURE(LONG cluster,LONG codeword)
  CODE
  RETURN SELF.CwTbl[cluster+1, codeword+1]

Pdf417Class.EmitPat PROCEDURE(LONG row,LONG x,LONG pattern,LONG bits)
i  LONG
  CODE
  LOOP i = bits-1 TO 0 BY -1
    SELF.Cells[row+1, x+1] = BAND(BSHIFT(pattern,-i), 1)
    x += 1
  END
  RETURN x

!=== the encoder: value -> SELF.Cells / NRows / NCols  (1 ok, 0 = too large) ===
Pdf417Class.Build PROCEDURE(*CSTRING pValue)
s       CSTRING(2200)
n       LONG
i       LONG
j       LONG
k       LONG
d       LONG
ncomp   LONG
b256    LONG,DIM(6)
cur     LONG
rem     LONG
level   LONG
ec      LONG
total   LONG
cols    LONG
rows    LONG
best    LONG
cc      LONG
rr      LONG
score   LONG
region  LONG
g       LONG,DIM(80)
ng      LONG,DIM(80)
coeffs  LONG,DIM(80)
e       LONG,DIM(80)
glen    LONG
root    LONG
t1      LONG
jj      LONG
cluster LONG
tval    LONG
leftI   LONG
rightI  LONG
x       LONG
c       LONG
  CODE
  SELF.Init()
  s = CLIP(pValue)
  n = LEN(s)
  SELF.NBin = n
  LOOP i = 1 TO n; SELF.BinB[i] = VAL(s[i]); END
  ! ---- byte compaction: 6 bytes -> 5 base-900 codewords (repeated /900), leftover -> 1 each ----
  ncomp = 0
  ncomp += 1; SELF.Comp[ncomp] = CHOOSE(SELF.Modulo(n,6)=0, 924, 901)        ! mode latch
  i = 1
  LOOP WHILE i+5 <= n
    LOOP j = 1 TO 6; b256[j] = SELF.BinB[i+j-1]; END                          ! 6 base-256 digits, high..low
    LOOP k = 5 TO 1 BY -1                                                     ! divide the 6-digit number by 900, 5x
      rem = 0
      LOOP j = 1 TO 6
        cur = rem*256 + b256[j]
        b256[j] = INT(cur/900)
        rem = cur - INT(cur/900)*900
      END
      SELF.Comp[ncomp+k] = rem
    END
    ncomp += 5
    i += 6
  END
  LOOP WHILE i <= n
    ncomp += 1; SELF.Comp[ncomp] = SELF.BinB[i]
    i += 1
  END
  d = ncomp
  ! ---- error-correction level + symbol size ----
  level = CHOOSE(d<=40, 2, CHOOSE(d<=160, 3, CHOOSE(d<=320, 4, 5)))
  ec = BSHIFT(1, level+1)
  total = d + 1 + ec
  best = 2147483647; cols = 0; rows = 0
  LOOP cc = 1 TO 30
    rr = INT((total + cc - 1)/cc)
    IF rr < 3 THEN rr = 3.
    IF rr > 90 THEN CYCLE.
    IF cc*rr - ec > 928 OR cc*rr - ec < d+1 THEN CYCLE.
    score = cc*rr - total + ABS(rr - cc*2)
    IF score < best
      best = score; cols = cc; rows = rr
    END
  END
  IF cols = 0 THEN RETURN 0.
  region = rows*cols - ec
  SELF.CW[1] = region                                                        ! symbol length descriptor
  LOOP i = 1 TO d; SELF.CW[i+1] = SELF.Comp[i]; END
  LOOP i = d+2 TO region; SELF.CW[i] = 900; END                              ! pad
  ! ---- GF(929) generator polynomial: product(x - 3^i), i=1..ec ----
  g[1] = 1; glen = 1; root = 1
  LOOP i = 1 TO ec
    root = SELF.Modulo(root*3, 929)
    LOOP j = 1 TO glen+1; ng[j] = 0; END
    LOOP j = 1 TO glen
      ng[j+1] = SELF.Modulo(ng[j+1] + g[j], 929)
      ng[j]   = SELF.Modulo(ng[j] + (929 - SELF.Modulo(g[j]*root, 929)), 929)
    END
    glen += 1
    LOOP j = 1 TO glen; g[j] = ng[j]; END
  END
  LOOP i = 1 TO ec; coeffs[i] = g[i]; END                                    ! c_0..c_{ec-1}
  ! ---- RS encode over the data region ----
  LOOP j = 1 TO ec; e[j] = 0; END
  LOOP i = 1 TO region
    t1 = SELF.Modulo(SELF.CW[i] + e[ec], 929)
    LOOP jj = ec TO 2 BY -1
      e[jj] = SELF.Modulo(e[jj-1] + (929 - SELF.Modulo(t1*coeffs[jj], 929)), 929)
    END
    e[1] = SELF.Modulo(929 - SELF.Modulo(t1*coeffs[1], 929), 929)
  END
  LOOP i = 1 TO ec
    jj = ec - i + 1
    SELF.CW[region+i] = CHOOSE(e[jj] <> 0, 929 - e[jj], 0)
  END
  ! ---- render rows ----
  SELF.NRows = rows
  SELF.NCols = 69 + 17*cols
  CLEAR(SELF.Cells)
  LOOP rr = 0 TO rows-1
    cluster = SELF.Modulo(rr, 3)
    tval = 30 * INT(rr/3)
    CASE cluster
    OF 0
      leftI = tval + INT((rows-1)/3);                 rightI = tval + (cols-1)
    OF 1
      leftI = tval + 3*level + SELF.Modulo(rows-1,3);  rightI = tval + INT((rows-1)/3)
    ELSE
      leftI = tval + (cols-1);                        rightI = tval + 3*level + SELF.Modulo(rows-1,3)
    END
    x = 0
    x = SELF.EmitPat(rr, x, PDF:Start, 17)
    x = SELF.EmitPat(rr, x, SELF.Pat(cluster, leftI), 17)
    LOOP c = 0 TO cols-1
      x = SELF.EmitPat(rr, x, SELF.Pat(cluster, SELF.CW[rr*cols + c + 1]), 17)
    END
    x = SELF.EmitPat(rr, x, SELF.Pat(cluster, rightI), 17)
    x = SELF.EmitPat(rr, x, PDF:Stop, 18)
  END
  RETURN 1

!=== drawing (stacked rows; each barcode row drawn taller than a module) =======
Pdf417Class.Paint PROCEDURE(SIGNED pImageFeq,LONG pDark,LONG pLight,LONG pQuiet)
ImgX     LONG
ImgY     LONG
imgW     LONG
imgH     LONG
cellW    LONG
rowH     LONG
totalW   LONG
totalH   LONG
offX     LONG
offY     LONG
r        LONG
c        LONG
runStart LONG
  CODE
  GETPOSITION(pImageFeq, ImgX, ImgY, imgW, imgH)
  SETPENCOLOR(pLight)
  BOX(ImgX, ImgY, imgW, imgH, pLight)
  IF SELF.NCols <= 0 THEN RETURN.
  cellW = INT(imgW / (SELF.NCols + 2*pQuiet)); IF cellW < 1 THEN cellW = 1.
  rowH  = INT(imgH / (SELF.NRows + 2));        IF rowH  < 1 THEN rowH  = 1.
  totalW = cellW*(SELF.NCols + 2*pQuiet); totalH = rowH*(SELF.NRows + 2)
  offX = ImgX + INT((imgW-totalW)/2) + pQuiet*cellW
  offY = ImgY + INT((imgH-totalH)/2) + rowH
  SETPENCOLOR(pDark)
  LOOP r = 0 TO SELF.NRows-1
    c = 0
    LOOP WHILE c < SELF.NCols
      IF SELF.Cells[r+1, c+1] = 1
        runStart = c
        LOOP WHILE c < SELF.NCols AND SELF.Cells[r+1, c+1] = 1
          c += 1
        END
        BOX(offX + runStart*cellW, offY + r*rowH, (c-runStart)*cellW, rowH, pDark)
      ELSE
        c += 1
      END
    END
  END

Pdf417Class.Draw PROCEDURE(SIGNED pImageFeq,*CSTRING pValue,LONG pDark,LONG pLight,LONG pQuiet)
  CODE
  IF SELF.Build(pValue) = 0 THEN RETURN.
  SETTARGET(,pImageFeq)
  BLANK
  SELF.Paint(pImageFeq, pDark, pLight, pQuiet)
  SETTARGET()
