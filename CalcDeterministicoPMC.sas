*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro obtemAtivosDeterPmc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.pmc_ativos&a.);

		proc sql;
			create table determin.pmc_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					atc.BenLiqCobATC,
					t1.flg_manutencao_saldo,
					t5.dx,
					(case 
						when (t4.tDeterministico = 0 or (&CdPlanBen = 4 | &CdPlanBen = 5))
							then t5.apxa
							else t5.apx
					end) format=12.8 as apx,
					t6.lx format=commax14.2 as lx,
					(ajco.lxs / ajca.lxs) format=12.8 as pxs,
					txc.vl_taxa_juros as taxa_juros_cob,
					txd.vl_taxa_juros as taxa_juros_det
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join work.taxa_juros txd on (txd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join cobertur.atc_ativos atc on (t1.id_participante = atc.id_participante and t3.t = atc.t)
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t4.IddPartiDeter = t5.Idade and t5.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t3.IddPartEvol = t6.Idade and t6.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajco on (t1.CdSexoPartic = ajco.Sexo and t3.IddPartEvol = ajco.Idade and ajco.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajca on (t1.CdSexoPartic = ajca.Sexo and t1.IddPartiCalc = ajca.Idade and ajca.t = 0)
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterPmc;

%macro calcDeterministicoPmc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.pmc_deterministico_ativos);

		proc iml;
			USE determin.pmc_ativos&a.;
				read all var {id_participante tCobertura tDeterministico BenLiqCobATC dx lx apx flg_manutencao_saldo pxs taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 9, 0);
				pagamento = 0;

				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					BenLiqCobAtc = ativos[a, 4];
					dx = ativos[a, 5];
					lx = ativos[a, 6];
					apx = ativos[a, 7];
					flg_manutencao_saldo = ativos[a, 8];
					*pxs = ativos[a, 9];
					taxa_juros_cob = ativos[a, 10];
					taxa_juros_det = ativos[a, 11];

					if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
						pxs = 1;
					else
						pxs = ativos[a, 9];

					v = 0;
					vt = 0;
					vt_dx = 0;
					despesa = 0;
					despesaVP = 0;
					beneficio = 0;

					if (&CdPlanBen ^= 1) then do;
						if (tCobertura = tDeterministico) then do;
							t_vt = 0;
						
							beneficio = max(0, round((BenLiqCobAtc / &FtBenEnti) * &peculioMorteAssistido, 0.01));
							
							if (flg_manutencao_saldo = 0 & beneficio > 0) then 
								beneficio = max(beneficio, &LimPecMin);

							pagamento = max(0, round(beneficio * apx, 0.01));
						end;
						else do;
							pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));
						end;
						
						vt = max(0, 1 / ((1 + taxa_juros_det) ** (t_vt + 1)));
						vt_dx = max(0, vt * dx);

						if (lx > 0) then 
							despesa = max(0, round(pagamento * vt_dx / lx, 0.01));

						v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
						despesaVP = max(0, round(despesa * pxs * v, 0.01));

						t_vt = t_vt + 1;
					end;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = beneficio;
					fluxoDeter[a, 5] = pagamento;
					fluxoDeter[a, 6] = despesa;
					fluxoDeter[a, 7] = despesaVP;
					fluxoDeter[a, 8] = v;
					fluxoDeter[a, 9] = vt_dx;
				END;

				create work.pmc_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'BeneficioPMC' 'PagamentoPMC' 'DespesaPMC' 'DespesaVpPMC' 'v' 'vt_dx'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.pmc_ativos&a.;
			merge determin.pmc_ativos&a. work.pmc_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format BeneficioPMC commax14.2 PagamentoPMC commax14.2 DespesaPMC commax14.2 DespesaVpPMC commax14.2 v 10.8 vt_dx 10.8;
		run;
	%end;

	proc delete data = work.pmc_deterministico_ativos;
%mend;
%calcDeterministicoPmc;

%_eg_conditional_dropds(determin.pmc_ativos);
data determin.pmc_ativos;
	set determin.pmc_ativos1 - determin.pmc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete pmc_ativos1 - pmc_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.pmc_despesa_ativos);
proc summary data = determin.pmc_ativos;
 class tDeterministico;
 var DespesaPMC DespesaVpPMC;
 output out=determin.pmc_despesa_ativos sum=;
run;

/*data determin.pmc_despesa_ativos;
	set determin.pmc_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.pmc_encargo_ativos);
proc summary data = determin.pmc_ativos;
 class id_participante;
 var DespesaVpPMC;
 output out=determin.pmc_encargo_ativos sum=;
run;

data determin.pmc_encargo_ativos;
	set determin.pmc_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.pmc_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			*delete pmc_ativos1 - pmc_ativos&numberOfBlocksAtivos;
			delete pmc_ativos;
			*delete pmc_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;