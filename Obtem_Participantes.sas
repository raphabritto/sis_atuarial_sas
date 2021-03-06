
%_eg_conditional_dropds(WORK.PARTICIPANTE);
PROC SQL;
   	CREATE TABLE WORK.PARTICIPANTE AS
   	SELECT t1.ID_PARTICIPANTE, 
          t1.ID_CADASTRO AS CdSitCadPart, 
          t1.NM_PARTICIPANTE AS NoNomePartic, 
          t1.NR_MATRICULA AS NuMatrPartic, 
          (DATEPART(t1.DT_NASCIMENTO)) FORMAT=DDMMYY10. AS DtNascPartic, 
	        (CASE  
	           WHEN t1.IR_SEXO = 'F'
	           THEN 1
	           ELSE 2
	        END) AS CdSexoPartic, 
          t1.ID_PATROCINADORA AS CdPatrocPlan, 
          t1.CD_SITUACAO_PATROC, 
	  	(CASE
			WHEN t1.CD_ESTADO_CIVIL = 'C' THEN 1
			WHEN t1.CD_ESTADO_CIVIL = 'D' THEN 2
			WHEN t1.CD_ESTADO_CIVIL = 'J' THEN 3
			WHEN t1.CD_ESTADO_CIVIL = 'S' THEN 4
			ELSE 5
		END) AS CdEstCivPart,
            (DATEPART(t1.DT_ADMISSAO)) FORMAT=DDMMYY10. AS DtAdmPatroci, 
            (DATEPART(t1.DT_ASSOCIACAO_FUNDACAO)) FORMAT=DDMMYY10. AS DtAssEntPrev, 
          (t1.PC_BENEFICIO_ESPECIAL / 100) AS PeFatReduPbe, 
/*        (CASE*/
/*           WHEN t1.FL_APOSENTADORIA_ESPECIAL = 'N'*/
/*           THEN 0*/
/*           ELSE 1*/
/*        END) AS CdElegApoEsp, */
/*          t1.ID_ENTIDADE_ORIGEM AS CdParEntPrev, */
        (CASE  
           WHEN t1.FL_DEFICIENTE = 'N'
           THEN 0
           ELSE 1
        END) AS FL_DEFICIENTE,
          t1.NR_MATRICULA_TITULAR AS NuMatrOrigem,
/*		  (CASE */
/*			  	WHEN t1.NR_MATRICULA_TITULAR IS NULL THEN 0*/
/*				ELSE 1*/
/*			END) AS FlgPensionista,*/
			t1.fl_migrado
  FROM ORACLE.TB_ATU_PARTICIPANTE t1
  WHERE t1.ID_CADASTRO = &id_cadastro
/*  and (t1.id_participante >= 13335482 and t1.id_participante <= 13335581)*/
/*  or (t1.id_participante >= 13338460 and t1.id_participante <= 13338559)*/
  ORDER BY t1.ID_PARTICIPANTE;
RUN;

*--- plano beneficio ---*;
%_eg_conditional_dropds(WORK.PLANO_BENEFICIO);
PROC SQL;
	CREATE TABLE WORK.PLANO_BENEFICIO AS 
	SELECT  distinct(t1.ID_PARTICIPANTE),
			t1.IDPLANOPREV,
			(DATEPART(t1.DT_ADESAO)) FORMAT=DDMMYY10. AS DtAdesaoPlan, 
			t1.VL_SLD_SUBCONTA_PARTICIPANTE FORMAT=COMMAX14.2 AS VlSdoConPart, 
			t1.VL_SLD_SUBCONTA_PATROCINADORA FORMAT=COMMAX14.2 AS VlSdoConPatr,
			t1.VL_RESERVA_BPD FORMAT=COMMAX14.2, 
			t1.VL_SALDO_PORTADO FORMAT=COMMAX14.2, 
			t1.VL_BEN_SALDADO_INICIAL FORMAT=COMMAX14.2 AS VlBenSaldado, 
			t1.VL_SALARIO_PARTICIPACAO FORMAT=COMMAX14.2 AS VlSalEntPrev, 
			t1.CD_SITUACAO_FUNDACAO, 
			(t1.PC_CONTRIBUICAO_PARTICIPANTE / 100) FORMAT=.5 AS PeContrParti, 
			(t1.PC_CONTRIBUICAO_PATROCINADORA / 100) FORMAT=.5 AS PeContrPatro
		FROM ORACLE.TB_ATU_PARTIC_PLANO t1
		INNER JOIN WORK.PARTICIPANTE t2 ON (t1.ID_PARTICIPANTE = t2.ID_PARTICIPANTE)
	WHERE t1.IDPLANOPREV = &IDPLANOPREV
		ORDER BY t1.ID_PARTICIPANTE;
