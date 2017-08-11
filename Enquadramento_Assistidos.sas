*-- Programa para cálculo do enquadramento dos assistidos		                                             --*;
*-- Versão: 8 de junho de 2012                                                                               --*;

%LET vRoundEnq = 0.0000000001;
%LET vBasis = 'ACT/ACT';
%LET vAlignment = 'S';

*** carrega os assistidos (aposentados e pensionistas) para realizar o enquadramento ***;
%_eg_conditional_dropds(work.assistidos_enquadramento);
PROC IML;
	USE partic.ASSISTIDOS;
		READ ALL VAR {ID_PARTICIPANTE DtNascPartic CdSexoPartic CdPatrocPlan CdEstCivPart DtIniBenInss VlBenefiInss VlBenefiPrev DtIniBenPrev CdTipoBenefi DtNascConjug CdSexoConjug DtNascFilJov CdSexoFilJov DtNascFilInv CdSexoFilInv FL_DEFICIENTE} into assistidos;
	CLOSE;

	qtd = nrow(assistidos);

	if (qtd > 0) then do;
		enquadramento = J(qtd, 11, 0);

		DO i = 1 TO qtd;
			IdParticipante = assistidos[i, 1];
			DtNascPartic = assistidos[i, 2];
			CdSexoPartic = assistidos[i, 3];
			CdPatrocPlan = assistidos[i, 4];
			CdEstCivPart = assistidos[i, 5];
			DtIniBenInss = assistidos[i, 6];
			VlBenefiInss = assistidos[i, 7];
			VlBenefiPrev = assistidos[i, 8];
			DtIniBenPrev = assistidos[i, 9];
			CdTipoBenefi = assistidos[i, 10];
			DtNascConjug = assistidos[i, 11];
			CdSexoConjug = assistidos[i, 12];
			DtNascFilJov = assistidos[i, 13];
			CdSexoFilJov = assistidos[i, 14];
			DtNascFilInv = assistidos[i, 15];
			CdSexoFilInv = assistidos[i, 16];
			is_deficiente = assistidos[i, 17];

			IddPartiCalc = .;
			IddPartiFrac = .;
			IddFilJovCalc = .;
			IddConjuCalc = .;
			IddFilInvCalc = .;
			IddIniBen = .;
			CdTipoFtAtuSal = .;

			*----- idade do assistido na data do cálculo -----*;
			*** idade do participante = diferenca entre a data de nascimento e a data do calculo ***;
			IddPartiCalc = round(yrdif(DtNascPartic, &DtCalAval, &vBasis));
			IddPartiFrac = round(yrdif(DtNascPartic, &DtCalAval, &vBasis), &vRoundEnq);

			*----- idade do cônjuge na data do cálculo -----*;
			IF (CdEstCivPart = 1 & DtNascConjug = .) THEN DO;
				IF (CdSexoPartic = 1) THEN DO;
					DtNascConjug = INTNX('YEAR', DtNascPartic, - (&NR_DIFERENCIA_IDADE_CONJ_FEM), &vAlignment);
					CdSexoConjug = 2;
				END;
				ELSE DO;
					DtNascConjug = INTNX('YEAR', DtNascPartic, &NR_DIFERENCIA_IDADE_CONJ_MAS, &vAlignment);
					CdSexoConjug = 1;
				END;
			END;
			
			IF (DtNascConjug ^= .) THEN IddConjuCalc = round(yrdif(DtNascConjug, &DtCalAval, &vBasis));

			*----- idade do filho mais jovem na data do cálculo -----*;
			IF (DtNascFilJov ^= . & CdSexoFilJov ^= .) THEN DO;
				IddFilJovCalc = round(yrdif(DtNascFilJov, &DtCalAval, &vBasis));

				IF (IddFilJovCalc > &MaiorIdad) THEN DO;
					IddFilJovCalc = .;
					DtNascFilJov = .;
					CdSexoFilJov = .;
				end;
			END;

			IF (DtNascFilInv ^= . & CdSexoFilInv ^= .) THEN IddFilInvCalc = round(yrdif(DtNascFilInv, &DtCalAval, &vBasis));

			*----- idade do assistido na data de inicio de benefício na entidade -----*;
			IF (DtIniBenPrev ^= .) THEN IddIniBen = round(yrdif(DtNascPartic, DtIniBenPrev, &vBasis));

			IF (&CdPlanBen = 1) THEN
				CdTipoFtAtuSal = 1;
			ELSE DO;
				IF (DtIniBenPrev < &DtReajBen) THEN
					CdTipoFtAtuSal = 1;
				ELSE
					CdTipoFtAtuSal = 2;
			END;

			tipo_assistido = 0;

			if (CdTipoBenefi = 1 | CdTipoBenefi = 2) then
				tipo_assistido = 1; *--- tipo 1 = aposentado valido ---*;
			else if (CdTipoBenefi = 3) then
				tipo_assistido = 2; *--- tipo 2 = aposentado invalido ---*;
			else if (IddPartiCalc >= &MaiorIdad & CdTipoBenefi = 4 & is_deficiente = 0) then
				tipo_assistido = 3; *--- tipo 3 = pensionista vitalicio valido ---*;
			else if (CdTipoBenefi = 4 & is_deficiente = 1) then
				tipo_assistido = 4; *--- tipo 4 = pensionista vitalicio invalido ---*;
			else
				tipo_assistido = 5; *--- tipo 5 = pensionista temporario ---*;

			enquadramento[i, 1] = IdParticipante;
			enquadramento[i, 2] = DtNascConjug;
			enquadramento[i, 3] = IddPartiCalc;
			enquadramento[i, 4] = IddPartiFrac;
			enquadramento[i, 5] = IddFilJovCalc;
			enquadramento[i, 6] = IddConjuCalc;
			enquadramento[i, 7] = IddIniBen;
			enquadramento[i, 8] = IddFilInvCalc;
			enquadramento[i, 9] = CdSexoConjug;
			enquadramento[i, 10] = CdTipoFtAtuSal;
			enquadramento[i, 11] = tipo_assistido;
		END;

		create work.assistidos_enquadramento from enquadramento[colname={'id_participante' 'DtNascConjug2' 'IddPartiCalc' 'IddPartiFrac' 'IddFilJovCalc' 'IddConjuCalc' 'IddIniBen' 'IddFilInvCalc' 'CdSexoConjug2' 'CdTipoFtAtuSal' 'TipoAssistido'}];
			append from enquadramento;
		close work.assistidos_enquadramento;
	end;
