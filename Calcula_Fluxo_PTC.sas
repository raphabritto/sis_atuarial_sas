*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro calculaFluxoPtc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo PrbCasado BenLiqCobPtc} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {px pjx pxs apx} into fatores;
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
					read all var {vivo aposentadoria valido ligado} into fatores_estoc;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_ptc = J(qtsObs, 6, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					probab_casado = ativos[a, 4];
					beneficio_liquido_ptc = ativos[a, 5];

					px	= fatores[a, 1];
					pjx	= fatores[a, 2];
					apx	= fatores[a, 4];
/*					taxa_juros_cober = fatores[a, 5];*/
/*					taxa_juros_fluxo = fatores[a, 6];*/

					taxa_juros_cober = taxas_juros[t_cober+1];
					taxa_juros_fluxo = taxas_juros[t_fluxo+1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs = 1;
						else
							pxs = fatores[a, 3];
					end;
					else do;
						px 	= fatores_estoc[a, 1];
						apx = fatores_estoc[a, 2] * fatores_estoc[a, 1] * fatores_estoc[a, 3] * fatores_estoc[a, 4];
						pxs = 1;
					end;
					
					if (t_cober = t_fluxo) then do;
						tvt = 0;
						pagamento = max(0, (beneficio_liquido_ptc / &FtBenEnti) * apx * &NroBenAno * probab_casado);
					end;
					else
						pagamento = max(0, pagamento * (1 + &PrTxBenef));

					despesa = max(0, pagamento * (pjx - px* pjx) * pxs);

					v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));
					vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** tvt));

					encargo = max(0, pagamento * (pjx - px* pjx) * vt * pxs * v * &FtBenEnti);

					tvt = tvt + 1;

					fluxo_ptc[a, 1] = ativos[a, 1];
					fluxo_ptc[a, 2] = t_cober;
					fluxo_ptc[a, 3] = t_fluxo;
					fluxo_ptc[a, 4] = pagamento;
					fluxo_ptc[a, 5] = despesa;
					fluxo_ptc[a, 6] = encargo;
				END;

				create temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s. from fluxo_ptc[colname={'id_participante' 'tCober' 'tFluxo' 'PagamentoPTC' 'DespesaPTC' 'DespesaVpPTC'}];
					append from fluxo_ptc;
				close temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;

				free ativos fatores fluxo_ptc fatores_estoc;
			end;
		quit;

/*		data temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;*/
/*			set temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;*/
/*			*by id_participante tCobertura tDeterministico;*/
/*			*format PagamentoPTC commax14.2 DespesaPTC commax14.2 DespesaVpPTC commax14.2 v_PTC 12.8 vt_PTC 12.8;*/
/*			format PagamentoPTC commax14.2 DespesaPTC commax14.2 DespesaVpPTC commax14.2;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_ptc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;
		 class tFluxo;
		 var DespesaPTC DespesaVpPTC;
		 format DespesaPTC commax18.2 DespesaVpPTC commax18.2;
		 output out= work.ativos_despesa_ptc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_ptc_tp&tipoCalculo._s&s.;
			if cmiss(tFluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_ptc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var DespesaVpPTC;
		 format DespesaVpPTC commax18.2;
		 output out= work.ativos_encargo_ptc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_ptc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_ptc_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_ptc_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;

		proc delete data = temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s. (gennum=all);
		run;
	%end;
%mend;
%calculaFluxoPtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*
%_eg_conditional_dropds(determin.ptc_ativos);
data determin.ptc_ativos;
	set determin.ptc_ativos1 - determin.ptc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete ptc_ativos1 - ptc_ativos&numberOfBlocksAtivos;
run;
*/

/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   delete ptc_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/