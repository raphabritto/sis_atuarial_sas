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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {salario_contrib} into SalConPrj;
				read all var {SalBenefInss} into SalBenefInss;
				read all var {saldo_conta_partic} into saldo_conta_partic;
				read all var {saldo_conta_patroc} into saldo_conta_patroc;
				read all var {VlBenSaldado} into beneficio_saldado;
				read all var {PeFatReduPbe} into PeFatReduPbe;
				read all var {probab_casado} into probab_casado;
				read all var {flg_manutencao_saldo} into is_manut_saldo;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {ajxcb} into ajxcb;
				read all var {dy_dx} into dy_dx;
				read all var {qx} into qx;
			close cobertur.ativos_fatores;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_total_ppa = J(qtd_ativos, 1, 0);
				contribuicao_ppa = J(qtd_ativos, 1, 0);
				beneficio_liquido_ppa = J(qtd_ativos, 1, 0);
				aplica_pxs_ppa = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					saldo_conta_total = max(0, round(saldo_conta_partic[a] + saldo_conta_patroc[a], 0.01));
					
					FatRenVitPpa = 0;
					BenTotPxsPpa = 0;
	
					if (&CdPlanBen = 1) then do;
						BenTotPxsPpa = max(0, round((SalConPrj[a] * &CtFamPens) - SalBenefInss[a], 0.01));

						if (PeFatReduPbe[a] > 0) then BenTotPxsPpa = round(BenTotPxsPpa * PeFatReduPbe[a], 0.01);

			    		FatRenVitPpa = max(0, round(ajxcb[a] * &NroBenAno * &FtBenEnti * probab_casado[a], 0.0000000001));

						if (FatRenVitPpa > 0) then 
		               		BenTotPpaRev = max(0, round((saldo_conta_total / FatRenVitPpa) * &FtBenEnti, 0.01));

						if (BenTotPxsPpa > BenTotPpaRev) then do;
							beneficio_total_ppa[a] = BenTotPxsPpa;
							aplica_pxs_ppa[a] = 1;
						end;
						else
							beneficio_total_ppa[a] = BenTotPpaRev;

						*------ Contribuição e benefício líquido da cobertura PPA ------;
						contribuicao_ppa[a] = max(0, round(GetContribuicao(beneficio_total_ppa[a] / &FtBenEnti) * (1 - &TxaAdmBen), 0.01));
					end;
					else if (&CdPlanBen = 2) then do;
						beneficio_total_ppa[a] = max(0, round(beneficio_saldado[a] * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
						aplica_pxs_ppa[a] = 1;
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						FtRenVitPpa = max(0, round(ajxcb[a] * &NroBenAno * &FtBenEnti * probab_casado[a], 0.0000000001));

						if (is_manut_saldo[a] = 0) then
							BenTotPxsPpa = max(0, max(round((SalConPrj[a] * &CtFamPens) - SalBenefInss[a], 0.01), round(SalConPrj[a] * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotPxsPpa = max(0, round(BenTotPxsPpa - (beneficio_saldado[a] * &FtBenLiquido * &CtFamPens), 0.01));

						if (FtRenVitPpa > 0) then
							BenTotPpaRev = max(0, round((saldo_conta_total / FtRenVitPpa) * &FtBenEnti, &vRoundMoeda));

						if (BenTotPxsPpa > BenTotPpaRev) then do;
							beneficio_total_ppa[a] = BenTotPxsPpa;
							aplica_pxs_ppa[a] = 1;
						end;
						else
							beneficio_total_ppa[a] = BenTotPpaRev;
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_ppa[a] = max(0, round((beneficio_total_ppa[a] - contribuicao_ppa[a]) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						beneficio_liquido_ppa[a] = max(0, round(beneficio_total_ppa[a] - contribuicao_ppa[a], 0.01));
				END;

				create work.ativos_cobertura_ppa_tp&tipoCalculo._s&s. var {id_participante t1 beneficio_total_ppa contribuicao_ppa beneficio_liquido_ppa aplica_pxs_ppa};
					append;
				close work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_ppa_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format beneficio_total_ppa COMMAX14.2 contribuicao_ppa COMMAX14.2 beneficio_liquido_ppa COMMAX14.2;
			run;

			proc delete data = work.ativos_cobertura_ppa_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaPpa;

proc datasets library=work kill memtype=data nolist;
	run;
quit;