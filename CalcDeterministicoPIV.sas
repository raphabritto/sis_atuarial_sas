*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro obtemAtivosDeterPiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.piv_ativos&a.);

		proc sql;
			create table determin.piv_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					t1.PrbCasado,
					piv.BenLiqCobPIV,
					piv.AplicarPxsPIV,
					max(0, (t5.lxii / t6.lxii)) format=12.8 as pxii,
					max(0, (t7.lx / t8.lx)) format=12.8 as pjx,
					max(0, (t9.lxs / t10.lxs)) format=12.8 as pxs,
					(case
						when t4.tCobertura = t4.tDeterministico
							then t9.ix
							else 0
					end) format=12.8 as ix,
					t5.apxa format=12.8 as apx,
					txc.vl_taxa_juros as taxa_juros_cob,
					txd.vl_taxa_juros as taxa_juros_det
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join work.taxa_juros txd on (txd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join cobertur.piv_ativos piv on (t1.id_participante = piv.id_participante and t3.t = piv.t)
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
%obtemAtivosDeterPiv;

%macro calcDeterministicoPiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.piv_deterministico_ativos);

		proc iml;
			USE determin.piv_ativos&a.;
				read all var {id_participante tCobertura tDeterministico pxii pjx pxs ix apx PrbCasado BenLiqCobPIV AplicarPxsPIV taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 8, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					pxii = ativos[a, 4];
					pjx = ativos[a, 5];
					*pxs = ativos[a, 6];
					ix = ativos[a, 7];
					apx = ativos[a, 8];
					PrbCasado = ativos[a, 9];
					BenLiqPiv = ativos[a, 10];
					AplicarPxsPIV = ativos[a, 11];
					taxa_juros_cob = ativos[a, 12];
					taxa_juros_det = ativos[a, 13];

					if (AplicarPxsPIV = 0) then 
						pxs = 1;
					else
						pxs = ativos[a, 6];

					if (tCobertura = tDeterministico) then do;
						pagamento = MAX(0, round((BenLiqPiv / &FtBenEnti) * (1 - apx) * ix * &NroBenAno * PrbCasado, 0.01));
						tvt = 0;
					end;
					else
						pagamento = MAX(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = MAX(0, round(pagamento * (pjx - pxii * pjx) * pxs, 0.01));

					v = 1 / ((1 + taxa_juros_cob) ** tCobertura);
					vt = 1 / ((1 + taxa_juros_det) ** tvt);

					encargo = max(0, round(pagamento * &FtBenEnti * (pjx - pxii * pjx) * vt * pxs * v, 0.01));

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

				create work.piv_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'PagamentoPIV' 'DespesaPIV' 'DespesaVpPIV' 'v_PIV' 'vt_PIV'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.piv_ativos&a.;
			merge determin.piv_ativos&a. work.piv_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format PagamentoPIV commax14.2 DespesaPIV commax14.2 DespesaVpPIV commax14.2 v_PIV 12.8 vt_PIV 12.8;
		run;
	%end;

	proc delete data = work.piv_deterministico_ativos;
%mend;
%calcDeterministicoPiv;

%_eg_conditional_dropds(determin.piv_ativos);
data determin.piv_ativos;
	set determin.piv_ativos1 - determin.piv_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete piv_ativos1 - piv_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.piv_despesa_ativos);
proc summary data = determin.piv_ativos;
 class tDeterministico;
 var DespesaPIV DespesaVpPIV;
 output out=determin.piv_despesa_ativos sum=;
run;

/*data determin.piv_despesa_ativos;
	set determin.piv_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.piv_encargo_ativos);
proc summary data = determin.piv_ativos;
 class id_participante;
 var DespesaVpPIV;
 output out=determin.piv_encargo_ativos sum=;
run;

data determin.piv_encargo_ativos;
	set determin.piv_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.piv_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			*delete piv_ativos1 - piv_ativos&numberOfBlocksAtivos;
			delete piv_ativos;
			*determin.piv_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;