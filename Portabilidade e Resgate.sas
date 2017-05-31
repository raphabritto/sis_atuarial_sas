*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

proc sql;
	create table determin.rotatividade_ativos as
	select t1.id_participante,
			ben.t,
			ben.SalConPrjEvol,
			ben.ConParSdoEvol,
			ben.ConPatSdoEvol,
			ben.VlSdoConPartEvol,
			ben.VlSdoConPatrEvol,
			floor(t1.TmpPlanoPrev + ben.t) as TmpPlanoPrev,
			ajco.'wx'n as wx,
			noco.apxa format=12.8 as apx,
			txc.vl_taxa_juros as taxa_juros_cob
	from partic.ativos t1
	inner join cobertur.cobertura_ativos ben on (t1.id_participante = ben.id_participante)
	inner join work.taxa_juros txc on (txc.t = min(ben.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal noco on (t1.CdSexoPartic = noco.Sexo and ben.IddPartEvol = noco.Idade and noco.t = min(ben.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada ajco on (t1.CdSexoPartic = ajco.Sexo and ben.IddPartEvol = ajco.Idade and ajco.t = min(ben.t, &maxTaxaJuros))
	order by t1.id_participante, ben.t;
quit;

%_eg_conditional_dropds(work.rotatividade_determin_ativos);
proc iml;
	USE determin.rotatividade_ativos;
		read all var {id_participante t SalConPrjEvol ConParSdoEvol ConPatSdoEvol VlSdoConPartEvol VlSdoConPatrEvol TmpPlanoPrev wx apx taxa_juros_cob} into ativos;
	CLOSE;

	qtsObs = nrow(ativos);

	if (qtsObs > 0) then do;
		lstResgatePortabilidade = J(qtsObs, 6, 0);

		DO a = 1 TO qtsObs;
			t = ativos[a, 2];
			SalConPrjEvol = ativos[a, 3];
			ConParSdoEvol = ativos[a, 4];
			ConPatSdoEvol = ativos[a, 5];
			VlSdoConPartEvol = ativos[a, 6];
			VlSdoConPatrEvol = ativos[a, 7];
			TmpPlanoPrev = ativos[a, 8];
			wx = ativos[a, 9];
			apx = ativos[a, 10];
			taxa_juros_cob = ativos[a, 11];

			resgate = 0;
			despesaResgate = 0;
			portabilidade = 0;
			despesaPortabilidade = 0;
			despesaResgateVP = 0;
			despesaPortabilidadeVP = 0;

			if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
				*** regra calculo resgate - regra separada pois as premissas de tempo de participacao no plano podem variar da portabilidade ***;
				if (&CdPlanBen = 4) then do;
					if (TmpPlanoPrev < 11) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 0.05, 0.01));
					end;
					else if (TmpPlanoPrev >= 11 & TmpPlanoPrev < 16) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 0.1, 0.01));
					end;
					else if (TmpPlanoPrev >= 16 & TmpPlanoPrev < 21) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 0.15, 0.01));
					end;
					else if (TmpPlanoPrev >= 21) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 0.2, 0.01));
					end;
				end;
				else if (&CdPlanBen = 5) then do;
					if (TmpPlanoPrev <= 10) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 10 & TmpPlanoPrev <= 15) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 15 & TmpPlanoPrev <= 20) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 20) then do;
						resgate = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
				end;

				if (TmpPlanoPrev < 3) then
					despesaResgate = max(0, round((VlSdoConPartEvol + resgate) * wx * (1 - apx), 0.01));
				else
					despesaResgate = max(0, round((VlSdoConPartEvol + resgate) * wx * &percentualResgate * (1 - apx), 0.01));

				*** regra calculo portabilidade - regra separada pois as premissas de tempo de participacao no plano podem variar do resgate ***;
				if (&CdPlanBen = 4) then do;
					if (TmpPlanoPrev <= 10) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 10 & TmpPlanoPrev <= 15) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 15 & TmpPlanoPrev <= 20) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 20) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
				end;
				else if (&CdPlanBen = 5) then do;
					if (TmpPlanoPrev <= 10) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 10 & TmpPlanoPrev <= 15) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 15 & TmpPlanoPrev <= 20) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
					else if (TmpPlanoPrev > 20) then do;
						portabilidade = max(0, round(VlSdoConPatrEvol * 1, 0.01));
					end;
				end;

				if (TmpPlanoPrev < 3) then
					despesaPortabilidade = 0;
				else
					despesaPortabilidade = max(0, round((VlSdoConPartEvol + portabilidade) * wx * &percentualPortabilidade * (1 - apx), 0.01));

				v = max(0, 1 / ((1 + taxa_juros_cob) ** t));

				despesaResgateVP = max(0, round(despesaResgate * v, 0.01));
				despesaPortabilidadeVP = max(0, round(despesaPortabilidade * v, 0.01));
			end;

			lstResgatePortabilidade[a, 1] = ativos[a, 1];
			lstResgatePortabilidade[a, 2] = ativos[a, 2];
			lstResgatePortabilidade[a, 3] = despesaResgate;
			lstResgatePortabilidade[a, 4] = despesaPortabilidade;
			lstResgatePortabilidade[a, 5] = despesaResgateVP;
			lstResgatePortabilidade[a, 6] = despesaPortabilidadeVP;
		END;

		create work.rotatividade_determin_ativos from lstResgatePortabilidade[colname={'id_participante' 't' 'DespesaResgate' 'DespesaPortabilidade' 'DespesaResgateVP' 'DespesaPortabilidadeVP'}];
			append from lstResgatePortabilidade;
		close;

		free lstResgatePortabilidade ativos;
	end;
quit;

data determin.rotatividade_ativos;
	merge determin.rotatividade_ativos work.rotatividade_determin_ativos;
	by id_participante t;
	format DespesaResgate commax14.2 DespesaPortabilidade commax14.2 DespesaResgateVP commax14.2 DespesaPortabilidadeVP commax14.2;
run;

proc delete data = work.rotatividade_determin_ativos;

/*%_eg_conditional_dropds(determin.rotatividade_ativos);
data determin.rotatividade_ativos;
	set determin.rotatividade_ativos1 - determin.rotatividade_ativos&numberOfBlocksAtivos;
run;*/

/*proc datasets nodetails library=determin;
   delete rotatividade_ativos1 - rotatividade_ativos&numberOfBlocksAtivos;
run;*/

%_eg_conditional_dropds(determin.rotatividade_despesa_ativos);
proc summary data = determin.rotatividade_ativos;
	class t;
	var DespesaResgate DespesaPortabilidade DespesaResgateVP DespesaPortabilidadeVP;
	output out=determin.rotatividade_despesa_ativos sum=;
run;

%_eg_conditional_dropds(determin.rotatividade_encargo_ativos);
proc summary data = determin.rotatividade_ativos;
	class id_participante;
	var DespesaResgateVP DespesaPortabilidadeVP;
	output out=determin.rotatividade_encargo_ativos sum=;
run;

/*data determin.rotatividade_despesa_ativos;
	set determin.rotatividade_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete rotatividade_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;