*-------------------------------------------------------------------------------------------------------------*;
*-- ATC - APOSENTADORIA POR TEMPO DE CONTRIBUIÇÃO					                                        --*;
*-- Versão: 11 de março de 2013                                                                             --*;
*-------------------------------------------------------------------------------------------------------------*;

%macro calcCoberturaAtc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_atc_tp&tipoCalculo._s&s.);

		PROC IML;
			load module= GetContribuicao;

			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t SalConPrjEvol SalProjeInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado} into ativos;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {axcb ajxcb ajxx dy_dx Ax} into fatores;
			close cobertur.ativos_fatores;

			qtdObs = nrow(ativos);
			qtdFatores = nrow(fatores);

			if (qtdObs > 0 & qtdFatores > 0 & (qtdObs = qtdFatores)) then do;
				cobertura_atc = J(qtdObs, 5, 0);

				do a = 1 to qtdObs;
					beneficio_total_atc = 0;
				    contribuicao_atc = 0;
				    beneficio_liquido_atc = 0;
					FtRenVitAtc = 0;

					SalConPrj = ativos[a, 3];
					SalProjeInss = ativos[a, 4];
					saldo_conta_total = round(ativos[a, 5] + ativos[a, 6], 0.01);
					beneficio_saldado = ativos[a, 7];
					PeFatReduPbe = ativos[a, 8];
					probab_casado = ativos[a, 9];

					axcb = fatores[a, 1];
					ajxcb = fatores[a, 2];
					ajxx = fatores[a, 3];
					dy_dx = fatores[a, 4];
					ax = fatores[a, 5];

					if (&CdPlanBen = 1) then do; *--- REG REPLAN NÃO SALDADO ---*;
						beneficio_total_atc = max(0, round(SalConPrj - SalProjeInss, &vRoundMoeda));

						if (PeFatReduPbe > 0) then beneficio_total_atc = max(0, round(beneficio_total_atc * PeFatReduPbe, &vRoundMoeda));

						FtRenVitAtc = max(0, round((axcb + &CtFamPens * probab_casado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti, 0.00000001));

						if (FtRenVitAtc > 0) then
							beneficio_total_atc = max(beneficio_total_atc, round((saldo_conta_total / FtRenVitAtc) * &FtBenEnti, &vRoundMoeda));

						*--- Calcula a contribuição utilizando benefício total cobertura ATC ---*;
						contribuicao_atc = GetContribuicao(beneficio_total_atc/&FtBenEnti) * (1 - &TxaAdmBen);
					end;
					else if (&CdPlanBen = 2) then do; *--- REG REPLAN SALDADO ---*;
						beneficio_total_atc = max(0, beneficio_saldado * &FtBenLiquido * &FtBenEnti);
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do; *--- REB e NOVO PLANO ---*;
						FtRenVitAtc = round((axcb + &CtFamPens * probab_casado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti + (ax * &peculioMorteAssistido), 0.00000001);

						if (FtRenVitAtc > 0) then do;
							beneficio_total_atc = max(0, round((saldo_conta_total / FtRenVitAtc) * &FtBenEnti, &vRoundMoeda));
						end;
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_atc = max(0, round((beneficio_total_atc - contribuicao_atc) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						beneficio_liquido_atc = max(0, round(beneficio_total_atc - contribuicao_atc, 0.01));

					cobertura_atc[a, 1] = ativos[a, 1];
					cobertura_atc[a, 2] = ativos[a, 2];
					cobertura_atc[a, 3] = beneficio_total_atc;
					cobertura_atc[a, 4] = contribuicao_atc;
					cobertura_atc[a, 5] = beneficio_liquido_atc;
				end;

				create work.ativos_cobertura_atc_tp&tipoCalculo._s&s. from cobertura_atc[colname={'id_participante' 't' 'BenTotCobATC' 'ConPrvCobATC' 'BenLiqCobATC'}];
					append from cobertura_atc;
				close work.ativos_cobertura_atc_tp&tipoCalculo._s&s.;

				free cobertura_atc ativos fatores;
			end;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_atc_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenTotCobATC commax14.2 ConPrvCobATC commax14.2 BenLiqCobATC commax14.2;
		run;
	%end;
%mend;
%calcCoberturaAtc;

proc datasets library=work kill memtype=data nolist;
/*proc datasets library=temp kill memtype=data nolist;*/
	run;
quit;