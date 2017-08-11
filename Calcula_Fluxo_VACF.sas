

%macro calculaFluxoVacf;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.);

		proc iml;
			USE cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {contribuicao_partic} into contribuicao_partic;
				read all var {contribuicao_patroc} into contribuicao_patroc;
				read all var {salario_contrib} into salario_contribuicao;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {pxs} into pxs;
				read all var {apxa} into apxa;
				read all var {taxa_risco_partic} into taxa_risco_partic;
				read all var {taxa_risco_patroc} into taxa_risco_patroc;
			close cobertur.ativos_fatores;

			if (&tipoCalculo = 1) then do;
				use premissa.taxa_juros;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros;
			end;
			else if (&tipoCalculo = 2) then do;
				use premissa.taxa_juros_s&s.;
					read all var {taxa_juros} into taxas_juros;
				close premissa.taxa_juros_s&s.;

				use cobertur.ativos_fatores_estoc_s&s.;
					read all var {vivo} into vivo;
					read all var {valido} into valido;
					read all var {ligado} into ligado;
					read all var {ativo} into ativo;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				receita_prog_partic = J(qtd_ativos, 1, 0);
				receita_risco_partic = J(qtd_ativos, 1, 0);
				receita_prog_patroc = J(qtd_ativos, 1, 0);
				receita_risco_patroc = J(qtd_ativos, 1, 0);
				vacf_prog_partic = J(qtd_ativos, 1, 0);
				vacf_risco_partic = J(qtd_ativos, 1, 0);
				vacf_prog_patroc = J(qtd_ativos, 1, 0);
				vacf_risco_patroc = J(qtd_ativos, 1, 0);
				
				DO a = 1 TO qtd_ativos;
					v = max(0, 1 / ((1 + taxas_juros[t1[a] + 1]) ** t1[a]));

					if (&CdPlanBen = 1) then do;
						receita_prog_partic[a] = max(0, round(contribuicao_partic[a] * (1 - &TxCarregamentoAdm), 0.01));
						vacf_prog_partic[a] = max(0, round(receita_prog_partic[a] * v * &FtSalPart, 0.01));

						if (&tipoCalculo = 2) then
							receita_prog_partic[a] = max(0, round(receita_prog_partic[a] * vivo[a] * valido[a] * ligado[a] * ativo[a], 0.01));

						receita_prog_patroc[a] = receita_prog_partic[a];
						vacf_prog_patroc[a] = vacf_prog_partic[a];
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						receita_prog_partic[a] = contribuicao_partic[a];

						if (&tipoCalculo = 2) then
							receita_prog_partic[a] = max(0, round(receita_prog_partic[a] * vivo[a] * valido[a] * ligado[a] * ativo[a], 0.01));

						if (&CdPlanBen = 4) then do;
							if (contribuicao_partic[a] > 0) then do;
								if (&tipoCalculo = 1) then
									receita_risco_partic[a] = max(0, round((salario_contribuicao[a] / &FtSalPart) * taxa_risco_partic[a] * &NroBenAno * (1 - apxa[a]) * pxs[a], 0.01));
								else
									receita_risco_partic[a] = max(0, round((salario_contribuicao[a] / &FtSalPart) * taxa_risco_partic[a] * &NroBenAno * vivo[a] * valido[a] * ligado[a] * ativo[a], 0.01));
							end;
						end;

						vacf_prog_partic[a] = max(0, round(receita_prog_partic[a] * v * &FtSalPart, 0.01));
						vacf_risco_partic[a] = max(0, round(receita_risco_partic[a] * v * &FtSalPart, 0.01));

						receita_prog_patroc[a] = contribuicao_patroc[a];

						if (&tipoCalculo = 2) then
							receita_prog_patroc[a] = max(0, round(receita_prog_patroc[a] * vivo[a] * valido[a] * ligado[a] * ativo[a], 0.01));

						if (contribuicao_patroc[a] > 0) then do;
							if (&tipoCalculo = 1) then
								receita_risco_patroc[a] = max(0, round((salario_contribuicao[a] / &FtSalPart) * taxa_risco_patroc[a] * &NroBenAno * (1 - apxa[a]) * pxs[a], 0.01));
							else
								receita_risco_patroc[a] = max(0, round((salario_contribuicao[a] / &FtSalPart) * taxa_risco_patroc[a] * &NroBenAno * vivo[a] * valido[a] * ligado[a] * ativo[a], 0.01));
						end;

						vacf_prog_patroc[a] = max(0, round(receita_prog_patroc[a] * v * &FtSalPart, 0.01));
						vacf_risco_patroc[a] = max(0, round(receita_risco_patroc[a] * v * &FtSalPart, 0.01));
					end;
				END;

				create temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s. var {id_participante t1 receita_prog_partic receita_risco_partic receita_prog_patroc receita_risco_patroc vacf_prog_partic vacf_risco_partic vacf_prog_patroc vacf_risco_patroc};
					append;
				close temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;
			end;
		quit;

		%if (%sysfunc(exist(temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.))) %then %do;
			%_eg_conditional_dropds(temp.ativos_receita_vacf_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;
				class t1;
				var vacf_prog_partic vacf_risco_partic vacf_prog_patroc vacf_risco_patroc 
					 receita_prog_partic receita_risco_partic receita_prog_patroc receita_risco_patroc;
				format vacf_prog_partic commax18.2 vacf_risco_partic commax18.2 vacf_prog_patroc commax18.2 vacf_risco_patroc commax18.2
					 receita_prog_partic commax18.2 receita_risco_partic commax18.2 receita_prog_patroc commax18.2 receita_risco_patroc commax18.2;
				output out= temp.ativos_receita_vacf_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s.);
			data fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s.;
				set temp.ativos_receita_vacf_tp&tipoCalculo._s&s.;
				if cmiss(t1) then delete;
				drop _TYPE_ _FREQ_;
			run;

			%_eg_conditional_dropds(temp.ativos_encargo_vacf_tp&tipoCalculo._s&s.);
			proc summary data = temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var vacf_prog_partic vacf_risco_partic vacf_prog_patroc vacf_risco_patroc;
			 format vacf_prog_partic commax18.2 vacf_risco_partic commax18.2 vacf_prog_patroc commax18.2 vacf_risco_patroc commax18.2;
			 output out= temp.ativos_encargo_vacf_tp&tipoCalculo._s&s. sum=;
			run;

			%_eg_conditional_dropds(fluxo.ativos_encargo_vacf_tp&tipoCalculo._s&s.);
			data fluxo.ativos_encargo_vacf_tp&tipoCalculo._s&s.;
				set temp.ativos_encargo_vacf_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;
		%end;
	%end;
%mend;
%calculaFluxoVacf;

proc datasets library=work kill memtype=data nolist;
	run;
quit;

