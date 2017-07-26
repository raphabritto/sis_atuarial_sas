*-- Programa para cálculo de cobertura para ativos                                                          --*;
*-- Regime de financiamento de capitalização                                                                --*;
*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*;
*-- Versão: 11 de março de 2013                                                                             --*;

%macro calculaBeneficioInss;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_benef_inss_tp&tipoCalculo._s&s.);
		
		PROC IML;
			load module = GetFatorMediaSalariosInss;
			load module = GetContribuicao;
			load module = GetContribuicaoPercentual;
			load module = GetFatorPrevidenciario;
			load module = CalcSalarioInss;
			load module = CalculaSaldoConta;

			use cobertur.ativos;
				read all var {id_participante t DtNascPartic CdSexoPartic VlSdoConPart VlSdoConPatr VlSalEntPrev DtIniContInss TmpInssCalcu TmpContribInss VlBenefiInss IddIniApoInss IddParticCobert IddConjugCobert reajuste_salario PeContrParti PeContrPatro CdAutoPatroc} into ativos;
			close cobertur.ativos;

			use cobertur.ativos_fatores;
				read all var {ex apxa pxs taxa_risco_partic taxa_risco_patroc} into fatores;
			close cobertur.ativos_fatores;

			if (&tipoCalculo = 1) then do;
				use premissa.taxa_juros;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros;
			end;
			else do;
				use premissa.taxa_juros_s&s.;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros_s&s.;
			end;

			qtdAtivos = nrow(ativos);
			qtdFatores = nrow(fatores);

			if (qtdAtivos > 0 & qtdFatores > 0 & (qtdAtivos = qtdFatores)) then do;
				benef_inss = J(qtdAtivos, 9, 0);
				px1s = 0;
				apx1 = 0;

				DO a = 1 TO qtdAtivos;
					IdParticipante = ativos[a, 1];
					t = ativos[a, 2];
					DtNascPartic = ativos[a, 3];
					CdSexoPartic = ativos[a, 4];
					VlSalEntPrev = ativos[a, 7];
					DtIniContInss = ativos[a, 8];
					TmpInssCalcu = ativos[a, 9];
					TmpContribInss = ativos[a, 10];
					VlBenefiInss = ativos[a, 11];
					IddIniApoInss = ativos[a, 12];
					i = ativos[a, 13];
					j = ativos[a, 14];
					fator_reajuste_salarial = ativos[a, 15];
					perc_contribuicao_partic = ativos[a, 16];
					perc_contribuicao_patroc = ativos[a, 17];
					CdAutoPatroc = ativos[a, 18];

					ex = fatores[a, 1];
					apx = fatores[a, 2];
					pxs = fatores[a, 3];
					taxa_risco_partic = fatores[a, 4];
					taxa_risco_patroc = fatores[a, 5];

					contribuicao_partic = 0;
					contribuicao_patroc = 0;
					FtRenVit = 0;
					FtPrevideAtc = 0;
					SalConPrj = 0;
					pxs_px1s = 0;

					if (&CdPlanBen = 2) then do;
						saldo_conta_partic = 0;
						saldo_conta_patroc = 0;
						SalBenefInss = 0;
						beneficioInss = 0;
					end;
					else if (t = 0) then do;
						saldo_conta_partic = ativos[a, 5];
						saldo_conta_patroc = ativos[a, 6];
						SalBenefInss = 0;
						beneficioInss = 0;
						contrib_sld_cnt_partic = 0;
						contrib_sld_cnt_patroc = 0;

						*--- para REB e Novo Plano ---*;
						apx1 = fatores[a, 2];
						px1s = fatores[a, 3];
/*						taxa_juros = fatores[a, 4];*/
						taxa_juros = taxas_juros[t+1];
					end;
					else if (t > 0) then do;
/*						contrib_sld_cnt_partic = benef_inss[a - 1, 4];*/
/*						contrib_sld_cnt_patroc = benef_inss[a - 1, 5];*/
						*--- para REB e Novo Plano ---*;
						apx1 = fatores[a - 1, 2];
						px1s = fatores[a - 1, 3];
