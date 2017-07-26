/*-- Programa para cálculo de cobertura para ativos                                                   		 --*/
/*-- Regime de financiamento de capitalização                                                                --*/
/*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*/
/*-- Versão: 11 de março de 2013                                                                             --*/

%macro calcCoberturaPtc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.);

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
				cobertura_ptc = J(qtdObs, 5, 0);

				DO a = 1 TO qtdObs;
					beneficio_total_ptc = 0;
					contribuicao_ptc = 0;
					beneficio_liquido_ptc = 0;

					SalConPrj = ativos[a, 3];
					SalProjeInss = ativos[a, 4];
					saldo_conta_total = ativos[a, 5] + ativos[a, 6];
					beneficio_saldado = ativos[a, 7];
					PeFatReduPbe = ativos[a, 8];
					probab_casado = ativos[a, 9];

					axcb = fatores[a, 1];
					ajxcb = fatores[a, 2];
					ajxx = fatores[a, 3];
					dy_dx = fatores[a, 4];
					ax = fatores[a, 5];
					
					*** CALCULO DO BENEFICIO TOTAL DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					IF (&CdPlanBen = 1) THEN DO;
						*------ Benefício total da cobertura PTC ------;
						beneficio_total_ptc = max(0, round(SalConPrj - SalProjeInss, &vRoundMoeda)); 

 						if (PeFatReduPbe > 0) then 
							beneficio_total_ptc = max(0, round(beneficio_total_ptc * PeFatReduPbe, &vRoundMoeda));

						beneficio_total_ptc = round(((SalProjeInss + beneficio_total_ptc) * &CtFamPens) - SalProjeInss, &vRoundMoeda);

						FtRenVitPtc = round((axcb + &CtFamPens * probab_casado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti, 0.00000001);

						if (FtRenVitPtc > 0) then 
							beneficio_total_ptc = max(beneficio_total_ptc, round((saldo_conta_total / FtRenVitPtc) * &CtFamPens * &FtBenEnti, &vRoundMoeda));

						*------ Contribuição e benefício líquido da cobertura PTC ------;
						contribuicao_ptc = GetContribuicao(beneficio_total_ptc/&FtBenEnti) * (1 - &TxaAdmBen);
					END;
					ELSE IF (&CdPlanBen = 2) THEN DO;
						beneficio_total_ptc = max(0, round(beneficio_saldado * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
					END;
					ELSE IF (&CdPlanBen = 4 | &CdPlanBen = 5) THEN DO;
						FtRenVitPtc = max(0, round((axcb + &CtFamPens * probab_casado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti + (ax * &peculioMorteAssistido), 0.00000001));
						if (FtRenVitPtc > 0) then do;
							beneficio_total_ptc = max(0, round((saldo_conta_total / FtRenVitPtc) * &CtFamPens * &FtBenEnti, &vRoundMoeda));
						end;
					END;

					*** CALCULO DO BENEFICIO LIQUIDO DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_ptc = max(0, round((beneficio_total_ptc - contribuicao_ptc) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						beneficio_liquido_ptc = max(0, round(beneficio_total_ptc - contribuicao_ptc, &vRoundMoeda));

					cobertura_ptc[a, 1] = ativos[a, 1];
					cobertura_ptc[a, 2] = ativos[a, 2];
					cobertura_ptc[a, 3] = beneficio_total_ptc;
					cobertura_ptc[a, 4] = contribuicao_ptc;
					cobertura_ptc[a, 5] = beneficio_liquido_ptc;
				END;

				create work.ativos_cobertura_ptc_tp&tipoCalculo._s&s. from cobertura_ptc[colname={'id_participante' 't' 'BenTotCobPTC' 'ConPrvCobPTC' 'BenLiqCobPTC'}];
					append from cobertura_ptc;
				close work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.;
			end;

			free cobertura_ptc ativos fatores;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenTotCobPTC COMMAX14.2 ConPrvCobPTC COMMAX14.2 BenLiqCobPTC COMMAX14.2;
		run;
	%end;
%mend;
%calcCoberturaPtc;

proc datasets library=work kill memtype=data nolist;
/*proc datasets library=temp kill memtype=data nolist;*/
	run;
quit;


/*%_eg_conditional_dropds(cobertur.ptc_produto_ativos);*/
/*proc summary data = cobertur.ptc_ativos;*/
/* class id_participante;*/
/* var VatBefCobPTC;*/
/* output out=cobertur.ptc_produto_ativos sum=;*/
/*run;*/

/*data cobertur.ptc_produto_ativos;*/
/*	set cobertur.ptc_produto_ativos;*/
/*	if cmiss(id_participante) then delete;*/
/*	drop _TYPE_ _FREQ_;*/
/*run;*/
