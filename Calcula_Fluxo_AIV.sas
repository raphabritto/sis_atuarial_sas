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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {beneficio_liquido_aiv} into beneficio_liquido_aiv;
				read all var {beneficio_total_aiv} into beneficio_total_aiv;
				read all var {probab_casado} into probab_casado;
				read all var {aplica_pxs_aiv} into aplica_pxs_aiv;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {pxii} into pxii;
				read all var {pxs} into pxs;
				read all var {ix} into ix;
				read all var {apxa} into apxa;
				read all var {axiicb} into axiicb;
				read all var {ajxcb} into ajxcb;
				read all var {ajxx_i} into ajxx_i;
				read all var {Axii} into axii;
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
					read all var {vivo} into vivo;
					read all var {aposentado} into aposentado;
					read all var {invalido} into invalido;
					read all var {ativo} into ativo;
					read all var {ligado} into ligado;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				pagamento_aiv = J(qtd_ativos, 1, 0);
				despesa_bua_aiv = J(qtd_ativos, 1, 0);
				despesa_aiv = J(qtd_ativos, 1, 0);
				despesa_vp_aiv = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					taxa_juros_cob = taxas_juros[t1[a]+1];
					taxa_juros_det = taxas_juros[t2[a]+1];

					if (&tipoCalculo = 1) then do;
						if (aplica_pxs_aiv[a] = 0) then 
							pxs[a] = 1;
					end;
					else do;
						pxs[a] = 1;
						pxii[a] = vivo[a];
						apxa[a] = aposentado[a];
						ix[a] = invalido[a] * vivo[a] * ativo[a] * ligado[a];
					end;

					if (t1[a] = t2[a]) then do;
						tvt = 0;
						pagamento_aiv[a] = max(0, round((beneficio_liquido_aiv[a] / &FtBenEnti) * (1 - apxa[a]) * ix[a] * &NroBenAno, 0.01));

						if (&CdPlanBen ^= 1) then do;
							despesa_bua_aiv[a] = max(0, round(((beneficio_total_aiv[a] * (axiicb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx_i[a])) * &NroBenAno) + ((beneficio_total_aiv[a] / &FtBenEnti) * (axii[a] * &peculioMorteAssistido))) * (1 - apxa[a]) * ix[a] * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else
						pagamento_aiv[a] = max(0, round(pagamento_aiv[a-1] * (1 + &PrTxBenef), 0.01));

					despesa_aiv[a] = max(0, round((pagamento_aiv[a] + despesa_bua_aiv[a]) * pxii[a] * pxs[a], 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cob) ** t1[a]));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					if (t1[a] = t2[a] & &tipoCalculo = 1) then
						despesa_vp_aiv[a] = max(0, round(((pagamento_aiv[a] * pxii[a] * vt * &FtBenEnti) - (&Fb * pagamento_aiv[a] * &FtBenEnti) + despesa_bua_aiv[a]) * pxs[a] * v, 0.01));
					else
						despesa_vp_aiv[a] = max(0, round(pagamento_aiv[a] * pxii[a] * vt * pxs[a] * v * &FtBenEnti, 0.01));

					tvt = tvt + 1;
				END;

				create temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s. var {id_participante t1 t2 pagamento_aiv despesa_bua_aiv despesa_aiv despesa_vp_aiv} ;
					append;
				close temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_aiv_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;
				class t2;
				var despesa_aiv despesa_vp_aiv;
				format despesa_aiv commax18.2 despesa_vp_aiv commax18.2;
				output out= work.ativos_despesa_aiv_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_aiv_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_aiv_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_aiv_tp&tipoCalculo._s&s.;
				class id_participante;
				var despesa_vp_aiv;
				format despesa_vp_aiv commax18.2;
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
	%end;
%mend;
%calculaFluxoAiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;



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