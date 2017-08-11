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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {SALARIO_CONTRIB} into SalConPrj;
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
				beneficio_total_atc = J(qtd_ativos, 1, 0);
			    contribuicao_atc = J(qtd_ativos, 1, 0);
			    beneficio_liquido_atc = J(qtd_ativos, 1, 0);

				do a = 1 to qtd_ativos;
					FtRenVitAtc = 0;
					saldo_conta_total = max(0, round(saldo_conta_partic[a] + saldo_conta_patroc[a], 0.01));

					if (&CdPlanBen = 1) then do; *--- REG REPLAN NÃO SALDADO ---*;
						beneficio_total_atc[a] = max(0, round(SalConPrj[a] - SalProjeInss[a], &vRoundMoeda));

						if (PeFatReduPbe[a] > 0) then beneficio_total_atc[a] = max(0, round(beneficio_total_atc[a] * PeFatReduPbe[a], &vRoundMoeda));

						FtRenVitAtc = max(0, round((axcb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx[a])) * &NroBenAno * &FtBenEnti, 0.00000001));

						if (FtRenVitAtc > 0) then
							beneficio_total_atc[a] = max(beneficio_total_atc[a], round((saldo_conta_total / FtRenVitAtc) * &FtBenEnti, &vRoundMoeda));

						*--- Calcula a contribuição utilizando benefício total cobertura ATC ---*;
						contribuicao_atc[a] = max(0, round(GetContribuicao(beneficio_total_atc[a] / &FtBenEnti) * (1 - &TxaAdmBen), 0.01));
					end;
					else if (&CdPlanBen = 2) then do; *--- REG REPLAN SALDADO ---*;
						beneficio_total_atc[a] = max(0, beneficio_saldado[a] * &FtBenLiquido * &FtBenEnti);
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do; *--- REB e NOVO PLANO ---*;
						FtRenVitAtc = round((axcb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx[a])) * &NroBenAno * &FtBenEnti + (ax[a] * &peculioMorteAssistido), 0.00000001);

						if (FtRenVitAtc > 0) then do;
							beneficio_total_atc[a] = max(0, round((saldo_conta_total / FtRenVitAtc) * &FtBenEnti, &vRoundMoeda));
						end;
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						beneficio_liquido_atc[a] = max(0, round((beneficio_total_atc[a] - contribuicao_atc[a]) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						beneficio_liquido_atc[a] = max(0, round(beneficio_total_atc[a] - contribuicao_atc[a], 0.01));
				end;

				create work.ativos_cobertura_atc_tp&tipoCalculo._s&s. var {id_participante t1 beneficio_total_atc contribuicao_atc beneficio_liquido_atc};
					append;
				close work.ativos_cobertura_atc_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_atc_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_atc_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format beneficio_total_atc commax14.2 contribuicao_atc commax14.2 beneficio_liquido_atc commax14.2;
			run;

			proc delete data = work.ativos_cobertura_atc_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaAtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;