RUN;

*--- beneficio inss ----*;
%_eg_conditional_dropds(WORK.BENEFICIO_INSS);
PROC SQL;
   CREATE TABLE WORK.BENEFICIO_INSS AS 
   SELECT distinct(t1.ID_PARTICIPANTE),
          (DATEPART(t1.DT_INICIO_BENEFICIO)) FORMAT=DDMMYY10. AS DtIniBenInss, 
		  t1.VL_VALOR FORMAT=COMMAX14.2 AS VlBenefiInss
      FROM ORACLE.TB_ATU_PARTIC_BEN_RGPS t1
      INNER JOIN WORK.PARTICIPANTE t2 ON (t1.ID_PARTICIPANTE = t2.ID_PARTICIPANTE)
      ORDER BY t1.ID_PARTICIPANTE;
RUN;

*--- beneficio funcef ---;
%_eg_conditional_dropds(work.beneficio_funcef_all);
PROC SQL;
   CREATE TABLE work.beneficio_funcef_all AS 
   SELECT t1.ID_PARTICIPANTE,
		  t1.VL_VALOR format=commax14.2,
          (DATEPART(t1.DT_INICIO_BENEFICIO)) FORMAT=DDMMYY10. AS DT_INICIO_BENEFICIO, 
		  (CASE
		  	WHEN t1.IDBENEFICIO = 149 THEN 1
			WHEN t1.IDBENEFICIO = 154 THEN 2
			WHEN t1.IDBENEFICIO = 156 THEN 1
			WHEN t1.IDBENEFICIO = 159 THEN 3
			WHEN t1.IDBENEFICIO = 164 THEN 4
			WHEN t1.IDBENEFICIO = 338 THEN 4
			WHEN t1.IDBENEFICIO = 492 THEN 1
			WHEN t1.IDBENEFICIO = 495 THEN 1
			WHEN t1.IDBENEFICIO = 496 THEN 4
			WHEN t1.IDBENEFICIO = 497 THEN 4
			WHEN t1.IDBENEFICIO = 503 THEN 1
			WHEN t1.IDBENEFICIO = 504 THEN 3
			WHEN t1.IDBENEFICIO = 505 THEN 2
			WHEN t1.IDBENEFICIO = 513 THEN 1
			WHEN t1.IDBENEFICIO = 514 THEN 1
			WHEN t1.IDBENEFICIO = 521 THEN 3
			WHEN t1.IDBENEFICIO = 522 THEN 4
			WHEN t1.IDBENEFICIO = 488 THEN 4
			WHEN t1.IDBENEFICIO = 482 THEN 4
			WHEN t1.IDBENEFICIO = 480 THEN 1
			WHEN t1.IDBENEFICIO = 479 THEN 1
			WHEN t1.IDBENEFICIO = 487 THEN 1
			WHEN t1.IDBENEFICIO = 481 THEN 3
			WHEN t1.IDBENEFICIO = 325 THEN 4
			WHEN t1.IDBENEFICIO = 278 THEN 4
			WHEN t1.IDBENEFICIO = 324 THEN 4
			WHEN t1.IDBENEFICIO = 165 THEN 4
			WHEN t1.IDBENEFICIO = 326 THEN 4
			WHEN t1.IDBENEFICIO = 171 THEN 4
			WHEN t1.IDBENEFICIO = 251 THEN 3
			WHEN t1.IDBENEFICIO = 327 THEN 3
			WHEN t1.IDBENEFICIO = 517 THEN 1
			WHEN t1.IDBENEFICIO = 319 THEN 1
			WHEN t1.IDBENEFICIO = 252 THEN 1
			WHEN t1.IDBENEFICIO = 160 THEN 3
			WHEN t1.IDBENEFICIO = 328 THEN 3
			WHEN t1.IDBENEFICIO = 161 THEN 3
			WHEN t1.IDBENEFICIO = 329 THEN 3
			WHEN t1.IDBENEFICIO = 320 THEN 1
			WHEN t1.IDBENEFICIO = 318 THEN 1
			WHEN t1.IDBENEFICIO = 152 THEN 1
			ELSE 0
		END) AS ID_BENEFICIO
      FROM ORACLE.TB_ATU_PARTIC_BEN_FUNCEF t1
      INNER JOIN WORK.PARTICIPANTE t2 ON (t1.ID_PARTICIPANTE = t2.ID_PARTICIPANTE)
	 WHERE t1.IDPLANOPREV = &IDPLANOPREV
      ORDER BY t1.ID_PARTICIPANTE;
RUN;

