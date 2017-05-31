*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

%macro obtemAtivosDeterAiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.aiv_ativos&a.);

		proc sql;
			create table determin.aiv_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					aiv.BenLiqCobAIV,
					aiv.BenTotCobAIV,
					aiv.AplicarPxsAIV,
					t1.PrbCasado,
					max(0, (t5.lxii / t6.lxii)) format=12.8 as pxii,
					max(0, (t9.lxs / t10.lxs)) format=12.8 as pxs,
					max(0, ((t5.Nxiicb / t5.Dxiicb) - &Fb)) format=12.8 AS axiicb,
					(case
						when t4.tCobertura = t4.tDeterministico
							then t9.ix
							else 0
					end) format=12.8 as ix,
					t5.apxa format=12.8 as apx,
					(case
						when t4.tCobertura = t4.tDeterministico
							then max(0, ((snc.Nxcb / snc.Dxcb) - &Fb))
							else 0
					end) format=12.8 AS ajxcb,
					(case
						when t4.tCobertura = t4.tDeterministico
						then max(0, ((n1.njxx / d1.djxx) - &Fb)) 
						else 0
					end) format=12.8 AS ajxx_i,
					(case
						when t4.tCobertura = t4.tDeterministico
						then max(0, (t6.Mxii / t6.'Dxii*'n)) 
						else 0
					end) format=12.8 as Axii,
					txc.vl_taxa_juros as taxa_juros_cob,
					txd.vl_taxa_juros as taxa_juros_det
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join work.taxa_juros txd on (txd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join cobertur.aiv_ativos aiv on (t1.id_participante = aiv.id_participante and t3.t = aiv.t)
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t4.IddPartiDeter = t5.Idade and t5.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t3.IddPartEvol = t6.Idade and t6.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t3.IddPartEvol = t9.Idade and t9.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = 0)
			inner join TABUAS.TABUAS_SERVICO_NORMAL snc on (t1.CdSexoConjug = snc.Sexo and t3.IddConjEvol = snc.Idade and snc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join TABUAS.TABUAS_PENSAO_NJXX n1 on (t1.CdSexoPartic = n1.sexo AND t3.IddPartEvol = n1.idade_x AND t3.IddConjEvol = n1.idade_j AND n1.tipo = 2 and n1.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join TABUAS.TABUAS_PENSAO_DJXX d1 on (t1.CdSexoPartic = d1.sexo AND t3.IddPartEvol = d1.idade_x AND t3.IddConjEvol = d1.idade_j AND d1.tipo = 2 and d1.t = min(t4.tCobertura, &maxTaxaJuros))
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterAiv;

%macro calcDeterministicoAiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.aiv_deterministico_ativos);

		proc iml;
			USE determin.aiv_ativos&a.;
				read all var {id_participante tCobertura tDeterministico pxii pxs ix apx BenLiqCobAIV BenTotCobAIV axiicb PrbCasado ajxcb ajxx_i Axii AplicarPxsAIV taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 9, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					pxii = ativos[a, 4];
					*pxs = ativos[a, 5];
					ix = ativos[a, 6];
					apx = ativos[a, 7];
					BenLiqCobAiv = ativos[a, 8];
					BenTotAiv = ativos[a, 9];
					axiicb = ativos[a, 10];
					PrbCasado = ativos[a, 11];
					ajxcb = ativos[a, 12];
					ajxx_i = ativos[a, 13];
					axii = ativos[a, 14];
					AplicarPxsAIV = ativos[a, 15];
					taxa_juros_cob = ativos[a, 16];
					taxa_juros_det = ativos[a, 17];

					if (AplicarPxsAIV = 0) then 
						pxs = 1;
					else
						pxs = ativos[a, 5];

					despesaBuaAIV = 0;

					if (tCobertura = tDeterministico) then do;
						tvt = 0;
						pagamento = max(0, round((BenLiqCobAiv / &FtBenEnti) * (1 - apx) * ix * &NroBenAno, 0.01));

						if (&CdPlanBen ^= 1) then do;
							despesaBuaAIV = max(0, round(((BenTotAiv * (axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno) + ((BenTotAiv / &FtBenEnti) * (axii * &peculioMorteAssistido))) * (1 - apx) * ix * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else
						pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = max(0, round((pagamento + despesaBuaAIV) * pxii * pxs, 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					if (tCobertura = tDeterministico) then do;
						encargo = max(0, round(((pagamento * pxii * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti) + despesaBuaAIV) * pxs * v, 0.01));
					end;
					else do;
						encargo = max(0, round(pagamento * pxii * vt * pxs * v * &FtBenEnti, 0.01));
					end;

					tvt = tvt + 1;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = pagamento;
					fluxoDeter[a, 5] = despesaBuaAIV;
					fluxoDeter[a, 6] = despesa;
					fluxoDeter[a, 7] = encargo;
					fluxoDeter[a, 8] = v;
					fluxoDeter[a, 9] = vt;
				END;

				create work.aiv_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'PagamentoAIV' 'DespesaBuaAIV' 'DespesaAIV' 'DespesaVpAIV' 'v_AIV' 'vt_AIV'}];
					append from fluxoDeter;
				close;

				free ativos fluxoDeter;
			end;
		quit;

		data determin.aiv_ativos&a.;
			merge determin.aiv_ativos&a. work.aiv_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format PagamentoAIV commax14.2 DespesaBuaAIV commax14.2 DespesaAIV commax14.2 DespesaVpAIV commax14.2 v_AIV 12.8 vt_AIV 12.8;
		run;
	%end;

	proc delete data = work.aiv_deterministico_ativos;
%mend;
%calcDeterministicoAiv;


%_eg_conditional_dropds(determin.aiv_ativos);
data determin.aiv_ativos;
	set determin.aiv_ativos1 - determin.aiv_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete aiv_ativos1 - aiv_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.aiv_despesa_ativos);
proc summary data = determin.aiv_ativos;
 class tDeterministico;
 var DespesaAIV DespesaVpAIV;
 output out=determin.aiv_despesa_ativos sum=;
run;

/*data determin.aiv_despesa_ativos;
	set determin.aiv_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.aiv_encargo_ativos);
proc summary data = determin.aiv_ativos;
 class id_participante;
 var DespesaVpAIV;
 output out=determin.aiv_encargo_ativos sum=;
run;

data determin.aiv_encargo_ativos;
	set determin.aiv_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.aiv_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			*delete aiv_ativos1 - aiv_ativos&numberOfBlocksAtivos;
			delete aiv_ativos;
			*delete aiv_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;