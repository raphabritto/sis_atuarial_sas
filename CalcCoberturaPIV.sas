/*-------------------------------------------------------------------------------------------------------------*/
/*-- Programa para cálculo de cobertura para ativos                                                   		 --*/
/*-- Regime de financiamento de capitalização                                                                --*/
/*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*/
/*-- Versão: 11 de março de 2013                                                                             --*/
/*-------------------------------------------------------------------------------------------------------------*/

%_eg_conditional_dropds(cobertur.piv_ativos);
proc sql;
	create table cobertur.piv_ativos as
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
			t7.apxa format=12.8 AS apx,
			max(0, ((t8.Nxcb / t8.Dxcb) - &Fb)) format=12.8 AS ajxcb,
			max(0, ((t9.njxx / t10.djxx) - &Fb)) format=12.8 AS ajxx_i,
			max(0, (t11.Dxs / t12.Dxs)) format=12.8 AS dy_dx, 
			t11.ix,
			max(0, (t7.Mxii / t7.'Dxii*'n)) format=12.8 as Axii,
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

%macro calcCoberturaPiv;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.piv_cobertura_ativos);

		PROC IML;
			load module= GetContribuicao;

			use cobertur.piv_ativos;
				read all var {id_participante t IddPartEvol IddIniApoInss VlBenefiInss SalConPrjEvol SalBenefInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado axiicb ajxcb ajxx_i dy_dx ix apx Axii flg_manutencao_saldo DtAdesaoPlan DtIniBenInss} into ativos where(id_bloco = &a.);
			close;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				coberturaPiv = J(qtdObs, 6, 0);

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
					apx = ativos[a, 18];
					axii = ativos[a, 19];
					flg_manutencao_saldo = ativos[a, 20];
					DtAdesaoPlan = ativos[a, 21]; 
					DtIniBenInss = ativos[a, 22];

					BenTotPiv = 0;
					ConPvdPiv = 0;
					BenLiqPiv = 0;
					*VatBefCobPiv = 0;
					FtRenVitPiv = 0;
					AplicarPxsPIV = 0;
					BenTotPivPxs = 0;

					if ((&CdPlanBen = 1 | &CdPlanBen = 2) & VlBenefiInss = 0 & IddPartEvol < IddIniApoInss) then do;
						if (&CdPlanBen = 1) then do;
							BenTotPivPxs = max(0, round(SalConPrj - SalBenefInss , 0.01));

							if (PeFatReduPbe > 0) then BenTotPivPxs = round(BenTotPivPxs * PeFatReduPbe, 0.01);

							BenTotPivPxs = max(0, round(((SalBenefInss + BenTotPivPxs) * &CtFamPens) - SalBenefInss, 0.01));
							
				     		FtRenVitPiv = round((axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti, 0.0000000001);

							if (FtRenVitPiv > 0) then 
								BenTotPivRev = max(0, round((VlSdoConTot / FtRenVitPiv) * &CtFamPens * &FtBenEnti, 0.01));

							if (BenTotPivPxs > BenTotPivRev) then do;
								BenTotPiv = BenTotPivPxs;
								AplicarPxsPIV = 1;
							end;
							else
								BenTotPiv = BenTotPivRev;

							*------ Contribuição e benefício líquido da cobertura PIV ------;
							ConPvdPiv = GetContribuicao(BenTotPiv/&FtBenEnti) * (1 - &TxaAdmBen);
						end;
						else if (&CdPlanBen = 2) then do;
							BenTotPiv = max(0, round(VlBenSaldado * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
						end;
					end;
					else if ((&CdPlanBen = 5 & DtIniBenInss <= DtAdesaoPlan) | ((&CdPlanBen = 4 | &CdPlanBen = 5) & VlBenefiInss = 0 & IddPartEvol < IddIniApoInss)) then do;
						FtRenVitPiv = max(0, round((axiicb + &CtFamPens * PrbCasado * (ajxcb - ajxx_i)) * &NroBenAno * &FtBenEnti + (axii * &peculioMorteAssistido), 0.0000000001));

						if (flg_manutencao_saldo = 0) then
							BenTotPivPxs = max(0, max(round(SalConPrj - SalBenefInss, 0.01), round(SalConPrj * &percentualSRB, 0.01)));

						if (&CdPlanBen = 5) then
							BenTotPivPxs = max(0, round(BenTotPivPxs - (VlBenSaldado * &FtBenLiquido), 0.01));

						if (FtRenVitPiv > 0) then
							BenTotPivRev = max(0, round((VlSdoConTot / FtRenVitPiv) * &FtBenEnti, &vRoundMoeda));

						if (BenTotPivPxs > BenTotPivRev) then do;
							BenTotPiv = BenTotPivPxs;
							AplicarPxsPIV = 1;
						end;
						else
							BenTotPiv = BenTotPivRev;

						BenTotPiv = round(BenTotPiv * &CtFamPens, 0.01);
					end;

					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						BenLiqPiv = max(0, round((BenTotPiv - ConPvdPiv) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						BenLiqPiv = max(0, round(BenTotPiv - ConPvdPiv, &vRoundMoeda));

					*VatBefCobPiv = max(0, round(BenLiqPiv * dy_dx * PrbCasado * (ajxcb - ajxx_i) * ix * &NroBenAno * (1 - apx), &vRoundMoeda));

					coberturaPiv[a, 1] = ativos[a, 1];
					coberturaPiv[a, 2] = ativos[a, 2];
					coberturaPiv[a, 3] = BenTotPiv;
					coberturaPiv[a, 4] = ConPvdPiv;
					coberturaPiv[a, 5] = BenLiqPiv;
					*coberturaPiv[a, 6] = VatBefCobPiv;
					coberturaPiv[a, 6] = AplicarPxsPIV;
				END;

				create work.piv_cobertura_ativos from coberturaPiv[colname={'id_participante' 't' 'BenTotCobPIV' 'ConPvdCobPIV' 'BenLiqCobPIV' 'AplicarPxsPIV'}];
					append from coberturaPiv;
				close;
			end;
		QUIT;

		data cobertur.piv_ativos;
			merge cobertur.piv_ativos work.piv_cobertura_ativos;
			by id_participante t;
			format BenTotCobPIV COMMAX14.2 ConPvdCobPIV COMMAX14.2 BenLiqCobPIV COMMAX14.2;
		run;
	%end;

	proc delete data = work.piv_cobertura_ativos;
%mend;
%calcCoberturaPiv;

/*%_eg_conditional_dropds(cobertur.piv_produto_ativos);*/
/*proc summary data = cobertur.piv_ativos;*/
/* class id_participante;*/
/* var VatBefCobPIV;*/
/* output out=cobertur.piv_produto_ativos sum=;*/
/*run;*/

/*data cobertur.piv_produto_ativos;*/
/*	set cobertur.piv_produto_ativos;*/
/*	if cmiss(id_participante) then delete;*/
/*	drop _TYPE_ _FREQ_;*/
/*run;*/