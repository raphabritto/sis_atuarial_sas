*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro calculaFluxoAiv;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobAIV BenTotCobAIV PrbCasado AplicarPxsAIV} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {pxii pxs ix apxa axiicb ajxcb ajxx_i Axii} into fatores;
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
					read all var {vivo aposentadoria invalido ativo ligado} into fatores_estoc;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_aiv = J(qtsObs, 7, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_aiv = ativos[a, 4];
					beneficio_total_aiv = ativos[a, 5];
					probab_casado = ativos[a, 6];
					AplicarPxsAIV = ativos[a, 7];

					pxii = fatores[a, 1];
					ix = fatores[a, 3];
					apxa = fatores[a, 4];
					axiicb = fatores[a, 5];
					ajxcb = fatores[a, 6];
					ajxx_i = fatores[a, 7];
					axii = fatores[a, 8];
/*					taxa_juros_cob = fatores[a, 9];*/
/*					taxa_juros_det = fatores[a, 10];*/

					taxa_juros_cob = taxas_juros[t_cober+1];
					taxa_juros_det = taxas_juros[t_fluxo+1];

					if (&tipoCalculo = 1) then do;
						if (AplicarPxsAIV = 0) then 
							pxs = 1;
						else
							pxs = fatores[a, 2];
					end;
					else do;
						pxs = 1;
						pxii = fatores_estoc[a, 1];
						apxa = fatores_estoc[a, 2];
						ix = fatores_estoc[a, 3] * fatores_estoc[a, 1] * fatores_estoc[a, 4] * fatores_estoc[a, 5];
					end;

					despesaBuaAIV = 0;

					if (t_cober = t_fluxo) then do;
						tvt = 0;
						pagamento = max(0, round((beneficio_liquido_aiv / &FtBenEnti) * (1 - apxa) * ix * &NroBenAno, 0.01));

						if (&CdPlanBen ^= 1) then do;
							despesaBuaAIV = max(0, round(((beneficio_total_aiv * (axiicb + &CtFamPens * probab_casado * (ajxcb - ajxx_i)) * &NroBenAno) + ((beneficio_total_aiv / &FtBenEnti) * (axii * &peculioMorteAssistido))) * (1 - apxa) * ix * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else
						pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = max(0, round((pagamento + despesaBuaAIV) * pxii * pxs, 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cob) ** t_cober));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					if (t_cober = t_fluxo & &tipoCalculo = 1) then
						encargo = max(0, round(((pagamento * pxii * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti) + despesaBuaAIV) * pxs * v, 0.01));
					else
						encargo = max(0, round(pagamento * pxii * vt * pxs * v * &FtBenEnti, 0.01));

					tvt = tvt + 1;

					fluxo_aiv[a, 1] = ativos[a, 1];
					fluxo_aiv[a, 2] = t_cober;
					fluxo_aiv[a, 3] = t_fluxo;
					fluxo_aiv[a, 4] = pagamento;
					fluxo_aiv[a, 5] = despesaBuaAIV;
					fluxo_aiv[a, 6] = despesa;
					fluxo_aiv[a, 7] = encargo;
				END;

				create temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s. from fluxo_aiv[colname={'id_participante' 'tCober' 'tFluxo' 'PagamentoAIV' 'DespesaBuaAIV' 'DespesaAIV' 'DespesaVpAIV'}];
					append from fluxo_aiv;
				close temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;

				free ativos fluxo_aiv fatores fatores_estoc;
			end;
		quit;

/*		data determin.aiv_ativos&a.;*/
/*			merge determin.aiv_ativos&a. work.aiv_deterministico_ativos;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format PagamentoAIV commax14.2 DespesaBuaAIV commax14.2 DespesaAIV commax14.2 DespesaVpAIV commax14.2 v_AIV 12.8 vt_AIV 12.8;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_aiv_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;
			class tFluxo;
			var DespesaAIV DespesaVpAIV;
			format DespesaAIV commax18.2 DespesaVpAIV commax18.2;
			output out= work.ativos_despesa_aiv_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_aiv_tp&tipoCalculo._s&s.;
			if cmiss(tFluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_aiv_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;
			class id_participante;
			var DespesaVpAIV;
			format DespesaVpAIV commax18.2;
			output out= work.ativos_encargo_aiv_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_aiv_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_aiv_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_aiv_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;

		proc delete data = temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s. (gennum=all);
		run;
	%end;
%mend;
%calculaFluxoAiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;


/*
%_eg_conditional_dropds(determin.aiv_ativos);
data determin.aiv_ativos;
	set determin.aiv_ativos1 - determin.aiv_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete aiv_ativos1 - aiv_ativos&numberOfBlocksAtivos;
run;
*/


/*data ativos.ativos;*/
/*	merge ativos.ativos determin.aiv_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete aiv_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/