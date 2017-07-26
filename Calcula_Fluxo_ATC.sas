*-- CÁLCULO DETERMINISTICO DO BENEFÍCIO DE APOSENTADORIA POR TEMPO DE CONTRIBUIÇÃO (ATC) DOS PARTICIPANTES ATIVOS --*;
*-- Versão: 01 de DEZEMBRO de 2016                                                                                --*;

options noquotelenmax;

%macro calculaFluxoAtc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t tFluxo BenLiqCobAtc BenTotCobAtc VlSdoConPartEvol VlSdoConPatrEvol PrbCasado} into ativos;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {px apx axcb ajxcb ajxx Ax pxs} into fatores;
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
			qtdFatores = nrow(fatores);

			if (qtsObs > 0 & qtdFatores > 0 & (qtsObs = qtdFatores)) then do;
				fluxo_atc = J(qtsObs, 7, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					t_fluxo = ativos[a, 3];
					beneficio_liquido_atc = ativos[a, 4];
					beneficio_total_atc = ativos[a, 5];
					saldo_conta_total = round(ativos[a, 6] + ativos[a, 7], 0.01);
					probab_casado = ativos[a, 8];

					px = fatores[a, 1];
					apx = fatores[a, 2];
					axcb = fatores[a, 3];
					ajxcb = fatores[a, 4];
					ajxx = fatores[a, 5];
					ax = fatores[a, 6];
/*					taxa_juros_cobert = fatores[a, 8];*/
/*					taxa_juros_fluxo = fatores[a, 9];*/

					taxa_juros_cobert = taxas_juros[t_cober + 1];
					taxa_juros_fluxo = taxas_juros[t_fluxo + 1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs = 1;
						else
							pxs = fatores[a, 7];
					end;
					else do;
						pxs = 1;
						px = fatores_estoc[a, 1];
						apx = fatores_estoc[a, 2] * fatores_estoc[a, 1] * fatores_estoc[a, 3] * fatores_estoc[a, 4];
					end;

					despesaBUA = 0;
					despesaVP = 0;
					v = 0;
					vt = 0;
					
					if (t_cober = t_fluxo) then do;
						tvt = 0;
						pagamento = max(0, round((beneficio_liquido_atc / &FtBenEnti) * apx * &NroBenAno, 0.01));

						if (&CdPlanBen = 2) then do;
							despesaBUA = max(0, round(((beneficio_total_atc * (axcb + &CtFamPens * probab_casado * (ajxcb - ajxx)) * &NroBenAno) + ((beneficio_total_atc / &FtBenEnti) * (ax * &peculioMorteAssistido))) * apx * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							despesaBUA = max(0, round(saldo_conta_total * apx * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else do;
						pagamento = round(max(0, pagamento * (1 + &PrTxBenef)), 0.01);
					end;

					despesa = round(max(0, ((pagamento + despesaBUA) * px * pxs), 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cobert) ** t_cober));
					vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** tvt));

					if (t_cober = t_fluxo & &tipoCalculo = 1) then
						despesaVP = max(0, round(((pagamento * px * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti)) * pxs * v + despesaBUA * v * pxs, 0.01));
					else
						despesaVP = max(0, round(pagamento * px * vt * pxs * v * &FtBenEnti, 0.01));

					tvt = tvt + 1;

					fluxo_atc[a, 1] = ativos[a, 1];
					fluxo_atc[a, 2] = t_cober;
					fluxo_atc[a, 3] = t_fluxo;
					fluxo_atc[a, 4] = pagamento;
					fluxo_atc[a, 5] = despesaBUA;
					fluxo_atc[a, 6] = despesa;
					fluxo_atc[a, 7] = despesaVP;
				END;

				create temp.ativos_fluxo_atc_tp&tipoCalculo._s&s. from fluxo_atc[colname={'id_participante' 'tCober' 'tFluxo' 'PagamentoATC' 'PagamentoBuaATC' 'DespesaATC' 'DespesaVpATC'}];
					append from fluxo_atc;
				close temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;

				free ativos fatores fatores_estoc fluxo_atc;
			end;
		quit;

		/*data temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			*merge fluxo.ativos_tp&tipoCalculo._s&s. temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			*by id_participante t tFluxo;
			set temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			*format PagamentoATC commax14.2 PagamentoBuaATC commax14.2 DespesaATC commax14.2 DespesaVpATC commax14.2 v_ATC 12.8 vt_ATC 12.8;
			format PagamentoATC commax14.2 PagamentoBuaATC commax14.2 DespesaATC commax14.2 DespesaVpATC commax14.2;
		run;*/

		%_eg_conditional_dropds(work.ativos_despesa_atc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			class tFluxo;
			var DespesaATC DespesaVpATC;
			format DespesaATC commax18.2 DespesaVpATC commax18.2;
			output out= work.ativos_despesa_atc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s.;
			set work.ativos_despesa_atc_tp&tipoCalculo._s&s.;
			if cmiss(tFluxo) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_atc_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var DespesaVpATC;
		 format DespesaVpATC commax18.2;
		 output out= work.ativos_encargo_atc_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_atc_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_atc_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_atc_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;

		proc delete data = temp.ativos_fluxo_atc_tp&tipoCalculo._s&s. (gennum=all);
		run;

/*		proc datasets nodetails library=temp;*/
/*		   delete ativos_fluxo_atc_tp&tipoCalculo._s&s.;*/
/*		run;*/
	%end;
%mend;
%calculaFluxoAtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*
%_eg_conditional_dropds(determin.atc_ativos);
data determin.atc_ativos;
	set determin.atc_ativos1 - determin.atc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete atc_ativos1 - atc_ativos&numberOfBlocksAtivos;
run;
*/

/*
%_eg_conditional_dropds(determin.atc_despesa_ativos);
proc summary data = determin.atc_ativos;
 class tDeterministico;
 var DespesaATC DespesaVpATC;
 output out=determin.atc_despesa_ativos sum=;
run;

%_eg_conditional_dropds(work.atc_despesa_deter_ativos)
proc sql;
	create table work.atc_despesa_deter_ativos as
	select t1.tCobertura, t1.tDeterministico, sum(DespesaATC) format=commax18.2 as DespesaATC
	from determin.atc_ativos t1
	group by t1.tDeterministico, t1.tCobertura
	order by t1.tCobertura, t1.tDeterministico;
run;
*/

/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   delete atc_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/