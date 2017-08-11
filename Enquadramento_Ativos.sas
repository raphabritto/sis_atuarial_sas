*-- Programa para cálculo de cobertura para ativos                                                   		--*;
*-- Regime de financiamento de capitalização                                                                --*;
*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*;
*-- Versão: 11 de março de 2013                                                                             --*;

%let vRoundCobertura = 0.0000000001;
%let vRoundMoeda = 0.01;
%let vBasis = 'ACT/ACT';
%let vAlignment = 'S';

/*proc iml;*/
/*	x = do(1, 50, 1);*/
/*	j = 51:100;*/
/*	z = x // j;*/
/*	x = t(x);*/
/*	j = t(j);*/
/*	print x;*/
/*	print j;*/
/**/
/*	use work.reajuste_salarial;*/
/*		read all var {ID_PATROCINADORA PC_REAJUSTE} into reajuste_salarial[colname={'patroc' 'valor'}] where (CD_TIPO_REAJUSTE_SALARIAL = 1);*/
/*	close;*/
/**/
/*	slice = reajuste_salarial[(reajuste_salarial = 91008), 2];*/
/*	slice = colvec(reajuste_salarial);*/
/**/
/*	print z;*/
/*quit;*/

%_eg_conditional_dropds(work.ativos_enquadramento);
PROC IML;
	USE partic.ATIVOS;
		read all var {id_participante} into id_participante;
		read all var {DtNascPartic} into data_nasc_partic;
		read all var {CdSexoPartic} into sexo_partic;
		read all var {CdPatrocPlan} into CdPatrocPlan;
		read all var {DtAdmPatroci} into DtAdmPatroci;
		read all var {DtAssEntPrev} into DtAssEntPrev;
		read all var {PeFatReduPbe} into PeFatReduPbe;