%_eg_conditional_dropds(work.tipo_beneficio_dib_funcef);
PROC SQL;
   CREATE TABLE work.tipo_beneficio_dib_funcef AS 
	SELECT distinct(t1.ID_PARTICIPANTE),
		   t1.ID_BENEFICIO as CdTipoBenefi,
		   t1.DT_INICIO_BENEFICIO as DtIniBenPrev
	FROM work.beneficio_funcef_all t1
	WHERE t1.ID_BENEFICIO <> 0
	ORDER BY t1.ID_PARTICIPANTE;
RUN;

%_eg_conditional_dropds(work.BENEFICIO_FUNCEF);
PROC SQL;
	CREATE TABLE work.BENEFICIO_FUNCEF AS 
    SELECT t1.ID_PARTICIPANTE,
			SUM(t1.VL_VALOR) format=commax14.2 AS VlBenefiPrev
	FROM work.beneficio_funcef_all t1
   GROUP BY t1.ID_PARTICIPANTE
   ORDER BY t1.ID_PARTICIPANTE;
RUN;

data work.beneficio_funcef;
	merge work.beneficio_funcef work.tipo_beneficio_dib_funcef;
	by id_participante;
run;

proc delete data = work.tipo_beneficio_dib_funcef work.beneficio_funcef_all;


*--- rubrica judicial ----*;
%_eg_conditional_dropds(WORK.RUBRICA_JUDICIAL);
PROC SQL noprint;
	CREATE TABLE work.RUBRICA_JUDICIAL AS 
	SELECT t1.ID_PARTICIPANTE,
           (DATEPART(t1.DT_INICIO_BENEFICIO)) FORMAT=DDMMYY10. AS DtIniRubJud, 
		   t1.VL_VALOR FORMAT=COMMAX14.2 AS VlBenefiRubJud
     FROM ORACLE.TB_ATU_PARTIC_RUB_JUDICIAL t1
/*    INNER JOIN WORK.PARTICIPANTE t2 ON (t1.ID_PARTICIPANTE = t2.ID_PARTICIPANTE)*/
	INNER JOIN WORK.PLANO_BENEFICIO t3 ON (t1.ID_PARTICIPANTE = t3.ID_PARTICIPANTE AND t1.IDPLANOPREV = t3.IDPLANOPREV)
    ORDER BY t1.ID_PARTICIPANTE;

	SELECT COUNT (*) INTO: numberOfRubricas
  	FROM work.RUBRICA_JUDICIAL;
RUN;

%macro updateRubrica;
	%if (&numberOfRubricas > 0) %then %do;
		proc sql;
			update work.beneficio_funcef b1
			set DtIniBenPrev = (select DtIniRubJud from work.rubrica_judicial r1 where b1.id_participante = r1.id_participante),
				VlBenefiPrev = (select VlBenefiRubJud from work.rubrica_judicial r1 where b1.id_participante = r1.id_participante);
		run;
	%end;
%mend;
%updateRubrica;


*--- dependente ---*;
%_eg_conditional_dropds(WORK.DEPENDENTE);
PROC SQL;
   CREATE TABLE WORK.DEPENDENTE AS 
   SELECT t1.ID_PARTICIPANTE,
            (CASE  
               WHEN t1.CD_GRAU_DEPENDENCIA = 'COM' THEN 1
			   WHEN t1.CD_GRAU_DEPENDENCIA = 'EXC' THEN 1
               WHEN t1.CD_GRAU_DEPENDENCIA = 'FIL' THEN 2
			   WHEN t1.CD_GRAU_DEPENDENCIA = 'ENT' THEN 2
               ELSE 3
            END) AS CD_GRAU_DEPENDENCIA, 
            (DATEPART(t1.DT_NASCIMENTO)) FORMAT=DDMMYY10. AS DT_NASCIMENTO, 
            (CASE  
               WHEN t1.IR_SEXO = 'F'
               THEN 1
               ELSE 2
            END) AS IR_SEXO, 
            (CASE  
               WHEN t1.FL_INVALIDO = 'N'
               THEN 0
               ELSE 1
            END) AS FL_INVALIDO
      FROM ORACLE.TB_ATU_PARTIC_DEPENDENTE t1
	  INNER JOIN WORK.PARTICIPANTE t2 ON (t1.ID_PARTICIPANTE = t2.ID_PARTICIPANTE)
      ORDER BY t1.ID_PARTICIPANTE;
RUN;

%_eg_conditional_dropds(WORK.CONJUGE);
PROC SQL;
	CREATE TABLE WORK.CONJUGE AS
	SELECT distinct(t1.ID_PARTICIPANTE),
			t1.IR_SEXO AS CdSexoConjug,
			t1.DT_NASCIMENTO AS DtNascConjug
	FROM WORK.DEPENDENTE t1
	WHERE t1.CD_GRAU_DEPENDENCIA = 1
	ORDER BY t1.ID_PARTICIPANTE;
