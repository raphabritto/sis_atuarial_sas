
%macro obtemAtivosDeterPmi;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.pmi_ativos&a.);

		proc sql;
			create table determin.pmi_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					aiv.BenLiqCobAIV,
					aiv.AplicarPxsAIV,
					t1.flg_manutencao_saldo,
					t3.IddPartEvol,
					t1.IddIniApoInss,
					t5.dxii,
					ajcd.ix,
					t5.apxa format=12.8 as apx,
					t6.lxii,
					(ajco.lxs / ajca.lxs) format=12.8 as pxs,
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
			inner join tabuas.tabuas_servico_ajustada ajcd on (t1.CdSexoPartic = ajcd.Sexo and t4.IddPartiDeter = ajcd.Idade and ajcd.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajco on (t1.CdSexoPartic = ajco.Sexo and t3.IddPartEvol = ajco.Idade and ajco.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada ajca on (t1.CdSexoPartic = ajca.Sexo and t1.IddPartiCalc = ajca.Idade and ajca.t = 0)
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterPmi;

%macro calcDeterministicoPmi;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.ativos_resultado_pmi);

		proc iml;
			USE determin.pmi_ativos&a.;
				read all var {id_participante tCobertura tDeterministico BenLiqCobAIV dxii ix apx flg_manutencao_saldo IddPartEvol IddIniApoInss lxii pxs AplicarPxsAIV taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 9, 0);
				pagamento = 0;

				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					BenLiqAiv = ativos[a, 4];
					dxii = ativos[a, 5];
					ix = ativos[a, 6];
					apx = ativos[a, 7];
					flg_manutencao_saldo = ativos[a, 8];
					IddPartEvol = ativos[a, 9];
					IddIniApoInss = ativos[a, 10];
					lxii = ativos[a, 11];
					*pxs = ativos[a, 12];
					AplicarPxsAIV = ativos[a, 13];
					taxa_juros_cob = ativos[a, 14];
					taxa_juros_det = ativos[a, 15];

					if (AplicarPxsAIV = 0) then 
						pxs = 1;
					else
						pxs = ativos[a, 12];

					beneficio = 0;
					despesa = 0;
					despesaVP = 0;
					v = 0;
					vt = 0;
					vt_dxii = 0;

					if (&CdPlanBen ^= 1) then do;
						if (tCobertura = tDeterministico) then do;
							t_vt = 0;
							beneficio = max(0, round((BenLiqAiv / &FtBenEnti) * &peculioMorteAssistido, 0.01));

							if (flg_manutencao_saldo = 0 & beneficio > 0) then 
								beneficio = max(beneficio, &LimPecMin);

							pagamento = max(0, beneficio * ix * (1 - apx));
						end;
						else do;
							pagamento = max(0, round(pagamento * (1 + &PrTxBenef), 0.01));
						end;

						vt = max(0, 1 / ((1 + taxa_juros_det) ** (t_vt + 1)));
						vt_dxii = max(0, vt * dxii);

						if (lxii > 0) then 
							despesa = max(0, round(pagamento * vt_dxii / lxii, 0.01));

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
					fluxoDeter[a, 9] = vt_dxii;
				END;

				create work.ativos_resultado_pmi from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'BeneficioPMI' 'PagamentoPMI' 'DespesaPMI' 'DespesaVpPMI' 'v' 'vt_dxii'}];
					append from fluxoDeter;
				close;

				free fluxoDeter ativos;
			end;
		quit;

		data determin.pmi_ativos&a.;
			merge determin.pmi_ativos&a. work.ativos_resultado_pmi;
			by id_participante tCobertura tDeterministico;
			format BeneficioPMI commax14.2 PagamentoPMI commax14.2 DespesaPMI commax14.2 DespesaVpPMI commax14.2 v 10.8 vt_dxii commax14.2;
		run;
	%end;

	proc delete data = work.ativos_resultado_pmi;
%mend;
%calcDeterministicoPmi;

%_eg_conditional_dropds(determin.pmi_ativos);
data determin.pmi_ativos;
	set determin.pmi_ativos1 - determin.pmi_ativos&numberOfBlocksAtivos;
run;

/*proc datasets nodetails library=determin;*/
/*   delete pmi_ativos1 - pmi_ativos&numberOfBlocksAtivos;*/
/*run;*/

%_eg_conditional_dropds(determin.pmi_despesa_ativos);
proc summary data = determin.pmi_ativos;
 class tDeterministico;
 var DespesaPMI DespesaVpPMI;
 output out=determin.pmi_despesa_ativos sum=;
run;

/*data determin.pmi_despesa_ativos;
	set determin.pmi_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

%_eg_conditional_dropds(determin.pmi_encargo_ativos);
proc summary data = determin.pmi_ativos;
 class id_participante;
 var DespesaVpPMI;
 output out=determin.pmi_encargo_ativos sum=;
run;

data determin.pmi_encargo_ativos;
	set determin.pmi_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

/*data ativos.ativos;*/
/*	merge ativos.ativos determin.pmi_encargo_ativos;*/
/*	by id_participante;*/
/*run;*/

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
			delete pmi_ativos1 - pmi_ativos&numberOfBlocksAtivos;
			*delete pmi_ativos;
			*delete pmi_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;