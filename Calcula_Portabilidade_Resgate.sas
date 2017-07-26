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
				read all var {id_participante t VlSdoConPartEvol VlSdoConPatrEvol TmpPlanoPrev} into ativos;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			USE cobertur.ativos_fatores;
				read all var {wx apxa} into fatores;
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
					read all var {vivo valido ativo desligado} into fatores_estoc;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_resg_portab = J(qtsObs, 6, 0);

				DO a = 1 TO qtsObs;
					resgate = 0;
					despesaResgate = 0;
					portabilidade = 0;
					despesaPortabilidade = 0;
					despesaResgateVP = 0;
					despesaPortabilidadeVP = 0;

					if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						t = ativos[a, 2];
						saldo_conta_partic = ativos[a, 3];
						saldo_conta_patroc = ativos[a, 4];
						tempo_plano_previd = ativos[a, 5];

						if (&tipoCalculo = 1) then do;
							wx = fatores[a, 1];
							apxa = fatores[a, 2];
						end;
						else do;
							apxa = 0;
							wx = fatores_estoc[a, 1] * fatores_estoc[a, 2] * fatores_estoc[a, 3] *fatores_estoc[a, 4];
						end;

						taxa_juros_cober = taxas_juros[t + 1];

						*** regra calculo resgate - regra separada pois as premissas de tempo de participacao no plano podem variar da portabilidade ***;
						if (&CdPlanBen = 4) then do;
							if (tempo_plano_previd < 11) then do;
								resgate = max(0, round(saldo_conta_patroc * 0.05, 0.01));
							end;
							else if (tempo_plano_previd >= 11 & tempo_plano_previd < 16) then do;
								resgate = max(0, round(saldo_conta_patroc * 0.1, 0.01));
							end;
							else if (tempo_plano_previd >= 16 & tempo_plano_previd < 21) then do;
								resgate = max(0, round(saldo_conta_patroc * 0.15, 0.01));
							end;
							else if (tempo_plano_previd >= 21) then do;
								resgate = max(0, round(saldo_conta_patroc * 0.2, 0.01));
							end;
						end;
						else if (&CdPlanBen = 5) then do;
							if (tempo_plano_previd <= 10) then do;
								resgate = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 10 & tempo_plano_previd <= 15) then do;
								resgate = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 15 & tempo_plano_previd <= 20) then do;
								resgate = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 20) then do;
								resgate = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
						end;

						if (tempo_plano_previd < 3) then
							despesaResgate = max(0, round((saldo_conta_partic + resgate) * wx * (1 - apxa), 0.01));
						else
							despesaResgate = max(0, round((saldo_conta_partic + resgate) * wx * &percentualResgate * (1 - apxa), 0.01));

						*** regra calculo portabilidade - regra separada pois as premissas de tempo de participacao no plano podem variar do resgate ***;
						if (&CdPlanBen = 4) then do;
							if (tempo_plano_previd <= 10) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 10 & tempo_plano_previd <= 15) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 15 & tempo_plano_previd <= 20) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 20) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
						end;
						else if (&CdPlanBen = 5) then do;
							if (tempo_plano_previd <= 10) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 10 & tempo_plano_previd <= 15) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 15 & tempo_plano_previd <= 20) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
							else if (tempo_plano_previd > 20) then do;
								portabilidade = max(0, round(saldo_conta_patroc * 1, 0.01));
							end;
						end;

						if (tempo_plano_previd < 3) then
							despesaPortabilidade = 0;
						else
							despesaPortabilidade = max(0, round((saldo_conta_partic + portabilidade) * wx * &percentualPortabilidade * (1 - apxa), 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t));

						despesaResgateVP = max(0, round(despesaResgate * v, 0.01));
						despesaPortabilidadeVP = max(0, round(despesaPortabilidade * v, 0.01));
					end;

					fluxo_resg_portab[a, 1] = ativos[a, 1];
					fluxo_resg_portab[a, 2] = ativos[a, 2];
					fluxo_resg_portab[a, 3] = despesaResgate;
					fluxo_resg_portab[a, 4] = despesaPortabilidade;
					fluxo_resg_portab[a, 5] = despesaResgateVP;
					fluxo_resg_portab[a, 6] = despesaPortabilidadeVP;
				END;

				create temp.ativos_fluxo_portab_tp&tipoCalculo._s&s. from fluxo_resg_portab[colname={'id_participante' 't' 'DespesaResgate' 'DespesaPortabilidade' 'DespesaResgateVP' 'DespesaPortabilidadeVP'}];
					append from fluxo_resg_portab;
				close temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;

				free fluxo_resg_portab ativos fatores;
			end;
		quit;

/*		data determin.rotatividade_ativos;*/
/*			merge determin.rotatividade_ativos work.rotatividade_determin_ativos;*/
/*			by id_participante t;*/
/*			format DespesaResgate commax14.2 DespesaPortabilidade commax14.2 DespesaResgateVP commax14.2 DespesaPortabilidadeVP commax14.2;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_portab_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;
			class t;
			var DespesaResgate DespesaPortabilidade DespesaResgateVP DespesaPortabilidadeVP;
			format DespesaResgate commax18.2 DespesaPortabilidade commax18.2 DespesaResgateVP commax18.2 DespesaPortabilidadeVP commax18.2;
			output out= work.ativos_despesa_portab_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_portab_tp&tipoCalculo._s&s.;
			if cmiss(t) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_portab_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_portab_tp&tipoCalculo._s&s.;
			class id_participante;
			var DespesaResgateVP DespesaPortabilidadeVP;
			format DespesaResgateVP commax18.2 DespesaPortabilidadeVP commax18.2;
			output out= work.ativos_encargo_portab_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_portab_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_portab_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_portab_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calculaFluxoResgPortab;

proc datasets library=work kill memtype=data nolist;
	run;
quit;


*proc delete data = work.rotatividade_determin_ativos;

/*%_eg_conditional_dropds(determin.rotatividade_ativos);
data determin.rotatividade_ativos;
	set determin.rotatividade_ativos1 - determin.rotatividade_ativos&numberOfBlocksAtivos;
run;*/

/*proc datasets nodetails library=determin;
   delete rotatividade_ativos1 - rotatividade_ativos&numberOfBlocksAtivos;
run;*/





/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete rotatividade_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/