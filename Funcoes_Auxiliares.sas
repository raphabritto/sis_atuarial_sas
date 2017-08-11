/*-------------------------------------------------------------------------------------------------------------*/
/*-- Contém funções auxiliares e Constantes a serem utilizadas no projeto Atuarial                           --*/
/*-- Versão: 8 de junho de 2012                                                                              --*/
/*-------------------------------------------------------------------------------------------------------------*/

%let vRoundCobertura = 0.0000000001;
%let vRoundMoeda = 0.01;
%LET vBasis = 'ACT/ACT';
%LET vAlignment = 'S';

* ---- Obtem Fator de atualizacao do Salario ----*;
PROC IML;
	START GetFatorAtualizaSalario(patrocinadora, tipo);
		use SISATU.REAJUSTE_SALARIAL;
			read all var { PC_REAJUSTE } into fator where (ID_PATROCINADORA = patrocinadora & CD_TIPO_REAJUSTE_SALARIAL = tipo);
		close SISATU.REAJUSTE_SALARIAL;

		return (fator);
	FINISH;
	store module = GetFatorAtualizaSalario;
QUIT;

/* ---- Obtem Indexador Monetario ----*/
PROC IML;
	START GetIndexadorMonetario(tipoIndexadorMonetario);
		use SISATU.INDEXADOR_MONETARIO;
			read all var { PC_REAJUSTE } into vl_indexador where (ID_REFERENCIA_IDX_MON = tipoIndexadorMonetario);
		close SISATU.INDEXADOR_MONETARIO;

		return (vl_indexador);

	FINISH;
	store module = GetIndexadorMonetario;
QUIT;

/* ---- Calcula contribuição do Plano de Benefício Definido	----*/
PROC IML;
	start GetContribuicao(salario);

		contribuicao = 0;

		if (&CdPlanBen = 1) then do;
			contr1 = 0;
			contr2 = 0;
			contr3 = 0;

		    contr1 = round(MIN(salario, (&TtInssCon / 2)) * &Fxa01Cont, &vRoundMoeda);

			if (salario > (&TtInssCon / 2)) then
				contr2 = round((MIN(salario, &TtInssCon) - (&TtInssCon / 2)) * &Fxa02Cont, &vRoundMoeda);

			if (salario > &TtInssCon) then
				contr3 = round((salario - &TtInssCon) * &Fxa03Cont, &vRoundMoeda);
			
			contribuicao = round(contr1 + contr2 + contr3, &vRoundMoeda);
		end;

		return (contribuicao);
	finish;
	store module = GetContribuicao;
QUIT;

PROC IML;
	start GetContribuicaoPercentual(tipoCalculo, plano, salario, percentual, beneficioRisco, despesaAdmin, apx, pxs, responsabilidade);
		contribuicao = 0;

		if (tipoCalculo = 2) then do;
			apx = 0;
			pxs = 1;
		end;

		if (plano = 4) then do;
			contribuicao = max(0, round((salario * percentual * (1 - despesaAdmin) - salario * beneficioRisco) * &NroBenAno * (1 - apx), 0.01));
		end;
		else if (plano = 5) then do;
			if (responsabilidade = 1) then do;
				contribuicao = max(0, round(salario * percentual * (1 - despesaAdmin) * &NroBenAno * (1 - apx), 0.01));
			end;
			else do;
				contribuicao = max(0, round((salario * percentual * (1 - despesaAdmin) - salario * beneficioRisco) * &NroBenAno * (1 - apx), 0.01));
			end;
		end;

		contribuicao = max(0, round(contribuicao * pxs, 0.01));

		return(contribuicao);
	finish;
	store module = GetContribuicaoPercentual;
QUIT;

