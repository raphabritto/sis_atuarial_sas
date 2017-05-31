
%_eg_conditional_dropds(determin.vacf_ativos);
proc sql;
	create table determin.vacf_ativos as
	select t1.id_participante,
			t3.t as tCobertura,
			t3.ConParSdoEvol,
			t3.ConPatSdoEvol,
			t3.SalConPrjEvol,
			max(0, (t10.lxs / t12.lxs)) format=12.8 as pxs,
			max(0, (t10.dxs / t12.dxs)) format=12.8 as dxs,
			t5.apxa format=12.8 as apx,
			t1.id_bloco,
			txc.vl_taxa_juros as taxa_juros_cob,
			(case
				when txrp1.vl_taxa_risco is null
					then 0
					else txrp1.vl_taxa_risco
			end) format=10.6 as vl_taxa_risco_partic,
			(case
				when txrp2.vl_taxa_risco is null
					then 0
					else txrp2.vl_taxa_risco
			end) format=10.6 as vl_taxa_risco_patroc
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join work.taxa_juros txc on (txc.t = min(t3.t, &maxTaxaJuros))
	left join work.taxa_risco txrp1 on (txrp1.t = min(t3.t, &maxTaxaRiscoPartic) and txrp1.id_responsabilidade = 1)
	left join work.taxa_risco txrp2 on (txrp2.t = min(t3.t, &maxTaxaRiscoPatroc) and txrp2.id_responsabilidade = 2)
	inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t3.IddPartEvol = t5.Idade and t5.t = min(t3.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t3.IddPartEvol = t10.Idade and t10.t = min(t3.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t12 on (t1.CdSexoPartic = t12.Sexo and t1.IddPartiCalc = t12.Idade and t12.t = 0)
	order by t1.id_participante, t3.t;
quit;

%macro calcDeterministicoVacf;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.vacf_deterministico_ativos);

		proc iml;
			USE determin.vacf_ativos;
				read all var {id_participante tCobertura pxs apx dxs ConParSdoEvol ConPatSdoEvol SalConPrjEvol taxa_juros_cob vl_taxa_risco_partic vl_taxa_risco_patroc} into ativos where(id_bloco = &a.);
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 10, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					pxs = ativos[a, 3];
					apx = ativos[a, 4];
					dxs = ativos[a, 5];
					ConParSdoEvol = ativos[a, 6];
					ConPatSdoEvol = ativos[a, 7];
					SalConPrjEvol = ativos[a, 8];
					taxa_juros_cob = ativos[a, 9];
					taxa_risco_partic = ativos[a, 10];
					taxa_risco_patroc = ativos[a, 11];

					receitaParticipanteProgramada = 0;
					receitaParticipanteRisco = 0;
					receitaPatrocinadoraProgramada = 0;
					receitaPatrocinadoraRisco = 0;
					vacfParticipanteProgramada = 0;
					vacfParticipanteRisco = 0;
					vacfPatrocinadoraProgramada = 0;
					vacfPatrocinadoraRisco = 0;

					v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));

					if (&CdPlanBen = 1) then do;
						receitaParticipanteProgramada = max(0, round(ConParSdoEvol * (1 - &TxCarregamentoAdm), 0.01));
						vacfParticipanteProgramada = max(0, round(receitaParticipanteProgramada * v * &FtSalPart, 0.01));
						receitaPatrocinadoraProgramada = receitaParticipanteProgramada;
						vacfPatrocinadoraProgramada = vacfParticipanteProgramada;
					end;
					else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
						receitaParticipanteProgramada = ConParSdoEvol;

						if (&CdPlanBen = 4) then do;
							if (ConParSdoEvol > 0) then
								receitaParticipanteRisco = max(0, round((SalConPrjEvol / &FtSalPart) * taxa_risco_partic * &NroBenAno * (1 - apx) * pxs, 0.01));
						end;

						vacfParticipanteProgramada = max(0, round(receitaParticipanteProgramada * v * &FtSalPart, 0.01));
						vacfParticipanteRisco = max(0, round(receitaParticipanteRisco * v * &FtSalPart, 0.01));

						receitaPatrocinadoraProgramada = ConPatSdoEvol;

						if (ConPatSdoEvol > 0) then
							receitaPatrocinadoraRisco = max(0, round((SalConPrjEvol / &FtSalPart) * taxa_risco_patroc * &NroBenAno * (1 - apx) * pxs, 0.01));

						vacfPatrocinadoraProgramada = max(0, round(receitaPatrocinadoraProgramada * v * &FtSalPart, 0.01));
						vacfPatrocinadoraRisco = max(0, round(receitaPatrocinadoraRisco * v * &FtSalPart, 0.01));
					end;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = receitaParticipanteProgramada;
					fluxoDeter[a, 4] = receitaParticipanteRisco;
					fluxoDeter[a, 5] = receitaPatrocinadoraProgramada;
					fluxoDeter[a, 6] = receitaPatrocinadoraRisco;
					fluxoDeter[a, 7] = vacfParticipanteProgramada;
					fluxoDeter[a, 8] = vacfParticipanteRisco;
					fluxoDeter[a, 9] = vacfPatrocinadoraProgramada;
					fluxoDeter[a, 10] = vacfPatrocinadoraRisco;
				END;

				create work.vacf_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'ReceitaParticipanteProgramada' 'ReceitaParticipanteRisco' 'ReceitaPatrocinadoraProgramada' 'ReceitaPatrocinadoraRisco' 'VACFParticipanteProgramada' 'VACFParticipanteRisco' 'VACFPatrocinadoraProgramada' 'VACFPatrocinadoraRisco'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.vacf_ativos;
			merge determin.vacf_ativos work.vacf_deterministico_ativos;
			by id_participante tCobertura;
			format ReceitaParticipanteProgramada commax14.2 ReceitaParticipanteRisco commax14.2 ReceitaPatrocinadoraProgramada commax14.2 ReceitaPatrocinadoraRisco commax14.2 VACFParticipanteProgramada commax14.2 VACFParticipanteRisco commax14.2 VACFPatrocinadoraProgramada commax14.2 VACFPatrocinadoraRisco commax14.2;
		run;
	%end;

	proc delete data = work.vacf_deterministico_ativos;