QUIT;

/*%_eg_conditional_dropds(partic.assistidos);*/
data partic.assistidos;
	merge partic.assistidos work.assistidos_enquadramento;
	by id_participante;
	if CdSexoConjug2 ^= . and DtNascConjug2 ^= . then
		do;
			DtNascConjug = DtNascConjug2;
			CdSexoConjug = CdSexoConjug2;
		end;
	Drop DtNascConjug2 CdSexoConjug2;
	CdCopensao = .;
	QtdGrupoCopensao = .;
run;

%_eg_conditional_dropds(work.MATRICULA_GRUPO_COPENSAO);
proc sql noprint;
	CREATE TABLE work.MATRICULA_GRUPO_COPENSAO AS
	SELECT MONOTONIC() AS CdCopensao, t1.NuMatrOrigem, COUNT(*) as QtdGrupoFamiliar
	from partic.ASSISTIDOS t1
  	where t1.NuMatrOrigem is not null
  	group by t1.NuMatrOrigem
  	having count(*) > 1;

	SELECT COUNT (*) INTO: numberOfCopensao
 	  FROM work.MATRICULA_GRUPO_COPENSAO;
QUIT;

%macro updateGrupoCopensao;
	%if (&numberOfCopensao > 0) %then %do;
		proc sql;
			update partic.ASSISTIDOS a1
			set CdCopensao = (select CdCopensao from work.MATRICULA_GRUPO_COPENSAO g1 where a1.NuMatrOrigem = g1.NuMatrOrigem),
				QtdGrupoCopensao = (select QtdGrupoFamiliar from work.MATRICULA_GRUPO_COPENSAO g1 where a1.NuMatrOrigem = g1.NuMatrOrigem);
		run;
	%end;
%mend;
%updateGrupoCopensao;

data cobertur.assistidos;
	set partic.assistidos;
	drop CdSitCadPart NoNomePartic CD_SITUACAO_PATROC CdEstCivPart DtNascPartic DtAdmPatroci DtAssEntPrev IDPLANOPREV DtAdesaoPlan CD_SITUACAO_FUNDACAO DtIniBenInss DtIniBenPrev DtNascConjug DtNascFilJov DtNascFilInv CdAutoPatroc flg_manutencao_saldo;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
