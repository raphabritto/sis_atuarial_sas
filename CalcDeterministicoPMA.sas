*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro obtemAtivosDeterPma;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.pma_ativos&a.);

		proc sql;
			create table determin.pma_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					t3.SalConPrjEvol,
					t1.flg_manutencao_saldo,
					ajco.qx,
/*					(case*/
/*						when ((&CdPlanBen = 4 | &CdPlanBen = 5) & t4.tCobertura = 0 and t4.tDeterministico = 0 and t4.IddPartiDeter > (case when t1.CdSexoPartic = 1 then &idade_apx_fem else &idade_apx_mas end))*/
/*							then t6.apxa*/
/*							else t5.apxa*/
/*					end) format=10.8 as apx,*/
					t5.apxa format=10.8 as apx,
					(ajco.lxs / ajca.lxs) format=10.8 as pxs,
					txc.vl_taxa_juros as taxa_juros_cob
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura and t4.tCobertura = t4.tDeterministico)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t4.IddPartiDeter = t5.Idade and t5.t = min(t4.tCobertura, &maxTaxaJuros))
/*			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t6.Idade = (case when t1.CdSexoPartic = 1 then &idade_apx_fem else &idade_apx_mas end) and t6.t = 0)*/
			inner join tabuas.tabuas_servico_ajustada ajco on (t1.CdSexoPartic = ajco.Sexo and t3.IddPartEvol = ajco.Idade and ajco.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajca on (t1.CdSexoPartic = ajca.Sexo and t1.IddPartiCalc = ajca.Idade and ajca.t = 0)
/*			inner join tabuas.tabuas_servico_ajustada ajde on (t1.CdSexoPartic = ajde.Sexo and t4.IddPartiDeter = ajde.Idade and ajde.t = min(t4.tDeterministico, &maxTaxaJuros))*/
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterPma;

%macro calcDeterministicoPma;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.pma_deterministico_ativos);

		proc iml;
			USE determin.pma_ativos&a.;
				read all var {id_participante tCobertura tDeterministico SalConPrjEvol apx qx flg_manutencao_saldo pxs taxa_juros_cob} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 8, 0);
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					SalConPrjEvol = ativos[a, 4];
					apx = ativos[a, 5];
					qx = ativos[a, 6];
					flg_manutencao_saldo = ativos[a, 7];
					pxs = ativos[a, 8];
					taxa_juros_cob = ativos[a, 9];

					pagamento = 0;
					beneficio = 0;
					despesa = 0;
					despesaVP = 0;
					v = 0;

					if (&CdPlanBen ^= 1 & flg_manutencao_saldo = 0) then do;
						if (tCobertura = tDeterministico) then do;
							*if (flg_manutencao_saldo = 0) then;
							beneficio = max(0, max(&LimPecMin, round((SalConPrjEvol / &FtBenEnti) * &peculioMorteAtivo, 0.01)));

							pagamento = max(0, round(beneficio * qx * (1 - apx), 0.01));
							despesa = pagamento;
							v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
							despesaVP = max(0, round(pagamento * v * pxs, 0.01));
						end;
					end;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = beneficio;
					fluxoDeter[a, 5] = pagamento;
					fluxoDeter[a, 6] = despesa;
					fluxoDeter[a, 7] = despesaVP;
					fluxoDeter[a, 8] = v;
				END;

				create work.pma_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'BeneficioPMA' 'PagamentoPMA' 'DespesaPMA' 'DespesaVpPMA' 'v_PMA'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.pma_ativos&a.;
			merge determin.pma_ativos&a. work.pma_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format BeneficioPMA commax14.2 PagamentoPMA commax14.2 DespesaPMA commax14.2 DespesaVpPMA commax14.2 v_PMA 12.8;
		run;
	%end;

	proc delete data = work.pma_deterministico_ativos;
%mend;
%calcDeterministicoPma;

%_eg_conditional_dropds(determin.pma_ativos);
data determin.pma_ativos;
	set determin.pma_ativos1 - determin.pma_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete pma_ativos1 - pma_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.pma_despesa_ativos);
proc summary data = determin.pma_ativos;
 class tDeterministico;
 var DespesaPMA DespesaVpPMA;
 output out=determin.pma_despesa_ativos sum=;
run; 

/*data determin.pma_despesa_ativos;
	set determin.pma_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.pma_encargo_ativos);
proc summary data = determin.pma_ativos;
 class id_participante;
 var DespesaVpPMA;
 output out=determin.pma_encargo_ativos sum=;
run; 

data determin.pma_encargo_ativos;
	set determin.pma_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.pma_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

/*%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			*delete pma_ativos1 - pma_ativos&numberOfBlocksAtivos;
			*delete pma_ativos;
			*delete pma_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;*/