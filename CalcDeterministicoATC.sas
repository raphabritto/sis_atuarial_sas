*-- CÁLCULO DETERMINISTICO DO BENEFÍCIO DE APOSENTADORIA POR TEMPO DE CONTRIBUIÇÃO (ATC) DOS PARTICIPANTES ATIVOS --*;
*-- Versão: 01 de DEZEMBRO de 2016                                                                                --*;

options noquotelenmax;

%macro obtemAtivosDeterAtc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(determin.atc_ativos&a.);

		proc sql;
			create table determin.atc_ativos&a. as
			select t1.id_participante,
					t4.tCobertura,
					t4.tDeterministico,
					atc.BenLiqCobAtc,
					atc.BenTotCobAtc,
					t1.PrbCasado,
					(case
						when t4.tCobertura = t4.tDeterministico
							then t3.VlSdoConPartEvol
							else 0
					end) format=commax14.2 as VlSdoConPartEvol,
					(case
						when t4.tCobertura = t4.tDeterministico
							then t3.VlSdoConPatrEvol
							else 0
					end) format=commax14.2 as VlSdoConPatrEvol,
					max(0, (t5.lx / t6.lx)) format=12.8 as px,
					max(0, (t9.lxs / t10.lxs)) format=12.8 as pxs,
					max(0, ((t5.Nxcb / t5.Dxcb) - &Fb)) format=12.8 AS axcb,
					(case 
						when (t4.tDeterministico = 0 or (&CdPlanBen = 4 | &CdPlanBen = 5))
							then t5.apxa
							else t5.apx
					end) format=12.8 as apx,
					(case
						when t4.tCobertura = t4.tDeterministico
							then max(0, ((snc.Nxcb / snc.Dxcb) - &Fb))
							else 0
					end) format=12.8 AS ajxcb,
					(case
						when t4.tCobertura = t4.tDeterministico
							then max(0, ((n1.njxx / d1.djxx) - &Fb))
							else 0
					end) format=12.8 AS ajxx,
					(case
						when t4.tCobertura = t4.tDeterministico
							then max(0, (t6.Mx / t6.'Dx*'n))
							else 0
					end) format=12.8 as Ax,
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
			inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t3.IddPartEvol = t9.Idade and t9.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = 0)
			inner join TABUAS.TABUAS_SERVICO_NORMAL snc on (t1.CdSexoConjug = snc.Sexo and t4.IddConjuDeter = snc.Idade and snc.t = min(t4.tDeterministico, &maxTaxaJuros))
			inner join TABUAS.TABUAS_PENSAO_NJXX n1 on (t1.CdSexoPartic = n1.sexo AND t3.IddPartEvol = n1.idade_x AND t3.IddConjEvol = n1.idade_j AND n1.tipo = 1 and n1.t = min(t4.tCobertura, &maxTaxaJuros))
			inner join TABUAS.TABUAS_PENSAO_DJXX d1 on (t1.CdSexoPartic = d1.sexo AND t3.IddPartEvol = d1.idade_x AND t3.IddConjEvol = d1.idade_j AND d1.tipo = 1 and d1.t = min(t4.tCobertura, &maxTaxaJuros))
			order by t1.id_participante, t3.t, t4.tDeterministico;
		quit;
	%end;
%mend;
%obtemAtivosDeterAtc;