%mend;
%calcDeterministicoVacf;


/*%_eg_conditional_dropds(determin.vacf_ativos);*/
/*data determin.vacf_ativos;*/
/*	set determin.vacf_ativos1 - determin.vacf_ativos&numberOfBlocksAtivos;*/
/*run;*/

/*proc datasets nodetails library=determin;*/
/*   delete vacf_ativos1 - vacf_ativos&numberOfBlocksAtivos;*/
/*run;*/

%_eg_conditional_dropds(determin.vacf_receita_ativos);
proc summary data = determin.vacf_ativos;
 class tCobertura;
 var VACFParticipanteProgramada VACFParticipanteRisco VACFPatrocinadoraProgramada VACFPatrocinadoraRisco 
	 ReceitaParticipanteProgramada ReceitaParticipanteRisco ReceitaPatrocinadoraProgramada ReceitaPatrocinadoraRisco;
 output out=determin.vacf_receita_ativos sum=;
run;

/*data determin.vacf_despesa_ativos;
	set determin.vacf_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

/*%_eg_conditional_dropds(determin.receita_ativos);
proc summary data = determin.vacf_ativos;
 class tCobertura;
 var ReceitaParticipanteProgramada ReceitaParticipanteRisco ReceitaPatrocinadoraProgramada ReceitaPatrocinadoraRisco;
 output out=determin.receita_ativos sum=;
run;*/

%_eg_conditional_dropds(determin.vacf_encargo_ativos);
proc summary data = determin.vacf_ativos;
 class id_participante;
 var VACFParticipanteProgramada VACFParticipanteRisco VACFPatrocinadoraProgramada VACFPatrocinadoraRisco;
 output out=determin.vacf_encargo_ativos sum=;
run;

data determin.vacf_encargo_ativos;
	set determin.vacf_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.vacf_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   *delete vacf_ativos1 - vacf_ativos&numberOfBlocksAtivos;
		   delete vacf_ativos;
		   *delete vacf_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;