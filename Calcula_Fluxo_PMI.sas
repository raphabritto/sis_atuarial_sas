

%macro calculaFluxoPmi;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.);

		proc iml;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {beneficio_liquido_aiv} into beneficio_liquido_aiv;
				read all var {aplica_pxs_aiv} into aplica_pxs_aiv;
				read all var {flg_manutencao_saldo} into is_manut_saldo;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {dxii} into dxii;
				read all var {ix} into ix;
				read all var {apxa} into apxa;
				read all var {lxii} into lxii;
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
					read all var {invalido} into invalido;
					read all var {vivo} into vivo;
					read all var {ativo} into ativo;
					read all var {ligado} into ligado;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				beneficio_pmi = J(qtd_ativos, 1, 0);
				pagamento_pmi = J(qtd_ativos, 1, 0);
				despesa_pmi = J(qtd_ativos, 1, 0);
				despesa_vp_pmi = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					taxa_juros_cober = taxas_juros[t1[a] + 1];
					taxa_juros_fluxo = taxas_juros[t2[a] + 1];

					if (&tipoCalculo = 1) then do;
						if (aplica_pxs_aiv[a] = 0) then 
							pxs[a] = 1;
					end;
					else do;
						pxs[a] = 1;
						apxa[a] = aposentado[a];
						ix[a] = invalido[a] * vivo[a] * ativo[a] * ligado[a];
					end;
					
					v = 0;
					vt = 0;
					vt_dxii = 0;

					if (&CdPlanBen ^= 1) then do;
						if (t1[a] = t2[a]) then do;
							t_vt = 0;
							beneficio_pmi[a] = max(0, round((beneficio_liquido_aiv[a] / &FtBenEnti) * &peculioMorteAssistido, 0.01));

							if (is_manut_saldo[a] = 0 & beneficio_pmi[a] > 0) then 
								beneficio_pmi[a] = max(beneficio_pmi[a], &LimPecMin);

							pagamento_pmi[a] = max(0, round(beneficio_pmi[a] * ix[a] * (1 - apxa[a]), 0.01));
						end;
						else do;
							pagamento_pmi[a] = max(0, round(pagamento_pmi[a - 1] * (1 + &PrTxBenef), 0.01));
						end;

						vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** (t_vt + 1)));
						vt_dxii = max(0, vt * dxii[a]);

						if (&tipoCalculo = 1) then do;
							if (lxii[a] > 0) then 
								despesa_pmi[a] = max(0, round(pagamento_pmi[a] * vt_dxii / lxii[a], 0.01));
						end;
						else
							despesa_pmi[a] = max(0, round(pagamento_pmi[a] * qx[a], 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cober) ** t1[a]));
						despesa_vp_pmi[a] = max(0, round(despesa_pmi[a] * pxs[a] * v, 0.01));

						t_vt = t_vt + 1;
					end;
				END;

				create temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s. var {id_participante t1 t2 beneficio_pmi pagamento_pmi despesa_pmi despesa_vp_pmi};
					append;
				close temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_pmi_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;
			 class t2;
			 var despesa_pmi despesa_vp_pmi;
			 format despesa_pmi commax18.2 despesa_vp_pmi commax18.2;
			 output out= work.ativos_despesa_pmi_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_pmi_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_pmi_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var despesa_vp_pmi;
			 format despesa_vp_pmi commax18.2;
			 output out= work.ativos_encargo_pmi_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_encargo_pmi_tp&tipoCalculo._s&s.);
			data fluxo.ativos_encargo_pmi_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_pmi_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;
		%end;
	%end;
%mend;
%calculaFluxoPmi;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