%macro calcDeterministicoAtc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.atc_deterministico_ativos);

		proc iml;
			USE determin.atc_ativos&a.;
				read all var {id_participante tCobertura tDeterministico px pxs apx BenLiqCobAtc axcb BenTotCobAtc VlSdoConPartEvol VlSdoConPatrEvol PrbCasado ajxcb ajxx Ax taxa_juros_cob taxa_juros_det} into ativos;
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				fluxoDeter = J(qtsObs, 9, 0);

				pagamento = 0;
				
				DO a = 1 TO qtsObs;
					tCobertura = ativos[a, 2];
					tDeterministico = ativos[a, 3];
					px = ativos[a, 4];
					apx = ativos[a, 6];
					BenLiqCobAtc= ativos[a, 7];
					axcb = ativos[a, 8];
					BenTotCobAtc = ativos[a, 9];
					VlSdoConTotal = round(ativos[a, 10] + ativos[a, 11], 0.01);
					PrbCasado = ativos[a, 12];
					ajxcb = ativos[a, 13];
					ajxx = ativos[a, 14];
					ax = ativos[a, 15];
					taxa_juros_cob = ativos[a, 16];
					taxa_juros_det = ativos[a, 17];

					if (&CdPlanBen = 4 | &CdPlanBen = 5) then 
						pxs = 1;
					else
						pxs = ativos[a, 5];

					despesaBUA = 0;
					despesaVP = 0;
					v = 0;
					vt = 0;
					
					if (tCobertura = tDeterministico) then do;
						tvt = 0;
						pagamento = max(0, round((BenLiqCobAtc / &FtBenEnti) * apx * &NroBenAno, 0.01));

						if (&CdPlanBen = 2) then do;
							despesaBUA = max(0, round(((BenTotCobAtc * (axcb + &CtFamPens * PrbCasado * (ajxcb - ajxx)) * &NroBenAno) + ((BenTotCobAtc / &FtBenEnti) * (ax * &peculioMorteAssistido))) * apx * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
						else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
							despesaBUA = max(0, round(VlSdoConTotal * apx * &percentualSaqueBUA * &percentualBUA, 0.01));
						end;
					end;
					else do;
						pagamento = round(max(0, pagamento * (1 + &PrTxBenef)), 0.01);
					end;

					despesa = round(max(0, ((pagamento + despesaBUA) * px * pxs), 0.01));

					v = max(0, 1 / ((1 + taxa_juros_cob) ** tCobertura));
					vt = max(0, 1 / ((1 + taxa_juros_det) ** tvt));

					if (tCobertura = tDeterministico) then do;
						despesaVP = max(0, round(((pagamento * px * vt * &FtBenEnti) - (&Fb * pagamento * &FtBenEnti)) * pxs * v + despesaBUA * v * pxs, 0.01));
					end;
					else do;
						despesaVP = max(0, round(pagamento * px * vt * pxs * v * &FtBenEnti, 0.01));
					end;

					tvt = tvt + 1;

					fluxoDeter[a, 1] = ativos[a, 1];
					fluxoDeter[a, 2] = ativos[a, 2];
					fluxoDeter[a, 3] = ativos[a, 3];
					fluxoDeter[a, 4] = pagamento;
					fluxoDeter[a, 5] = despesaBUA;
					fluxoDeter[a, 6] = despesa;
					fluxoDeter[a, 7] = despesaVP;
					fluxoDeter[a, 8] = v;
					fluxoDeter[a, 9] = vt;
				END;

				create work.atc_deterministico_ativos from fluxoDeter[colname={'id_participante' 'tCobertura' 'tDeterministico' 'PagamentoATC' 'PagamentoBuaATC' 'DespesaATC' 'DespesaVpATC' 'v_ATC' 'vt_ATC'}];
					append from fluxoDeter;
				close;

				free ativos fluxoDeter;
			end;
		quit;

		data determin.atc_ativos&a.;
			merge determin.atc_ativos&a. work.atc_deterministico_ativos;
			format PagamentoATC commax14.2 PagamentoBuaATC commax14.2 DespesaATC commax14.2 DespesaVpATC commax14.2 v_ATC 12.8 vt_ATC 12.8;
		run;
	%end;

	proc delete data = work.atc_deterministico_ativos;
%mend;
%calcDeterministicoAtc;

%_eg_conditional_dropds(determin.atc_ativos);
data determin.atc_ativos;
	set determin.atc_ativos1 - determin.atc_ativos&numberOfBlocksAtivos;
run;

proc datasets nodetails library=determin;
   delete atc_ativos1 - atc_ativos&numberOfBlocksAtivos;
run;

%_eg_conditional_dropds(determin.atc_despesa_ativos);
proc summary data = determin.atc_ativos;
 class tDeterministico;
 var DespesaATC DespesaVpATC;
 output out=determin.atc_despesa_ativos sum=;
run;

/*data determin.atc_despesa_ativos;
	set determin.atc_despesa_ativos;
	if cmiss(tDeterministico) then delete;
	drop _TYPE_ _FREQ_;
run;*/

/*%_eg_conditional_dropds(work.atc_despesa_deter_ativos);
proc summary data = determin.atc_ativos;
 class tDeterministico tCobertura;
 var DespesaATC;
 output out=work.atc_despesa_deter_ativos sum=;
run;*/

%_eg_conditional_dropds(work.atc_despesa_deter_ativos)
proc sql;
	create table work.atc_despesa_deter_ativos as
	select t1.tCobertura, t1.tDeterministico, sum(DespesaATC) format=commax18.2 as DespesaATC
	from determin.atc_ativos t1
	group by t1.tDeterministico, t1.tCobertura
	order by t1.tCobertura, t1.tDeterministico;
run;

%_eg_conditional_dropds(WORK.TRNSTransposedATC_DESPESA_DETER_,
		WORK.SORTTempTableSorted);
/* -------------------------------------------------------------------
   Sort data set WORK.ATC_DESPESA_DETER_ATIVOS
   ------------------------------------------------------------------- */
PROC SORT
	DATA=WORK.ATC_DESPESA_DETER_ATIVOS(KEEP=DespesaATC tDeterministico)
	OUT=WORK.SORTTempTableSorted
	;
	BY tDeterministico;
RUN;
PROC TRANSPOSE DATA=WORK.SORTTempTableSorted
	OUT=determin.ATC_DESPESA_DETER_ATIVOS(drop = Source)
	PREFIX=Column
	NAME=Source
	LABEL=Label
;
	BY tDeterministico;
	VAR DespesaATC;
RUN; QUIT;
%_eg_conditional_dropds(WORK.SORTTempTableSorted, work.atc_despesa_deter_ativos);

%_eg_conditional_dropds(determin.atc_encargo_ativos);
proc summary data = determin.atc_ativos;
 class id_participante;
 var DespesaVpATC;
 output out=determin.atc_encargo_ativos sum=;
run;

data determin.atc_encargo_ativos;
	set determin.atc_encargo_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;

%macro gravaMemoriaCalculo;
	%if (&isGravaMemoriaCalculo = 0) %then %do;
		proc datasets nodetails library=determin;
		   *delete atc_ativos1 - atc_ativos&numberOfBlocksAtivos;
		   delete atc_ativos;
		   *delete atc_encargo_ativos;
		run;
	%end;
%mend;
%gravaMemoriaCalculo;