/*		read all var {CdParEntPrev} into CdParEntPrev;*/
		read all var {DtAdesaoPlan} into DtAdesaoPlan;
		read all var {VlSalEntPrev} into VlSalEntPrev;
		read all var {PeContrParti} into PeContrParti;
		read all var {PeContrPatro} into PeContrPatro;
		read all var {VlSdoConPart} into VlSdoConPart;
		read all var {VlSdoConPatr} into VlSdoConPatr;
		read all var {VlBenSaldado} into VlBenSaldado;
		read all var {DtIniBenInss} into DtIniBenInss;
		read all var {VlBenefiInss} into VlBenefiInss;
		read all var {DtNascConjug} into DtNascConjug;
		read all var {CdSexoConjug} into sexo_conjug;
	CLOSE partic.ATIVOS;

	qtdObs = nrow(id_participante);

	if (qtdObs > 0) then do;
		*enquadramento = J(qtdObs, 20, 0);

		idade_partic	= J(qtdObs, 1, .);
		idade_conjug 	= J(qtdObs, 1, .);
		IddApoEntPre 	= J(qtdObs, 1, 0);
		IddIniciInss 	= J(qtdObs, 1, 0);
		IddAdmPatroc	= J(qtdObs, 1, .);
		IddAssEntPre	= J(qtdObs, 1, .);
		TmpContribInss 	= J(qtdObs, 1, 0);
		TmpInssTotal 	= J(qtdObs, 1, 0);
		DtIniApoInss 	= J(qtdObs, 1, .);
		DifConjug 		= J(qtdObs, 1, 0);
		IddApoEntPre 	= J(qtdObs, 1, 0);
		IddIniciInss 	= J(qtdObs, 1, 0);
		TmpContribInss	= J(qtdObs, 1, 0);
		DifConjug 		= J(qtdObs, 1, 0);
		probab_casado 	= J(qtdObs, 1, 0);
		TmpPlanoRest 	= J(qtdObs, 1, 0);
		DtIniContInss	= J(qtdObs, 1, .);
		IddIniApoInss	= J(qtdObs, 1, .);
		TmpPlanoPrev	= J(qtdObs, 1, .);
		DtApoEntPrev	= J(qtdObs, 1, .);
		TmpInssCalcu	= J(qtdObs, 1, 0);
		TmpInssResto	= J(qtdObs, 1, 0);
		TmpAdmIns		= J(qtdObs, 1, 0);

		*---- início do loop para correr todas as linhas da tabela de dados ----*;
		DO n = 1 TO qtdObs;
			if (sexo_partic[n] = 1) then do;
				IddApoEntPre[n] 	= &NR_IDADE_INI_APOS_FEM;
				IddIniciInss[n] 	= &NR_IDADE_INI_CONT_INSS_FEM;
				TmpContribInss[n] 	= &NR_TEMPO_CONT_INSS_FEM;
				DifConjug[n] 		= &NR_DIFERENCIA_IDADE_CONJ_FEM;
				probab_casado[n] 		= &PC_PROB_PARTIC_CAS_APOS_FEM;
			end;
			else do;
				IddApoEntPre[n] 	= &NR_IDADE_INI_APOS_MAS;
				IddIniciInss[n] 	= &NR_IDADE_INI_CONT_INSS_MAS;
				TmpContribInss[n] 	= &NR_TEMPO_CONT_INSS_MAS;
				DifConjug[n] 		= &NR_DIFERENCIA_IDADE_CONJ_MAS;
				probab_casado[n] 		= &PC_PROB_PARTIC_CAS_APOS_MAS;
			end;

			*------ idade do ativos na data do cálculo ------*;
			idade_partic[n] = round(yrdif(data_nasc_partic[n], &DtCalAval, &vBasis));

			*------ idade do ativos na data de admissão na patrocinadora ------*;
	        IddAdmPatroc[n] = round(yrdif(data_nasc_partic[n], DtAdmPatroci[n], &vBasis));

			*------ idade do ativos na data de associação na entidade ------*;
	    	IddAssEntPre[n] = round(yrdif(data_nasc_partic[n], DtAssEntPrev[n], &vBasis));

			*------ idade de início no INSS ------*;
			IddIniciInss[n] = min(IddIniciInss[n], IddAdmPatroc[n]);

			*------ data de início da contribuicao INSS ------*;
			DtIniContInss[n] = INTNX('YEAR', data_nasc_partic[n], IddIniciInss[n], &vAlignment);

			*------ data de inicio do beneficio INSS - elegibilidade à aposentadoria integral no INSS ------*;
			if (DtIniBenInss[n] = .) then do;
				DtIniApoInss[n] = INTNX('YEAR', DtIniContInss[n], TmpContribInss[n], &vAlignment);
				DtIniApoInss[n] = max(DtIniApoInss[n], &DtCalAval);
			end;
			else
				DtIniApoInss[n] = DtIniBenInss[n];

			*------ idade na aposentadoria integral no INSS ------*;
			IddIniApoInss[n] = round(yrdif(data_nasc_partic[n], DtIniApoInss[n], &vBasis));

			*------ tempo de vinculação à patrocinadora ------*;
			if (&CdPlanBen = 1) then
				TmpPlanoPrev[n] = round(yrdif(DtAdmPatroci[n], &DtCalAval, &vBasis), 0.00000001);
			else
				TmpPlanoPrev[n] = round(yrdif(DtAssEntPrev[n], &DtCalAval, &vBasis), 0.00000001);

			*------ idade aposentadoria na entidade ------*;
			IddApoEntPre[n] = max(idade_partic[n], IddApoEntPre[n]);

			*------ data de elegibilidade à aposentadoria integral na entidade ------*;
			DtApoEntPrev[n] = INTNX('YEAR', data_nasc_partic[n], IddApoEntPre[n], &vAlignment);
			DtApoEntPrev[n] = max(DtApoEntPrev[n], &DtCalAval);

			*------ tempo restante de contribuição na entidade entre as datas do cálculo e de aposentadoria ------*;
			if (idade_partic[n] < IddApoEntPre[n]) then TmpPlanoRest[n] = max(0, round(IddApoEntPre[n] - idade_partic[n]));

			*------ Tempo de contribuição inss na data de cálculo ------*;
			TmpInssCalcu[n] = floor(yrdif(DtIniContInss[n], &DtCalAval, &vBasis));

			*------ Tempo de contribuição inss - maior valor entre o a premissa ou o tempo inss calculado ------*;
			TmpContribInss[n] = max(TmpContribInss[n], TmpInssCalcu[n]);

			*------ Tempo de contribuição inss restante ------*;
			TmpInssResto[n] = round(IddApoEntPre[n] - idade_partic[n]);
			
			*------ Tempo de contribuição inss total ------*;
			TmpInssTotal[n] = Round(TmpInssCalcu[n] + TmpInssResto[n]);

			if (sexo_partic[n] = 1) then do;
				idade_conjug[n] = idade_partic[n] + DifConjug[n];
				sexo_conjug[n] = 2;
			end;
			else do;
				idade_conjug[n] = idade_partic[n] - DifConjug[n];
				sexo_conjug[n] = 1;
			end;

			*---- Tempo de admissão na patrocinadora na data do cálculo ----;
			TmpAdmIns[n] = max(1, round(idade_partic[n] - IddAdmPatroc[n], &vRoundCobertura));
		END;

		create work.ativos_enquadramento var {id_participante idade_partic IddAdmPatroc IddAssEntPre TmpAdmIns DtIniApoInss IddIniciInss IddIniApoInss DtIniContInss probab_casado TmpInssCalcu TmpInssResto TmpInssTotal TmpContribInss DtApoEntPrev IddApoEntPre TmpPlanoPrev TmpPlanoRest sexo_conjug idade_conjug};
			append; 
		close work.ativos_enquadramento;
	end;
