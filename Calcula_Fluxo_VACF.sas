

%macro calculaFluxoVacf;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.);

		proc iml;
			USE cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t ConParSdoEvol ConPatSdoEvol SalConPrjEvol} into ativos;
			CLOSE cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {pxs apxa taxa_risco_partic taxa_risco_patroc} into fatores;
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
					read all var {vivo valido ligado ativo} into fatores_estoc;
				close cobertur.ativos_fatores_estoc_s&s.;
			end;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxo_vacf = J(qtsObs, 10, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					t_cober = ativos[a, 2];
					contribuicao_partic = ativos[a, 3];
					contribuicao_patroc = ativos[a, 4];
					salario_contribuicao = ativos[a, 5];

					pxs = fatores[a, 1];
					apxa = fatores[a, 2];
					taxa_risco_partic = fatores[a, 3];
					taxa_risco_patroc = fatores[a, 4];

					taxa_juros_cober = taxas_juros[t_cober + 1];

					if (&tipoCalculo = 2) then do;
						vivo = fatores_estoc[a, 1];
						valido = fatores_estoc[a, 2];
						ligado = fatores_estoc[a, 3];
						ativo = fatores_estoc[a, 4];
					end;

					receitaParticipanteProgramada = 0;
					receitaParticipanteRisco = 0;
					receitaPatrocinadoraProgramada = 0;
					receitaPatrocinadoraRisco = 0;
					vacfParticipanteProgramada = 0;
					vacfParticipanteRisco = 0;
					vacfPatrocinadoraProgramada = 0;
					vacfPatrocinadoraRisco = 0;

					v = max(0, 1 / ((1 + taxa_juros_cober) ** t_cober));

					if (&CdPlanBen = 1) then do;
						receitaParticipanteProgramada = max(0, round(contribuicao_partic * (1 - &TxCarregamentoAdm), 0.01));
						vacfParticipanteProgramada = max(0, round(receitaParticipanteProgramada * v * &FtSalPart, 0.01));
						receitaPatrocinadoraProgramada = receitaParticipanteProgramada;
						vacfPatrocinadoraProgramada = vacfParticipanteProgramada;
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						receitaParticipanteProgramada = contribuicao_partic;

						if (&tipoCalculo = 2) then
							receitaParticipanteProgramada = receitaParticipanteProgramada * vivo * valido * ligado * ativo;

						if (&CdPlanBen = 4) then do;
							if (contribuicao_partic > 0) then do;
								if (&tipoCalculo = 1) then
									receitaParticipanteRisco = max(0, round((salario_contribuicao / &FtSalPart) * taxa_risco_partic * &NroBenAno * (1 - apxa) * pxs, 0.01));
								else
									receitaParticipanteRisco = max(0, round((salario_contribuicao / &FtSalPart) * taxa_risco_partic * &NroBenAno * vivo * valido * ligado * ativo, 0.01));
							end;
						end;

						vacfParticipanteProgramada = max(0, round(receitaParticipanteProgramada * v * &FtSalPart, 0.01));
						vacfParticipanteRisco = max(0, round(receitaParticipanteRisco * v * &FtSalPart, 0.01));

						receitaPatrocinadoraProgramada = contribuicao_patroc;

						if (&tipoCalculo = 2) then
							receitaPatrocinadoraProgramada = receitaPatrocinadoraProgramada * vivo * valido * ligado * ativo;

						if (contribuicao_patroc > 0) then do;
							if (&tipoCalculo = 1) then
								receitaPatrocinadoraRisco = max(0, round((salario_contribuicao / &FtSalPart) * taxa_risco_patroc * &NroBenAno * (1 - apxa) * pxs, 0.01));
							else
								receitaPatrocinadoraRisco = max(0, round((salario_contribuicao / &FtSalPart) * taxa_risco_patroc * &NroBenAno * vivo * valido * ligado * ativo, 0.01));
						end;

						vacfPatrocinadoraProgramada = max(0, round(receitaPatrocinadoraProgramada * v * &FtSalPart, 0.01));
						vacfPatrocinadoraRisco = max(0, round(receitaPatrocinadoraRisco * v * &FtSalPart, 0.01));
					end;

					fluxo_vacf[a, 1] = ativos[a, 1];
					fluxo_vacf[a, 2] = ativos[a, 2];
					fluxo_vacf[a, 3] = receitaParticipanteProgramada;
					fluxo_vacf[a, 4] = receitaParticipanteRisco;
					fluxo_vacf[a, 5] = receitaPatrocinadoraProgramada;
					fluxo_vacf[a, 6] = receitaPatrocinadoraRisco;
					fluxo_vacf[a, 7] = vacfParticipanteProgramada;
					fluxo_vacf[a, 8] = vacfParticipanteRisco;
					fluxo_vacf[a, 9] = vacfPatrocinadoraProgramada;
					fluxo_vacf[a, 10] = vacfPatrocinadoraRisco;
				END;

				create temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s. from fluxo_vacf[colname={'id_participante' 't' 'ReceitaParticipanteProgramada' 'ReceitaParticipanteRisco' 'ReceitaPatrocinadoraProgramada' 'ReceitaPatrocinadoraRisco' 'VACFParticipanteProgramada' 'VACFParticipanteRisco' 'VACFPatrocinadoraProgramada' 'VACFPatrocinadoraRisco'}];
					append from fluxo_vacf;
				close temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;

				free fluxo_vacf ativos fatores fatores_estoc;
			end;
		quit;

/*		data determin.vacf_ativos;*/
/*			merge determin.vacf_ativos work.vacf_deterministico_ativos;*/
/*			by id_participante tCobertura;*/
/*			format ReceitaParticipanteProgramada commax14.2 ReceitaParticipanteRisco commax14.2 ReceitaPatrocinadoraProgramada commax14.2 ReceitaPatrocinadoraRisco commax14.2 VACFParticipanteProgramada commax14.2 VACFParticipanteRisco commax14.2 VACFPatrocinadoraProgramada commax14.2 VACFPatrocinadoraRisco commax14.2;*/
/*		run;*/

		%_eg_conditional_dropds(temp.ativos_receita_vacf_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;
			class t;
			var VACFParticipanteProgramada VACFParticipanteRisco VACFPatrocinadoraProgramada VACFPatrocinadoraRisco 
				 ReceitaParticipanteProgramada ReceitaParticipanteRisco ReceitaPatrocinadoraProgramada ReceitaPatrocinadoraRisco;
			output out= temp.ativos_receita_vacf_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s.);
		data fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s.;
			set temp.ativos_receita_vacf_tp&tipoCalculo._s&s.;
			if cmiss(t) then delete;
			drop _TYPE_ _FREQ_;
		run;

		%_eg_conditional_dropds(temp.ativos_encargo_vacf_tp&tipoCalculo._s&s.);
		proc summary data = temp.ativos_fluxo_vacf_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var VACFParticipanteProgramada VACFParticipanteRisco VACFPatrocinadoraProgramada VACFPatrocinadoraRisco;
		 output out= temp.ativos_encargo_vacf_tp&tipoCalculo._s&s. sum=;
		run;

		%_eg_conditional_dropds(fluxo.ativos_encargo_vacf_tp&tipoCalculo._s&s.);
		data fluxo.ativos_encargo_vacf_tp&tipoCalculo._s&s.;
			set temp.ativos_encargo_vacf_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calculaFluxoVacf;

proc datasets library=temp kill memtype=data nolist;
proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*%_eg_conditional_dropds(determin.vacf_ativos);*/
/*data determin.vacf_ativos;*/
/*	set determin.vacf_ativos1 - determin.vacf_ativos&numberOfBlocksAtivos;*/
/*run;*/

/*proc datasets nodetails library=determin;*/
/*   delete vacf_ativos1 - vacf_ativos&numberOfBlocksAtivos;*/
/*run;*/


/*%_eg_conditional_dropds(determin.receita_ativos);
proc summary data = determin.vacf_ativos;
 class tCobertura;
 var ReceitaParticipanteProgramada ReceitaParticipanteRisco ReceitaPatrocinadoraProgramada ReceitaPatrocinadoraRisco;
 output out=determin.receita_ativos sum=;
run;*/


/*
%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   delete vacf_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;
*/