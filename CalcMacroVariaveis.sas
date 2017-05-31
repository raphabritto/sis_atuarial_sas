
PROC IML;
	use WORK.indexador_monetario;
		read all var { PC_REAJUSTE } into FtBenMin2_ where(ID_REFERENCIA_IDX_MON = 1);
		read all var { PC_REAJUSTE } into FtInssAss_ where(ID_REFERENCIA_IDX_MON = 2);
		read all var { PC_REAJUSTE } into FtInssCon_ where(ID_REFERENCIA_IDX_MON = 3);
	close WORK.indexador_monetario;

	call symputx('FtBenMin2', FtBenMin2_);
	call symputx('FtInssAss', FtInssAss_);
	call symputx('FtInssCon', FtInssCon_);

	*call symputx('PrSalario', ((1 + &PrTxJrAno) / (1 + &PrSalPart)) - 1);
	*call symputx('PrBenPlan', (( 1 + &PrTxJrAno) / (1 + &PrTxBenef)) - 1);
	call symputx('TtInssCon', round(&VL_TETO_INSS_CONTRIBUICAO * FtInssCon_ * &FtBenInss, 0.01));
	
	*fator anuidade mensal / fracionamento de anuidade*;
	call symputx('Fb', round((&NroBenAno - 2) / ((&NroBenAno - 1) * 2), 0.00000000000001));
QUIT;