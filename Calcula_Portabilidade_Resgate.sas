*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;


%macro calculaFluxoResgPortab;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.);
		proc iml;
			USE cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {saldo_conta_partic} into saldo_conta_partic;
				read all var {saldo_conta_patroc} into saldo_conta_patroc;
				read all var {TmpPlanoPrev} into tempo_plano_previd;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			USE cobertur.ativos_fatores;
				read all var {wx} into wx;
				read all var {apxa} into apxa;
			CLOSE cobertur.ativos_fatores;

			if (&tipoCalculo = 1) then do;
				use premissa.taxa_juros;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros;
			end;
			else if (&tipoCalculo = 2) then do;
				use premissa.taxa_juros_s&s.;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros_s&s.;

				use cobertur.ativos_fatores_estoc_s&s.;
					read all var {vivo} into vivo;
					read all var {valido} into valido;
					read all var {ativo} into ativo;
					read all var {desligado} into desligado;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				resgate = J(qtd_ativos, 1, 0);
				despesa_resgat = J(qtd_ativos, 1, 0);
				portabilidade = J(qtd_ativos, 1, 0);
				despesa_portab = J(qtd_ativos, 1, 0);
				despesa_vp_resgat = J(qtd_ativos, 1, 0);
				despesa_vp_portab = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						if (&tipoCalculo = 2) then do;
							apxa[a] = 0;
							wx[a] = vivo[a] * valido[a] * ativo[a] * desligado[a];
						end;

						taxa_juros_cober = taxas_juros[t1[a] + 1];

						*** regra calculo resgate - regra separada pois as premissas de tempo de participacao no plano podem variar da portabilidade ***;
						if (&CdPlanBen = 4) then do;
							if (tempo_plano_previd[a] < 11) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 0.05, 0.01));
							end;
							else if (tempo_plano_previd[a] >= 11 & tempo_plano_previd[a] < 16) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 0.1, 0.01));
							end;
							else if (tempo_plano_previd[a] >= 16 & tempo_plano_previd[a] < 21) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 0.15, 0.01));
							end;
							else if (tempo_plano_previd[a] >= 21) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 0.2, 0.01));
							end;
						end;
						else if (&CdPlanBen = 5) then do;
							if (tempo_plano_previd[a] <= 10) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 10 & tempo_plano_previd[a] <= 15) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 15 & tempo_plano_previd[a] <= 20) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 20) then do;
								resgate[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
						end;

						if (tempo_plano_previd[a] < 3) then
							despesa_resgat[a] = max(0, round((saldo_conta_partic[a] + resgate[a]) * wx[a] * (1 - apxa[a]), 0.01));
						else
							despesa_resgat[a] = max(0, round((saldo_conta_partic[a] + resgate[a]) * wx[a] * &percentualResgate * (1 - apxa[a]), 0.01));

						*** regra calculo portabilidade - regra separada pois as premissas de tempo de participacao no plano podem variar do resgate ***;
						if (&CdPlanBen = 4) then do;
							if (tempo_plano_previd[a] <= 10) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 10 & tempo_plano_previd[a] <= 15) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 15 & tempo_plano_previd[a] <= 20) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 20) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
						end;
						else if (&CdPlanBen = 5) then do;
							if (tempo_plano_previd[a] <= 10) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 10 & tempo_plano_previd[a] <= 15) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 15 & tempo_plano_previd[a] <= 20) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
							else if (tempo_plano_previd[a] > 20) then do;
								portabilidade[a] = max(0, round(saldo_conta_patroc[a] * 1, 0.01));
							end;
						end;

						if (tempo_plano_previd[a] < 3) then
							despesa_portab[a] = 0;
						else
							despesa_portab[a] = max(0, round((saldo_conta_partic[a] + portabilidade[a]) * wx[a] * &percentualPortabilidade * (1 - apxa[a]), 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t1[a]));

						despesa_vp_resgat[a] = max(0, round(despesa_resgat[a] * v, 0.01));
						despesa_vp_portab[a] = max(0, round(despesa_portab[a] * v, 0.01));
					end;
				END;

				create temp.ativos_fluxo_portab_tp&tipoCalculo._s&s. var {id_participante t1 despesa_resgat despesa_portab despesa_vp_resgat despesa_vp_portab};
					append;
				close temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_portab_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;
				class t1;
				var despesa_resgat despesa_portab despesa_vp_resgat despesa_vp_portab;
				format despesa_resgat commax18.2 despesa_portab commax18.2 despesa_vp_resgat commax18.2 despesa_vp_portab commax18.2;
				output out= work.ativos_despesa_portab_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_portab_tp&tipoCalculo._s&s.;
				if cmiss(t1) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_portab_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;
				class id_participante;
				var despesa_vp_resgat despesa_vp_portab;
				format despesa_vp_resgat commax18.2 despesa_vp_portab commax18.2;
				output out= work.ativos_encargo_portab_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_encargo_portab_tp&tipoCalculo._s&s.);
			data fluxo.ativos_encargo_portab_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_portab_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;
		%end;
	%end;
%mend;
%calculaFluxoResgPortab;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
