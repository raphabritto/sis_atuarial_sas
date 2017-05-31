*-- Programa para cálculo de cobertura para ativos                                                   		--*;
*-- Regime de financiamento de capitalização                                                                --*;
*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*;
*-- Versão: 11 de março de 2013                                                                             --*;

%let vRoundCobertura = 0.0000000001;
%let vRoundMoeda = 0.01;
%LET vBasis = 'ACT/ACT';
%LET vAlignment = 'S';

%_eg_conditional_dropds(work.ativos_enquadramento_tmp);
PROC IML;
	USE work.ATIVOS;
		read all var {Id_Participante DtNascPartic CdSexoPartic CdPatrocPlan DtAdmPatroci DtAssEntPrev PeFatReduPbe CdParEntPrev DtAdesaoPlan VlSalEntPrev PeContrParti PeContrPatro VlSdoConPart VlSdoConPatr VlBenSaldado DtIniBenInss VlBenefiInss DtNascConjug CdSexoConjug DtNascFilJov CdSexoFilJov DtNascFilInv CdSexoFilInv} into ativos;
	CLOSE;

	qtdObs = nrow(ativos);

	if (qtdObs > 0) then do;
		enquadramento = J(qtdObs, 27, 0);

		*---- início do loop para correr todas as linhas da tabela de dados ----*;
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
			DtNascFilJov = ativos[n, 20];
			CdSexoFilJov = ativos[n, 21];
			DtNascFilInv = ativos[n, 22];
			CdSexoFilInv = ativos[n, 23];

			IddFilJovCalc = .;
			IddConjuCalc = .;
			IddFilInvCalc = .;
			IddCjgApoEnt = .;
			IddFilJovApoEnt = .;
			IddFilInvApoEnt = .;

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

			*------ idade do ativos na data do cálculo ------*;
			IddPartiCalc = round(yrdif(DtNascPartic, &DtCalAval, &vBasis));
			IddPartiFrac = round(yrdif(DtNascPartic, &DtCalAval, &vBasis), 0.00000001);

			*------ idade do ativos na data de admissão na patrocinadora ------*;
	        IddAdmPatroc = round(yrdif(DtNascPartic, DtAdmPatroci, &vBasis));
	        IddAdmFracao = round(yrdif(DtNascPartic, DtAdmPatroci, &vBasis), 0.00000001);

			*------ idade do ativos na data de associação na entidade ------*;
	    	IddAssEntPre = round(yrdif(DtNascPartic, DtAssEntPrev, &vBasis));

			*------ idade de início no INSS ------*;
			IddIniciInss = min(IddIniciInss, IddAdmPatroc);

			*------ data de início da contribuicao INSS ------*;
			DtIniContInss = INTNX('YEAR', DtNascPartic, IddIniciInss, &vAlignment);

			*------ data de inicio do beneficio INSS - elegibilidade à aposentadoria integral no INSS ------*;
			if (DtIniBenInss = .) then do;
				DtIniApoInss = INTNX('YEAR', DtIniContInss, TmpContribInss, &vAlignment);
				DtIniApoInss = max(DtIniApoInss, &DtCalAval);
			end;
			else
				DtIniApoInss = DtIniBenInss;

			*------ idade na aposentadoria integral no INSS ------*;
			IddIniApoInss = round(yrdif(DtNascPartic, DtIniApoInss, &vBasis));

			*------ tempo de vinculação à patrocinadora ------*;
			if (&CdPlanBen = 1) then
				TmpPlanoPrev = round(yrdif(DtAdmPatroci, &DtCalAval, &vBasis), 0.00000001);
			else
				TmpPlanoPrev = round(yrdif(DtAssEntPrev, &DtCalAval, &vBasis), 0.00000001);

			*------ idade aposentadoria na entidade ------*;
			IddApoEntPre = max(IddPartiCalc, IddApoEntPre);

			*------ data de elegibilidade à aposentadoria integral na entidade ------*;
			DtApoEntPrev = INTNX('YEAR', DtNascPartic, IddApoEntPre, &vAlignment);
			DtApoEntPrev = max(DtApoEntPrev, &DtCalAval);

			*------ tempo restante de contribuição na entidade entre as datas do cálculo e de aposentadoria ------*;
			TmpPlanoRest = 0;
			if (IddPartiFrac < IddApoEntPre) then TmpPlanoRest = max(0, round(IddApoEntPre - IddPartiCalc));

			*------ Tempo de contribuição inss na data de cálculo ------*;
			TmpInssCalcu = floor(yrdif(DtIniContInss, &DtCalAval, &vBasis));

			*------ Tempo de contribuição inss - maior valor entre o a premissa ou o tempo inss calculado ------*;
			TmpContribInss = max(TmpContribInss, TmpInssCalcu);

			*------ Tempo de contribuição inss restante ------*;
			TmpInssResto = round(IddApoEntPre - IddPartiCalc);
			
			*------ Tempo de contribuição inss total ------*;
			TmpInssTotal = Round(TmpInssCalcu + TmpInssResto);

			if (&CD_COMPOSICAO_FAMILIAR = 1) then do;
				if (CdSexoPartic = 1) then do;
					IddConjuCalc = IddPartiCalc + DifConjug;
					IddCjgApoEnt = IddApoEntPre + DifConjug;
					CdSexoConjug = 2;
				end;
				else do;
					IddConjuCalc = IddPartiCalc - DifConjug;
					IddCjgApoEnt = IddApoEntPre - DifConjug;
					CdSexoConjug = 1;
				end;
			end;
			else if (&CD_COMPOSICAO_FAMILIAR = 2) then do;
				IF (DtNascConjug ^= . & CdSexoConjug ^= .) THEN DO;
					IddConjuCalc = round(yrdif(DtNascConjug, &DtCalAval, &vBasis));
					IddCjgApoEnt = round(yrdif(DtNascConjug, DtApoEntPrev, &vBasis));
				END;

				IF (DtNascFilJov ^= . & CdSexoFilJov ^= .) THEN DO;
					IddFilJovCalc = round(yrdif(DtNascFilJov, &DtCalAval, &vBasis));
					IddFilJovApoEnt = round(yrdif(DtNascFilJov, DtApoEntPrev, &vBasis));
				END;

				IF (DtNascFilInv ^= . & CdSexoFilInv ^= .) THEN DO;
					IddFilInvCalc = round(yrdif(DtNascFilInv, &DtCalAval, &vBasis));
					IddFilInvApoEnt = round(yrdif(DtNascFilInv, DtApoEntPrev, &vBasis));
				END;
			end;

			*---- Tempo de admissão na patrocinadora na data do cálculo ----;
			TmpAdmIns = max(1, round(IddPartiFrac - IddAdmFracao, &vRoundCobertura));

			enquadramento[n, 1] = idParticipante;
			enquadramento[n, 2] = IddPartiCalc;
			enquadramento[n, 3] = IddPartiFrac;
			enquadramento[n, 4] = IddAdmPatroc;
			enquadramento[n, 5] = IddAdmFracao;
			enquadramento[n, 6] = IddAssEntPre;
			enquadramento[n, 7] = TmpAdmIns;
			enquadramento[n, 8] = DtIniApoInss;
			enquadramento[n, 9] = IddIniciInss;
			enquadramento[n, 10] = IddIniApoInss;
			enquadramento[n, 11] = DtIniContInss;
			enquadramento[n, 12] = PrbCasado;
			enquadramento[n, 13] = TmpInssCalcu;
			enquadramento[n, 14] = TmpInssResto;
			enquadramento[n, 15] = TmpInssTotal;
			enquadramento[n, 16] = TmpContribInss;
			enquadramento[n, 17] = DtApoEntPrev;
			enquadramento[n, 18] = IddApoEntPre;
			enquadramento[n, 19] = TmpPlanoPrev;
			enquadramento[n, 20] = TmpPlanoRest;
			enquadramento[n, 21] = CdSexoConjug;
			enquadramento[n, 22] = IddConjuCalc;
			enquadramento[n, 23] = IddCjgApoEnt;
			enquadramento[n, 24] = IddFilJovCalc;
			enquadramento[n, 25] = IddFilJovApoEnt;
			enquadramento[n, 26] = IddFilInvCalc;
			enquadramento[n, 27] = IddFilInvApoEnt;
		END;

		create work.ativos_enquadramento_tmp from enquadramento[colname={'id_participante' 'IddPartiCalc' 'IddPartiFrac' 'IddAdmPatroc' 'IddAdmFracao' 'IddAssEntPre' 'TmpAdmIns' 'DtIniApoInss' 'IddIniciInss' 'IddIniApoInss' 'DtIniContInss' 'PrbCasado' 'TmpInssCalcu' 'TmpInssResto' 'TmpInssTotal' 'TmpContribInss' 'DtApoEntPrev' 'IddApoEntPre' 'TmpPlanoPrev' 'TmpPlanoRest' 'CdSexoConjugTmp' 'IddConjuCalc' 'IddCjgApoEnt' 'IddFilJovCalc' 'IddFilJovApoEnt' 'IddFilInvCalc' 'IddFilInvApoEnt'}];
			append from enquadramento;
		close;

		free enquadramento;
	end;
