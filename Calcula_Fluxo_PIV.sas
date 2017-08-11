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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {beneficio_liquido_piv} into beneficio_liquido_piv;
				read all var {aplica_pxs_piv} into aplica_pxs_piv;
				read all var {probab_casado} into probab_casado;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {pxii} into pxii;
				read all var {pjx} into pjx;
				read all var {pxs} into pxs;
				read all var {ix} into ix;
				read all var {apxa} into apxa;
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
			 	pagamento_piv = J(qtd_ativos, 1, 0);
				despesa_piv = J(qtd_ativos, 1, 0);
				despesa_vp_piv = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					taxa_juros_cober = taxas_juros[t1[a]+1];
					taxa_juros_fluxo = taxas_juros[t2[a]+1];

					if (&tipoCalculo = 1) then do;
						if (aplica_pxs_piv[a] = 0) then 
							pxs[a] = 1;
					end;
					else do;
						pxs[a] = 1;
						pxii[a] = vivo[a];
						apxa[a] = aposentado[a];
						ix[a] = invalido[a] * vivo[a] * ativo[a] * ligado[a];
					end;

					if (t1[a] = t2[a]) then do;
						pagamento_piv[a] = max(0, round((beneficio_liquido_piv[a] / &FtBenEnti) * (1 - apxa[a]) * ix[a] * &NroBenAno * probab_casado[a], 0.01));
						tvt = 0;
					end;
					else
						pagamento_piv[a] = max(0, round(pagamento_piv[a-1] * (1 + &PrTxBenef), 0.01));

					despesa_piv[a] = max(0, round(pagamento_piv[a] * (pjx[a] - pxii[a] * pjx[a]) * pxs[a], 0.01));

					v = 1 / ((1 + taxa_juros_cober) ** t1[a]);
					vt = 1 / ((1 + taxa_juros_fluxo) ** tvt);

					despesa_vp_piv[a] = max(0, round(pagamento_piv[a] * &FtBenEnti * (pjx[a] - pxii[a] * pjx[a]) * vt * pxs[a] * v, 0.01));

					tvt = tvt + 1;
				END;

				create temp.ativos_fluxo_piv_tp&tipoCalculo._s&s. var {id_participante t1 t2 pagamento_piv despesa_piv despesa_vp_piv};
					append;
				close temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_piv_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;
				class t2;
				var despesa_piv despesa_vp_piv;
				format despesa_piv commax18.2 despesa_vp_piv commax18.2;
				output out= work.ativos_despesa_piv_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_piv_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_piv_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_piv_tp&tipoCalculo._s&s.;
				class id_participante;
				var despesa_vp_piv;
				format despesa_vp_piv commax18.2;
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
	%end;
%mend;
%calculaFluxoPiv;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
