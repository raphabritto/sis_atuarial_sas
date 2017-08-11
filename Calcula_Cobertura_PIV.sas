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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {idade_partic_cober} into idade_partic_cober;
				read all var {IddIniApoInss} into idade_aposent_inss;
				read all var {VlBenefiInss} into beneficio_inss;
				read all var {salario_contrib} into SalConPrj;
				read all var {SalBenefInss} into SalBenefInss;
				read all var {saldo_conta_partic} into saldo_conta_partic;
				read all var {saldo_conta_patroc} into saldo_conta_patroc;
				read all var {VlBenSaldado} into beneficio_saldado;
				read all var {PeFatReduPbe} into PeFatReduPbe;
				read all var {probab_casado} into probab_casado;
				read all var {flg_manutencao_saldo} into is_manut_saldo;
				read all var {DtAdesaoPlan} into data_adesao_plano;
				read all var {DtIniBenInss} into data_inicio_benef_inss;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {axiicb} into axiicb;
				read all var {ajxcb} into ajxcb;
				read all var {ajxx_i} into ajxx_i;
				read all var {dy_dx} into dy_dx;
				read all var {ix} into ix;
				read all var {Axii} into axii;
			close cobertur.ativos_fatores;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_total_piv = J(qtd_ativos, 1, 0);
				contribuicao_piv = J(qtd_ativos, 1, 0);
				beneficio_liquido_piv = J(qtd_ativos, 1, 0);
				aplica_pxs_piv = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					saldo_conta_total = max(0, round(saldo_conta_partic[a] + saldo_conta_patroc[a], 0.01));

					FtRenVitPiv = 0;
					BenTotPivPxs = 0;
					BenTotPivRev = 0;

					if ((&CdPlanBen = 1 | &CdPlanBen = 2) & beneficio_inss[a] = 0 & idade_partic_cober[a] < idade_aposent_inss[a]) then do;
						if (&CdPlanBen = 1) then do;
							BenTotPivPxs = max(0, round(SalConPrj[a] - SalBenefInss[a], 0.01));

							if (PeFatReduPbe[a] > 0) then BenTotPivPxs = round(BenTotPivPxs * PeFatReduPbe[a], 0.01);

							BenTotPivPxs = max(0, round(((SalBenefInss[a] + BenTotPivPxs) * &CtFamPens) - SalBenefInss[a], 0.01));
							
				     		FtRenVitPiv = round((axiicb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx_i[a])) * &NroBenAno * &FtBenEnti, 0.0000000001);

							if (FtRenVitPiv > 0) then 
								BenTotPivRev = max(0, round((saldo_conta_total / FtRenVitPiv) * &CtFamPens * &FtBenEnti, 0.01));

							if (BenTotPivPxs > BenTotPivRev) then do;
								beneficio_total_piv[a] = BenTotPivPxs;
								aplica_pxs_piv[a] = 1;
							end;
							else
								beneficio_total_piv[a] = BenTotPivRev;

							*------ Contribuição e benefício líquido da cobertura PIV ------;
							contribuicao_piv[a] = max(0, round(GetContribuicao(beneficio_total_piv[a] / &FtBenEnti) * (1 - &TxaAdmBen), 0.01));
						end;
						else if (&CdPlanBen = 2) then do;
							beneficio_total_piv[a] = max(0, round(beneficio_saldado[a] * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
						end;
					end;
					else if ((&CdPlanBen = 5 & data_inicio_benef_inss[a] <= data_adesao_plano[a]) | ((&CdPlanBen = 4 | &CdPlanBen = 5) & beneficio_inss[a] = 0 & idade_partic_cober[a] < idade_aposent_inss[a])) then do;
						FtRenVitPiv = max(0, round((axiicb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx_i[a])) * &NroBenAno * &FtBenEnti + (axii[a] * &peculioMorteAssistido), 0.0000000001));

						if (is_manut_saldo[a] = 0) then
							BenTotPivPxs = max(0, max(round(SalConPrj[a] - SalBenefInss[a], 0.01), round(SalConPrj[a] * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotPivPxs = max(0, round(BenTotPivPxs - (beneficio_saldado[a] * &FtBenLiquido), 0.01));

						if (FtRenVitPiv > 0) then
							BenTotPivRev = max(0, round((saldo_conta_total / FtRenVitPiv) * &FtBenEnti, &vRoundMoeda));

						if (BenTotPivPxs > BenTotPivRev) then do;
							beneficio_total_piv[a] = BenTotPivPxs;
							aplica_pxs_piv[a] = 1;
						end;
						else
							beneficio_total_piv[a] = BenTotPivRev;

						beneficio_total_piv[a] = round(beneficio_total_piv[a] * &CtFamPens, 0.01);
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_piv[a] = max(0, round((beneficio_total_piv[a] - contribuicao_piv[a]) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						beneficio_liquido_piv[a] = max(0, round(beneficio_total_piv[a] - contribuicao_piv[a], &vRoundMoeda));
				END;

				create work.ativos_cobertura_piv_tp&tipoCalculo._s&s. var {id_participante t1 beneficio_total_piv contribuicao_piv beneficio_liquido_piv aplica_pxs_piv};
					append;
				close work.ativos_cobertura_piv_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_piv_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_piv_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format beneficio_total_piv COMMAX14.2 contribuicao_piv COMMAX14.2 beneficio_liquido_piv COMMAX14.2;
			run;

			proc delete data = work.ativos_cobertura_piv_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaPiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;