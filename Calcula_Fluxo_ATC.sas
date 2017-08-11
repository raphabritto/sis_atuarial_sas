*-- CÁLCULO DETERMINISTICO DO BENEFÍCIO DE APOSENTADORIA POR TEMPO DE CONTRIBUIÇÃO (ATC) DOS PARTICIPANTES ATIVOS --*;
*-- Versão: 01 de DEZEMBRO de 2016                                                                                --*;

options noquotelenmax;

%macro calculaFluxoAtc;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.);

		proc iml symsize=68719476736 worksize=68719476736;
			USE fluxo.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {t2} into t2;
				read all var {beneficio_liquido_atc} into beneficio_liquido_atc;
				read all var {beneficio_total_atc} into beneficio_total_atc;
				read all var {saldo_conta_partic} into saldo_conta_partic;
				read all var {saldo_conta_patroc} into saldo_conta_patroc;
				read all var {probab_casado} into probab_casado;
			CLOSE fluxo.ativos_tp&tipoCalculo._s&s.;

			use fluxo.ativos_fatores;
				read all var {px} into px;
				read all var {apx} into apx;
				read all var {axcb} into axcb;
				read all var {ajxcb} into ajxcb;
				read all var {ajxx} into ajxx;
				read all var {Ax} into ax;
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
					read all var {vivo} into vivo;
					read all var {aposentado} into aposentado;
					read all var {valido} into valido;
					read all var {ligado} into ligado;
				close fluxo.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				pagamento_atc = J(qtd_ativos, 1, 0);
				despesa_bua_atc = J(qtd_ativos, 1, 0);
				despesa_atc = J(qtd_ativos, 1, 0);
				despesa_vp_atc = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					saldo_conta_total = max(0, round(saldo_conta_partic[a] + saldo_conta_patroc[a], 0.01));

					taxa_juros_cobert = taxas_juros[t1[a] + 1];
					taxa_juros_fluxo = taxas_juros[t2[a] + 1];

					if (&tipoCalculo = 1) then do;
						if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
							pxs[a] = 1;
					end;
					else do;
						pxs[a] = 1;
						px[a] = vivo[a];
						apx[a] = aposentado[a] * vivo[a] * valido[a] * ligado[a];
					end;

					v = 0;
					vt = 0;
					
					if (t1[a] = t2[a]) then do;
						tvt = 0;
						pagamento_atc[a] = max(0, round((beneficio_liquido_atc[a] / &FtBenEnti) * apx[a] * &NroBenAno, 0.01));

						if (&CdPlanBen = 2) then do;
							despesa_bua_atc[a] = max(0, round(((beneficio_total_atc[a] * (axcb[a] + &CtFamPens * probab_casado[a] * (ajxcb[a] - ajxx[a])) * &NroBenAno) + ((beneficio_total_atc[a] / &FtBenEnti) * (ax[a] * &peculioMorteAssistido))) * apx[a] * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							despesa_bua_atc[a] = max(0, round(saldo_conta_total * apx[a] * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else do;
						pagamento_atc[a] = max(0, round(pagamento_atc[a - 1] * (1 + &PrTxBenef), 0.01));
					end;

					despesa_atc[a] = max(0, round(((pagamento_atc[a] + despesa_bua_atc[a]) * px[a] * pxs[a]), 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cobert) ** t1[a]));
					vt = max(0, 1 / ((1 + taxa_juros_fluxo) ** tvt));

					if (t1[a] = t2[a] & &tipoCalculo = 1) then
						despesa_vp_atc[a] = max(0, round(((pagamento_atc[a] * px[a] * vt * &FtBenEnti) - (&Fb * pagamento_atc[a] * &FtBenEnti)) * pxs[a] * v + despesa_bua_atc[a] * v * pxs[a], 0.01));
					else
						despesa_vp_atc[a] = max(0, round(pagamento_atc[a] * px[a] * vt * pxs[a] * v * &FtBenEnti, 0.01));

					tvt = tvt + 1;
				END;

				create temp.ativos_fluxo_atc_tp&tipoCalculo._s&s. var {id_participante t1 t2 pagamento_atc despesa_bua_atc despesa_atc despesa_vp_atc};
					append;
				close temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(work.ativos_despesa_atc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
				class t2;
				var despesa_atc despesa_vp_atc;
				format despesa_atc commax18.2 despesa_vp_atc commax18.2;
				output out= work.ativos_despesa_atc_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s.);
			data fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s.;
				set work.ativos_despesa_atc_tp&tipoCalculo._s&s.;
				if cmiss(t2) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_atc_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_atc_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var despesa_vp_atc;
			 format despesa_vp_atc commax18.2;
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
		%end;
	%end;
%mend;
%calculaFluxoAtc;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
