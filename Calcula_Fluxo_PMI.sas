

%macro calculaFluxoPmi;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobAIV AplicarPxsAIV flg_manutencao_saldo} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {dxii ix apxa lxii pxs} into fatores;
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
					read all var {aposentadoria morto invalido vivo ativo ligado} into fatores_estoc;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_pmi = J(qtsObs, 7, 0);
				pagamento = 0;

				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_aiv = ativos[a, 4];
					AplicarPxsAIV = ativos[a, 5];
					flg_manutencao_saldo = ativos[a, 6];

					dxii = fatores[a, 1];
					ix = fatores[a, 2];
					apxa = fatores[a, 3];
					lxii = fatores[a, 4];
/*					taxa_juros_cober = fatores[a, 6];*/
/*					taxa_juros_fluxo = fatores[a, 7];*/

					taxa_juros_cober = taxas_juros[t_cober + 1];
					taxa_juros_fluxo = taxas_juros[t_fluxo + 1];

					if (&tipoCalculo = 1) then do;
						if (AplicarPxsAIV = 0) then 
							pxs = 1;
						else
							pxs = fatores[a, 5];
					end;
					else do;
						pxs = 1;
						apxa = fatores_estoc[a, 1];
						qx = fatores_estoc[a, 2];
						ix = fatores_estoc[a, 3] * fatores_estoc[a, 4] * fatores_estoc[a, 5] * fatores_estoc[a, 6];
					end;

					beneficio = 0;
					despesa = 0;
					despesaVP = 0;
					v = 0;
					vt = 0;
					vt_dxii = 0;

					if (&CdPlanBen ^= 1) then do;
						if (t_cober = t_fluxo) then do;
							t_vt = 0;
							beneficio = max(0, round((beneficio_liquido_aiv / &FtBenEnti) * &peculioMorteAssistido, 0.01));

							if (flg_manutencao_saldo = 0 & beneficio > 0) then 
								beneficio = max(beneficio, &LimPecMin);

							pagamento = max(0, beneficio * ix * (1 - apxa));
						end;
						else do;
							pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));
						end;

						vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** (t_vt + 1)));
						vt_dxii = max(0, vt * dxii);

						if (&tipoCalculo = 1) then do;
							if (lxii > 0) then 
								despesa = max(0, round(pagamento * vt_dxii / lxii, 0.01));
						end;
						else
							despesa = max(0, round(pagamento * qx, 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));
						despesaVP = max(0, round(despesa * pxs * v, 0.01));

						t_vt = t_vt + 1;
					end;

					fluxo_pmi[a, 1] = ativos[a, 1];
					fluxo_pmi[a, 2] = ativos[a, 2];
					fluxo_pmi[a, 3] = ativos[a, 3];
					fluxo_pmi[a, 4] = beneficio;
					fluxo_pmi[a, 5] = pagamento;
					fluxo_pmi[a, 6] = despesa;
					fluxo_pmi[a, 7] = despesaVP;
				END;

				create temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s. from fluxo_pmi[colname={'id_participante' 'tCober' 'tFluxo' 'BeneficioPMI' 'PagamentoPMI' 'DespesaPMI' 'DespesaVpPMI'}];
					append from fluxo_pmi;
				close temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;

				free fluxo_pmi ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.pmi_ativos&a.;*/
/*			merge determin.pmi_ativos&a. work.ativos_resultado_pmi;*/
/*			by id_participante tCobertura tDeterministico;*/
/*			format BeneficioPMI commax14.2 PagamentoPMI commax14.2 DespesaPMI commax14.2 DespesaVpPMI commax14.2 v 10.8 vt_dxii commax14.2;*/
/*		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_pmi_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;
		 class tFluxo;
		 var DespesaPMI DespesaVpPMI;
		 output out= work.ativos_despesa_pmi_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_pmi_tp&tipoCalculo._s&s.;
			if cmiss(tfluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_pmi_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var DespesaVpPMI;
		 output out= work.ativos_encargo_pmi_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_pmi_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_pmi_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_pmi_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calculaFluxoPmi;

proc datasets library=work kill memtype=data nolist;
	run;
quit;


/*
%_eg_conditional_dropds(determin.pmi_ativos);
data determin.pmi_ativos;
	set determin.pmi_ativos1 - determin.pmi_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete pmi_ativos1 - pmi_ativos&numberOfBlocksAtivos;
run;
*/


/*%macro gravaMemoriaCalculo;*/
/*	%if (&isGravaMemoriaCalculo = 0) %then %do;*/
/*		proc datasets nodetails library=determin;*/
/*			*/
/*		run;*/
/*	%end;*/
/*%mend;*/
/*%gravaMemoriaCalculo;*/