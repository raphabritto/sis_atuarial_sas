*-- Programa para cálculo de cobertura para ativos                                                          --*;
*-- Regime de financiamento de capitalização                                                                --*;
*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*;
*-- Versão: 11 de março de 2013                                                                             --*;

%_eg_conditional_dropds(work.beneficio_input_ativos);
proc sql;
	create table work.beneficio_input_ativos as
	select t1.id_participante,
			t1.DtNascPartic,
			t1.CdSexoPartic,
			t1.VlSdoConPart,
			t1.VlSdoConPatr,
			t1.VlSalEntPrev,
			t1.PeContrParti,
			t1.PeContrPatro,
			t1.DtIniContInss,
			t1.TmpInssCalcu,
			t1.TmpContribInss,
			t1.VlBenefiInss,
			t1.IddIniApoInss,
			t3.IddPartEvol,
			t3.IddConjEvol,
			t3.t,
			t4.PC_REAJUSTE AS ftAtuSal,
			tsn.ex,
			tsn.apxa format=12.8 AS apx,
			max(0, (t9.'lxs'n / t10.'lxs'n)) format=12.8 as pxs,
			t1.CdAutoPatroc,
			txj.vl_taxa_juros,
			(case
				when txrp1.vl_taxa_risco is null
					then 0
					else txrp1.vl_taxa_risco
			end) format=10.6 as vl_taxa_risco_partic,
			(case
				when txrp2.vl_taxa_risco is null
					then 0
					else txrp2.vl_taxa_risco
			end) format=10.6 as vl_taxa_risco_patroc,
			t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join work.taxa_juros txj on (txj.t = min(t3.t, &maxTaxaJuros))
	left join work.taxa_risco txrp1 on (txrp1.t = min(t3.t, &maxTaxaRiscoPartic) and txrp1.id_responsabilidade = 1)
	left join work.taxa_risco txrp2 on (txrp2.t = min(t3.t, &maxTaxaRiscoPatroc) and txrp2.id_responsabilidade = 2)
	inner join work.REAJUSTE_SALARIAL t4 on (t1.CdPatrocPlan = t4.ID_PATROCINADORA and t4.CD_TIPO_REAJUSTE_SALARIAL = 1)
	inner join TABUAS.TABUAS_SERVICO_NORMAL tsn on (t1.CdSexoPartic = tsn.Sexo and t3.IddPartEvol = tsn.Idade and tsn.t = min(t3.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t9 on (t1.CdSexoPartic = t9.Sexo and t3.IddPartEvol = t9.Idade and t9.t = min(t3.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada t10 on (t1.CdSexoPartic = t10.Sexo and t1.IddPartiCalc = t10.Idade and t10.t = min(t3.t, &maxTaxaJuros))
	order by t1.id_participante, t3.t;
quit;


%_eg_conditional_dropds(work.beneficio_cobertura_ativos);
PROC IML;
	load module = GetFatorMediaSalariosInss;
	load module = GetContribuicao;
	load module = GetContribuicaoPercentual;
	load module = GetFatorPrevidenciario;
	load module = CalcSalarioInss;

	use work.beneficio_input_ativos;
		read all var {id_participante DtNascPartic CdSexoPartic VlSdoConPart VlSdoConPatr VlSalEntPrev DtIniContInss TmpInssCalcu TmpContribInss VlBenefiInss IddIniApoInss IddPartEvol IddConjEvol t ftAtuSal ex PeContrParti PeContrPatro apx CdAutoPatroc pxs vl_taxa_juros vl_taxa_risco_partic vl_taxa_risco_patroc} into ativos;
	close;

	qtdAtivos = nrow(ativos);

	if (qtdAtivos > 0) then do;
		cobertura = J(qtdAtivos, 9, 0);
		px1s = 0;
		apx1 = 0;

		DO a = 1 TO qtdAtivos;
			IdParticipante = ativos[a, 1];
			DtNascPartic = ativos[a, 2];
			CdSexoPartic = ativos[a, 3];
			VlSalEntPrev = ativos[a, 6];
			DtIniContInss = ativos[a, 7];
			TmpInssCalcu = ativos[a, 8];
			TmpContribInss = ativos[a, 9];
			VlBenefiInss = ativos[a, 10];
			IddIniApoInss = ativos[a, 11];
			i = ativos[a, 12];
			j = ativos[a, 13];
			t = ativos[a, 14];
			ftAtuSal = ativos[a, 15];
			ex = ativos[a, 16];
			PeContrParti = ativos[a, 17];
			PeContrPatro = ativos[a, 18];
			apx = ativos[a, 19];
			CdAutoPatroc = ativos[a, 20];
			pxs = ativos[a, 21];
			*taxa_juros = ativos[a, 22];
			taxa_risco_partic = ativos[a, 23];
			taxa_risco_patroc = ativos[a, 24];

			ConParSdo = 0;
			ConPatSdo = 0;
			FtRenVit = 0;
			FtPrevideAtc = 0;
			SalConPrj = 0;
			pxs_px1s = 0;

			if (&CdPlanBen = 2) then do;
				VlSdoConPart = 0;
				VlSdoConPatr = 0;
				SalBenefInss = 0;
				beneficioInss = 0;
			end;
			else if (t = 0) then do;
				VlSdoConPart = ativos[a, 4];
				VlSdoConPatr = ativos[a, 5];
				SalBenefInss = 0;
				beneficioInss = 0;

				*--- para REB e Novo Plano ---*;
				apx1 = ativos[a, 19];
				px1s = ativos[a, 21];
				taxa_juros_ant = ativos[a, 22];
				*contribPartic1 = 0;
				*contribPartro1 = 0;
			end;
			else if (t > 0) then do;
				*--- para REB e Novo Plano ---*;
				apx1 = ativos[a - 1, 19];
				px1s = ativos[a - 1, 21];
				taxa_juros_ant = ativos[a-1, 22];
			end;

			if (&CdPlanBen ^= 2) then do;
				*------ Data do calculo na evolucao ------*;
				DtCalcEvol = INTNX('YEAR', &DtCalAval, t, 'S');
				*------ Data de aposentadoria de acordo com a idade na evolucao ------*;
				DtApoEntPrev = INTNX('YEAR', DtNascPartic, i, &vAlignment);

				TmpInssContr = min(TmpInssCalcu + t, TmpContribInss);
				*------ Salário de contribuicao projetado ------*;
				SalConPrj = max(0, round(VlSalEntPrev * ftAtuSal * &FtSalPart, 0.01));

				if (CdAutoPatroc = 0) then
					SalConPrj = max(0, round(SalConPrj * ((1 + &PrSalPart) ** t), 0.01));

				if (pxs > 0 & px1s > 0) then
					pxs_px1s = pxs / px1s;

				if (&CdPlanBen = 1) then do;
					if (CdAutoPatroc = 0) then do;
						ConParSdo = round(max(0, (GetContribuicao(SalConPrj / &FtSalPart) * &NroBenAno * (1 - apx)) * pxs), 0.01);
						ConPatSdo = ConParSdo;
					end;

					VlSdoConPart = max(0, round(VlSdoConPart * pxs_px1s + ConParSdo, 0.01));
					VlSdoConPatr = 0;
				end;
				else if (&CdPlanBen = 4 | &CdPlanBen = 5) then do;
					ConParSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrParti, taxa_risco_partic, &PC_DESPESA_ADM_PARTICIPANTE, apx, 1);
					ConParSdo = max(0, round(ConParSdo * pxs, 0.01));
					
					ConPatSdo = GetContribuicaoPercentual(SalConPrj / &FtSalPart, PeContrPatro, taxa_risco_patroc, &PC_DESPESA_ADM_PATROCINADORA, apx, 0);
					ConPatSdo = max(0, round(ConPatSdo * pxs, 0.01));

					if (t > 0) then do;
						VlSdoConPart = (VlSdoConPart * (1 + taxa_juros_ant) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 4] * (1 + taxa_juros_ant));
						VlSdoConPatr = max(0, round(VlSdoConPatr * (1 + taxa_juros_ant) * pxs_px1s * (1 - apx1) + cobertura[a - 1, 5] * (1 + taxa_juros_ant), 0.01));
					end;

					*contribPartic1 = ConParSdo;
					*contribPartro1 = ConPatSdo;
				end;
					
				if ((t = 0 & i > IddIniApoInss) | (i <= IddIniApoInss)) then do;
					*------ Fator para refletir a média dos 80% maiores salários do inss ------*;
					ftSlBen80 = GetFatorMediaSalariosInss(max(DtIniContInss, &DatMedSal), DtCalcEvol);
					*------ Fator previdenciário na data de aposentadoria integral na entidade / fator de transição ------*;
					auxInssContr = TmpInssContr;
					FtPrevideAtc = GetFatorPrevidenciario(auxInssContr, ex, i, CdSexoPartic);
					*------ Salário para efeito de cálculo do inss - aposentadoria por tempo de contribuição ------*;
					if (VlBenefiInss > 0) then 
						SalBenefInss = round(VlBenefiInss * &FtInssAss * &FtBenInss, 0.01);
					else do;
						SalBenefInss = max(0, min(round(SalConPrj * ftSlBen80, 0.01), round(&TtInssBen * &FtBenInss, 0.01)));
						SalBenefInss = max(0, max(round(SalBenefInss, 0.01), round(&SalMinimo * &FtBenInss, 0.01)));
					end;
					*------ Salário projetado para efeito de cálculo do inss ------*;
					beneficioInss = CalcSalarioInss(CdSexoPartic, VlBenefiInss, DtApoEntPrev, i, TmpInssContr, SalBenefInss, FtPrevideAtc);
					beneficioInss = max(0, round(beneficioInss, 0.01));
				end;
			end;

			cobertura[a, 1] = IdParticipante;
			cobertura[a, 2] = t;
			cobertura[a, 3] = SalConPrj;
			cobertura[a, 4] = ConParSdo;
			cobertura[a, 5] = ConPatSdo;
			cobertura[a, 6] = VlSdoConPart;
			cobertura[a, 7] = VlSdoConPatr;
			cobertura[a, 8] = SalBenefInss;
			cobertura[a, 9] = beneficioInss;
		END;

		create work.beneficio_cobertura_ativos from cobertura[colname={'id_participante' 't' 'SalConPrjEvol' 'ConParSdoEvol' 'ConPatSdoEvol' 'VlSdoConPartEvol' 'VlSdoConPatrEvol' 'SalBenefInssEvol' 'SalProjeInssEvol'}];
			append from cobertura;
		close;

		free ativos cobertura;
	end;
QUIT;

data cobertur.cobertura_ativos;
	merge cobertur.cobertura_ativos work.beneficio_cobertura_ativos;
	by id_participante t;
	format SalConPrjEvol commax14.2 ConParSdoEvol commax14.2 ConPatSdoEvol commax14.2 VlSdoConPartEvol commax14.2 VlSdoConPatrEvol commax14.2 SalBenefInssEvol commax14.2 SalProjeInssEvol commax14.2;
run;

proc delete data = work.beneficio_cobertura_ativos work.beneficio_input_ativos;