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
  SELF.PackTbl = 'kHnmMMnOJkDZmJnnN?ffAkBPfdG^AhfcJ^AHgLFkNlmP@gGekLZmNh^lWgE[^j]_R\gRDkQ__NHgOekPT_L>gN\_XZgTj_VHgS__[MnQbjmXmEmnKXfR=jkN' & |
                  'mDdfPCjjI]L`fOFji`]L@fNa]Kcf\_k=WmGM]cKfZUjoN]aQfYPjnc]`TfXg]mmf_^k>j]kcf^U]j^f]j^=lfa>]oc]oEfGnjfMmBJfFAjeHmA_\k\fEDjd_' & |
                  '\jofD_\j_\jW]EEfKRjgf]CKfJMjgH]BNfId]Ai]A]]H\fLk]GWfLM]Fn]JBfA@jbam@R\aZf@CjbE\`mf?^jaj\`]f?R\`Uf?L\gHfBejcT\fKfBI\effAn' & |
                  '\eZ\eTfCX\hC\\Yf=\j`k\[lf=Dj`]\[\eok\[Teoe\[P\^c\^K\^?\YRj`=en^enX\XgjEPldinAVdg`jCFlc`defjBAlcBZE@ddiZDSe?OjHOlfIZ[^e=E' & |
                  'jGFZYddo@ZXgZXOZfMeBNjIbZdCeAEZc>ZbUZiLeCaZhCZj_kb@mYinUXk`FmXdnTmglfk_ImXHglFk^dmWmgkik^Xd]^j>ElaFhFOd[dj=@l`[hDUkdRmZd' & |
                  '`hQYcOdZOioI`gdhC@`gTZ=XdaBj?^aAmYn^d`=j?@a@@hHakfRa?CYmIa>^Z@odb[aEQZ?jdb=aDLhJaaCcZBUaFjZAjaFLk[EmVJnS`gbdkZHmUagbDkYc' & |
                  'mUSgagkYWga_ga[dVcimYl_NghRdUfim=`JKYYMk\Nilb`I^YY=dUB`INgfddToYXdY_[dXUinL`OlY^^dWl`Nogi[dW^`NWY]mY]gYaMdYH`Q^Y`d`QBY`V' & |
                  '`Pg`RQg]ckWamTTg]CkWImTFg\fkW=g\^kVjg\Zg\XYTldSLikc_nHYTLdRgikU_m[g_UkXL_mKYSgdRU_mCg_C_m?YWCdTE`=RYV^dSj_omg`X_oaYVL_o[' & |
                  '`>K`>=gZ\kUomSYgZLkUcgZDkU]gZ@gZ>YQedQZijh_f@YQUdQN_ecg[UdQH_e[YQI_eWYQGYRj_gE_fl_ffkUCkU=gXddPaYP@_ag_ac_aachVi]AlWDcf\' & |
                  'i[oXF_ce_i[SXF?ceGXEbXEZXSHckmi^ZXQNcjhi]oXPQcjLXOlXO`XV_cmSXUZclhXU>XXEXWZjQllkDnD]ePLjPolj[eO_jPWljMeOOjPKeOGjPEca[iYU' & |
                  'lULeUmc`^iXl[XNWo=jSBiX^[WaeTXc_m[WQWnX[WIXBKccMiZH[]oXANjTQ[]?eWCcbV[\ZX@][\NXD=cd@[_aXCT[_EXCFXDc[`Tkn\m`DnX_kmom__nXQ' & |
                  'km_m_SkmWm_MkmSeKKjNUliNh\meJ^ma=li@h\Ml=Nm`bh\=eJFjM^h[hkooeJ@Wj\c^DiW_[IKWioc]_iWQal\[H^eM=jO@akoh^_l>Qc]Mak_[HFeL^akW' & |
                  'WiQWlfc_=[KUWlNc^banf[K=eN@anNh_bWko[J^Wm_[LNWmQao_[L@kkUm^RnWdkkEm^Fkk=m^@kjlkjjeHDjLclhShTeeGgm^hhTUklNjLQhTMeG[hTIeGY' & |
                  'hTGWgUc\RiVd[ACWgEc\FaZR[@feI=c\@aZBhU^WflaYm[@ZWfj[@XWhZc\h[BHWhNa[W[AoWhHa[K[AiWi=a[mkikm]Ykicm]Ski_ki]eFZjKjhPaeFRjKd' & |
                  'hPYkjNhPUeFLhPSWekc[Y[=?Wecc[SaQMZojeG=aQEhQDWe]aQAZodaQ?[=[aQiaQcm]Cki=jKTeEaeE_WeCZn=aLdWe=ZmjcMWWGUcLZWFhcLBiN\WFXcKi' & |
                  'WFPcKcWMCcOIiPFWLFcN`WKacNRWKUWKOWNhcOoWNLWN>WO[dB?icOlZKdARibjdABib^d@mibXd@iWBTcJ@iM]XifWAgidHiMOXiFdCdicmXhiWAOcIIXha' & |
                  'dCRWAIWD^cJlXl=WDFcJ^XkXdDgXkLWCgWEWXliWEIXl[jXGlnKnFGjWjln?jWblmljW^jW\d>kia]eaId>[iaQe`ljY@iaKe`dd>Oe``d>Me`^W?McHNXa^' & |
                  'W?=ib@\@MXaNd?dcGo\@=ebBW>d\?hXaBW>bXa@W@RcHdXbcW@F\ARXbWW@@\AFXbQW@hXcF\AhmcKnZImcCnZCmc?mc=jV]lmRlCTmcglmLlCLmcalCHjVO' & |
                  'lCFd=Ni`de]Ed=Fi`^hife]=jW@hi^lCjd=@hiZe\jhiXW=ccGUX]ZW=[cGO[jHX]Rd=dbPW[j@e][W=UbPOhjIX]LbPKW>LX^CW>F[jdX^=bQ@[j^bPmmbV' & |
                  'nYfmbRmbPjUhllolARmbdlANjUblALcoYi`Ne[CcoUheJe[?coSheFe[=heDVoncG?X[Xcog[e_X[TVohbFm[e[X[RbFi[eYbFgX[fbGHmb@l@Ql@OeZBhbo' & |
                  'hbmXZW[cQbBEbBCVaPV`cc?YV`SV`KV`GVcZVcBVbiVbcVdSVdEcSecSUiRNcSMiRHcSIcSGV^Ic>LWXRcTjc>@WXBcT^WWmcTXWWiV]^WWgV_Nc>bWYWcUM' & |
                  'WYKV^oWYEV_dWYmifVifNifJifHcRHdIjig?iQ[dIbifldI^cQmdI\V\_WTNV\Wc=MYC_WTFV\SYCWWTBV\QYCSWT@V]HWTjV]BYDHWTdYDBlohlodlobiea' & |
                  'j\Cm=Cj\?ie[j\=cQSiQKdGhieoeg_dGdcQMeg[dGbegYV[jc==WRLcQaY?CWRHV[d\KdY??WRF\K`Y?=V\EWRZY?Q\L?n[>nZoloTmeIloRmeGieMj[BieK' & |
                  'lF_j[@lF]cQ?dFgcQ=eeQdFehoXnNaniXmIinMdnhomIInMLnhamHlnM@mHdnLmmH`mOWnPSnjKkKUmNZnOjkJhmNBnO\kJXmMikJPmMckJLkQCmQInQFgN`' & |
                  'kPFmP`gN@kOamPRgMckOUgM[kOOgMWgTNkRhmQo_UCgSQkRL_TVgRlkR>_TFgR`_T>gRZ_ZdgV@kS[_YggUW_YOgUI_YC_\VgVf_[m_[_mDhnKJngbmDHnJe' & |
                  'ngTmCknJYmCcnJSmC_mC]joRmG?nLCjnemFZnKhjnUmFNjnMmFHjnIjnGf^Yk>\mGkf]lk>DmG]f]\k=kf]Tk=ef]Pf]N]ogf`ck?U]oGf`Kk?G]njf`?]nb' & |
                  'f_l]n^^?>fa\^>YfaN^>M^>G^?j^?\mAanIXnfgmAQnILmAInIFmAEmACjgJmBfnInjfmmBZjfemBTjfajf_fLOjhOmCIfL?jhCfKjjh=fKffKd]IYfMTjhe' & |
                  ']IIfMH]IAfMB]I=]Hn]J^fMj]JR]JL]KAm@DnH_m?onHYm?km?ijcFm@`jc>m@ZjbmjbkfCJjcbfCBjc\fC>fBo\iRfCf\iJfC`\iF\iD\in\ihm?OnHIm?K' & |
                  'm?IjaDm?]ja@ja>f>ajaRf>]f>[\_hf>o\_d\_bm>nm>lj`Cj`AeoSeoQlcdnAHnbalcDn@cnbSlbgn@Wlb_n@Qlb[lbYjGJlennBAjF]leVnAfjFMleJjFE' & |
                  'leDjFAjF?eAIjITlfge@\jHolfYe@LjHce@DjH]e@@e@>ZhGeCSjJMZgZeBnjJ?ZgJeBbZgBeB\Zg>ZjQeDLZileD>Zi`ZiZZkJZjonTonl_`fgnT_nlS`\m' & |
                  'nTWnlM`X=nTSnTQl`]n?VnafmZfl`MnmBmZVnUhn?DmZNl`AmZJl`?mZHj?Blabn?lkfTj>elaVkfDm[_laPkeoj>Ykekj>Wkeidb?j@GlbEhJcdabj?nhJS' & |
                  'kgMj?hhJKdaVhJGdaThJEZAldcDj@]aFNZA\dbkaF>hK\dbeaEiZAPaEeZANZC>dcZaGSZBeaGGZB_aGAZCTnSRnkf`HinSJnk``ClnSF`ATnSDl_@n>]mVb' & |
                  'l^kn>WmVZnShmVVl^emVTin>l_\k]Oimil_Vk]GmWEk]Cimck]AdXminZgj\dXeinTgjTk]egjPdX_gjNYaedYV`RCYa]dYP`Qngk?`QjYaW`QhYbN`R_YbH' & |
                  '`RYnR]nkP_ljnRY_jRnRWl^Kn>GmT`nRkmT\l^EmTZikol^YkXfikkkXbikikX`dTQilJga?kYAg`ndTKg`lYXHdT_`>WYXD`>SYXB`>QYXV`>enRI_eQnRG' & |
                  'l]jmS_l]hmS]ijnkVXijlkVVdRCg\JdRAg\HYSS_gaYSQ_g_nR?l]`mSEijTkUQdPogYilV[mmUn_LlVKmmIlVCmmClV?lV=i^>lW`mmki]alWTi]YlWNi]U' & |
                  'i]Sclji_ClXCclZi^jclRi^dclNclLXW\cmoi_YXWLcmcXWDcm]XW@XW>XXacnRXXUXXOXYDnDOndK[VlnDGndE[QonDC[OWnDAlU>ml\lk\lTimlVlkTnDe' & |
                  'lkPlTclkNiYmlUZjTCiYelUTjSnll?jSjiY_jShcceiZVeXDcc]iZPeWojTYeWkccWeWiXDUcdN[`FXDMcdH[`>eXZ[_mXDG[_kXE>[`bXDk[`\nnIaf>h[\' & |
                  'nnEaaEhYDnnCa^ba]WnCZnch[GmnXknnWakK[EUnXgnCTahfnXelTImlFliZlTEmaInYFlTCmaEliTmaCiWklTWjOZiWgl>kjOViWel>gjOTl>ec_IiXFeNZ' & |
                  'c_Eh`IeNVc_Ch`EeNTh`CWmkc_W[LZWmgaok[LVWmeaog[LTaoeWnF[LhnmhaWChTCnmfaT`aSUnCF[@TnWjnCDaYcnWhlShlhYlSfm^nlhWm^liVjjMLiVh' & |
                  'kmCjMJkmAc\neIec\lhVSeIchVQWiC[BdWiAa\@[Bba\>nm^aO_aNTnBonWPlS^lh?m]giVPjLEkjbc[geGQhQXWfb[=iaRDaKmlP=mjBlOhmiolOdlObiOk' & |
                  'lPYiOclPSiO_iO]cOaiPTcOYiPNcOUcOSWOMcPJWOEcPDWOAWO?WOiWOcmo?n`AXhUmnnXf=mnllOHmi_lZWlODlZSlOBlZQiMilOVidTiMeidPiMcidNcKE' & |
                  'iNDdENcKAdEJcK?dEHWEccKSXmBWE_Xm>WE]XloWF>XmPne@\=>e`Zne>[m[[lPmn^X`onFMmn\\?^nFKlNglYVlNelnglYTlneiLhibFiLfjYhibDjYfcHj' & |
                  'd@YcHhebjd@WebhW@nXcLW@l\AnXcJ\AlbLChhEbIdhfmbH[bH=ndi[hZnoHbNi[gObM^mnTnEfnZWlN]lXolm`mdBiLNia?jWTlDKcGcd>Ee]ohj]W>ZX^Q' & |
                  '[k?bDchdSbCZbBo[dhbFCbA@b@Ub?HlLalL]lL[iHhlLoiHdiHbcACiICcA?cA=Vd_cAQVd[VdYVdmmjjWWcmjhlLMlQnlLKlQliGgiSCiGeiSAc>hcUSc>f' & |
                  'cUQV_jWZ@V_hWZ>n`UYB>Y@fmj`n=>lLClQTl\CiGMiQoigMc=acS?dJaV]VWUEYDV\IZefh\HQ\GfY>L\JmbX_hnSbWZhmhbW>bVc\EjbZE\ELbYZbU@hl[' & |
                  'bTWbTI\D?bUfbSJbRobROiEMiEKblgbleVUhVUflM`iDfiJTbk`cCoVSTVj?W^>YHLYGa\Oheio\OL\O>YFT\P[b^mi>Zb^Ui>Lb^Ib^C\N?b_f\Mdb_Xb]H' & |
                  'i=_b\ob\i\MDb]^b\Ob\IWaEYKSYKE\RoekY\Rc\R]YJX\SR\RC\R=gBdkJ@^SRfl?kEC^J=fgFkB^^ELfdc^Bmnj=_IGgMKnih_?UgHNnid^m\gEinib^kF' & |
                  'nPknjY_SanPcnjS_NdnP__LLnP]mQanQTmQYnQNmQUmQSkSMmRJkSEmRDkSAkS?gVXkSigVPkScgVL]^JfWnjnA]ThfSBjk\]PDfP_]MefOT]L\ngn]iIf]H' & |
                  'ngj]dPfZcngh]am]`bnLOnhI]nVnLK]l>nLImHDnL]mH@mH>k?amHRk?]k?[fahk?ofadfab]@dfI@jf[\o@fF]\lafER\kX\jmnfm]FJfK`nfk]Cg]B\nJA' & |
                  ']HjnJ?mCOmCMjhkjhifN=fMn\e>fA\\b_f@Q\aV\`knfS\gd\fYnHmm@njd=\]^f=j\\U\[j\_>\Yn\YPZV]dm^jElZMHdhejCTZHWdfOZFEdeDZDonbmZa\' & |
                  'e?knbiZ\ce=SnbgZZMZYBnBMncHZfinBIZdQnBGlg@nB[lfolfmjJYlgNjJUjJSeDXjJgeDTeDRhAnkcEmZD`[hh=Jk`b`WTgmkk_W`UJglb`TEglD`S\YlD' & |
                  'd^cj>Sa=YYgSd\M`khhE>d[B`iVYck`hMYcM`gbnalZ>]daPnmHnajaC?YoGnmFa@\Ymoa?Qn@?ZAJnV]n@=aE_nV[lbKm\TlbIm\Rj@ckhBj@akh@dc`dc^' & |
                  '`GdgfHk[a`CPgcikZV`AFgb``@AgbB`?X`?JY]QdWL`MbY[?dVA`KPggc`JGYYK`I\naRY`DnlA`PUY^l`OJn>knTIl_jmWYinhk^FdYd_lNg^hkWo_jDg]_' & |
                  '_i?g]A_hV_hHYV>dSZ_oMYTh_nDYTJ_mYYWQ`=`_eCg[E_d>gZZ_cU_cGYRN_f\YQc_f>_aWgYM_`n_``YPV_bJ__a__SXNgci[i]OXJCcgEXGdcemXF[XF=' & |
                  'n_RXTMclHn_PXQjXP_mn>XVmmmolXIlXGi__i_]cnXcnV[UgeScjRU[QSeQQjQJ[OIePH[NDeO][M[[MMX@AcbD[[eX=bc`l[YSeUK[XJWnn[W_n^kXBgndY' & |
                  '[^XXA\[]MmljnEFlUhllSiZdjTmcd\h[@koam`Ra`@hXiknXa^FhWdkmma]IhWHa\dhVma\X[GQeLPjNcajb[EGeKGahXh\ieJ\agS[CYafj[CKaf\Wkac^R' & |
                  '[JPWjXama[IGWimalX[H\akmWmA[KcaoAaV>hShkl>aTDhRckkSaSGhRGaRbhQlaRVaRP[@FeH`aYU[?AeHBaXPhTcaWg[>JaWYWh>[A_WgSaZn[AAaZPaOC' & |
                  'hPIkjFaNFhO`aMahORaMUaMOZoZeFhaPhZo>aPLZncaP>WfF[=MaQ[aK_hNSaKGhNEaJnaJhZmdaLXZmVaLJaImhMXaIaaI[ZliaJPaIAaHnWJlcN@WHZcLh' & |
                  'WGQWFfWM_WLTmjPlPgiPbcPXXgldCDic]XebdAnXd]dAPXdAXcfWCYcJNXjkWBPXibWAeXiDWDlXlK[nle`LjXc[m?e_GjXE[lBe^^[k]e^P[kQ[kKX`ad?T' & |
                  '\?PX_\d>i\>KX_@\=bX^e\=TW?iXbGW?K\@iXa\\@Khg\lBomcYbH_hf_lBSbH?hfGlBEbGbhenbGZhehbGV[h>e\`jVkbNM[gAe\DbMPhhee[ibLk[fPbL_' & |
                  '[fJbLYX]Bd=\[icX\YbP?[iGX\KbOV[hlbOHW>>X]h[jVbPebC^hdElAFbC>hc`l@kbBahcTbBYhcNbBUbBS[dZeZjbEh[dBeZ\bEPhdcbED[ccbE>X[L[eS' & |
                  'X[>bFa[eEbFSb@WhbSl@Kb@GhbGb@?hbAb?nb?l[bheYobA\[b\bAP[bVbAJXZQ[cKbB?b>mhaZb>ehaTb>ab>_[aob?V[aib?Pb>EhaDb>Ab>?[aYb>SVbU' & |
                  'c@LVaLV`aVchWWUcTNWVPcScWUgWUYV^eWXnV^GWXPYAUdIRifdY@XdHiY@@dH[Y?gY?aWSicRVYCGWSMYB^WS?YBPV\mWT\YCm\HUefZj[j\GhefBj[\\GX' & |
                  'eei\GPeec\GL\GJY>>dG\\J_Y=YdGN\JGegE\InY=G\IhWR@Y>jWQe\KXY>\\KJhmjlFCmeChmZlEjhmRlEdhmNhmL\ENedhjZobY\\E>ed\bYLhncedVbYD' & |
                  '\DebY@\DcbY>XoLdFa\FSXo@bZa\FGXnmbZU\FAbZOWQEXob\Fib[DhlMlEJhlElEDhlAhl?\CdecobUX\C\ecibUPhlcbUL\CVbUJXnS\DMXnMbVA\DGbUn' & |
                  'hkXlDghkThkR\BoecYbSV\BkbSR\BibSPXn=\CJbSdhkDhkB\B[bRU\BYbRSVTcVTEVhccCSVhGVglVRkViVW]ccWUW]KcWGW]?W\lVfmW^\Vf_W^NYGcdLY' & |
                  'ihNYGSdLMYGKdLGYGGYGEW\>cVZYHhdLoYH\W[_YHVVf?W\TYIKeiaj]TeiYj]NeiUeiSYFFdK`\PMejJdKZ\PEYEm\PAYEk\P?W[EYFbW[?\PiYF\\PclG`' & |
                  'meklG\lGZehlj]>i>fehhi>behfi>`YEQdKJ\NKYEMb`?\NGYEKb_n\NEb_lWZbYE_\NYb`MlGLlGJehXi=eehVi=cYE=\MJYDnb]d\MHb]blGBehNi=KYDf' & |
                  '\Lcb\]VWjVW\VkjcE=Vk^VkXVVoVlMW`jcY?W`bcXlW`^W`\Vk>WaSVjkWaMdNCiiCdN?dN=W`BcX\YK_dNQYK[W_oYKYVj[W`PYKmj^Ij^GdMbek_dM`ek]' & |
                  'W_aYJ^W__\SXYJ\\SVj^?dMXekEW_WYJD\RQVYTVYNVmTcEeVmPVmNVY>VmbcYgcYeVm@WbhVm>WbfiiW'
  LOOP i = 0 TO 2786
    p = i*3 + 1
    v = (VAL(SELF.PackTbl[p])-61)*2601 + (VAL(SELF.PackTbl[p+1])-61)*51 + (VAL(SELF.PackTbl[p+2])-61)
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
