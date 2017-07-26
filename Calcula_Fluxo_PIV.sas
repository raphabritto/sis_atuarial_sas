*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro calculaFluxoPiv;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobPIV AplicarPxsPIV PrbCasado} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {pxii pjx pxs ix apxa} into fatores;
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
				fluxo_piv = J(qtsObs, 6, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_piv = ativos[a, 4];
					AplicarPxsPIV = ativos[a, 5];
					probab_casado = ativos[a, 6];

					pxii = fatores[a, 1];
					pjx = fatores[a, 2];
					ix = fatores[a, 4];
					apxa = fatores[a, 5];
/*					taxa_juros_cober = fatores[a, 6];*/
/*					taxa_juros_fluxo = fatores[a, 7];*/

					taxa_juros_cober = taxas_juros[t_cober+1];
					taxa_juros_fluxo = taxas_juros[t_fluxo+1];

					if (&tipoCalculo = 1) then do;
						if (AplicarPxsPIV = 0) then 
							pxs = 1;
						else
							pxs = fatores[a, 3];
					end;
					else do;
						pxs = 1;
						pxii = fatores_estoc[a, 1];
						apxa = fatores_estoc[a, 2];
						ix = fatores_estoc[a, 3] * fatores_estoc[a, 1] * fatores_estoc[a, 4] * fatores_estoc[a, 5];
					end;

					if (t_cober = t_fluxo) then do;
						pagamento = max(0, round((beneficio_liquido_piv / &FtBenEnti) * (1 - apxa) * ix * &NroBenAno * probab_casado, 0.01));
						tvt = 0;
					end;
					else
						pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = max(0, round(pagamento * (pjx - pxii * pjx) * pxs, 0.01));

					v = 1 / ((1 + taxa_juros_cober) ** t_cober);
					vt = 1 / ((1 + taxa_juros_fluxo) ** tvt);

					encargo = max(0, round(pagamento * &FtBenEnti * (pjx - pxii * pjx) * vt * pxs * v, 0.01));

					tvt = tvt + 1;

					fluxo_piv[a, 1] = ativos[a, 1];
					fluxo_piv[a, 2] = ativos[a, 2];
					fluxo_piv[a, 3] = ativos[a, 3];
					fluxo_piv[a, 4] = pagamento;
					fluxo_piv[a, 5] = despesa;
					fluxo_piv[a, 6] = encargo;
				END;

				create temp.ativos_fluxo_piv_tp&tipoCalculo._s&s. from fluxo_piv[colname={'id_participante' 'tCober' 'tFluxo' 'PagamentoPIV' 'DespesaPIV' 'DespesaVpPIV'}];
					append from fluxo_piv;
				close temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;

				free fluxo_piv ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.piv_ativos&a.;*/
/*			merge determin.piv_ativos&a. work.piv_deterministico_ativos;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format PagamentoPIV commax14.2 DespesaPIV commax14.2 DespesaVpPIV commax14.2 v_PIV 12.8 vt_PIV 12.8;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_piv_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;
			class tfluxo;
			var DespesaPIV DespesaVpPIV;
			format DespesaPIV commax18.2 DespesaVpPIV commax18.2;
			output out= work.ativos_despesa_piv_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_piv_tp&tipoCalculo._s&s.;
			if cmiss(tFluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_piv_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;
			class id_participante;
			var DespesaVpPIV;
			format DespesaVpPIV commax18.2;
			output out= work.ativos_encargo_piv_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_piv_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_piv_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_piv_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;

		proc delete data = temp.ativos_fluxo_piv_tp&tipoCalculo._s&s. (gennum=all);
		run;
	%end;
%mend;
%calculaFluxoPiv;

proc datasets library=temp kill memtype=data nolist;
proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*
%_eg_conditional_dropds(determin.piv_ativos);
data determin.piv_ativos;
	set determin.piv_ativos1 - determin.piv_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete piv_ativos1 - piv_ativos&numberOfBlocksAtivos;
run;
*/



/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete piv_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/