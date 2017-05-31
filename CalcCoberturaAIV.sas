*-------------------------------------------------------------------------------------------------------------*;
*-- AIV - APOSENTADORIA POR INVALIDEZ DE ATIVO						                                        --*;
*-- Versão: 13 de dezembro de 2016                                                                          --*;
*-------------------------------------------------------------------------------------------------------------*;

%_eg_conditional_dropds(cobertur.aiv_ativos);
proc sql;
	create table cobertur.aiv_ativos as
	select t1.id_participante,
			t3.t,
			t3.IddPartEvol,
			t1.IddIniApoInss,
			t1.VlBenefiInss,
			t3.SalConPrjEvol,
			t3.SalBenefInssEvol,
			t3.VlSdoConPartEvol,
			t3.VlSdoConPatrEvol,
			t1.VlBenSaldado,
			t1.PeFatReduPbe,
			t1.PrbCasado,
			t1.flg_manutencao_saldo,
			t1.DtAdesaoPlan,
			t1.DtIniBenInss,
			max(0, ((t7.Nxiicb / t7.Dxiicb) - &Fb)) format=12.8 AS axiicb,
			max(0, ((t8.Nxcb / t8.Dxcb) - &Fb)) format=12.8 AS ajxcb,
			max(0, ((t9.njxx / t10.djxx) - &Fb)) format=12.8 AS ajxx_i,
			max(0, (t11.Dxs / t12.Dxs)) format=12.8 AS dy_dx,
			t11.ix,
			max(0, (t7.Mxii / t7.'Dxii*'n)) format=12.8 as Axii,
			t7.apxa format=12.8 AS apx,
			t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join TABUAS.TABUAS_SERVICO_NORMAL t7 on (t1.CdSexoPartic = t7.Sexo and t3.IddPartEvol = t7.Idade and t7.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_NORMAL t8 on (t1.CdSexoConjug = t8.Sexo and t3.IddConjEvol = t8.Idade and t8.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_PENSAO_NJXX t9 on (t1.CdSexoPartic = t9.sexo AND t3.IddPartEvol = t9.idade_x AND t3.IddConjEvol = t9.idade_j AND t9.tipo = 2 and t9.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_PENSAO_DJXX t10 on (t1.CdSexoPartic = t10.sexo AND t3.IddPartEvol = t10.idade_x AND t3.IddConjEvol = t10.idade_j AND t10.tipo = 2 and t10.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t11 on (t1.CdSexoPartic = t11.Sexo AND t3.IddPartEvol = t11.Idade and t11.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t12 on (t1.CdSexoPartic = t12.Sexo AND t1.IddPartiCalc = t12.Idade and t12.t = 0)
	order by t1.id_participante, t3.t;
quit;

%macro calcCoberturaAiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.aiv_cobertura_ativos);

		PROC IML;
			load module= GetContribuicao;

			use cobertur.aiv_ativos;
				read all var {id_participante t IddPartEvol IddIniApoInss VlBenefiInss SalConPrjEvol SalBenefInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado axiicb ajxcb ajxx_i dy_dx ix Axii apx flg_manutencao_saldo DtAdesaoPlan DtIniBenInss} into ativos where (id_bloco = &a.);
			close;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				coberturaAiv = J(qtdObs, 6, 0);

				DO a = 1 TO qtdObs;
					IddPartEvol = ativos[a, 3];
					IddIniApoInss = ativos[a, 4];
					VlBenefiInss = ativos[a, 5];
					SalConPrj = ativos[a, 6];
					SalBenefInss = ativos[a, 7];
					VlSdoConPart = ativos[a, 8];
					VlSdoConPatr = ativos[a, 9];
					VlSdoConTot = VlSdoConPart + VlSdoConPatr;
					VlBenSaldado = ativos[a, 10];
					PeFatReduPbe = ativos[a, 11];
					PrbCasado = ativos[a, 12];
					axiicb = ativos[a, 13];
					ajxcb = ativos[a, 14];
					ajxx_i = ativos[a, 15];
					dy_dx = ativos[a, 16];
					ix = ativos[a, 17];
					axii = ativos[a, 18]; 
					apx = ativos[a, 19];
					flg_manutencao_saldo = ativos[a, 20];
					DtAdesaoPlan = ativos[a, 21];
					DtIniBenInss = ativos[a, 22];

					BenTotAiv = 0;
					ConPvdAiv = 0;
					BenLiqAiv = 0;
					*VatBefCobAiv = 0;
					FatRenVitAiv = 0;
					*despesaBUA = 0;
					*ResMatBenefConc = 0;
					AplicarPxsAIV = 0;
					BenTotAivPxs = 0;

					*------ Beneficio total da cobertura AIV ------;
					if ((&CdPlanBen = 1 | &CdPlanBen = 2) & VlBenefiInss = 0 & IddPartEvol < IddIniApoInss) then do; *--- REG REPLAN NÃO SALDADO e REG REPLAN SALDADO ---*;
						if (&CdPlanBen = 1) then do;
							BenTotAivPxs = max(0, round(SalConPrj - SalBenefInss, 0.01));

							if (PeFatReduPbe > 0) then BenTotAivPxs = round(BenTotAivPxs * PeFatReduPbe, 0.01);

							FatRenVitAiv = max(0, round((axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti, 0.0000000001));

							if (FatRenVitAiv > 0) then
								BenTotAivRev = max(0, round((VlSdoConTot / FatRenVitAiv) * &FtBenEnti, 0.01));

							if (BenTotAivPxs > BenTotAivRev) then do;
								BenTotAiv = BenTotAivPxs;
								AplicarPxsAIV = 1;
							end;
							else 
								BenTotAiv = BenTotAivRev;

							*------ Contribuição e benefício líquido da cobertura AIV ------;
							ConPvdAiv = GetContribuicao(BenTotAiv/&FtBenEnti) * (1 - &TxaAdmBen);
						end;
						else if (&CdPlanBen = 2) then do;
							BenTotAiv = VlBenSaldado * &FtBenLiquido * &FtBenEnti;
							AplicarPxsAIV = 1;
						end;
					end;
					else if ((&CdPlanBen = 5 & DtIniBenInss <= DtAdesaoPlan) | ((&CdPlanBen = 4 | &CdPlanBen = 5) & VlBenefiInss = 0 & IddPartEvol < IddIniApoInss)) then do;
						FtRenVitAiv = max(0, round((axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti + (axii * &peculioMorteAssistido), 0.0000000001));

						if (flg_manutencao_saldo = 0) then
							BenTotAivPxs = max(0, max(round(SalConPrj - SalBenefInss, 0.01), round(SalConPrj * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotAivPxs = max(0, round(BenTotAivPxs - (VlBenSaldado * &FtBenLiquido), 0.01));

						if (FtRenVitAiv > 0) then
							BenTotAivRev = max(0, round((VlSdoConTot / FtRenVitAiv) * &FtBenEnti, &vRoundMoeda));

						if (BenTotAivPxs > BenTotAivRev) then do;
							BenTotAiv = BenTotAivPxs;
							AplicarPxsAIV = 1;
						end;
						else 
							BenTotAiv = BenTotAivRev;
					end;

					*if (&CdPlanBen ^= 1) then
						ResMatBenefConc = max(0, round((BenTotAiv * (axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno) + ((BenTotAiv / &FtBenEnti) * (axii * &peculioMorteAssistido)), 0.01));

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						BenLiqAiv = max(0, round((BenTotAiv - ConPvdAiv) * (1 - &percentualBUA * &percentualSaqueBUA), 0.01));
					else
						BenLiqAiv = max(0, round(BenTotAiv - ConPvdAiv, 0.01));

					*VatBefCobAiv = max(0, round(BenLiqAiv * dy_dx * axiicb * ix * &NroBenAno * (1 - apx), &vRoundMoeda));

					coberturaAiv[a, 1] = ativos[a, 1];
					coberturaAiv[a, 2] = ativos[a, 2];
					coberturaAiv[a, 3] = BenTotAiv;
					coberturaAiv[a, 4] = ConPvdAiv;
					coberturaAiv[a, 5] = BenLiqAiv;
					*coberturaAiv[a, 6] = VatBefCobAiv;
					*coberturaAiv[a, 7] = despesaBUA;
					*coberturaAiv[a, 8] = ResMatBenefConc;
					coberturaAiv[a, 6] = AplicarPxsAIV;
				END;

				create work.aiv_cobertura_ativos from coberturaAiv[colname={'id_participante' 't' 'BenTotCobAIV' 'ConPvdCobAIV' 'BenLiqCobAIV' 'AplicarPxsAIV'}];
					append from coberturaAiv;
				close;
			end;
		QUIT;

		data cobertur.aiv_ativos;
			merge cobertur.aiv_ativos work.aiv_cobertura_ativos;
			by id_participante t;
			format BenTotCobAIV COMMAX14.2 ConPvdCobAIV COMMAX14.2 BenLiqCobAIV COMMAX14.2;
		run;
	%end;

	proc delete data = work.aiv_cobertura_ativos;
%mend;
%calcCoberturaAiv;

/*%_eg_conditional_dropds(cobertur.aiv_produto_ativos);*/
/*proc summary data = cobertur.aiv_ativos;*/
/* class id_participante;*/
/* var VatBefCobAIV;*/
/* output out=cobertur.aiv_produto_ativos sum=;*/
/*run; */
/**/
/*data cobertur.aiv_produto_ativos;*/
/*	set cobertur.aiv_produto_ativos;*/
/*	if cmiss(id_participante) then delete;*/
/*	drop _TYPE_ _FREQ_;*/
/*run;*/