QUIT;

data partic.ativos;
	merge work.ativos work.ativos_enquadramento_tmp;
	by id_participante;
	CdSexoConjug = CdSexoConjugTmp;
	if (&CdPlanBen = 5) then
		VlSalEntPrev = min(VlSalEntPrev, &VL_MAX_SALARIO_CAIXA);
	format DtIniApoInss DDMMYY10. DtIniApoInss DDMMYY10. DtIniContInss DDMMYY10. DtApoEntPrev DDMMYY10.;
	drop CdSexoConjugTmp;
run;

proc delete data = work.ativos_enquadramento_tmp;

%_eg_conditional_dropds(work.ativos_blocos);
proc iml;
	use partic.ativos;
		read all var {id_participante} into ativos;
	close;

	numberObs = nrow(ativos);

	if (numberObs > 0) then do;
		blocosAtivos = j(numberObs, 2, 0);

		countRecords = 1;
		countBlocks = 1;

		do a = 1 to numberObs;
			blocosAtivos[a, 1] = ativos[a, 1];
			blocosAtivos[a, 2] = countBlocks;

			if (countRecords < &recordsPerBlockAtivos) then do;
				countRecords = countRecords + 1;
			end;
			else do;
				countRecords = 1;
				countBlocks = countBlocks + 1;
			end;
		end;

		create work.ativos_blocos from blocosAtivos[colname={'id_participante' 'id_bloco'}];
			append from blocosAtivos;
		close;
	
		call symputx('numberOfBlocksAtivos', countBlocks);
	end;
quit;

data partic.ativos;
	merge partic.ativos work.ativos_blocos;
	by id_participante;
run;

proc delete data = work.ativos_blocos;