/*						taxa_juros = fatores[a - 1, 4];*/
						taxa_juros = taxas_juros[t];
					end;

					if (&tipoCalculo = 2) then do;
						apx1 = 0;
						pxs = 1;
						px1s = 1;
					end;

					if (&CdPlanBen ^= 2) then do;
						*------ Data do calculo na evolucao ------*;
						DtCalcEvol = INTNX('YEAR', &DtCalAval, t, 'S');
						*------ Data de aposentadoria de acordo com a idade na evolucao ------*;
						DtApoEntPrev = INTNX('YEAR', DtNascPartic, i, &vAlignment);

						TmpInssContr = min(TmpInssCalcu + t, TmpContribInss);
						*------ Salário de contribuicao projetado ------*;
						SalConPrj = max(0, round(VlSalEntPrev * fator_reajuste_salarial * &FtSalPart, 0.01));

						if (CdAutoPatroc = 0) then
							SalConPrj = max(0, round(SalConPrj * ((1 + &PrSalPart) ** t), 0.01));

						if (pxs > 0 & px1s > 0) then
							pxs_px1s = pxs / px1s;

						if (&CdPlanBen = 1) then do;
							if (CdAutoPatroc = 0) then do;
								contribuicao_partic = round(max(0, (GetContribuicao(SalConPrj / &FtSalPart) * &NroBenAno * (1 - apx)) * pxs), 0.01);
								contribuicao_patroc = contribuicao_partic;
							end;

							saldo_conta_partic = max(0, round(saldo_conta_partic * pxs_px1s + contribuicao_partic, 0.01));
							saldo_conta_patroc = 0;
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							contribuicao_partic = GetContribuicaoPercentual(&tipoCalculo, &CdPlanBen, (SalConPrj / &FtSalPart), perc_contribuicao_partic, taxa_risco_partic, &PC_DESPESA_ADM_PARTICIPANTE, apx, pxs, 1);
							contribuicao_patroc = GetContribuicaoPercentual(&tipoCalculo, &CdPlanBen, (SalConPrj / &FtSalPart), perc_contribuicao_patroc, taxa_risco_patroc, &PC_DESPESA_ADM_PATROCINADORA, apx, pxs, 2);

							if (t > 0) then do;
								saldo_conta_partic = max(0, round(saldo_conta_partic * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + benef_inss[a - 1, 4] * (1 + taxa_juros), 0.01));
								saldo_conta_patroc = max(0, round(saldo_conta_patroc * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + benef_inss[a - 1, 5] * (1 + taxa_juros), 0.01));
							end;
						end;
							
						if ((t = 0 & i > IddIniApoInss) | (i <= IddIniApoInss)) then do;
							*------ Fator para refletir a média dos 80% maiores salários do inss ------*;
							ftSlBen80 = GetFatorMediaSalariosInss(max(DtIniContInss, &DatMedSal), DtCalcEvol);
							*------ Fator previdenciário na data de aposentadoria integral na entidade / fator de transição ------*;
							auxInssContr = TmpInssContr;
							FtPrevideAtc = GetFatorPrevidenciario(auxInssContr, ex, i, CdSexoPartic);
							*------ Salário para efeito de cálculo do inss - aposentadoria por tempo de contribuição ------*;
							if (VlBenefiInss > 0) then 
								SalBenefInss = round(VlBenefiInss * &FtInssAss * &FtBenInss, 0.01);
							else do;
								SalBenefInss = max(0, min(round(SalConPrj * ftSlBen80, 0.01), round(&TtInssBen * &FtBenInss, 0.01)));
								SalBenefInss = max(0, max(round(SalBenefInss, 0.01), round(&SalMinimo * &FtBenInss, 0.01)));
							end;
							*------ Salário projetado para efeito de cálculo do inss ------*;
							beneficioInss = CalcSalarioInss(CdSexoPartic, VlBenefiInss, DtApoEntPrev, i, TmpInssContr, SalBenefInss, FtPrevideAtc);
							*beneficioInss = max(0, min(round(beneficioInss, 0.01), round(&TtInssBen * &FtBenInss, 0.01))); /* implementar em 31/12/2017 */
							beneficioInss = max(0, round(beneficioInss, 0.01));
						end;
					end;

					benef_inss[a, 1] = IdParticipante;
					benef_inss[a, 2] = t;
					benef_inss[a, 3] = SalConPrj;
					benef_inss[a, 4] = contribuicao_partic;
					benef_inss[a, 5] = contribuicao_patroc;
					benef_inss[a, 6] = saldo_conta_partic;
					benef_inss[a, 7] = saldo_conta_patroc;
					benef_inss[a, 8] = SalBenefInss;
					benef_inss[a, 9] = beneficioInss;
				END;

				create work.ativos_benef_inss_tp&tipoCalculo._s&s. from benef_inss[colname={'id_participante' 't' 'SalConPrjEvol' 'ConParSdoEvol' 'ConPatSdoEvol' 'VlSdoConPartEvol' 'VlSdoConPatrEvol' 'SalBenefInssEvol' 'SalProjeInssEvol'}];
					append from benef_inss;
				close work.ativos_benef_inss_tp&tipoCalculo._s&s.;

				free ativos benef_inss fatores;
			end;
		QUIT;

