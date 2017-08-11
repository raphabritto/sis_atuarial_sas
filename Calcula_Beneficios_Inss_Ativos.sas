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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {DtNascPartic} into DtNascPartic;
				read all var {sexo_partic} into CdSexoPartic;
				read all var {VlSdoConPart} into VlSdoConPart;
				read all var {VlSdoConPatr} into VlSdoConPatr;
				read all var {VlSalEntPrev} into VlSalEntPrev;
				read all var {DtIniContInss} into DtIniContInss;
				read all var {TmpInssCalcu} into TmpInssCalcu;
				read all var {TmpContribInss} into TmpContribInss;
				read all var {VlBenefiInss} into VlBenefiInss;
				read all var {IddIniApoInss} into IddIniApoInss;
				read all var {IDADE_PARTIC_COBER} into IddParticCobert;
				read all var {IDADE_CONJUG_COBER} into IddConjugCobert;
				read all var {reajuste_salario} into reajuste_salario;
				read all var {PeContrParti} into perc_contribuicao_partic;
				read all var {PeContrPatro} into perc_contribuicao_patroc;
				read all var {CdAutoPatroc} into CdAutoPatroc;
			close cobertur.ativos;

			use cobertur.ativos_fatores;
				read all var {ex} into ex;
				read all var {apxa} into apxa;
				read all var {pxs} into pxs;
				read all var {taxa_risco_partic} into taxa_risco_partic;
				read all var {taxa_risco_patroc} into taxa_risco_patroc;
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

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				salario_contrib 	= J(qtd_ativos, 1, 0);
				contribuicao_partic	= J(qtd_ativos, 1, 0);
				contribuicao_patroc	= J(qtd_ativos, 1, 0);
				saldo_conta_partic	= J(qtd_ativos, 1, 0);
				saldo_conta_patroc	= J(qtd_ativos, 1, 0);
				SalBenefInss		= J(qtd_ativos, 1, 0);
				beneficioInss		= J(qtd_ativos, 1, 0);

				if (&CdPlanBen ^= 2) then do;
					DO a = 1 TO qtd_ativos;
						FtRenVit = 0;
						FtPrevideAtc = 0;
						pxs_px1s = 0;
						taxa_juros = 0;

						if (t1[a] = 0) then do;
							*--- para REB e Novo Plano ---*;
							taxa_juros = taxas_juros[t1[a] + 1];
						end;
						else if (t1[a] > 0) then do;
							*--- para REB e Novo Plano ---*;
							taxa_juros = taxas_juros[t1[a]];
						end;

						if (&tipoCalculo = 2) then do;
							apxa[a] = 0;
							pxs[a] = 1;
						end;

