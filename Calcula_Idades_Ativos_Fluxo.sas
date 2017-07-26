
%_eg_conditional_dropds(work.ativos_idades_fluxo);
PROC IML;
	USE cobertur.ativos;
		read all var {id_participante t IddParticCobert IddConjugCobert} into ativos;
	CLOSE cobertur.ativos;

	qtsObs = nrow(ativos);

	if (qtsObs > 0) then do;
		qtdEvol = 0;
		b = 1;

		DO a = 1 TO qtsObs;
			IddPartEvol = ativos[a, 3];
			qtdEvol = qtdEvol + ((&MaxAge - IddPartEvol) + 1);
		END;

		idade_deterministico = J(qtdEvol, 5, 0);

		DO a = 1 TO qtsObs;
			IdParticipante = ativos[a, 1];
			t_cober = ativos[a, 2];
			IddPartEvol = ativos[a, 3];
			IddConjEvol = ativos[a, 4];
			c = 0;
			t_fluxo = t_cober;

			DO i = IddPartEvol to &MaxAge;
				*------ Idade do participante na evolucao ------*;
				*i = min(IddPartEvol + c, &MaxAgeDeterministicoAtivos);
				*------ Idade do conjuce na evolucao ------*;
				j = min(IddConjEvol + (i - IddPartEvol), &MaxAge);

				idade_deterministico[b, 1] = IdParticipante;
				idade_deterministico[b, 2] = t_cober;
				idade_deterministico[b, 3] = t_fluxo;
				idade_deterministico[b, 4] = i;
				idade_deterministico[b, 5] = j;
				b = b + 1;
				t_fluxo = t_fluxo + 1;
			END;
		END;

		create work.ativos_idades_fluxo from idade_deterministico[colname={'id_participante' 't' 'tFluxo' 'IddParticFluxo' 'IddConjugFluxo'}];
			append from idade_deterministico;
		close work.ativos_idades_fluxo;

		free idade_deterministico ativos;
	end;
QUIT;

%_eg_conditional_dropds(work.ativos_fluxo);
data work.ativos_fluxo;
	merge cobertur.ativos work.ativos_idades_fluxo;
	by id_participante t;
	keep id_participante t tFluxo CdSexoPartic IddPartiCalc IddParticCobert IddParticFluxo CdSexoConjug IddConjugCobert IddConjugFluxo;
run;

%_eg_conditional_dropds(fluxo.ativos_fatores);
proc sql;
	create table fluxo.ativos_fatores as
	select t1.id_participante,
		   t1.t,
		   t1.tFluxo,
		   max(0, (t5.lx / t6.lx)) format=12.8 as px,
		   max(0, (t9.lxs / t10.lxs)) format=12.8 as pxs,
		   max(0, ((t5.Nxcb / t5.Dxcb) - &Fb)) format=12.8 as axcb,
		   (case 
				when (t1.tFluxo = 0 or (&CdPlanBen = 4 | &CdPlanBen = 5))
					then t5.apxa
					else t5.apx
			end) format=12.8 as apx,
			t5.apxa,
			(case
				when t1.t = t1.tFluxo
					then max(0, ((t7.Nxcb / t7.Dxcb) - &Fb))
					else 0
			end) format=12.8 as ajxcb,
			(case
				when t1.t = t1.tFluxo
					then max(0, ((n1.njxx / d1.djxx) - &Fb))
					else 0
			end) format=12.8 as ajxx,
			(case
				when t1.t = t1.tFluxo
					then max(0, (t6.Mx / t6.'Dx*'n))
					else 0
			end) format=12.8 as Ax,
			max(0, (t7.lx / t8.lx)) format=12.8 as pjx,
			t5.dx,
			t6.lx,
			t11.qx,
			t5.dxii,
			t6.lxii,
			max(0, (t5.lxii / t6.lxii)) format=12.8 as pxii,
			max(0, ((t5.Nxiicb / t5.Dxiicb) - &Fb)) format=12.8 as axiicb,
			(case
				when t1.t = t1.tFluxo
					then t9.ix
					else 0
			end) format=12.8 as ix,