QUIT;

data partic.ativos;
	merge partic.ativos work.ativos_enquadramento;
	by id_participante;
	*CdSexoConjug = sexo_conjug;
	if (&CdPlanBen = 5) then
		VlSalEntPrev = min(VlSalEntPrev, &VL_MAX_SALARIO_CAIXA);
	format DtIniApoInss DDMMYY10. DtIniApoInss DDMMYY10. DtIniContInss DDMMYY10. DtApoEntPrev DDMMYY10.;
	*drop sexo_conjug;
	drop CdSexoConjug;
	rename CdSexoPartic = sexo_partic;
run;

PROC SORT DATA=partic.ativos OUT=partic.ativos;
  BY CdPatrocPlan;
RUN;

data partic.ativos;
	merge partic.ativos premissa.reajuste_salarial(where=(CD_TIPO_REAJUSTE_SALARIAL = 1));
	by CdPatrocPlan;
	if _n_ = 1 and ID_PARTICIPANTE = . then delete;
	drop CD_TIPO_REAJUSTE_SALARIAL;
run;

PROC SORT DATA=partic.ativos OUT=partic.ativos;
  BY id_participante;
RUN;

/*
proc sql;
	create table partic.ativos as
	select t1.*, t2.reajuste_salario
	from partic.ativos t1
	inner join premissa.reajuste_salarial t2 on (t1.CdPatrocPlan = t2.CdPatrocPlan)
	where t2.CD_TIPO_REAJUSTE_SALARIAL = 1
	order by t1.id_participante;
run; quit;
*/


/*proc datasets library=temp kill memtype=data nolist;*/
proc datasets library=work kill memtype=data nolist;
	run;
quit;

/*%_eg_conditional_dropds(work.ativos_blocos);*/
/*proc iml;*/
/*	use partic.ativos;*/
/*		read all var {id_participante} into ativos;*/
/*	close;*/
/**/
/*	numberObs = nrow(ativos);*/
/**/
/*	if (numberObs > 0) then do;*/
/*		blocosAtivos = j(numberObs, 2, 0);*/
/**/
/*		countRecords = 1;*/
/*		countBlocks = 1;*/
/**/
/*		do a = 1 to numberObs;*/
/*			blocosAtivos[a, 1] = ativos[a, 1];*/
/*			blocosAtivos[a, 2] = countBlocks;*/
/**/
/*			if (countRecords < &recordsPerBlockAtivos) then do;*/
/*				countRecords = countRecords + 1;*/
/*			end;*/
/*			else do;*/
/*				countRecords = 1;*/
/*				countBlocks = countBlocks + 1;*/
/*			end;*/
/*		end;*/
/**/
/*		create work.ativos_blocos from blocosAtivos[colname={'id_participante' 'id_bloco'}];*/
/*			append from blocosAtivos;*/
/*		close;*/
/*	*/
/*		call symputx('numberOfBlocksAtivos', countBlocks);*/
/*	end;*/
/*quit;*/

/*data partic.ativos;*/
/*	merge partic.ativos work.ativos_blocos;*/
/*	by id_participante;*/
/*run;*/

/*proc delete data = work.ativos_blocos;*/
