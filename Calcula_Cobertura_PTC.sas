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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {salario_contrib} into SalConPrj;
				read all var {beneficioInss} into SalProjeInss;
				read all var {saldo_conta_partic} into saldo_conta_partic;
				read all var {saldo_conta_patroc} into saldo_conta_patroc;
				read all var {VlBenSaldado} into beneficio_saldado;
				read all var {PeFatReduPbe} into PeFatReduPbe;
				read all var {probab_casado} into probab_casado;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {axcb} into axcb;
				read all var {ajxcb} into ajxcb;
				read all var {ajxx} into ajxx;
				read all var {dy_dx} into dy_dx;
				read all var {Ax} into ax;
			close cobertur.ativos_fatores;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_total_ptc = J(qtd_ativos, 1, 0);
				contribuicao_ptc = J(qtd_ativos, 1, 0);
				beneficio_liquido_ptc = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					saldo_conta_total = max(0, round(saldo_conta_partic[a] + saldo_conta_patroc[a], 0.01));
					
					*** CALCULO DO BENEFICIO TOTAL DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					IF (&CdPlanBen = 1) THEN DO;
						*------ Benefício total da cobertura PTC ------;
						beneficio_total_ptc[a] = max(0, round(SalConPrj[a] - SalProjeInss[a], &vRoundMoeda)); 

 						if (PeFatReduPbe[a] > 0) then 
							beneficio_total_ptc[a] = max(0, round(beneficio_total_ptc[a] * PeFatReduPbe[a], &vRoundMoeda));

						beneficio_total_ptc[a] = max(0, round(((SalProjeInss[a] + beneficio_total_ptc[a]) * &CtFamPens) - SalProjeInss[a], &vRoundMoeda));

						FtRenVitPtc = max(0, round((axcb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx[a])) * &NroBenAno * &FtBenEnti, 0.00000001));

						if (FtRenVitPtc > 0) then 
							beneficio_total_ptc[a] = max(beneficio_total_ptc[a], round((saldo_conta_total / FtRenVitPtc) * &CtFamPens * &FtBenEnti, 0.01));

						*------ Contribuição e benefício líquido da cobertura PTC ------;
						contribuicao_ptc[a] = max(0, round(GetContribuicao(beneficio_total_ptc[a] / &FtBenEnti) * (1 - &TxaAdmBen), 0.01));
					END;
					ELSE IF (&CdPlanBen = 2) THEN DO;
						beneficio_total_ptc[a] = max(0, round(beneficio_saldado[a] * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
					END;
					ELSE IF (&CdPlanBen = 4 | &CdPlanBen = 5) THEN DO;
						FtRenVitPtc = max(0, round((axcb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx[a])) * &NroBenAno * &FtBenEnti + (ax[a] * &peculioMorteAssistido), 0.00000001));
						if (FtRenVitPtc > 0) then do;
							beneficio_total_ptc[a] = max(0, round((saldo_conta_total / FtRenVitPtc) * &CtFamPens * &FtBenEnti, &vRoundMoeda));
						end;
					END;

					*** CALCULO DO BENEFICIO LIQUIDO DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_ptc[a] = max(0, round((beneficio_total_ptc[a] - contribuicao_ptc[a]) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						beneficio_liquido_ptc[a] = max(0, round(beneficio_total_ptc[a] - contribuicao_ptc[a], &vRoundMoeda));
				END;

				create work.ativos_cobertura_ptc_tp&tipoCalculo._s&s. var {id_participante t1 beneficio_total_ptc contribuicao_ptc beneficio_liquido_ptc};
					append;
				close work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_ptc_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format beneficio_total_ptc COMMAX14.2 contribuicao_ptc COMMAX14.2 beneficio_liquido_ptc COMMAX14.2;
			run;

			proc delete data = work.ativos_cobertura_ptc_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaPtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;