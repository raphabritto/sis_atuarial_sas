*-- Programa para c�lculo de cobertura para ativos                                                   		--*;
*-- Regime de financiamento de capitaliza��o                                                                --*;
*-- M�todo de financiamento do tipo cr�dito unit�rio projetado - PUC                                        --*;
*-- Vers�o: 11 de mar�o de 2013                                                                             --*;

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
		read all var {Id_Participante DtNascPartic CdSexoPartic CdPatrocPlan DtAdmPatroci DtAssEntPrev PeFatReduPbe CdParEntPrev DtAdesaoPlan VlSalEntPrev PeContrParti PeContrPatro VlSdoConPart VlSdoConPatr VlBenSaldado DtIniBenInss VlBenefiInss DtNascConjug CdSexoConjug DtNascFilJov CdSexoFilJov DtNascFilInv CdSexoFilInv} into ativos;
	CLOSE partic.ATIVOS;

	qtdObs = nrow(ativos);

	if (qtdObs > 0) then do;
		enquadramento = J(qtdObs, 20, 0);

		*---- in�cio do loop para correr todas as linhas da tabela de dados ----*;
		DO n = 1 TO qtdObs;
			idParticipante = ativos[n, 1];
			DtNascPartic = ativos[n, 2];
			CdSexoPartic = ativos[n, 3];
			CdPatrocPlan = ativos[n, 4];
			DtAdmPatroci = ativos[n, 5];
			DtAssEntPrev = ativos[n, 6];
			PeFatReduPbe = ativos[n, 7];
			CdParEntPrev = ativos[n, 8];
			DtAdesaoPlan = ativos[n, 9];
			*VlSalEntPrev = ativos[n, 10];
			PeContrParti = ativos[n, 11];
			PeContrPatro = ativos[n, 12];
			VlSdoConPart = ativos[n, 13];
			VlSdoConPatr = ativos[n, 14];
			VlBenSaldado = ativos[n, 15];
			DtIniBenInss = ativos[n, 16];
			VlBenefiInss = ativos[n, 17];
			DtNascConjug = ativos[n, 18];
			CdSexoConjug = ativos[n, 19];

			IddConjuCalc = .;

			IddApoEntPre = 0;
			IddIniciInss = 0;
			TmpContribInss = 0;
			TmpInssTotal = 0;
			DtIniApoInss = .;
			DifConjug = 0;

			if (CdSexoPartic = 1) then do;
				IddApoEntPre = &NR_IDADE_INI_APOS_FEM;
				IddIniciInss = &NR_IDADE_INI_CONT_INSS_FEM;
				TmpContribInss = &NR_TEMPO_CONT_INSS_FEM;
				DifConjug = &NR_DIFERENCIA_IDADE_CONJ_FEM;
				PrbCasado = &PC_PROB_PARTIC_CAS_APOS_FEM;
			end;
			else do;
				IddApoEntPre = &NR_IDADE_INI_APOS_MAS;
				IddIniciInss = &NR_IDADE_INI_CONT_INSS_MAS;
				TmpContribInss = &NR_TEMPO_CONT_INSS_MAS;
				DifConjug = &NR_DIFERENCIA_IDADE_CONJ_MAS;
				PrbCasado = &PC_PROB_PARTIC_CAS_APOS_MAS;
			end;

			*------ idade do ativos na data do c�lculo ------*;
			IddPartiCalc = round(yrdif(DtNascPartic, &DtCalAval, &vBasis));
/*			IddPartiFrac = round(yrdif(DtNascPartic, &DtCalAval, &vBasis), 0.00000001);*/

			*------ idade do ativos na data de admiss�o na patrocinadora ------*;
	        IddAdmPatroc = round(yrdif(DtNascPartic, DtAdmPatroci, &vBasis));
/*	        IddAdmFracao = round(yrdif(DtNascPartic, DtAdmPatroci, &vBasis), 0.00000001);*/

			*------ idade do ativos na data de associa��o na entidade ------*;
	    	IddAssEntPre = round(yrdif(DtNascPartic, DtAssEntPrev, &vBasis));

			*------ idade de in�cio no INSS ------*;
			IddIniciInss = min(IddIniciInss, IddAdmPatroc);

			*------ data de in�cio da contribuicao INSS ------*;
			DtIniContInss = INTNX('YEAR', DtNascPartic, IddIniciInss, &vAlignment);

			*------ data de inicio do beneficio INSS - elegibilidade � aposentadoria integral no INSS ------*;
			if (DtIniBenInss = .) then do;
				DtIniApoInss = INTNX('YEAR', DtIniContInss, TmpContribInss, &vAlignment);
				DtIniApoInss = max(DtIniApoInss, &DtCalAval);
			end;
			else
				DtIniApoInss = DtIniBenInss;

			*------ idade na aposentadoria integral no INSS ------*;
			IddIniApoInss = round(yrdif(DtNascPartic, DtIniApoInss, &vBasis));

			*------ tempo de vincula��o � patrocinadora ------*;
			if (&CdPlanBen = 1) then
				TmpPlanoPrev = round(yrdif(DtAdmPatroci, &DtCalAval, &vBasis), 0.00000001);
			else
				TmpPlanoPrev = round(yrdif(DtAssEntPrev, &DtCalAval, &vBasis), 0.00000001);

			*------ idade aposentadoria na entidade ------*;
			IddApoEntPre = max(IddPartiCalc, IddApoEntPre);

			*------ data de elegibilidade � aposentadoria integral na entidade ------*;
			DtApoEntPrev = INTNX('YEAR', DtNascPartic, IddApoEntPre, &vAlignment);
			DtApoEntPrev = max(DtApoEntPrev, &DtCalAval);

			*------ tempo restante de contribui��o na entidade entre as datas do c�lculo e de aposentadoria ------*;
			TmpPlanoRest = 0;
