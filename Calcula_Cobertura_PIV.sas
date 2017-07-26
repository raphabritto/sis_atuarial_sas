/*-------------------------------------------------------------------------------------------------------------*/
/*-- Programa para cálculo de cobertura para ativos                                                   		 --*/
/*-- Regime de financiamento de capitalização                                                                --*/
/*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*/
/*-- Versão: 11 de março de 2013                                                                             --*/
/*-------------------------------------------------------------------------------------------------------------*/

%macro calcCoberturaPiv;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_piv_tp&tipoCalculo._s&s.);

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
				cobertura_piv = J(qtdObs, 6, 0);

				DO a = 1 TO qtdObs;
					*--- VARIAVEIS INPUT ---*;
					idade_partic_cober = ativos[a, 3];
					idade_aposent_inss = ativos[a, 4];
					beneficio_inss = ativos[a, 5];
					SalConPrj = ativos[a, 6];
					SalBenefInss = ativos[a, 7];
					saldo_conta_total = round(ativos[a, 8] + ativos[a, 9], 0.01);
					beneficio_saldado = ativos[a, 10];
					PeFatReduPbe = ativos[a, 11];
					probab_casado = ativos[a, 12];
					flg_manutencao_saldo = ativos[a, 13];
					data_adesao_plano = ativos[a, 14]; 
					data_inicio_benef_inss = ativos[a, 15];

					axiicb = fatores[a, 1];
					ajxcb = fatores[a, 2];
					ajxx_i = fatores[a, 3];
					dy_dx = fatores[a, 4];
					ix = fatores[a, 5];
					axii = fatores[a, 6];

					*--- VARIAVEIS OUTPUT ---*;
					beneficio_total_piv = 0;
					contribuicao_piv = 0;
					beneficio_liquido_piv = 0;
					FtRenVitPiv = 0;
					AplicarPxsPIV = 0;
					BenTotPivPxs = 0;
					BenTotPivRev = 0;

					if ((&CdPlanBen = 1 | &CdPlanBen = 2) & beneficio_inss = 0 & idade_partic_cober < idade_aposent_inss) then do;
						if (&CdPlanBen = 1) then do;
							BenTotPivPxs = max(0, round(SalConPrj - SalBenefInss , 0.01));

							if (PeFatReduPbe > 0) then BenTotPivPxs = round(BenTotPivPxs * PeFatReduPbe, 0.01);

							BenTotPivPxs = max(0, round(((SalBenefInss + BenTotPivPxs) * &CtFamPens) - SalBenefInss, 0.01));
							
				     		FtRenVitPiv = round((axiicb + &CtFamPens * probab_casado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti, 0.0000000001);

							if (FtRenVitPiv > 0) then 
								BenTotPivRev = max(0, round((saldo_conta_total / FtRenVitPiv) * &CtFamPens * &FtBenEnti, 0.01));

							if (BenTotPivPxs > BenTotPivRev) then do;
								beneficio_total_piv = BenTotPivPxs;
								AplicarPxsPIV = 1;
							end;
							else
								beneficio_total_piv = BenTotPivRev;

							*------ Contribuição e benefício líquido da cobertura PIV ------;
							contribuicao_piv = GetContribuicao(beneficio_total_piv/&FtBenEnti) * (1 - &TxaAdmBen);
						end;
						else if (&CdPlanBen = 2) then do;
							beneficio_total_piv = max(0, round(beneficio_saldado * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
						end;
					end;
					else if ((&CdPlanBen = 5 & data_inicio_benef_inss <= data_adesao_plano) | ((&CdPlanBen = 4 | &CdPlanBen = 5) & beneficio_inss = 0 & idade_partic_cober < idade_aposent_inss)) then do;
						FtRenVitPiv = max(0, round((axiicb + &CtFamPens * probab_casado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti + (axii * &peculioMorteAssistido), 0.0000000001));

						if (flg_manutencao_saldo = 0) then
							BenTotPivPxs = max(0, max(round(SalConPrj - SalBenefInss, 0.01), round(SalConPrj * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotPivPxs = max(0, round(BenTotPivPxs - (beneficio_saldado * &FtBenLiquido), 0.01));

						if (FtRenVitPiv > 0) then
							BenTotPivRev = max(0, round((saldo_conta_total / FtRenVitPiv) * &FtBenEnti, &vRoundMoeda));

						if (BenTotPivPxs > BenTotPivRev) then do;
							beneficio_total_piv = BenTotPivPxs;
							AplicarPxsPIV = 1;
						end;
						else
							beneficio_total_piv = BenTotPivRev;

						beneficio_total_piv = round(beneficio_total_piv * &CtFamPens, 0.01);
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_piv = max(0, round((beneficio_total_piv - contribuicao_piv) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						beneficio_liquido_piv = max(0, round(beneficio_total_piv - contribuicao_piv, &vRoundMoeda));

					cobertura_piv[a, 1] = ativos[a, 1];
					cobertura_piv[a, 2] = ativos[a, 2];
					cobertura_piv[a, 3] = beneficio_total_piv;
					cobertura_piv[a, 4] = contribuicao_piv;
					cobertura_piv[a, 5] = beneficio_liquido_piv;
					cobertura_piv[a, 6] = AplicarPxsPIV;
				END;

				create work.ativos_cobertura_piv_tp&tipoCalculo._s&s. from cobertura_piv[colname={'id_participante' 't' 'BenTotCobPIV' 'ConPvdCobPIV' 'BenLiqCobPIV' 'AplicarPxsPIV'}];
					append from cobertura_piv;
				close work.ativos_cobertura_piv_tp&tipoCalculo._s&s.;

				free cobertura_piv ativos fatores;
			end;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_piv_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenTotCobPIV COMMAX14.2 ConPvdCobPIV COMMAX14.2 BenLiqCobPIV COMMAX14.2;
		run;
	%end;
%mend;
%calcCoberturaPiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;