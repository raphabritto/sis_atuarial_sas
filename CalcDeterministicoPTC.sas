*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

*--- obtem os participantes, os valores do beneficio e os fatores utilizados no calculo ca cobertura PTC ---*;
%macro obtemAtivosDeterPtc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.ptc_ativos&a.);

		proc sql;
			create table determin.ptc_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					t1.PrbCasado,
					ptc.BenLiqCobPtc,
					(t5.lx / t6.lx) format=12.8 as lx,
					(t7.lx / t8.lx) format=12.8 as ljx,
					(t9.lxs / t10.lxs) format=12.8 as pxs,
					(case 
						when (t4.tDeterministico = 0 or (&CdPlanBen = 4 | &CdPlanBen = 5))
							then t5.apxa
							else t5.apx
					end) format=12.8 as apx,
					txc.vl_taxa_juros as taxa_juros_cob,
					txd.vl_taxa_juros as taxa_juros_det
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join work.taxa_juros txd on (txd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join cobertur.ptc_ativos ptc on (t1.id_participante = ptc.id_participante and t3.t = ptc.t)
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t4.IddPartiDeter = t5.Idade and t5.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t3.IddPartEvol = t6.Idade and t6.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t7 on (t1.CdSexoConjug = t7.Sexo and t4.IddConjuDeter = t7.Idade and t7.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t8 on (t1.CdSexoConjug = t8.Sexo and t3.IddConjEvol = t8.Idade and t8.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t3.IddPartEvol = t9.Idade and t9.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = 0)
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterPtc;

%macro calcDeterministicoPtc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.ptc_deterministico_ativos);

		proc iml;
			USE determin.ptc_ativos&a.;
				read all var {id_participante tCobertura tDeterministico lx ljx pxs apx PrbCasado BenLiqCobPtc taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 8, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					lx = ativos[a, 4];
					ljx = ativos[a, 5];
					*pxs = ativos[a, 6];
					apx = ativos[a, 7];
					PrbCasado = ativos[a, 8];
					BenLiqCobPtc = ativos[a, 9];
					taxa_juros_cob = ativos[a, 10];
					taxa_juros_det = ativos[a, 11];

					if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
						pxs = 1;
					else
						pxs = ativos[a, 6];
					
					if (tCobertura = tDeterministico) then do;
						tvt = 0;
						pagamento = max(0, (BenLiqCobPtc / &FtBenEnti) * apx * &NroBenAno * PrbCasado);
					end;
					else
						pagamento = max(0, pagamento * (1 + &PrTxBenef));

					despesa = max(0, pagamento * (ljx - lx * ljx) * pxs);

					v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					encargo = max(0, pagamento * (ljx - lx * ljx) * vt * pxs * v * &FtBenEnti);

					tvt = tvt + 1;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = pagamento;
					fluxoDeter[a, 5] = despesa;
					fluxoDeter[a, 6] = encargo;
					fluxoDeter[a, 7] = v;
					fluxoDeter[a, 8] = vt;
				END;

				create work.ptc_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'PagamentoPTC' 'DespesaPTC' 'DespesaVpPTC' 'v_PTC' 'vt_PTC'}];
					append from fluxoDeter;
				close;

				free ativos fluxoDeter;
			end;
		quit;

		data determin.ptc_ativos&a.;
			merge determin.ptc_ativos&a. work.ptc_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format PagamentoPTC commax14.2 DespesaPTC commax14.2 DespesaVpPTC commax14.2 v_PTC 12.8 vt_PTC 12.8;
		run;
	%end;

	proc delete data = work.ptc_deterministico_ativos;
%mend;
%calcDeterministicoPtc;

%_eg_conditional_dropds(determin.ptc_ativos);
data determin.ptc_ativos;
	set determin.ptc_ativos1 - determin.ptc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete ptc_ativos1 - ptc_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.ptc_despesa_ativos);
proc summary data = determin.ptc_ativos;
 class tDeterministico;
 var DespesaPTC DespesaVpPTC;
 output out=determin.ptc_despesa_ativos sum=;
run;

/*data determin.ptc_despesa_ativos;
	set determin.ptc_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.ptc_encargo_ativos);
proc summary data = determin.ptc_ativos;
 class id_participante;
 var DespesaVpPTC;
 output out=determin.ptc_encargo_ativos sum=;
run;

data determin.ptc_encargo_ativos;
	set determin.ptc_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.ptc_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   *delete ptc_ativos1 - ptc_ativos&numberOfBlocksAtivos;
		   delete ptc_ativos;
		   *delete ptc_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;