/*		%_eg_conditional_dropds(cobertur.ativos_tp&tipoCalculo._s&s.);*/
		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos work.ativos_benef_inss_tp&tipoCalculo._s&s.;
			by id_participante t;
			format SalConPrjEvol commax14.2 ConParSdoEvol commax14.2 ConPatSdoEvol commax14.2 VlSdoConPartEvol commax14.2 VlSdoConPatrEvol commax14.2 SalBenefInssEvol commax14.2 SalProjeInssEvol commax14.2;
			retain id_participante t;
			drop CdSexoPartic CdSexoConjug CdAutoPatroc IddPartiCalc IddConjuCalc IddConjugCobert DtNascPartic CdPatrocPlan VlSdoConPart VlSdoConPatr VlSalEntPrev PeContrParti PeContrPatro reajuste_salario IddAdmPatroc IddAssEntPre TmpAdmIns DtIniContInss TmpInssCalcu TmpInssResto TmpInssTotal TmpContribInss IddApoEntPre TmpPlanoRest;
		run;
	%end;

	*proc delete data = cobertur.ativos;
%mend;
%calculaBeneficioInss;

/*proc datasets library=temp kill memtype=data nolist;*/
proc datasets library=work kill memtype=data nolist;
	run;
quit;


/*proc delete data = work.beneficio_cobertura_ativos work.beneficio_input_ativos;*/

/*
proc iml;
	use tabuas.tabuas_servico_normal;
		read all var {idade ex} into ex_fem where (sexo = 1 & t = 0);
		read all var {idade ex} into ex_mas where (sexo = 2 & t = 0);
		read all var {idade apxa} into apx_fem where (sexo = 1 & t = 0);
		read all var {idade apxa} into apx_mas where (sexo = 2 & t = 0);
	close;

	use tabuas.tabuas_servico_ajustada;
		read all var {idade lxs} into lxs_fem where (sexo = 1 & t = 0);
		read all var {idade lxs} into lxs_mas where (sexo = 2 & t = 0);
	close;

	use work.taxa_risco;
		read all var {t vl_taxa_risco} into risco_partic where (ID_RESPONSABILIDADE = 1);
		read all var {t vl_taxa_risco} into risco_patroc where (ID_RESPONSABILIDADE = 2);
	close;

	use sisatu.taxa_juros;
		read all var {t taxa_juros} into juros;
	close;
quit;
*/

