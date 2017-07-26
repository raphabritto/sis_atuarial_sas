*-------------------------------------------------------------------------------------------------------------*;
*-- AIV - APOSENTADORIA POR INVALIDEZ DE ATIVO						                                        --*;
*-- Versão: 13 de dezembro de 2016                                                                          --*;
*-------------------------------------------------------------------------------------------------------------*;

%macro calcCoberturaAiv;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_aiv_tp&tipoCalculo._s&s.);

		PROC IML;
			load module= GetContribuicao;

			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t IddParticCobert IddIniApoInss VlBenefiInss SalConPrjEvol SalBenefInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado flg_manutencao_saldo DtAdesaoPlan DtIniBenInss} into ativos;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {axiicb ajxcb ajxx_i dy_dx ix Axii} into fatores;
			close cobertur.ativos_fatores;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				cobertura_aiv = J(qtdObs, 6, 0);

				DO a = 1 TO qtdObs;
					*--- VARIAVEIS INPUT ---*;
					IddPartEvol = ativos[a, 3];
					IddIniApoInss = ativos[a, 4];
					beneficio_inss = ativos[a, 5];
					SalConPrj = ativos[a, 6];
					SalBenefInss = ativos[a, 7];
					saldo_conta_total = round(ativos[a, 8] + ativos[a, 9], 0.01);
					beneficio_saldado = ativos[a, 10];
					PeFatReduPbe = ativos[a, 11];
					probab_casado = ativos[a, 12];
					flg_manutencao_saldo = ativos[a, 13];
					DtAdesaoPlan = ativos[a, 14];
					DtIniBenInss = ativos[a, 15];

					*--- FATORES ---*;
					axiicb = fatores[a, 1];
					ajxcb = fatores[a, 2];
					ajxx_i = fatores[a, 3];
					dy_dx = fatores[a, 4];
					ix = fatores[a, 5];
					axii = fatores[a, 6];

					*--- VARIAVEIS OUTPUT ---*;
					beneficio_total_aiv = 0;
					contribuicao_aiv = 0;
					beneficio_liquido_aiv = 0;
					FatRenVitAiv = 0;
					AplicarPxsAIV = 0;
					BenTotAivPxs = 0;
					BenTotAivRev = 0;

					*------ Beneficio total da cobertura AIV ------;
					if ((&CdPlanBen = 1 | &CdPlanBen = 2) & beneficio_inss = 0 & IddPartEvol < IddIniApoInss) then do; *--- REG REPLAN NÃO SALDADO e REG REPLAN SALDADO ---*;
						if (&CdPlanBen = 1) then do;
							BenTotAivPxs = max(0, round(SalConPrj - SalBenefInss, 0.01));

							if (PeFatReduPbe > 0) then BenTotAivPxs = round(BenTotAivPxs * PeFatReduPbe, 0.01);

							FatRenVitAiv = max(0, round((axiicb + &CtFamPens * probab_casado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti, 0.0000000001));

							if (FatRenVitAiv > 0) then
								BenTotAivRev = max(0, round((saldo_conta_total / FatRenVitAiv) * &FtBenEnti, 0.01));

							if (BenTotAivPxs > BenTotAivRev) then do;
								beneficio_total_aiv = BenTotAivPxs;
								AplicarPxsAIV = 1;
							end;
							else 
								beneficio_total_aiv = BenTotAivRev;

							*------ Contribuição e benefício líquido da cobertura AIV ------;
							contribuicao_aiv = GetContribuicao(beneficio_total_aiv/&FtBenEnti) * (1 - &TxaAdmBen);
						end;
						else if (&CdPlanBen = 2) then do;
							beneficio_total_aiv = beneficio_saldado * &FtBenLiquido * &FtBenEnti;
							AplicarPxsAIV = 1;
						end;
					end;
					else if ((&CdPlanBen = 5 & DtIniBenInss <= DtAdesaoPlan) | ((&CdPlanBen = 4 | &CdPlanBen = 5) & beneficio_inss = 0 & IddPartEvol < IddIniApoInss)) then do;
						FtRenVitAiv = max(0, round((axiicb + &CtFamPens * probab_casado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti + (axii * &peculioMorteAssistido), 0.0000000001));

						if (flg_manutencao_saldo = 0) then
							BenTotAivPxs = max(0, max(round(SalConPrj - SalBenefInss, 0.01), round(SalConPrj * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotAivPxs = max(0, round(BenTotAivPxs - (beneficio_saldado * &FtBenLiquido), 0.01));

						if (FtRenVitAiv > 0) then
							BenTotAivRev = max(0, round((saldo_conta_total / FtRenVitAiv) * &FtBenEnti, &vRoundMoeda));

						if (BenTotAivPxs > BenTotAivRev) then do;
							beneficio_total_aiv = BenTotAivPxs;
							AplicarPxsAIV = 1;
						end;
						else 
							beneficio_total_aiv = BenTotAivRev;
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_aiv = max(0, round((beneficio_total_aiv - contribuicao_aiv) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						beneficio_liquido_aiv = max(0, round(beneficio_total_aiv - contribuicao_aiv, 0.01));

					cobertura_aiv[a, 1] = ativos[a, 1];
					cobertura_aiv[a, 2] = ativos[a, 2];
					cobertura_aiv[a, 3] = beneficio_total_aiv;
					cobertura_aiv[a, 4] = contribuicao_aiv;
					cobertura_aiv[a, 5] = beneficio_liquido_aiv;
					cobertura_aiv[a, 6] = AplicarPxsAIV;
				END;

				create work.ativos_cobertura_aiv_tp&tipoCalculo._s&s. from cobertura_aiv[colname={'id_participante' 't' 'BenTotCobAIV' 'ConPvdCobAIV' 'BenLiqCobAIV' 'AplicarPxsAIV'}];
					append from cobertura_aiv;
				close work.ativos_cobertura_aiv_tp&tipoCalculo._s&s.;

				free cobertura_aiv ativos fatores;
			end;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_aiv_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenTotCobAIV COMMAX14.2 ConPvdCobAIV COMMAX14.2 BenLiqCobAIV COMMAX14.2;
		run;
	%end;
%mend;
%calcCoberturaAiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;