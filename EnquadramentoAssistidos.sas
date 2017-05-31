*-- Programa para cálculo do enquadramento dos assistidos		                                             --*;
*-- Versão: 8 de junho de 2012                                                                               --*;

%LET vRoundEnq = 0.0000000001;
%LET vBasis = 'ACT/ACT';
%LET vAlignment = 'S';

%_eg_conditional_dropds(work.assistidos_enquadra);
PROC IML;
	USE work.ASSISTIDOS;
		READ ALL VAR {ID_PARTICIPANTE DtNascPartic CdSexoPartic CdPatrocPlan CdEstCivPart DtIniBenInss VlBenefiInss VlBenefiPrev DtIniBenPrev CdTipoBenefi DtNascConjug CdSexoConjug DtNascFilJov CdSexoFilJov DtNascFilInv CdSexoFilInv} into assistidos;
	CLOSE;

	qtd = nrow(assistidos);

	if (qtd > 0) then do;
		enquadramento = J(qtd, 10, 0);

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

			IddPartiCalc = .;
			IddPartiFrac = .;
			IddFilJovCalc = .;
			IddConjuCalc = .;
			IddFilInvCalc = .;
			IddIniBen = .;
			CdTipoFtAtuSal = .;

			*----- idade do assistido na data do cálculo -----*;
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
		END;

		create work.assistidos_enquadra from enquadramento[colname={'id_participante' 'DtNascConjug2' 'IddPartiCalc' 'IddPartiFrac' 'IddFilJovCalc' 'IddConjuCalc' 'IddIniBen' 'IddFilInvCalc' 'CdSexoConjug2' 'CdTipoFtAtuSal'}];
			append from enquadramento;
		close;
	end;
QUIT;

%_eg_conditional_dropds(partic.assistidos);
data partic.assistidos;
	merge work.ASSISTIDOS work.assistidos_enquadra;
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
	from work.ASSISTIDOS t1
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

%_eg_conditional_dropds(work.assistidos_fator_salario);
proc sql;
	create table work.assistidos_fator_salario as
	select t1.id_participante,
			t2.PC_REAJUSTE AS ftAtuSal
	from partic.ASSISTIDOS t1, work.REAJUSTE_SALARIAL t2
	where t1.CdPatrocPlan = t2.ID_PATROCINADORA 
	and t2.CD_TIPO_REAJUSTE_SALARIAL = 2 
	and t1.CdTipoFtAtuSal = 1
	order by t1.id_participante;
run;

%_eg_conditional_dropds(work.assistidos_cotacao);
proc sql;
	create table work.assistidos_cotacao as
	select t1.id_participante, 
		   EXP(SUM(LOG(t2.COTVALOR))) format=.10 AS ftAtuSal
	from partic.assistidos t1, work.COTACAO t2
	where t1.DtIniBenPrev >= &DtReajBen 
	and t1.CdTipoFtAtuSal = 2
	and t2.COTDATA between MDY(month(t1.DtIniBenPrev), 1, year(t1.DtIniBenPrev)) and INTNX('month', MDY(month(&DtCalAval), 1, year(&DtCalAval)), -1, &vAlignment)
	and t2.MOECODIGO = 7
	group by t1.id_participante
	order by t1.id_participante;
run;

%_eg_conditional_dropds(work.ASSISTIDOS_FATOR_REAJ_SALARIO);
proc sql;
	update work.assistidos_cotacao t1
	set ftAtuSal = 1
	where t1.id_participante in (select t2.id_participante 
								   from partic.ASSISTIDOS t2 
								  where month(t2.DtIniBenPrev) = month(&DtCalAval)
								    and year(t2.DtIniBenPrev) = year(&DtCalAval));

	CREATE TABLE work.ASSISTIDOS_FATOR_REAJ_SALARIO AS 
	SELECT * FROM work.assistidos_fator_salario
	OUTER UNION CORR 
	SELECT * FROM work.assistidos_cotacao
	order by id_participante;
quit;

data partic.assistidos;
	merge partic.assistidos work.ASSISTIDOS_FATOR_REAJ_SALARIO;
	by id_participante;
run;

proc datasets nodetails library=work;
	delete assistidos_enquadra;
	delete ASSISTIDOS;
	delete MATRICULA_GRUPO_COPENSAO;
	delete assistidos_fator_salario;
	delete assistidos_cotacao;
	delete assistidos_enquadra;
	delete ASSISTIDOS_FATOR_REAJ_SALARIO;
run;