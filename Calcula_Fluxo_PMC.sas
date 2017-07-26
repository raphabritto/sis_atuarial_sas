*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro calculaFluxoPmc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobATC flg_manutencao_saldo} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {dx lx apx pxs} into fatores;
			close fluxo.ativos_fatores;

			if (&tipoCalculo = 1) then do;
				use premissa.taxa_juros;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros;
			end;
			else if (&tipoCalculo = 2) then do;
				use premissa.taxa_juros_s&s.;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros_s&s.;

				use fluxo.ativos_fatores_estoc_s&s.;
					read all var {aposentadoria morto vivo valido ligado} into fatores_estoc;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_pmc = J(qtsObs, 7, 0);
				pagamento = 0;

				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_atc = ativos[a, 4];
					flg_manutencao_saldo = ativos[a, 5];

					dx = fatores[a, 1];
					lx = fatores[a, 2];
					apx = fatores[a, 3];
/*					taxa_juros_cober = fatores[a, 5];*/
/*					taxa_juros_fluxo = fatores[a, 6];*/

					taxa_juros_cober = taxas_juros[t_cober + 1];
					taxa_juros_fluxo = taxas_juros[t_fluxo + 1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs = 1;
						else
							pxs = fatores[a, 4];
					end;
					else do;
						pxs = 1;
						apx = fatores_estoc[a, 1] * fatores_estoc[a, 3] * fatores_estoc[a, 4] * fatores_estoc[a, 5];
						qx = fatores_estoc[a, 2];
					end;

					v = 0;
					vt = 0;
					vt_dx = 0;
					despesa = 0;
					despesaVP = 0;
					beneficio = 0;

					if (&CdPlanBen ^= 1) then do;
						if (t_cober = t_fluxo) then do;
							t_vt = 0;
						
							beneficio = max(0, round((beneficio_liquido_atc / &FtBenEnti) * &peculioMorteAssistido, 0.01));
							
							if (flg_manutencao_saldo = 0 & beneficio > 0) then 
								beneficio = max(beneficio, &LimPecMin);

							pagamento = max(0, round(beneficio * apx, 0.01));
						end;
						else do;
							pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));
						end;
						
						vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** (t_vt + 1)));
						vt_dx = max(0, vt * dx);

						if (&tipoCalculo = 1) then do;
							if (lx > 0) then
								despesa = max(0, round(pagamento * vt_dx / lx, 0.01));
						end;
						else
							despesa = max(0, round(pagamento * qx, 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));
						despesaVP = max(0, round(despesa * pxs * v, 0.01));

						t_vt = t_vt + 1;
					end;

					fluxo_pmc[a, 1] = ativos[a, 1];
					fluxo_pmc[a, 2] = ativos[a, 2];
					fluxo_pmc[a, 3] = ativos[a, 3];
					fluxo_pmc[a, 4] = beneficio;
					fluxo_pmc[a, 5] = pagamento;
					fluxo_pmc[a, 6] = despesa;
					fluxo_pmc[a, 7] = despesaVP;
				END;

				create temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s. from fluxo_pmc[colname={'id_participante' 'tCober' 'tFluxo' 'BeneficioPMC' 'PagamentoPMC' 'DespesaPMC' 'DespesaVpPMC'}];
					append from fluxo_pmc;
				close temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;

				free fluxo_pmc ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.pmc_ativos&a.;*/
/*			merge determin.pmc_ativos&a. work.pmc_deterministico_ativos;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format BeneficioPMC commax14.2 PagamentoPMC commax14.2 DespesaPMC commax14.2 DespesaVpPMC commax14.2 v 10.8 vt_dx 10.8;*/
/*		run;*/
		
		%_eg_conditional_dropds(work.ativos_despesa_pmc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;
			class tFluxo;
			var DespesaPMC DespesaVpPMC;
			format DespesaPMC commax18.2 DespesaVpPMC commax18.2;
			output out= work.ativos_despesa_pmc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_pmc_tp&tipoCalculo._s&s.;
			if cmiss(tfluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_pmc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;
			class id_participante;
			var DespesaVpPMC;
			format DespesaVpPMC commax18.2;
			output out= work.ativos_encargo_pmc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_pmc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_pmc_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_pmc_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calculaFluxoPmc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*
%_eg_conditional_dropds(determin.pmc_ativos);
data determin.pmc_ativos;
	set determin.pmc_ativos1 - determin.pmc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete pmc_ativos1 - pmc_ativos&numberOfBlocksAtivos;
run;
*/

/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete pmc_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/