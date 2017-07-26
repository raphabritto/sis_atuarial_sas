*-------------------------------------------------------------------------------------------------------------*;
*-- PPA - Pensão por morte de ativo				                                     	          		 	--*;
*-- Versão: 12 de dezembro de 2016                                                                          --*;
*-------------------------------------------------------------------------------------------------------------*;

%macro calcCoberturaPpa;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.);

		PROC IML;
			LOAD MODULE= GetContribuicao;

			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t SalConPrjEvol SalBenefInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado flg_manutencao_saldo} into ativos;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {ajxcb dy_dx qx} into fatores;
			close cobertur.ativos_fatores;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				cobertura_ppa = J(qtdObs, 6, 0);

				DO a = 1 TO qtdObs;
					t = ativos[a, 2];
					SalConPrj = ativos[a, 3];
					SalBenefInss = ativos[a, 4];
					saldo_conta_total = round(ativos[a, 5] + ativos[a, 6], 0.01);
					beneficio_saldado = ativos[a, 7];
					PeFatReduPbe = ativos[a, 8];
					probab_casado = ativos[a, 9];
					flg_manutencao_saldo = ativos[a, 10];

					ajxcb = fatores[a, 1];
					dy_dx = fatores[a, 2];
					qx = fatores[a, 3];

					beneficio_total_ppa = 0;
					contribuicao_ppa = 0;
					beneficio_liquido_ppa = 0;
					FatRenVitPpa = 0;
					AplicarPxsPPA = 0;
					BenTotPxsPpa = 0;
	
					if (&CdPlanBen = 1) then do;
						BenTotPxsPpa = max(0, round((SalConPrj * &CtFamPens) - SalBenefInss, 0.01));

						if (PeFatReduPbe > 0) then BenTotPxsPpa = round(BenTotPxsPpa * PeFatReduPbe, 0.01);

			    		FatRenVitPpa = max(0, round(ajxcb * &NroBenAno * &FtBenEnti * probab_casado, 0.0000000001));

						if (FatRenVitPpa > 0) then 
		               		BenTotPpaRev = max(0, round((saldo_conta_total / FatRenVitPpa) * &FtBenEnti, 0.01));

						if (BenTotPxsPpa > BenTotPpaRev) then do;
							beneficio_total_ppa = BenTotPxsPpa;
							AplicarPxsPPA = 1;
						end;
						else
							beneficio_total_ppa = BenTotPpaRev;

						*------ Contribuição e benefício líquido da cobertura PPA ------;
						contribuicao_ppa = GetContribuicao(beneficio_total_ppa / &FtBenEnti) * (1 - &TxaAdmBen);
					end;
					else if (&CdPlanBen = 2) then do;
						beneficio_total_ppa = max(0, round(beneficio_saldado * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
						AplicarPxsPPA = 1;
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						FtRenVitPpa = max(0, round(ajxcb * &NroBenAno * &FtBenEnti * probab_casado, 0.0000000001));

						if (flg_manutencao_saldo = 0) then
							BenTotPxsPpa = max(0, max(round((SalConPrj * &CtFamPens) - SalBenefInss, 0.01), round(SalConPrj * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotPxsPpa = max(0, round(BenTotPxsPpa - (beneficio_saldado * &FtBenLiquido * &CtFamPens), 0.01));

						if (FtRenVitPpa > 0) then
							BenTotPpaRev = max(0, round((saldo_conta_total / FtRenVitPpa) * &FtBenEnti, &vRoundMoeda));

						if (BenTotPxsPpa > BenTotPpaRev) then do;
							beneficio_total_ppa = BenTotPxsPpa;
							AplicarPxsPPA = 1;
						end;
						else
							beneficio_total_ppa = BenTotPpaRev;
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_ppa = max(0, round((beneficio_total_ppa - contribuicao_ppa) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						beneficio_liquido_ppa = max(0, round(beneficio_total_ppa - contribuicao_ppa, 0.01));

					cobertura_ppa[a, 1] = ativos[a, 1];
					cobertura_ppa[a, 2] = ativos[a, 2];
					cobertura_ppa[a, 3] = beneficio_total_ppa;
					cobertura_ppa[a, 4] = contribuicao_ppa;
					cobertura_ppa[a, 5] = beneficio_liquido_ppa;
					cobertura_ppa[a, 6] = AplicarPxsPPA;
				END;

				create work.ativos_cobertura_ppa_tp&tipoCalculo._s&s. from cobertura_ppa[colname={'id_participante' 't' 'BenTotCobPPA' 'ConPvdCobPPA' 'BenLiqCobPPA' 'AplicarPxsPPA'}];
					append from cobertura_ppa;
				close work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.;

				free fatores ativos cobertura_ppa;
			end;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenTotCobPPA COMMAX14.2 ConPvdCobPPA COMMAX14.2 BenLiqCobPPA COMMAX14.2;
		run;
	%end;
%mend;
%calcCoberturaPpa;

proc datasets library=work kill memtype=data nolist;
	run;
quit;