proc iml;
	start CalculaSaldoConta(tipoCalculo, t, saldoConta, taxaJuros, pxs, apx, contribuicao);
		saldo_conta = 0;

		if (tipoCalculo = 2) then do;
			apx = 0;
			pxs = 1;
		end;

		if (t = 0) then 
			saldo_conta = saldoConta;
		else
			saldo_conta = max(0, round(saldoConta * (1 + taxaJuros) * pxs * (1 - apx) + contribuicao * (1 + taxaJuros), 0.01));

		return(saldo_conta);
	finish;

	store module= calculaSaldoConta;
quit;

PROC IML;
	*--- Calcula fator previdenciario ---*;
	*--- OBS: O parâmetro Result deve conter a variável de retorno da função, ou seja, a variável que deverá conter o fator previdenciário ---*;
	*--- vide: site www.previdencia.gov.br                                                                                                 ---*;
	*--- O Fator Previ é arredondado com 5 casas decimais : round(variavel,.00001)                                                         ---*;
	start GetFatorPrevidenciario(TempoContr_, ExpectVida, IdadeCalcu, CdSexoPartic);
		AliqContr = 0.31;

		if (CdSexoPartic = 1) then TempoContr_ = TempoContr_ + 5;

		FatorPrevi = round((TempoContr_ * AliqContr / ExpectVida) * (1 + (IdadeCalcu + TempoContr_ * AliqContr) / 100), 0.0000000001);

/*		if (NrMesesLei <= 60) then */
/*			FatorPrevi = round(FatorPrevi * NrMesesLei / 60 + ((60 - NrMesesLei) / 60), .0000000001);*/

		return (FatorPrevi);
	finish;
	store module = GetFatorPrevidenciario;
QUIT;

/* ---- Calcula fator da média dos 80% maiores salários do inss - arrendondamento em 5 casas decimais ---- */
PROC IML;
	start GetFatorMediaSalariosInss(Data1, Data2);
		fat_80 = 0;

		if (&PrSalPart = 0) then do;
			fat_80 = 0.8;
		end;
		else do;
			tempo80 = round(yrdif(Data1, Data2, '30/360') * 0.8, 0.0000000001);

			if (tempo80 <= 0) then tempo80 = 1;

			fat_x = round(1 / (1 + &PrSalPart), 0.0000000001);
			fat_1 = round(((1 / 12) * (1 - fat_x)) / (1 - fat_x ** (1 / 12)), 0.0000000001);
			fat_80 = round((1 / tempo80) * ((1 - (fat_x ** tempo80)) / (1 - fat_x)) * fat_1, 0.0000000001);
		end;

		return(fat_80);
	finish;
	store module = GetFatorMediaSalariosInss;
QUIT;

