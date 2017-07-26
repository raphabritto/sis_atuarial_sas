*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;


%macro calculaFluxoPpa;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobPPA BenTotCobPPA AplicarPxsPPA PrbCasado} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {pjx pxs qx apxa ajxcb} into fatores;
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
					read all var {morto aposentadoria valido ativo ligado} into fatores_estoc;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_ppa = J(qtsObs, 7, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_ppa = ativos[a, 4];
					beneficio_total_ppa = ativos[a, 5];
					AplicarPxsPPA = ativos[a, 6];
					probab_casado = ativos[a, 7];

					pjx = fatores[a, 1];
					qx = fatores[a, 3];
					apxa = fatores[a, 4];
					ajxcb = fatores[a, 5];
/*					taxa_juros_cober = fatores[a, 6];*/
/*					taxa_juros_fluxo = fatores[a, 7];*/

					taxa_juros_cober = taxas_juros[t_cober + 1];
					taxa_juros_fluxo = taxas_juros[t_fluxo + 1];

					if (&tipoCalculo = 1) then do;
						if (AplicarPxsPPA = 0) then 
							pxs = 1;
						else
							pxs = fatores[a, 2];
					end;
					else do;
						pxs = 1;
						qx = fatores_estoc[a, 1] * fatores_estoc[a, 3] * fatores_estoc[a, 4] * fatores_estoc[a, 5];
						apxa = fatores_estoc[a, 2];
					end;

					descontoPpaBUA = 0;

					if (t_cober = t_fluxo) then do;
						tvt = 0;
						pagamento = max(0, round((beneficio_liquido_ppa / &FtBenEnti) * qx * &NroBenAno * probab_casado * (1 - apxa), 0.01));

						if (&CdPlanBen ^= 1) then do;
							descontoPpaBUA = max(0, round((beneficio_total_ppa * ajxcb * &NroBenAno) * qx * (1 - apxa) * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else
						pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = max(0, round((pagamento + descontoPpaBUA) * pjx * pxs, 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));
					vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** tvt));

					if (t_cober = t_fluxo & &tipoCalculo = 1) then do;
						encargo = max(0 , round(((pagamento * pjx * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti) + descontoPpaBUA) * pxs * v, 0.01));
					end;
					else do;
						encargo = max(0 , round(pagamento * &FtBenEnti * pjx * vt * pxs * v, 0.01));
					end;

					tvt = tvt + 1;

					fluxo_ppa[a, 1] = ativos[a, 1];
					fluxo_ppa[a, 2] = ativos[a, 2];
					fluxo_ppa[a, 3] = ativos[a, 3];
					fluxo_ppa[a, 4] = pagamento;
					fluxo_ppa[a, 5] = descontoPpaBUA;
					fluxo_ppa[a, 6] = despesa;
					fluxo_ppa[a, 7] = encargo;
				END;

				create temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s. from fluxo_ppa[colname={'id_participante' 'tCober' 'tFluxo' 'PagamentoPPA' 'DescontoBuaPPA' 'DespesaPPA' 'DespesaVpPPA'}];
					append from fluxo_ppa;
				close temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s.;

				free fluxo_ppa ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.ppa_ativos&a.;*/
/*			merge determin.ppa_ativos&a. work.ppa_deterministico_ativos;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format PagamentoPPA COMMAX14.2 DescontoBuaPPA COMMAX14.2 DespesaPPA COMMAX14.2 DespesaVpPPA COMMAX14.2 v_PPA 12.8 vt_PPA 12.8;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_ppa_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s.;
		 class tFluxo;
		 var DespesaPPA DespesaVpPPA;
		 format DespesaPPA commax18.2 DespesaVpPPA commax18.2;
		 output out= work.ativos_despesa_ppa_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_ppa_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_ppa_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_ppa_tp&tipoCalculo._s&s.;
			if cmiss(tFluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_ppa_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var DespesaVpPPA;
		 format DespesaVpPPA commax18.2;
		 output out= work.ativos_encargo_ppa_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_ppa_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_ppa_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_ppa_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;

		proc delete data = temp.ativos_fluxo_ppa_tp&tipoCalculo._s&s. (gennum=all);
		run;
	%end;
%mend;
%calculaFluxoPpa;

proc datasets library=temp kill memtype=data nolist;
proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*
%_eg_conditional_dropds(determin.ppa_ativos);
data determin.ppa_ativos;
	set determin.ppa_ativos1 - determin.ppa_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete ppa_ativos1 - ppa_ativos&numberOfBlocksAtivos;
run;
*/

/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete ppa_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/