RUN;

%_eg_conditional_dropds(WORK.FILHO_JOVEM);
PROC SQL;
	CREATE TABLE WORK.FILHO_JOVEM AS
	SELECT DISTINCT(t1.ID_PARTICIPANTE) AS ID_PARTICIPANTE,
			t1.IR_SEXO AS CdSexoFilJov,
			t1.DT_NASCIMENTO AS DtNascFilJov
	FROM WORK.DEPENDENTE t1
	WHERE t1.CD_GRAU_DEPENDENCIA = 2
	AND t1.FL_INVALIDO = 0
	ORDER BY t1.ID_PARTICIPANTE, t1.DT_NASCIMENTO;
RUN;

%_eg_conditional_dropds(WORK.FILHO_INVALIDO);
PROC SQL;
	CREATE TABLE WORK.FILHO_INVALIDO AS
	SELECT DISTINCT(t1.ID_PARTICIPANTE) AS ID_PARTICIPANTE,
			t1.IR_SEXO as CdSexoFilInv,
			t1.DT_NASCIMENTO AS DtNascFilInv
	FROM WORK.DEPENDENTE t1
	WHERE t1.CD_GRAU_DEPENDENCIA = 2
	AND t1.FL_INVALIDO = 1
	ORDER BY t1.ID_PARTICIPANTE, t1.DT_NASCIMENTO;
RUN;

data work.participante;
	MERGE WORK.PARTICIPANTE WORK.PLANO_BENEFICIO WORK.BENEFICIO_INSS WORK.BENEFICIO_FUNCEF WORK.CONJUGE WORK.FILHO_JOVEM WORK.FILHO_INVALIDO;
	BY ID_PARTICIPANTE;

	if (VlBenefiInss = .) then
		VlBenefiInss = 0;

	if (VlBenefiPrev = .) then
		VlBenefiPrev = 0;

	if (CD_SITUACAO_FUNDACAO in (58, 63, 121)) then
		CdAutoPatroc = 1;
	else CdAutoPatroc = 0;

	/*if (CD_SITUACAO_FUNDACAO not in (1, 2, 3, 26, 33, 41, 77, 93, 112, 116) & CdTipoBenefi = .) then
			flg_manutencao_saldo = 1;
	else flg_manutencao_saldo = 0;*/

	if (CD_SITUACAO_FUNDACAO not in (1, 2, 3, 4, 11, 12, 15, 26, 33, 36, 37, 38, 39, 41, 65, 77, 83, 89, 93, 112, 116) & CdTipoBenefi = .) then
			flg_manutencao_saldo = 1;
	else flg_manutencao_saldo = 0;
run;


*--- separa participante grupo ativo e assistido ---*;
%_eg_conditional_dropds(partic.ATIVOS);
data partic.ativos;
	set work.participante(where=(CdTipoBenefi = . & DtIniBenPrev = .));
	drop CdSexoFilJov DtNascFilJov CdSexoFilInv DtNascFilInv;
run;

/*data partic.ativos;*/
/*	do i = 1 to 100;*/
/*		Slice = int(nObs * ranuni(1850));*/
/*		set partic.ativos point= Slice nobs= nObs;*/
/*		output;*/
/*		end;*/
/*	stop;*/
/**/
/*	drop i;*/
/*run;*/

/*proc sort data=partic.ativos out=partic.ativos;*/
/*	by id_participante;*/
/*run;*/

PROC SQL NOPRINT;
	SELECT COUNT (*) INTO: numberOfAtivos
	FROM partic.ATIVOS;
RUN;
  
%_eg_conditional_dropds(partic.ASSISTIDOS);
data partic.ASSISTIDOS;
	set work.participante(where=(CdTipoBenefi ^= . & DtIniBenPrev ^= .));
	drop VlSdoConPart VlSdoConPatr VL_RESERVA_BPD VL_SALDO_PORTADO VlBenSaldado VlSalEntPrev PeContrParti PeContrPatro;
run;

/*data partic.ASSISTIDOS;*/
/*	do i = 1 to 100;*/
/*		Slice = int(nObs * ranuni(1850));*/
/*		set partic.ASSISTIDOS point= Slice nobs= nObs;*/
/*		output;*/
/*		end;*/
/*	stop;*/
/**/
/*	drop i;*/
/*run;*/

/*proc sort data=partic.assistidos out=partic.assistidos;*/
/*	by id_participante;*/
/*run;*/

PROC SQL NOPRINT;
	SELECT COUNT (*) INTO: numberOfAssistidos
	FROM partic.ASSISTIDOS;
RUN;

proc datasets library=temp kill memtype=data nolist;
proc datasets library=work kill memtype=data nolist;
	run;
quit;