/*			(case*/
/*				when t1.t = t1.tFluxo*/
/*					then max(0, ((t8.Nxcb / t8.Dxcb) - &Fb))*/
/*					else 0*/
/*			end) format=12.8 as ajxcb,*/
			(case
				when t1.t = t1.tFluxo
				then max(0, (t6.Mxii / t6.'Dxii*'n))
				else 0
			end) format=12.8 as Axii,
			(case
				when t1.t = t1.tFluxo
				then max(0, ((n2.njxx / d2.djxx) - &Fb))
				else 0
			end) format=12.8 as ajxx_i
	from work.ativos_fluxo t1
	inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t1.IddParticFluxo = t5.Idade and t5.t = min(t1.tFluxo, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t1.IddParticCobert = t6.Idade and t6.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal t7 on (t1.CdSexoConjug = t7.Sexo and t1.IddConjugFluxo = t7.Idade and t7.t = min(t1.tFluxo, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal t8 on (t1.CdSexoConjug = t8.Sexo and t1.IddConjugCobert = t8.Idade and t8.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t1.IddParticCobert = t9.Idade and t9.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = 0)
	inner join tabuas.tabuas_servico_ajustada t11 on (t1.CdSexoPartic = t11.Sexo and t1.IddParticFluxo = t11.Idade and t11.t = min(t1.tFluxo, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n1 on (t1.CdSexoPartic = n1.sexo and t1.IddParticCobert = n1.idade_x and t1.IddConjugCobert = n1.idade_j and n1.tipo = 1 and n1.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d1 on (t1.CdSexoPartic = d1.sexo and t1.IddParticCobert = d1.idade_x and t1.IddConjugCobert = d1.idade_j and d1.tipo = 1 and d1.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n2 on (t1.CdSexoPartic = n2.sexo and t1.IddParticCobert = n2.idade_x and t1.IddConjugCobert = n2.idade_j and n2.tipo = 2 and n2.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d2 on (t1.CdSexoPartic = d2.sexo and t1.IddParticCobert = d2.idade_x and t1.IddConjugCobert = d2.idade_j and d2.tipo = 2 and d2.t = min(t1.t, &maxTaxaJuros))
	order by t1.id_participante, t1.t, t1.tFluxo;
run;

%macro calculaIdadeFluxo;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(fluxo.ativos_tp&tipoCalculo._s&s.);
		data fluxo.ativos_tp&tipoCalculo._s&s.;
			retain id_participante t tFluxo;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_idades_fluxo;
			by id_participante t;
			drop PeFatReduPbe DtAdesaoPlan VlBenSaldado DtIniBenInss VlBenefiInss IddIniApoInss IddParticCobert SalConPrjEvol ConParSdoEvol ConPatSdoEvol SalBenefInssEvol SalProjeInssEvol ConPrvCobATC BenTotCobPTC ConPrvCobPTC ConPvdCobAIV BenTotCobPIV ConPvdCobPIV ConPvdCobPPA CusNorCobAXFA BenefCobAxfi CusNorCobAXFI IddParticFluxo IddConjugFluxo;
			*keep id_participante t tFluxo BenLiqCobATC BenTotCobATC BenLiqCobPtc VlSdoConPartEvol VlSdoConPatrEvol PrbCasado IddParticCobert IddConjugCobert IddParticFluxo IddConjugFluxo CdSexoPartic IddPartiCalc CdSexoConjug FLG_MANUTENCAO_SALDO BenLiqCobAIV BenTotCobAIV AplicarPxsAIV BenLiqCobPIV AplicarPxsPIV BenLiqCobPPA BenTotCobPPA AplicarPxsPPA SalConPrjEvol;
		run;

		/*%_eg_conditional_dropds(fluxo.ativos_fatores_tp&tipoCalculo._s&s.);
		proc sql;
			create table fluxo.ativos_fatores_tp&tipoCalculo._s&s. as
			select t1.id_participante,
				   t1.t,
				   t1.tFluxo,
				   max(0, (t5.lx / t6.lx)) format=12.8 as px,
				   max(0, (t9.lxs / t10.lxs)) format=12.8 as pxs,
				   max(0, ((t5.Nxcb / t5.Dxcb) - &Fb)) format=12.8 as axcb,
				   (case 
						when (t1.tFluxo = 0 or (&CdPlanBen = 4 | &CdPlanBen = 5))
							then t5.apxa
							else t5.apx
					end) format=12.8 as apx,
					t5.apxa,
					(case
						when t1.t = t1.tFluxo
							then max(0, ((t7.Nxcb / t7.Dxcb) - &Fb))
							else 0
					end) format=12.8 as ajxcb,
					(case
						when t1.t = t1.tFluxo
							then max(0, ((n1.njxx / d1.djxx) - &Fb))
							else 0
					end) format=12.8 as ajxx,
					(case
						when t1.t = t1.tFluxo
							then max(0, (t6.Mx / t6.'Dx*'n))
							else 0
					end) format=12.8 as Ax,
					max(0, (t7.lx / t8.lx)) format=12.8 as pjx,
					t5.dx,
					t6.lx,
					t11.qx,
					t5.dxii,
					t6.lxii,
					max(0, (t5.lxii / t6.lxii)) format=12.8 as pxii,
					max(0, ((t5.Nxiicb / t5.Dxiicb) - &Fb)) format=12.8 as axiicb,
					(case
						when t1.t = t1.tFluxo
							then t9.ix
							else 0
					end) format=12.8 as ix,
					(case
						when t1.t = t1.tFluxo
							then max(0, ((t8.Nxcb / t8.Dxcb) - &Fb))
							else 0
					end) format=12.8 as ajxcb,
					(case
						when t1.t = t1.tFluxo
						then max(0, (t6.Mxii / t6.'Dxii*'n))
						else 0
					end) format=12.8 as Axii,
					(case
						when t1.t = t1.tFluxo
						then max(0, ((n2.njxx / d2.djxx) - &Fb)) 
						else 0
					end) format=12.8 as ajxx_i,
					txc.taxa_juros as taxa_juros_cober,
					txd.taxa_juros as taxa_juros_fluxo
			from fluxo.ativos_tp&tipoCalculo._s&s. t1
			inner join tabuas.tabuas_servico_normal t5 on (t1.CdSexoPartic = t5.Sexo and t1.IddParticFluxo = t5.Idade and t5.t = min(t1.tFluxo, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t6 on (t1.CdSexoPartic = t6.Sexo and t1.IddParticCobert = t6.Idade and t6.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t7 on (t1.CdSexoConjug = t7.Sexo and t1.IddConjugFluxo = t7.Idade and t7.t = min(t1.tFluxo, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_normal t8 on (t1.CdSexoConjug = t8.Sexo and t1.IddConjugCobert = t8.Idade and t8.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t1.IddParticCobert = t9.Idade and t9.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = 0)
			inner join tabuas.tabuas_servico_ajustada t11 on (t1.CdSexoPartic = t11.Sexo and t1.IddParticFluxo = t11.Idade and t11.t = min(t1.tFluxo, &maxTaxaJuros))
			inner join tabuas.tabuas_pensao_njxx n1 on (t1.CdSexoPartic = n1.sexo and t1.IddParticCobert = n1.idade_x and t1.IddConjugCobert = n1.idade_j and n1.tipo = 1 and n1.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_pensao_djxx d1 on (t1.CdSexoPartic = d1.sexo and t1.IddParticCobert = d1.idade_x and t1.IddConjugCobert = d1.idade_j and d1.tipo = 1 and d1.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_pensao_njxx n2 on (t1.CdSexoPartic = n2.sexo and t1.IddParticCobert = n2.idade_x and t1.IddConjugCobert = n2.idade_j and n2.tipo = 2 and n2.t = min(t1.t, &maxTaxaJuros))
			inner join tabuas.tabuas_pensao_djxx d2 on (t1.CdSexoPartic = d2.sexo and t1.IddParticCobert = d2.idade_x and t1.IddConjugCobert = d2.idade_j and d2.tipo = 2 and d2.t = min(t1.t, &maxTaxaJuros))
			inner join premissa.taxa_juros_tp&tipoCalculo._s&s. txc on (txc.t = min(t1.t, &maxTaxaJuros))
			inner join premissa.taxa_juros_tp&tipoCalculo._s&s. txd on (txd.t = min(t1.tFluxo, &maxTaxaJuros))
			order by t1.id_participante, t1.t, t1.tFluxo;
		run;*/

		%if (&tipoCalculo = 2) %then %do;
/*			data fluxo.ativos_fatores_tp&tipoCalculo._s&s.;*/
/*				merge fluxo.ativos_fatores_tp&tipoCalculo._s&s.(in=tFluxo) temp.ativos_fatores_estoc_tp&tipoCalculo._s&s.(in=t);*/
/*				by id_participante;*/
/*				if tFluxo & t;*/
/*				*t = tFluxo;*/
/*			run;*/
			%_eg_conditional_dropds(fluxo.ativos_fatores_estoc_s&s.);
			proc sql;
				create table fluxo.ativos_fatores_estoc_s&s. as
				select t2.vivo, t2.Morto, t2.Invalido, t2.ativo, t2.ligado, t2.valido, t3.aposentadoria
				from work.ativos_fluxo t1
				inner join cobertur.ativos_fatores_estoc_s&s. t2 on (t1.id_participante = t2.id_participante and t1.tFluxo = t2.t)
				inner join cobertur.ativos_fatores_estoc_s&s. t3 on (t1.id_participante = t3.id_participante and t1.t = t3.t)
				order by t1.id_participante, t1.t, t1.tFluxo;
			run; quit;
		%end;
	%end;
%mend;
%calculaIdadeFluxo;

/*proc datasets library=temp kill memtype=data nolist;*/
proc datasets library=work kill memtype=data nolist;
	run;
quit;