/*
%macro calculaBeneficioInss1;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_beneficios_inss);
		
		PROC IML;
			load module = GetFatorMediaSalariosInss;
			load module = GetContribuicao;
			load module = GetContribuicaoPercentual;
			load module = GetFatorPrevidenciario;
			load module = CalcSalarioInss;

			use tabuas.tabuas_servico_normal;
				read all var {idade ex} into ex_fem where (sexo = 1 & t = 0);
				read all var {idade ex} into ex_mas where (sexo = 2 & t = 0);
				read all var {idade apxa} into apx_fem where (sexo = 1 & t = 0);
				read all var {idade apxa} into apx_mas where (sexo = 2 & t = 0);
			close;

			use tabuas.tabuas_servico_ajustada;
				read all var {idade lxs} into lxs_fem where (sexo = 1 & t = 0);
				read all var {idade lxs} into lxs_mas where (sexo = 2 & t = 0);
			close;

			use work.taxa_risco;
				read all var {t vl_taxa_risco} into risco_partic where (ID_RESPONSABILIDADE = 1);
				read all var {t vl_taxa_risco} into risco_patroc where (ID_RESPONSABILIDADE = 2);
			close;

			use sisatu.taxa_juros;
				read all var {t taxa_juros} into juros;
			close;

			use partic.ativos;
				read all var {id_participante IddPartiCalc IddConjuCalc} into ativos; *DtNascPartic CdSexoPartic VlSdoConPart VlSdoConPatr VlSalEntPrev DtIniContInss TmpInssCalcu TmpContribInss VlBenefiInss IddIniApoInss IddPartEvol IddConjEvol fator_reajuste_salarial PeContrParti PeContrPatro CdAutoPatroc} into ativos;
			close;

			qtdAtivos = nrow(ativos);

			if (qtdAtivos > 0) then do;
				*qtd_evol = 0;
				*b = 1;

*				DO a = 1 TO qtdAtivos;*;
*					IddPartiCalc = ativos[a, 2];*;
*					qtd_evol = qtd_evol + ((&MaxAge - IddPartiCalc) + 1);*;
*				END;*;

				*cobertura = J(qtd_evol, 4, 0);

				do a = 1 to qtdAtivos;
					id_participante	= ativos[a, 1];
					idade_partic 	= ativos[a, 2];
					idade_conjug 	= ativos[a, 3];

					*------ Projeta os benefícios até a idade de aposentadoria do plano -1 ------*;
					do t1 = 0 to (&MaxAge - idade_partic);
						*------ Idade do participante na evolucao ------*;
						i = min(idade_partic + t, &MaxAge);
						*------ Idade do conjuce na evolucao ------*;
						j = min(idade_conjug + t, &MaxAge);

*						cobertura[b, 1] = IdParticipante;*;
*						cobertura[b, 2] = t;*;
*						cobertura[b, 3] = i;*;
*						cobertura[b, 4] = j;*;
*						b = b + 1;*;
					END;
				END;

				create work.ativos_idades_cobertura from cobertura[colname={'id_participante' 't' 'IddPartEvol' 'IddConjEvol'}];
					append from cobertura;
				close;
			end;

			/*use work.ativos_idades_cobertura;
				read all var {id_participante t DtNascPartic CdSexoPartic VlSdoConPart VlSdoConPatr VlSalEntPrev DtIniContInss TmpInssCalcu TmpContribInss VlBenefiInss IddIniApoInss IddPartEvol IddConjEvol fator_reajuste_salarial PeContrParti PeContrPatro CdAutoPatroc} into ativos;
			close work.ativos_idades;

			use work.ativos_fatores_tp&tipoCalculo._s&s.;
				read all var {ex apxa pxs taxa_juros taxa_risco_partic taxa_risco_patroc} into fatores;
			close work.ativos_fatores;

			qtdAtivos = nrow(ativos);
			qtdFatores = nrow(fatores);

			if (qtdAtivos > 0 & qtdFatores > 0 & (qtdAtivos = qtdFatores)) then do;
				cobertura = J(qtdAtivos, 9, 0);
				px1s = 0;
				apx1 = 0;

				DO a = 1 TO qtdAtivos;
					IdParticipante = ativos[a, 1];
					t = ativos[a, 2];
					DtNascPartic = ativos[a, 3];
					CdSexoPartic = ativos[a, 4];
					VlSalEntPrev = ativos[a, 7];
					DtIniContInss = ativos[a, 8];
					TmpInssCalcu = ativos[a, 9];
					TmpContribInss = ativos[a, 10];
					VlBenefiInss = ativos[a, 11];
					IddIniApoInss = ativos[a, 12];
					i = ativos[a, 13];
					j = ativos[a, 14];
					fator_reajuste_salarial = ativos[a, 15];
					PeContrParti = ativos[a, 16];
					PeContrPatro = ativos[a, 17];
					CdAutoPatroc = ativos[a, 18];

					ex = fatores[a, 1];
					apx = fatores[a, 2];
					pxs = fatores[a, 3];
					taxa_risco_partic = fatores[a, 5];
					taxa_risco_patroc = fatores[a, 6];

					ConParSdo = 0;
					ConPatSdo = 0;
					FtRenVit = 0;
					FtPrevideAtc = 0;
					SalConPrj = 0;
					pxs_px1s = 0;

					if (&CdPlanBen = 2) then do;
						VlSdoConPart = 0;
						VlSdoConPatr = 0;
						SalBenefInss = 0;
						beneficioInss = 0;
					end;
					else if (t = 0) then do;
						VlSdoConPart = ativos[a, 5];
						VlSdoConPatr = ativos[a, 6];
						SalBenefInss = 0;
						beneficioInss = 0;

						*--- para REB e Novo Plano ---*;
						apx1 = fatores[a, 2];
						px1s = fatores[a, 3];
						taxa_juros = fatores[a, 4];
					end;
					else if (t > 0) then do;
						*--- para REB e Novo Plano ---*;
						apx1 = fatores[a - 1, 2];
						px1s = fatores[a - 1, 3];
						taxa_juros = fatores[a - 1, 4];
					end;

					if (&CdPlanBen ^= 2) then do;
						*------ Data do calculo na evolucao ------*;
						DtCalcEvol = INTNX('YEAR', &DtCalAval, t, 'S');
						*------ Data de aposentadoria de acordo com a idade na evolucao ------*;
						DtApoEntPrev = INTNX('YEAR', DtNascPartic, i, &vAlignment);

						TmpInssContr = min(TmpInssCalcu + t, TmpContribInss);
						*------ Salário de contribuicao projetado ------*;
						SalConPrj = max(0, round(VlSalEntPrev * fator_reajuste_salarial * &FtSalPart, 0.01));

						if (CdAutoPatroc = 0) then
							SalConPrj = max(0, round(SalConPrj * ((1 + &PrSalPart) ** t), 0.01));

						if (pxs > 0 & px1s > 0) then
							pxs_px1s = pxs / px1s;

						if (&CdPlanBen = 1) then do;
							if (CdAutoPatroc = 0) then do;
								ConParSdo = round(max(0, (GetContribuicao(SalConPrj / &FtSalPart) * &NroBenAno * (1 - apx)) * pxs), 0.01);
								ConPatSdo = ConParSdo;
							end;

							VlSdoConPart = max(0, round(VlSdoConPart * pxs_px1s + ConParSdo, 0.01));
							VlSdoConPatr = 0;
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							ConParSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrParti, taxa_risco_partic, &PC_DESPESA_ADM_PARTICIPANTE, apx, 1);
							ConParSdo = max(0, round(ConParSdo * pxs, 0.01));
							
							ConPatSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrPatro, taxa_risco_patroc, &PC_DESPESA_ADM_PATROCINADORA, apx, 0);
							ConPatSdo = max(0, round(ConPatSdo * pxs, 0.01));

							if (t > 0) then do;
								VlSdoConPart = max(0, round(VlSdoConPart * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 4] * (1 + taxa_juros), 0.01));
								VlSdoConPatr = max(0, round(VlSdoConPatr * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 5] * (1 + taxa_juros), 0.01));
							end;
						end;
							
						if ((t = 0 & i > IddIniApoInss) | (i <= IddIniApoInss)) then do;
							*------ Fator para refletir a média dos 80% maiores salários do inss ------*;
							ftSlBen80 = GetFatorMediaSalariosInss(max(DtIniContInss, &DatMedSal), DtCalcEvol);
							*------ Fator previdenciário na data de aposentadoria integral na entidade / fator de transição ------*;
							auxInssContr = TmpInssContr;
							FtPrevideAtc = GetFatorPrevidenciario(auxInssContr, ex, i, CdSexoPartic);
							*------ Salário para efeito de cálculo do inss - aposentadoria por tempo de contribuição ------*;
							if (VlBenefiInss > 0) then 
								SalBenefInss = round(VlBenefiInss * &FtInssAss * &FtBenInss, 0.01);
							else do;
								SalBenefInss = max(0, min(round(SalConPrj * ftSlBen80, 0.01), round(&TtInssBen * &FtBenInss, 0.01)));
								SalBenefInss = max(0, max(round(SalBenefInss, 0.01), round(&SalMinimo * &FtBenInss, 0.01)));
							end;
							*------ Salário projetado para efeito de cálculo do inss ------*;
							beneficioInss = CalcSalarioInss(CdSexoPartic, VlBenefiInss, DtApoEntPrev, i, TmpInssContr, SalBenefInss, FtPrevideAtc);
							beneficioInss = max(0, round(beneficioInss, 0.01));
						end;
					end;

					cobertura[a, 1] = IdParticipante;
					cobertura[a, 2] = t;
					cobertura[a, 3] = SalConPrj;
					cobertura[a, 4] = ConParSdo;
					cobertura[a, 5] = ConPatSdo;
					cobertura[a, 6] = VlSdoConPart;
					cobertura[a, 7] = VlSdoConPatr;
					cobertura[a, 8] = SalBenefInss;
					cobertura[a, 9] = beneficioInss;
				END;

				create work.ativos_beneficios_inss from cobertura[colname={'id_participante' 't' 'SalConPrjEvol' 'ConParSdoEvol' 'ConPatSdoEvol' 'VlSdoConPartEvol' 'VlSdoConPatrEvol' 'SalBenefInssEvol' 'SalProjeInssEvol'}];
					append from cobertura;
				close work.ativos_beneficios_inss;

				free ativos cobertura;
			end;*
		QUIT;

*		%_eg_conditional_dropds(cobertur.ativos_tp&tipoCalculo._s&s.);*;
*		data cobertur.ativos_tp&tipoCalculo._s&s.;*;
*			merge work.ativos_idades_cobertura work.ativos_beneficios_inss;*;
*			by id_participante t;*;
*			format SalConPrjEvol commax14.2 ConParSdoEvol commax14.2 ConPatSdoEvol commax14.2 VlSdoConPartEvol commax14.2 VlSdoConPatrEvol commax14.2 SalBenefInssEvol commax14.2 SalProjeInssEvol commax14.2;*;
*		run;*;
	%end;
%mend;
%calculaBeneficioInss1;
*/