/*			if (IddPartiFrac < IddApoEntPre) then TmpPlanoRest = max(0, round(IddApoEntPre - IddPartiCalc));*/
			if (IddPartiCalc < IddApoEntPre) then TmpPlanoRest = max(0, round(IddApoEntPre - IddPartiCalc));

			*------ Tempo de contribui��o inss na data de c�lculo ------*;
			TmpInssCalcu = floor(yrdif(DtIniContInss, &DtCalAval, &vBasis));

			*------ Tempo de contribui��o inss - maior valor entre o a premissa ou o tempo inss calculado ------*;
			TmpContribInss = max(TmpContribInss, TmpInssCalcu);

			*------ Tempo de contribui��o inss restante ------*;
			TmpInssResto = round(IddApoEntPre - IddPartiCalc);
			
			*------ Tempo de contribui��o inss total ------*;
			TmpInssTotal = Round(TmpInssCalcu + TmpInssResto);

			if (CdSexoPartic = 1) then do;
				IddConjuCalc = IddPartiCalc + DifConjug;
				CdSexoConjug = 2;
			end;
			else do;
				IddConjuCalc = IddPartiCalc - DifConjug;
				CdSexoConjug = 1;
			end;

			*---- Tempo de admiss�o na patrocinadora na data do c�lculo ----;
/*			TmpAdmIns = max(1, round(IddPartiFrac - IddAdmFracao, &vRoundCobertura));*/
			TmpAdmIns = max(1, round(IddPartiCalc - IddAdmPatroc, &vRoundCobertura));

			enquadramento[n, 1] = idParticipante;
			enquadramento[n, 2] = IddPartiCalc;
			enquadramento[n, 3] = IddAdmPatroc;
			enquadramento[n, 4] = IddAssEntPre;
			enquadramento[n, 5] = TmpAdmIns;
			enquadramento[n, 6] = DtIniApoInss;
			enquadramento[n, 7] = IddIniciInss;
			enquadramento[n, 8] = IddIniApoInss;
			enquadramento[n, 9] = DtIniContInss;
			enquadramento[n, 10] = PrbCasado;
			enquadramento[n, 11] = TmpInssCalcu;
			enquadramento[n, 12] = TmpInssResto;
			enquadramento[n, 13] = TmpInssTotal;
			enquadramento[n, 14] = TmpContribInss;
			enquadramento[n, 15] = DtApoEntPrev;
			enquadramento[n, 16] = IddApoEntPre;
			enquadramento[n, 17] = TmpPlanoPrev;
			enquadramento[n, 18] = TmpPlanoRest;
			enquadramento[n, 19] = CdSexoConjug;
			enquadramento[n, 20] = IddConjuCalc;
/*			enquadramento[n, 3] = IddPartiFrac;*/
/*			enquadramento[n, 5] = IddAdmFracao;*/
		END;

		create work.ativos_enquadramento from enquadramento[colname={'id_participante' 'IddPartiCalc' 'IddAdmPatroc' 'IddAssEntPre' 'TmpAdmIns' 'DtIniApoInss' 'IddIniciInss' 'IddIniApoInss' 'DtIniContInss' 'PrbCasado' 'TmpInssCalcu' 'TmpInssResto' 'TmpInssTotal' 'TmpContribInss' 'DtApoEntPrev' 'IddApoEntPre' 'TmpPlanoPrev' 'TmpPlanoRest' 'CdSexoConjugTmp' 'IddConjuCalc'}];
			append from enquadramento;
		close work.ativos_enquadramento;

		free enquadramento ativos;
	end;
QUIT;

data partic.ativos;
	merge partic.ativos work.ativos_enquadramento;
	by id_participante;
	CdSexoConjug = CdSexoConjugTmp;
	if (&CdPlanBen = 5) then
		VlSalEntPrev = min(VlSalEntPrev, &VL_MAX_SALARIO_CAIXA);
	format DtIniApoInss DDMMYY10. DtIniApoInss DDMMYY10. DtIniContInss DDMMYY10. DtApoEntPrev DDMMYY10.;
	drop CdSexoConjugTmp;
run;

data partic.ativos;
	merge partic.ativos premissa.reajuste_salarial(where=(CD_TIPO_REAJUSTE_SALARIAL = 1));
	by CdPatrocPlan;
	if _n_ = 1 and ID_PARTICIPANTE = . then delete;
	drop CD_TIPO_REAJUSTE_SALARIAL;
run;

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