/*						if (&CdPlanBen ^= 2) then do;*/
						*------ Data do calculo na evolucao ------*;
						DtCalcEvol = INTNX('YEAR', &DtCalAval, t1[a], 'S');

						*------ Data de aposentadoria de acordo com a idade na evolucao ------*;
						DtApoEntPrev = INTNX('YEAR', DtNascPartic[a], IddParticCobert[a], &vAlignment);

						TmpInssContr = min(TmpInssCalcu[a] + t1[a], TmpContribInss[a]);

						*------ Salário de contribuicao projetado ------*;
						salario_contrib[a] = max(0, round(VlSalEntPrev[a] * reajuste_salario[a] * &FtSalPart, 0.01));

						if (CdAutoPatroc[a] = 0) then
							salario_contrib[a] = max(0, round(salario_contrib[a] * ((1 + &PrSalPart) ** t1[a]), 0.01));

						if (t1[a] = 0) then
							pxs_px1s = 1;
						else do;
							if (pxs[a] > 0 & pxs[a-1] > 0) then
								pxs_px1s = pxs[a] / pxs[a-1];
						end;

						if (&CdPlanBen = 1) then do;
							if (CdAutoPatroc[a] = 0) then do;
								contribuicao_partic[a] = round(max(0, (GetContribuicao(salario_contrib[a] / &FtSalPart) * &NroBenAno * (1 - apxa[a])) * pxs[a]), 0.01);
								contribuicao_patroc[a] = contribuicao_partic[a];
							end;

							if (t1[a] = 0) then
								saldo_conta_partic[a] = max(0, round(VlSdoConPart[a] * pxs_px1s + contribuicao_partic[a], 0.01));
							else
								saldo_conta_partic[a] = max(0, round(saldo_conta_partic[a-1] * pxs_px1s + contribuicao_partic[a], 0.01));
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							contribuicao_partic[a] = GetContribuicaoPercentual(&tipoCalculo, &CdPlanBen, (salario_contrib[a] / &FtSalPart), perc_contribuicao_partic[a], taxa_risco_partic[a], &PC_DESPESA_ADM_PARTICIPANTE, apxa[a], pxs[a], 1);
							contribuicao_patroc[a] = GetContribuicaoPercentual(&tipoCalculo, &CdPlanBen, (salario_contrib[a] / &FtSalPart), perc_contribuicao_patroc[a], taxa_risco_patroc[a], &PC_DESPESA_ADM_PATROCINADORA, apxa[a], pxs[a], 2);

							if (t1[a] > 0) then do;
								saldo_conta_partic[a] = max(0, round(saldo_conta_partic[a-1] * (1 + taxa_juros) * pxs_px1s * (1 - apxa[a - 1]) + contribuicao_partic[a - 1] * (1 + taxa_juros), 0.01));
								saldo_conta_patroc[a] = max(0, round(saldo_conta_patroc[a-1] * (1 + taxa_juros) * pxs_px1s * (1 - apxa[a - 1]) + contribuicao_patroc[a - 1] * (1 + taxa_juros), 0.01));
							end;
						end;

						if ((t1[a] = 0 & IddParticCobert[a] > IddIniApoInss[a]) | (IddParticCobert[a] <= IddIniApoInss[a])) then do;
							*------ Fator para refletir a média dos 80% maiores salários do inss ------*;
							ftSlBen80 = max(0, GetFatorMediaSalariosInss(max(DtIniContInss[a], &DatMedSal), DtCalcEvol));

							*------ Fator previdenciário na data de aposentadoria integral na entidade / fator de transição ------*;
							auxInssContr = TmpInssContr;
							FtPrevideAtc = max(0, GetFatorPrevidenciario(auxInssContr, ex[a], IddParticCobert[a], CdSexoPartic[a]));

							*------ Salário para efeito de cálculo do inss - aposentadoria por tempo de contribuição ------*;
							if (VlBenefiInss[a] > 0) then 
								SalBenefInss[a] = max(0, round(VlBenefiInss[a] * &FtInssAss * &FtBenInss, 0.01));
							else do;
								SalBenefInss[a] = max(0, min(round(salario_contrib[a] * ftSlBen80, 0.01), round(&TtInssBen * &FtBenInss, 0.01)));
								SalBenefInss[a] = max(0, max(round(SalBenefInss[a], 0.01), round(&SalMinimo * &FtBenInss, 0.01)));
							end;

							*------ Salário projetado para efeito de cálculo do inss ------*;
							beneficioInss[a] = max(0, CalcSalarioInss(CdSexoPartic[a], VlBenefiInss[a], DtApoEntPrev, IddParticCobert[a], TmpInssContr, SalBenefInss[a], FtPrevideAtc));
							*beneficioInss = max(0, min(round(beneficioInss, 0.01), round(&TtInssBen * &FtBenInss, 0.01))); /* implementar em 31/12/2017 */
						end;
						else do;
							SalBenefInss[a] = SalBenefInss[a - 1];
							beneficioInss[a] = beneficioInss[a - 1];
						end;
/*						end;*/
					END;
				end;

				create work.ativos_benef_inss_tp&tipoCalculo._s&s. var {id_participante t1 salario_contrib contribuicao_partic contribuicao_patroc saldo_conta_partic saldo_conta_patroc SalBenefInss beneficioInss};
					append;
				close work.ativos_benef_inss_tp&tipoCalculo._s&s.;
			end;
		QUIT;

/*		%_eg_conditional_dropds(cobertur.ativos_tp&tipoCalculo._s&s.);*/
		%if (%sysfunc(exist(work.ativos_benef_inss_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos work.ativos_benef_inss_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format salario_contrib commax14.2 contribuicao_partic commax14.2 contribuicao_patroc commax14.2 saldo_conta_partic commax14.2 saldo_conta_patroc commax14.2 SalBenefInss commax14.2 beneficioInss commax14.2;
				retain id_participante t1;
				drop sexo_partic sexo_conjug CdAutoPatroc idade_partic idade_conjug idade_conjug_cober DtNascPartic CdPatrocPlan VlSdoConPart VlSdoConPatr VlSalEntPrev PeContrParti PeContrPatro reajuste_salario IddAdmPatroc IddAssEntPre TmpAdmIns DtIniContInss TmpInssCalcu TmpInssResto TmpInssTotal TmpContribInss IddApoEntPre TmpPlanoRest;
			run;

			proc delete data = work.ativos_benef_inss_tp&tipoCalculo._s&s.;
		%end;
	%end;
%mend;
%calculaBeneficioInss;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