/*
proc iml;
	start calculaBeneficiosINSS(beneficio_inss);

		use work.ativos_idades_cobertura;
			read all var {id_participante t DtNascPartic CdSexoPartic VlSdoConPart VlSdoConPatr VlSalEntPrev DtIniContInss TmpInssCalcu TmpContribInss VlBenefiInss IddIniApoInss IddPartEvol IddConjEvol fator_reajuste_salarial PeContrParti PeContrPatro CdAutoPatroc} into ativos;
		close work.ativos_idades;

		use work.ativos_fatores_tp&tipoCalculo._s&s.;
			read all var {ex apxa pxs taxa_juros taxa_risco_partic taxa_risco_patroc} into fatores;
		close work.ativos_fatores;

		qtdAtivos = nrow(ativos);
		qtdFatores = nrow(fatores);

		if (qtdAtivos > 0 & qtdFatores > 0 & (qtdAtivos = qtdFatores)) then do;
			cobertura = J(qtdAtivos, 9, 0);
			px1s = 0;
			apx1 = 0;

			DO a = 1 TO qtdAtivos;
				IdParticipante = ativos[a, 1];
				t = ativos[a, 2];
				DtNascPartic = ativos[a, 3];
				CdSexoPartic = ativos[a, 4];
				VlSalEntPrev = ativos[a, 7];
				DtIniContInss = ativos[a, 8];
				TmpInssCalcu = ativos[a, 9];
				TmpContribInss = ativos[a, 10];
				VlBenefiInss = ativos[a, 11];
				IddIniApoInss = ativos[a, 12];
				i = ativos[a, 13];
				j = ativos[a, 14];
				fator_reajuste_salarial = ativos[a, 15];
				PeContrParti = ativos[a, 16];
				PeContrPatro = ativos[a, 17];
				CdAutoPatroc = ativos[a, 18];

				ex = fatores[a, 1];
				apx = fatores[a, 2];
				pxs = fatores[a, 3];
				taxa_risco_partic = fatores[a, 5];
				taxa_risco_patroc = fatores[a, 6];

				ConParSdo = 0;
				ConPatSdo = 0;
				FtRenVit = 0;
				FtPrevideAtc = 0;
				SalConPrj = 0;
				pxs_px1s = 0;

				if (&CdPlanBen = 2) then do;
					VlSdoConPart = 0;
					VlSdoConPatr = 0;
					SalBenefInss = 0;
					beneficioInss = 0;
				end;
				else if (t = 0) then do;
					VlSdoConPart = ativos[a, 5];
					VlSdoConPatr = ativos[a, 6];
					SalBenefInss = 0;
					beneficioInss = 0;

					*--- para REB e Novo Plano ---*;
					apx1 = fatores[a, 2];
					px1s = fatores[a, 3];
					taxa_juros = fatores[a, 4];
				end;
				else if (t > 0) then do;
					*--- para REB e Novo Plano ---*;
					apx1 = fatores[a - 1, 2];
					px1s = fatores[a - 1, 3];
					taxa_juros = fatores[a - 1, 4];
				end;

				if (&CdPlanBen ^= 2) then do;
					*------ Data do calculo na evolucao ------*;
					DtCalcEvol = INTNX('YEAR', &DtCalAval, t, 'S');
					*------ Data de aposentadoria de acordo com a idade na evolucao ------*;
					DtApoEntPrev = INTNX('YEAR', DtNascPartic, i, &vAlignment);

					TmpInssContr = min(TmpInssCalcu + t, TmpContribInss);
					*------ Salário de contribuicao projetado ------*;
					SalConPrj = max(0, round(VlSalEntPrev * fator_reajuste_salarial * &FtSalPart, 0.01));

					if (CdAutoPatroc = 0) then
						SalConPrj = max(0, round(SalConPrj * ((1 + &PrSalPart) ** t), 0.01));

					if (pxs > 0 & px1s > 0) then
						pxs_px1s = pxs / px1s;

					if (&CdPlanBen = 1) then do;
						if (CdAutoPatroc = 0) then do;
							ConParSdo = round(max(0, (GetContribuicao(SalConPrj / &FtSalPart) * &NroBenAno * (1 - apx)) * pxs), 0.01);
							ConPatSdo = ConParSdo;
						end;

						VlSdoConPart = max(0, round(VlSdoConPart * pxs_px1s + ConParSdo, 0.01));
						VlSdoConPatr = 0;
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						ConParSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrParti, taxa_risco_partic, &PC_DESPESA_ADM_PARTICIPANTE, apx, 1);
						ConParSdo = max(0, round(ConParSdo * pxs, 0.01));
						
						ConPatSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrPatro, taxa_risco_patroc, &PC_DESPESA_ADM_PATROCINADORA, apx, 0);
						ConPatSdo = max(0, round(ConPatSdo * pxs, 0.01));

						if (t > 0) then do;
							VlSdoConPart = max(0, round(VlSdoConPart * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 4] * (1 + taxa_juros), 0.01));
							VlSdoConPatr = max(0, round(VlSdoConPatr * (1 + taxa_juros) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 5] * (1 + taxa_juros), 0.01));
						end;
					end;
						
					if ((t = 0 & i > IddIniApoInss) | (i <= IddIniApoInss)) then do;
						*------ Fator para refletir a média dos 80% maiores salários do inss ------*;
						ftSlBen80 = GetFatorMediaSalariosInss(max(DtIniContInss, &DatMedSal), DtCalcEvol);
						*------ Fator previdenciário na data de aposentadoria integral na entidade / fator de transição ------*;
						auxInssContr = TmpInssContr;
						FtPrevideAtc = GetFatorPrevidenciario(auxInssContr, ex, i, CdSexoPartic);
						*------ Salário para efeito de cálculo do inss - aposentadoria por tempo de contribuição ------*;
						if (VlBenefiInss > 0) then 
							SalBenefInss = round(VlBenefiInss * &FtInssAss * &FtBenInss, 0.01);
						else do;
							SalBenefInss = max(0, min(round(SalConPrj * ftSlBen80, 0.01), round(&TtInssBen * &FtBenInss, 0.01)));
							SalBenefInss = max(0, max(round(SalBenefInss, 0.01), round(&SalMinimo * &FtBenInss, 0.01)));
						end;
						*------ Salário projetado para efeito de cálculo do inss ------*;
						beneficioInss = CalcSalarioInss(CdSexoPartic, VlBenefiInss, DtApoEntPrev, i, TmpInssContr, SalBenefInss, FtPrevideAtc);
						beneficioInss = max(0, round(beneficioInss, 0.01));
					end;
				end;

				cobertura[a, 1] = IdParticipante;
				cobertura[a, 2] = t;
				cobertura[a, 3] = SalConPrj;
				cobertura[a, 4] = ConParSdo;
				cobertura[a, 5] = ConPatSdo;
				cobertura[a, 6] = VlSdoConPart;
				cobertura[a, 7] = VlSdoConPatr;
				cobertura[a, 8] = SalBenefInss;
				cobertura[a, 9] = beneficioInss;
			END;

			create work.ativos_beneficios_inss from cobertura[colname={'id_participante' 't' 'SalConPrjEvol' 'ConParSdoEvol' 'ConPatSdoEvol' 'VlSdoConPartEvol' 'VlSdoConPatrEvol' 'SalBenefInssEvol' 'SalProjeInssEvol'}];
				append from cobertura;
			close work.ativos_beneficios_inss;

			free ativos cobertura;
		end;
	finish;

	store module= calculaBeneficiosINSS;
quit;
*/