PROC IML;
	START CalcSalarioInss(CdSexoPartic_, VlBenefiInss_, DtApoEntPrev, IddApoEntPre, TmpInssContr, SalBenefInss_, FtPrevideAtc);
		SalarioProjetadoInss = 0;

		if (VlBenefiInss_ > 0) then
			SalarioProjetadoInss = round(VlBenefiInss_ * &FtInssAss * &FtBenInss, 0.01);
		else do;
			if (DtApoEntPrev <= &DtLeiInss8595) then do;
				if (CdSexoPartic_ = 1) then do;
					If (IddApoEntPre + TmpInssContr) >= 85 then 
                        SalarioProjetadoInss = Max(Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01), &SalMinimo);
					else 
						SalarioProjetadoInss = Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), &SalMinimo);
				end;
				else do;
					if (IddApoEntPre + TmpInssContr) >= 95 then 
                        SalarioProjetadoInss = Max(Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_)), &SalMinimo);
                    else
						SalarioProjetadoInss = Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), &SalMinimo);
				end;
			end;
			else if (DtApoEntPrev > &DtLeiInss8595 & DtApoEntPrev <= INTNX('YEAR', &DtLeiInss8595, 2, 'S')) then do;
				if (CdSexoPartic_ = 1) then do;
					If (IddApoEntPre + TmpInssContr) >= 86 then 
                        SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
				else do;
					If (IddApoEntPre + TmpInssContr) >= 96 then 
                        SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
                    Else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
			end;
			else if (DtApoEntPrev > INTNX('YEAR', &DtLeiInss8595, 2, 'S') & DtApoEntPrev <= INTNX('YEAR', &DtLeiInss8595, 4, 'S')) then do;
				if (CdSexoPartic_ = 1) then do;
					If (IddApoEntPre + TmpInssContr) >= 87 then 
                        SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
				else do;
					If (IddApoEntPre + TmpInssContr) >= 97 Then 
                        SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
                    Else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
			end;
			else if (DtApoEntPrev > INTNX('YEAR', &DtLeiInss8595, 4, 'S') & DtApoEntPrev <= INTNX('YEAR', &DtLeiInss8595, 6, 'S')) then do;
				if (CdSexoPartic_ = 1) then do;
					if (IddApoEntPre + TmpInssContr) >= 88 Then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
				else do;
					if (IddApoEntPre + TmpInssContr) >= 98 then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					Else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
			end;
			else if (DtApoEntPrev > INTNX('YEAR', &DtLeiInss8595, 6, 'S') & DtApoEntPrev <= INTNX('YEAR', &DtLeiInss8595, 8, 'S')) then do;
				if (CdSexoPartic_ = 1) then do;
					If (IddApoEntPre + TmpInssContr) >= 89 then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
				else do;
					If (IddApoEntPre + TmpInssContr) >= 99 Then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					Else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
			end;
			else if (DtApoEntPrev > INTNX('YEAR', &DtLeiInss8595, 8, 'S')) then do;
				if (CdSexoPartic_ = 1) then do;
					If (IddApoEntPre + TmpInssContr) >= 90 then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
				else do;
					if (IddApoEntPre + TmpInssContr) >= 100 then 
						SalarioProjetadoInss = Max(Max(0, Round(Max(SalBenefInss_ * FtPrevideAtc, SalBenefInss_), 0.01)), &SalMinimo);
					else SalarioProjetadoInss = Max(Max(Round(SalBenefInss_ * FtPrevideAtc, 0.01), 0), &SalMinimo);
				end;
			end;
		end;

		Return (SalarioProjetadoInss);
	FINISH;
	STORE MODULE= CalcSalarioInss;
QUIT;


PROC IML;
start drawValidezRotatividade(probabilidade, isValido);
	resultado = 0;

/*	if (t = 0) then do;*/
/*		resultado = 1;*/
/*	end;*/
	if (isValido = 1) then do;
		probabilidade = max(0, min(1, 1 - probabilidade));

		if (probabilidade = 1) then
			resultado = 1;
		else if (probabilidade = 0) then
			resultado = 0;
		else
			resultado = ranbin(-563, 1, probabilidade);
	end;

	return (resultado);
finish;

	store module = drawValidezRotatividade;
QUIT;

PROC IML;
start drawSobrevivencia(probabilidade, isVivo);
	resultado = 0;

/*	if (t = 0) then do;*/
/*		resultado = 1;*/
/*	end;*/
	if (isVivo = 1) then do;
		probabilidade = max(0, min(1, 1 - probabilidade));

		if (probabilidade = 1) then
			resultado = 1;
		else if (probabilidade = 0) then
			resultado = 0;
		else
			resultado = ranbin(-1055, 1, probabilidade);
	end;

	return (int(resultado));
finish;

	store module = drawSobrevivencia;
QUIT;


PROC IML;
start sorteioEstocastico(probabilidade, situacao);
	resultado = 0;

	if (situacao = 1) then do;
		probabilidade = max(0, min(1, 1 - probabilidade));

		if (probabilidade = 1) then
			resultado = 1;
		else if (probabilidade = 0) then
			resultado = 0;
		else
			resultado = ranbin(-561, 1, probabilidade);
	end;

	return (resultado);
finish;

	store module = sorteioEstocastico;
QUIT;