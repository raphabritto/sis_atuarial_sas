*-- CÁLCULO DO FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS - PARTICIPANTES E ASSISTIDOS         --*;
*-- Versão: 22 de junho de 2012                                                                                   --*;
*-- Modificação para incorporar o saque de BUA: 30 de outubro de 2012                                             --*;
*-- Para o cálculo de BUA, ele é feito com base no saldo de conta, para o caso dos planos CD e CV. Para os        --*;
*-- planos BD, o cálculo de BUA é feito apenas quando o método de financiamento é do tipo BSD.                    --*;

/*data determin.ppa_ativos2;
	retain id_participante t PrbCasado;
	merge partic.ativos cobertur.cobertura_ativos;
	by id_participante;
run;*/

%macro obtemAtivosDeterPpa;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.ppa_ativos&a.);

		proc sql;
			create table determin.ppa_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					t1.PrbCasado,
					ppa.BenLiqCobPPA,
					ppa.BenTotCobPPA,
					ppa.AplicarPxsPPA,
					max(0, (t7.lx / t8.lx)) format=12.8 as pjx,
					max(0, (ajco.lxs / ajca.lxs)) format=12.8 as pxs,
					max(0, ((t7.Nxcb / t7.Dxcb) - &Fb)) format=12.8 AS ajxcb,
					ajde.qx,
/*					(case*/
/*						when ((&CdPlanBen = 4 | &CdPlanBen = 5) & t4.tCobertura = 0 and t4.tDeterministico = 0 and t4.IddPartiDeter > (case when t1.CdSexoPartic = 1 then &idade_apx_fem else &idade_apx_mas end))*/
/*							then t6.apxa*/
/*							else t5.apxa*/
/*					end) format=10.6 as apx,*/
					t5.apxa format=10.6 as apx,
					txc.vl_taxa_juros as taxa_juros_cob,
					txd.vl_taxa_juros as taxa_juros_det
			from partic.ativos t1
			inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
			inner join determin.deterministico_ativos&a. t4 on (t1.id_participante = t4.id_participante and t3.t = t4.tCobertura)
			inner join work.taxa_juros txc on (txc.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join work.taxa_juros txd on (txd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join cobertur.ppa_ativos ppa on (t1.id_participante = ppa.id_participante and t3.t = ppa.t)
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t4.IddPartiDeter = t5.Idade and t5.t = min(t4.tDeterministico, &maxTaxaJuros))
/*			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t6.Idade = (case when t1.CdSexoPartic = 1 then &idade_apx_fem else &idade_apx_mas end) and t6.t = 0)*/
			inner join tabuas.tabuas_servico_normal t7 on (t1.CdSexoConjug = t7.Sexo and t4.IddConjuDeter = t7.Idade and t7.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t8 on (t1.CdSexoConjug = t8.Sexo and t3.IddConjEvol = t8.Idade and t8.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajco on (t1.CdSexoPartic = ajco.Sexo and t3.IddPartEvol = ajco.Idade and ajco.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajca on (t1.CdSexoPartic = ajca.Sexo and t1.IddPartiCalc = ajca.Idade and ajca.t = 0)
			inner join tabuas.tabuas_servico_ajustada ajde on (t1.CdSexoPartic = ajde.Sexo and t4.IddPartiDeter = ajde.Idade and ajde.t = min(t4.tDeterministico, &maxTaxaJuros))
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterPpa;

%macro calcDeterministicoPpa;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.ppa_deterministico_ativos);

		proc iml;
			USE determin.ppa_ativos&a.;
				read all var {id_participante tCobertura tDeterministico pjx pxs qx apx PrbCasado BenLiqCobPPA BenTotCobPPA ajxcb AplicarPxsPPA taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 9, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					pjx = ativos[a, 4];
					*pxs = ativos[a, 5];
					qx = ativos[a, 6];
					apx = ativos[a, 7];
					PrbCasado = ativos[a, 8];
					BenLiqCobPpa = ativos[a, 9];
					BenTotPpa = ativos[a, 10];
					ajxcb = ativos[a, 11];
					AplicarPxsPPA = ativos[a, 12];
					taxa_juros_cob = ativos[a, 13];
					taxa_juros_det = ativos[a, 14];

					if (AplicarPxsPPA = 0) then 
						pxs = 1;
					else
						pxs = ativos[a, 5];

					descontoPpaBUA = 0;

					if (tCobertura = tDeterministico) then do;
						tvt = 0;
						pagamento = max(0, round((BenLiqCobPpa / &FtBenEnti) * qx * &NroBenAno * PrbCasado * (1 - apx), 0.01));

						if (&CdPlanBen ^= 1) then do;
							descontoPpaBUA = max(0, round((BenTotPpa * ajxcb * &NroBenAno) * qx * (1 - apx) * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else
						pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));

					despesa = max(0, round((pagamento + descontoPpaBUA) * pjx * pxs, 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					if (tCobertura = tDeterministico) then do;
						encargo = max(0 , round(((pagamento * pjx * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti) + descontoPpaBUA) * pxs * v, 0.01));
					end;
					else do;
						encargo = max(0 , round(pagamento * &FtBenEnti * pjx * vt * pxs * v, 0.01));
					end;

					tvt = tvt + 1;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = pagamento;
					fluxoDeter[a, 5] = descontoPpaBUA;
					fluxoDeter[a, 6] = despesa;
					fluxoDeter[a, 7] = encargo;
					fluxoDeter[a, 8] = v;
					fluxoDeter[a, 9] = vt;
				END;

				create work.ppa_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'PagamentoPPA' 'DescontoBuaPPA' 'DespesaPPA' 'DespesaVpPPA' 'v_PPA' 'vt_PPA'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.ppa_ativos&a.;
			merge determin.ppa_ativos&a. work.ppa_deterministico_ativos;
			by id_participante tCobertura tDeterministico;
			format PagamentoPPA COMMAX14.2 DescontoBuaPPA COMMAX14.2 DespesaPPA COMMAX14.2 DespesaVpPPA COMMAX14.2 v_PPA 12.8 vt_PPA 12.8;
		run;
	%end;

	proc delete data = work.ppa_deterministico_ativos;
%mend;
%calcDeterministicoPpa;


%_eg_conditional_dropds(determin.ppa_ativos);
data determin.ppa_ativos;
	set determin.ppa_ativos1 - determin.ppa_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete ppa_ativos1 - ppa_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.ppa_despesa_ativos);
proc summary data = determin.ppa_ativos;
 class tDeterministico;
 var DespesaPPA DespesaVpPPA;
 output out=determin.ppa_despesa_ativos sum=;
run;

/*data determin.ppa_despesa_ativos;
	set determin.ppa_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.ppa_encargo_ativos);
proc summary data = determin.ppa_ativos;
 class id_participante;
 var DespesaVpPPA;
 output out=determin.ppa_encargo_ativos sum=;
run;

data determin.ppa_encargo_ativos;
	set determin.ppa_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.ppa_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			*delete ppa_ativos1 - ppa_ativos&numberOfBlocksAtivos;
			delete ppa_ativos;
			*delete ppa_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;