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
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {beneficio_liquido_atc} into beneficio_liquido_atc;
				read all var {flg_manutencao_saldo} into is_manut_saldo;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {dx} into dx;
				read all var {lx} into lx;
				read all var {apx} into apx;
				read all var {pxs} into pxs;
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
					read all var {aposentado} into aposentado;
					read all var {morto} into qx;
					read all var {vivo} into vivo;
					read all var {valido} into valido;
					read all var {ligado} into ligado;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_pmc = J(qtd_ativos, 1, 0);
				pagamento_pmc = J(qtd_ativos, 1, 0);
				despesa_pmc = J(qtd_ativos, 1, 0);
				despesa_vp_pmc = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					taxa_juros_cober = taxas_juros[t1[a] + 1];
					taxa_juros_fluxo = taxas_juros[t2[a] + 1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs[a] = 1;
					end;
					else do;
						pxs[a] = 1;
						apx[a] = aposentado[a] * vivo[a] * valido[a] * ligado[a];
					end;

					v = 0;
					vt = 0;
					vt_dx = 0;

					if (&CdPlanBen ^= 1) then do;
						if (t1[a] = t2[a]) then do;
							t_vt = 0;
						
							beneficio_pmc[a] = max(0, round((beneficio_liquido_atc[a] / &FtBenEnti) * &peculioMorteAssistido, 0.01));
							
							if (is_manut_saldo[a] = 0 & beneficio_pmc[a] > 0) then 
								beneficio_pmc[a] = max(beneficio_pmc[a], &LimPecMin);

							pagamento_pmc[a] = max(0, round(beneficio_pmc[a] * apx[a], 0.01));
						end;
						else do;
							pagamento_pmc[a] = max(0, round(pagamento_pmc[a-1] * (1 + &PrTxBenef), 0.01));
						end;
						
						vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** (t_vt + 1)));
						vt_dx = max(0, vt * dx[a]);

						if (&tipoCalculo = 1) then do;
							if (lx[a] > 0) then
								despesa_pmc[a] = max(0, round(pagamento_pmc[a] * vt_dx / lx[a], 0.01));
						end;
						else
							despesa_pmc[a] = max(0, round(pagamento_pmc[a] * qx[a], 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t1[a]));
						despesa_vp_pmc[a] = max(0, round(despesa_pmc[a] * pxs[a] * v, 0.01));

						t_vt = t_vt + 1;
					end;
				END;

				create temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s. var {id_participante t1 t2 beneficio_pmc pagamento_pmc despesa_pmc despesa_vp_pmc};
					append;
				close temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;
			end;
		quit;
		
		%if (%sysfunc(exist(temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_pmc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;
				class t2;
				var despesa_pmc despesa_vp_pmc;
				format despesa_pmc commax18.2 despesa_vp_pmc commax18.2;
				output out= work.ativos_despesa_pmc_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_pmc_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_pmc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pmc_tp&tipoCalculo._s&s.;
				class id_participante;
				var despesa_vp_pmc;
				format despesa_vp_pmc commax18.2;
				output out= work.ativos_encargo_pmc_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_encargo_pmc_tp&tipoCalculo._s&s.);
			data fluxo.ativos_encargo_pmc_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_pmc_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;
		%end;
	%end;
%mend;
%calculaFluxoPmc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
