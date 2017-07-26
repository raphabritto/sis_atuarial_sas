
%macro calculaFluxoAssistidos;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(fluxo.assistidos_fluxo_tp&tipoCalculo._s&s.);
		PROC IML;
			*--- CALCULA O FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS DOS ASSISTIDOS ---*;
			load module= GetContribuicao;
				
			USE fluxo.assistidos;
				read all var {id_participante t IddPartiCalc IddPartiEvol IddConjuEvol IddFilJovEvol IddFilInvEvol IddFilJovCalc CdTipoBenefi ftFluxoCopen BenTotApo BenTotFut BenTotPms fl_deficiente} into assistidos;
			CLOSE fluxo.assistidos;

			USE fluxo.assistidos_fatores;
				read all var {id_participante t px pxii pjx pxi dxn_lx dxnii_lxii dxn_lxn pxn pxnii taxa_juros_fluxo} into fatores;
			CLOSE fluxo.assistidos_fatores;

			if (&tipoCalculo = 2) then do;
				USE fluxo.assistidos_estoc_s&s.;
					read all var {id_participante t vivo morto} into fatores_estoc;
				CLOSE fluxo.assistidos_estoc_s&s.;
			end;

			nObs = nrow(assistidos);

			if (nObs > 0) then do;

				assistido_fluxo = J(nObs, 14, 0);

				DO a = 1 TO nObs;
					t = assistidos[a, 2];
					idade_partic = assistidos[a, 3];
					idade_partic_fluxo = assistidos[a, 4];
					idade_conjug_fluxo = assistidos[a, 5];
					IddFilJovEvol = assistidos[a, 6];
					IddFilInvEvol = assistidos[a, 7];
					IddFilJovCalc = assistidos[a, 8];
					tipo_beneficio = assistidos[a, 9];
					ftFluxoCopen = assistidos[a, 10];
					BenTotApo = assistidos[a, 11];
					BenTotFut = assistidos[a, 12];
					BenTotPms = assistidos[a, 13];
					is_deficiente = assistidos[a, 14];

					if (tipo_beneficio = 4) then
						BenTotApo = BenTotApo * ftFluxoCopen;

					px =  fatores[a, 3];
					pxii = fatores[a, 4];
					pjx = fatores[a, 5];
					pxi = fatores[a, 6];
					dxn_lx = fatores[a, 7];
					dxnii_lxii = fatores[a, 8];
					dxn_lxn = fatores[a, 9];
					pxn = fatores[a, 10];
					pxnii = fatores[a, 11];
					taxa_juros_fluxo = fatores[a, 12];

					ftApo = 0;
					ftFut = 0;
					ftPms = 0;
					tPfr_r = 0; * conjuge *;
					tPjr_r = 0; * filho jovem *;
					tPjri_r = 0; * filho invalido *;

					if (&tipoCalculo = 2) then do;
						px = fatores_estoc[a, 3];
						pxii = fatores_estoc[a, 3];
						ftPms = fatores_estoc[a, 4];
					end;
			
					*------ ZERA AS VARIÁVEIS DO CÁLCULO ------*;
					ContribApo = 0;
					BenLiqApo = 0;
					DespApoFxo = 0;
					DespApoVP = 0;
					ContribFut = 0;
					BenLiqFut = 0;
					DespFutFxo = 0;
					DespFutVP = 0;
					DespPmsFxo = 0;
					DespPmsVP = 0;

					if (tipo_beneficio = 1 | tipo_beneficio = 2) then do;
						ftApo = px;

						if (idade_conjug_fluxo ^= .) then do;
							tPjr_r = max(0, pjx - (px * pjx));
						end;

						if (IddFilJovEvol ^= .) then do;
							tPfr = 0;

							if (t < &MaiorIdad - IddFilJovCalc) then
								tPfr = 1;

							tPfr_r = max(0, tPfr - (px * tPfr));
						end;

						if (IddFilInvEvol ^= .) then do;
							tPjri_r = max(0, pxi - (px * pxi));
						end;
					end;
					else if (tipo_beneficio = 3) then do;
						ftApo = pxii;

						if (idade_conjug_fluxo ^= .) then do;
							tPjr_r = max(0, pjx - (pxii * pjx));
						end;

						if (IddFilJovEvol ^= .) then do;
							tPfr = 0;

							if (t < &MaiorIdad - IddFilJovCalc) then
								tPfr = 1;

							tPfr_r = max(0, tPfr - (pxii * tPfr));
						end;

						if (IddFilInvEvol ^= .) then do;
							tPjri_r = max(0, pxi - (pxii * pxi));
						end;
					end;
					else if (tipo_beneficio = 4) then do;
						if (idade_partic < &MaiorIdad & idade_partic_fluxo < &MaiorIdad) then
							ftApo = 1;
						else if (idade_partic < &MaiorIdad & idade_partic_fluxo >= &MaiorIdad) then
							ftApo = 0;
						else
							ftApo = px;
					end;

					if (idade_conjug_fluxo ^= . & IddFilJovEvol = . & IddFilInvEvol = .) then do;
						ftFut = tPjr_r;
					end;
					else if (idade_conjug_fluxo = . & IddFilJovEvol ^= . & IddFilInvEvol = .) then do;
						ftFut = tPfr_r;
					end;
					else if (idade_conjug_fluxo ^= . & IddFilJovEvol ^= . & IddFilInvEvol = .) then do;
						ftFut = max(0, max(tPfr_r, tPjr_r));
					end;
					else if (idade_conjug_fluxo = . & IddFilJovEvol ^= . & IddFilInvEvol ^= .) then do;
						ftFut = max(0, max(tPfr_r, tPjri_r));
					end;
					else if (idade_conjug_fluxo ^= . & IddFilJovEvol = . & IddFilInvEvol ^= .) then do;
						ftFut = max(0, max(tPjr_r, tPjri_r));
					end;
					else if (idade_conjug_fluxo ^= . & IddFilJovEvol ^= . & IddFilInvEvol ^= .) then do;
						ftFut = max(0, max(max(tPfr_r, tPjr_r), tPjri_r));
					end;

					vt = 1 / ((1 + taxa_juros_fluxo) ** t);
					v = 1 / ((1 + taxa_juros_fluxo)/(1 + &PrTxBenef));

					if (&tipoCalculo = 1) then do;
						if (tipo_beneficio = 1 | tipo_beneficio = 2 | (tipo_beneficio = 4 & idade_partic >= &MaiorIdad & is_deficiente = 0)) then do;
							ftPms = max(0, dxn_lx * vt);
						end;
						else if (tipo_beneficio = 4 & idade_partic < &MaiorIdad & is_deficiente = 0 & idade_partic_fluxo < &MaiorIdad) then do;
							ftPms = max(0, dxn_lxn * px * vt);
						end;
						else if (tipo_beneficio = 3 | (tipo_beneficio = 4 & is_deficiente = 1)) then do;
							ftPms = max(0, dxnii_lxii * vt);
						end;
					end;

					BenTotApo = max(0, round(BenTotApo * ((1 + &PrTxBenef) ** t), 0.01));
					ContribApo = max(0, GetContribuicao(BenTotApo));
					ContribApo = max(0, round(ContribApo * (1 - &TxaAdmBen), 0.01));
					BenLiqApo = max(0, round(BenTotApo - ContribApo, 0.01));
					DespApoFxo = max(0, round(BenLiqApo * &NroBenAno * ftApo, 0.01));

					BenTotFut = max(0, round(BenTotFut * ((1 + &PrTxBenef) ** t), 0.01));
					ContribFut = max(0, GetContribuicao(BenTotFut));
					ContribFut = max(0, round(ContribFut * (1 - &TxaAdmBen), 0.01));
					BenLiqFut = max(0, round(BenTotFut - ContribFut, 0.01));
					DespFutFxo = max(0, round(BenLiqFut * &NroBenAno * ftFut, 0.01));

					DespPmsFxo = max(0, round(BenTotPms * ftPms * ((1 + &PrTxBenef) ** t), 0.01));
					
					if (t = 0) then do;
						if (tipo_beneficio = 1 | tipo_beneficio = 2 | tipo_beneficio = 3 | (tipo_beneficio = 4 & idade_partic >= &MaiorIdad & is_deficiente = 0)) then do;
							DespApoVP = max(0, round(((DespApoFxo * vt) - &NroBenAno * &Fb * BenLiqApo) * &FtBenEnti, 0.01));
						end;
						else do;
							DespApoVP = max(0, round(((DespApoFxo * vt) - &NroBenAno * &Fb * BenLiqApo * (1 - v ** (&MaiorIdad - idade_partic))) * &FtBenEnti, 0.01));
						end;

						if ((tipo_beneficio = 1 | tipo_beneficio = 2) & idade_conjug_fluxo = . & IddFilInvEvol = . & IddFilJovEvol ^= .) then do;
							DespFutVP = max(0, round(((DespFutFxo * vt) - (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol))) + (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol) * pxn))) * &FtBenEnti, 0.01));
						end;
						else if (tipo_beneficio = 3 & idade_conjug_fluxo = . & IddFilInvEvol = . & IddFilJovEvol ^= .) then do;
							DespFutVP = max(0, round(((DespFutFxo * vt) - (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol))) + (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol) * pxnii))) * &FtBenEnti, 0.01));
						end;
						else do;
							DespFutVP = max(0, round((DespFutFxo * vt) * &FtBenEnti), 0.01);
						end;
					end;
					else do;
						DespApoVP = max(0, round(DespApoFxo * vt * &FtBenEnti, 0.01));
						DespFutVP = max(0, round(DespFutFxo * vt * &FtBenEnti, 0.01));
					end;

					 DespPmsVP = max(0, round(DespPmsFxo * (1 / ((1 + taxa_juros_fluxo)/(1 + &PrTxBenef))), 0.01));

					assistido_fluxo[a, 1] = assistidos[a, 1];
					assistido_fluxo[a, 2] = assistidos[a, 2];
					assistido_fluxo[a, 3] = BenTotApo;
					assistido_fluxo[a, 4] = ContribApo;
					assistido_fluxo[a, 5] = BenLiqApo;
					assistido_fluxo[a, 6] = DespApoFxo;
					assistido_fluxo[a, 7] = DespApoVP;
					assistido_fluxo[a, 8] = BenTotFut;
					assistido_fluxo[a, 9] = ContribFut;
					assistido_fluxo[a, 10] = BenLiqFut;
					assistido_fluxo[a, 11] = DespFutFxo;
					assistido_fluxo[a, 12] = DespFutVP;
					assistido_fluxo[a, 13] = DespPmsFxo;
					assistido_fluxo[a, 14] = DespPmsVP;
				END;

				create fluxo.assistidos_fluxo_tp&tipoCalculo._s&s. from assistido_fluxo[colname={'id_participante' 't' 'BenTotApoFxo' 'ContribApoFxo' 'BenLiqApoFxo' 'DespApoFxo' 'DespApoVP' 'BenTotFutFxo' 'ContribFutFxo' 'BenLiqFutFxo' 'DespFutFxo' 'DespFutVP' 'DespPmsFxo' 'DespPmsVP'}];
					append from assistido_fluxo;
				close fluxo.assistidos_fluxo_tp&tipoCalculo._s&s.;
			end;
		QUIT;

/*		data determin.deterministico_assistidos;*/
/*			merge determin.deterministico_assistidos work.cal_deterministico_assistidos;*/
/*			by id_participante t;*/
/*			format BenTotApoFxo commax14.2 ContribApoFxo commax14.2 BenLiqApoFxo commax14.2 DespApoFxo commax14.2 DespApoVP commax14.2 BenTotFutFxo commax14.2 ContribFutFxo commax14.2 BenLiqFutFxo commax14.2 DespFutFxo commax14.2 DespFutVP commax14.2 DespPmsFxo commax14.2 DespPmsVP commax14.2;*/
/*		run;*/

/*		proc delete data = work.cal_deterministico_assistidos;*/
	%end;
%mend;
%calculaFluxoAssistidos;