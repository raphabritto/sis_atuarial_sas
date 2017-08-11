*options fullstimer;

options dlcreatedir;

*** 
	tipo calculo: 
		1 - deterministico
		2 - estocastico
***;
%let tipoCalculo = 2;

* --- variaveis de configuração do sistema que devem ser alteradas manuamente --- *;
%let numeroCalculos = 0;
data _null_;
	if &tipoCalculo = 1 then
		call symputx('numeroCalculos', 1);
	else if &tipoCalculo = 2 then
		call symputx('numeroCalculos', 100);
run;


* --- variaveis de configuração do sistema que devem ser alteradas manuamente --- *;
*%let root_dir = \\shaula\caprev_sas\Fluxo_Atuarial_Estocastico;
%let root_dir = \\shaula\caprev_sas\SIS_ATUARIAL\Resul_Estoc\;

%let maxAge = 125;
*%let MaxAgeAtivos = 125;
*%let MaxAgeAssistidos = 125;
*%let MaxAgeDeterministicoAtivos = 125;
*%let MaxAgeDeterministicoAssistidos = 125;
*%let recordsPerBlockAtivos = 2500;
*%let recordsPerBlockAssistidos = 50000;

* --- variaveis que não podem ser alteradas manuamente --- *;
*%let numberOfBlocksAtivos = 0;
*%let numberOfBlocksAssistidos = 0;
%let numberOfAtivos = 0;
%let numberOfAssistidos = 0;
%let numberOfTaxaJuros = 0;
%let maxTaxaJuros = 0;
*%let numberOfTaxaRiscoPartic = 0;
*%let numberOfTaxaRiscoPatroc = 0;
%let numberOfRubricas = 0;
%let numberOfCopensao = 0;
%let maxTaxaRiscoPartic = 0;
%let maxTaxaRiscoPatroc = 0;

%LET Fb = 0;

/* PREMISSAS AVALIACAO CALCULO */
%let id_avaliacao = 0;
%let id_cadastro = 0;

%let percentualBUA = 0;
%let percentualSaqueBUA = 0;

%let percentualSRB = 0;
%let isGravaMemoriaCalculo = 0;

%let isGravaMemoriaCalculo = 0;

%let percentualSaidaBPD = 0;
%let percentualPortabilidade = 0;
%let percentualResgate = 0;

%LET BenMinimo = 0;
%LET CD_COMPOSICAO_FAMILIAR = 0;
%LET CtFamPens = 0;
%LET CdPlanBen = 0;
%LET DtCalAval = .;
%LET DtReajBen = .;
*%LET FL_MAXIMO_SALARIO = 0;
%LET FlCalculaFluxo = 0;
%LET FtBenEnti = 0;
%LET FtBenLiquido = 0;
%LET FtBenMin2 = 0;
%LET FtBenInss = 0;
%LET FtInssAss = 0;
%LET FtSalPart = 0;
%LET Fxa01Cont = 0;
%LET Fxa02Cont = 0;
%LET Fxa03Cont = 0;
%LET IDPLANOPREV = 0;
%LET IncBenMinBD = 0;
%LET IncPecMor = 0;
%LET LimPecMin = 0;
%LET MetFinBen = 0;
%LET NR_DIFERENCIA_IDADE_CONJ_FEM = 0;
%LET NR_DIFERENCIA_IDADE_CONJ_MAS = 0;
%LET NR_IDADE_INI_CONT_INSS_MAS = 0;
%LET NR_IDADE_INI_CONT_INSS_FEM = 0;
%LET MaiorIdad = 0;
%LET NR_TEMPO_CONT_INSS_MAS = 0;
%LET NR_TEMPO_CONT_INSS_FEM = 0;
%LET NR_IDADE_INI_APOS_MAS = 0;
%LET NR_IDADE_INI_APOS_FEM = 0;
%LET NroBenAno = 0;
%LET PC_DESPESA_ADM_PARTICIPANTE = 0;
%LET PC_DESPESA_ADM_PATROCINADORA = 0;
%LET PC_FATOR_VLR_REAL_BEN_INSS = 0;
%LET PC_PROB_PARTIC_CAS_APOS_MAS = 0;
%LET PC_PROB_PARTIC_CAS_APOS_FEM = 0;
*%LET PrBenPlan = 0;
*%LET PrSalario = 0;
%LET PrSalPart = 0;
%LET PrTxBenef = 0;
*%LET PrTxJrAno = 0;
%LET peculioMorteAtivo = 0;
%let peculioMorteAssistido = 0;
%LET RegFinBen = 0;
%LET SalMinimo = 0;
%LET TtInssBen = 0;
%LET TtInssCon = 0;
%LET TxaAdmBen = 0;
%LET VlrLxInicial = 0;
%LET VL_SALARIO_CAIXA = 0; 
*%LET VL_MAX_SALARIO_FUNCEF = 0;
%LET VL_TETO_INSS_BENEFICIO = 0;
%LET VL_TETO_INSS_CONTRIB_ATUAL = 0;
%LET VL_TETO_INSS_CONTRIBUICAO = 0;


*---- PARAMETROS GERAIS ----*;
*---DATA INÍCIO DA MÉDIA DOS 80% MAIORES SALÁRIOS INSS---;
%LET DatMedSal = .;
*---DATA INÍCIO ORIUNDOS PREVHAB---;
%LET DtOrigBnh = .;
*---DATA INÍCIO DA LEI Nº 9876/1999 (FATOR PREVIDENCIÁRIO)---;
%LET DtLei9876 = .;

%let DtLeiInss8595 = mdy(12, 30, 2018);