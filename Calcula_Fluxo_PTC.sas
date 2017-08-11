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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {probab_casado} into probab_casado;
				read all var {beneficio_liquido_ptc} into beneficio_liquido_ptc;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {px} into px;
				read all var {pjx} into pjx;
				read all var {pxs} into pxs;
				read all var {apx} into apx;
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
					read all var {valido} into valido;
					read all var {ligado} into ligado;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				pagamento_ptc = J(qtd_ativos, 1, 0);
				despesa_ptc = J(qtd_ativos, 1, 0);
				despesa_vp_ptc = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					taxa_juros_cober = taxas_juros[t1[a]+1];
					taxa_juros_fluxo = taxas_juros[t2[a]+1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs[a] = 1;
					end;
					else do;
						px[a] = vivo[a];
						apx[a] = aposentado[a] * vivo[a] * valido[a] * ligado[a];
						pxs[a] = 1;
					end;
					
					if (t1[a] = t2[a]) then do;
						tvt = 0;
						pagamento_ptc[a] = max(0, round((beneficio_liquido_ptc[a] / &FtBenEnti) * apx[a] * &NroBenAno * probab_casado[a], 0.01));
					end;
					else
						pagamento_ptc[a] = max(0, round(pagamento_ptc[a-1] * (1 + &PrTxBenef), 0.01));

					despesa_ptc[a] = max(0, round(pagamento_ptc[a] * (pjx[a] - px[a] * pjx[a]) * pxs[a], 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cober) ** t1[a]));
					vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** tvt));

					despesa_vp_ptc[a] = max(0, round(pagamento_ptc[a] * (pjx[a] - px[a] * pjx[a]) * vt * pxs[a] * v * &FtBenEnti, 0.01));

					tvt = tvt + 1;
				END;

				create temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s. var {id_participante t1 t2 pagamento_ptc despesa_ptc despesa_vp_ptc};
					append;
				close temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_ptc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;
			 class t2;
			 var despesa_ptc despesa_vp_ptc;
			 format despesa_ptc commax18.2 despesa_vp_ptc commax18.2;
			 output out= work.ativos_despesa_ptc_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_ptc_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_ptc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_ptc_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var despesa_vp_ptc;
			 format despesa_vp_ptc commax18.2;
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
	%end;
%mend;
%calculaFluxoPtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
