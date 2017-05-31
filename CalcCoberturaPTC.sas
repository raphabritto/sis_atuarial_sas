/*-- Programa para cálculo de cobertura para ativos                                                   		 --*/
/*-- Regime de financiamento de capitalização                                                                --*/
/*-- Método de financiamento do tipo crédito unitário projetado - PUC                                        --*/
/*-- Versão: 11 de março de 2013                                                                             --*/

%_eg_conditional_dropds(cobertur.ptc_ativos);
proc sql;
	create table cobertur.ptc_ativos as
	select t1.id_participante,
			t3.t,
			t3.SalConPrjEvol,
			t3.SalProjeInssEvol,
			t3.VlSdoConPartEvol,
			t3.VlSdoConPatrEvol,
			t1.VlBenSaldado,
			t1.PeFatReduPbe,
			t1.PrbCasado,
			max(0, ((t7.Nxcb / t7.Dxcb) - &Fb)) format=12.8 AS axcb,
			max(0, ((t8.Nxcb / t8.Dxcb) - &Fb)) format=12.8 AS ajxcb,
			max(0, ((t9.njxx / t10.djxx) - &Fb)) format=12.8 AS ajxx,
			max(0, (t11.Dxs / t12.Dxs)) format=12.8 AS dy_dx,
			max(0, (t7.Mx / t7.'Dx*'n)) format=12.8 as Ax,
			(case
				when t3.t = 0
					then t7.apxa
					else t7.apx
			end) format=12.8 AS apx,
			t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join TABUAS.TABUAS_SERVICO_NORMAL t7 on (t1.CdSexoPartic = t7.Sexo and t3.IddPartEvol = t7.Idade and t7.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_NORMAL t8 on (t1.CdSexoConjug = t8.Sexo and t3.IddConjEvol = t8.Idade and t8.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_PENSAO_NJXX t9 on (t1.CdSexoPartic = t9.sexo AND t3.IddPartEvol = t9.idade_x AND t3.IddConjEvol = t9.idade_j AND t9.tipo = 1 and t9.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_PENSAO_DJXX t10 on (t1.CdSexoPartic = t10.sexo AND t3.IddPartEvol = t10.idade_x AND t3.IddConjEvol = t10.idade_j AND t10.tipo = 1 and t10.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t11 on (t1.CdSexoPartic = t11.Sexo AND t3.IddPartEvol = t11.Idade and t11.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t12 on (t1.CdSexoPartic = t12.Sexo AND t1.IddPartiCalc = t12.Idade and t12.t = 0)
	order by t1.id_participante, t3.t;
quit;

%macro calcCoberturaPtc;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.ptc_cobertura_ativos);

		PROC IML;
			load module= GetContribuicao;

			use cobertur.ptc_ativos;
				read all var {id_participante t SalConPrjEvol SalProjeInssEvol VlSdoConPartEvol VlSdoConPatrEvol VlBenSaldado PeFatReduPbe PrbCasado axcb ajxcb ajxx dy_dx apx Ax} into ativos where (id_bloco = &a.);
			close;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				coberturaPtc = J(qtdObs, 5, 0);

				DO a = 1 TO qtdObs;
					BenTotCobPtc = 0;
					ConPrvCobPtc = 0;
					BenLiqCobPtc = 0;
					*VatBefCobPtc = 0;

					SalConPrj = ativos[a, 3];
					SalProjeInss = ativos[a, 4];
					VlSdoConPart = ativos[a, 5];
					VlSdoConPatr = ativos[a, 6];
					VlSdoConTot = VlSdoConPart + VlSdoConPatr;
					VlBenSaldado = ativos[a, 7];
					PeFatReduPbe = ativos[a, 8];
					PrbCasado = ativos[a, 9];
					axcb = ativos[a, 10];
					ajxcb = ativos[a, 11];
					ajxx = ativos[a, 12];
					dy_dx = ativos[a, 13];
					apx = ativos[a, 14];
					ax = ativos[a, 15];
					
					*** CALCULO DO BENEFICIO TOTAL DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					IF (&CdPlanBen = 1) THEN DO;
						*------ Benefício total da cobertura PTC ------;
						BenTotCobPtc = max(0, round(SalConPrj - SalProjeInss, &vRoundMoeda)); 

 						if (PeFatReduPbe > 0) then 
							BenTotCobPtc = max(0, round(BenTotCobPtc * PeFatReduPbe, &vRoundMoeda));

						BenTotCobPtc = round(((SalProjeInss + BenTotCobPtc) * &CtFamPens) - SalProjeInss, &vRoundMoeda);

						FtRenVitPtc = round((axcb + &CtFamPens * PrbCasado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti, 0.00000001);

						if (FtRenVitPtc > 0) then 
							BenTotCobPtc = max(BenTotCobPtc, round((VlSdoConTot / FtRenVitPtc) * &CtFamPens * &FtBenEnti, &vRoundMoeda));

						*------ Contribuição e benefício líquido da cobertura PTC ------;
						ConPrvCobPtc = GetContribuicao(BenTotCobPtc/&FtBenEnti) * (1 - &TxaAdmBen);
					END;
					ELSE IF (&CdPlanBen = 2) THEN DO;
						BenTotCobPtc = max(0, round(VlBenSaldado * &CtFamPens * &FtBenLiquido * &FtBenEnti, 0.01));
					END;
					ELSE IF (&CdPlanBen = 4 | &CdPlanBen = 5) THEN DO;
						FtRenVitPtc = max(0, round((axcb + &CtFamPens * PrbCasado * (ajxcb - ajxx)) * &NroBenAno * &FtBenEnti + (ax * &peculioMorteAssistido), 0.00000001));
						if (FtRenVitPtc > 0) then do;
							BenTotCobPtc = max(0, round((VlSdoConTot / FtRenVitPtc) * &CtFamPens * &FtBenEnti, &vRoundMoeda));
						end;
					END;

					*** CALCULO DO BENEFICIO LIQUIDO DA PENSAO POR MORTE DE ATIVO POR TEMPO DE CONTRIBUICAO ***;
					if (&CdPlanBen ^= 1 & &percentualSaqueBUA > 0) then
						BenLiqCobPtc = max(0, round((BenTotCobPtc - ConPrvCobPtc) * (1 - &percentualBUA * &percentualSaqueBUA), &vRoundMoeda));
					else
						BenLiqCobPtc = max(0, round(BenTotCobPtc - ConPrvCobPtc, &vRoundMoeda));

					*VatBefCobPtc = max(0, round(BenLiqCobPtc * &NroBenAno * dy_dx * ((ajxcb - ajxx) * PrbCasado) * apx, &vRoundMoeda));

					coberturaPtc[a, 1] = ativos[a, 1];
					coberturaPtc[a, 2] = ativos[a, 2];
					coberturaPtc[a, 3] = BenTotCobPtc;
					coberturaPtc[a, 4] = ConPrvCobPtc;
					coberturaPtc[a, 5] = BenLiqCobPtc;
					*coberturaPtc[a, 6] = VatBefCobPtc;
				END;

				create work.ptc_cobertura_ativos from coberturaPtc[colname={'id_participante' 't' 'BenTotCobPTC' 'ConPrvCobPTC' 'BenLiqCobPTC'}];
					append from coberturaPtc;
				close;
			end;
		QUIT;

		data cobertur.ptc_ativos;
			merge cobertur.ptc_ativos work.ptc_cobertura_ativos;
			by id_participante t;
			format BenTotCobPTC COMMAX14.2 ConPrvCobPTC COMMAX14.2 BenLiqCobPTC COMMAX14.2;
		run;
	%end;

	proc delete data = work.ptc_cobertura_ativos;
%mend;
%calcCoberturaPtc;

/*%_eg_conditional_dropds(cobertur.ptc_produto_ativos);*/
/*proc summary data = cobertur.ptc_ativos;*/
/* class id_participante;*/
/* var VatBefCobPTC;*/
/* output out=cobertur.ptc_produto_ativos sum=;*/
/*run;*/
/**/
/*data cobertur.ptc_produto_ativos;*/
/*	set cobertur.ptc_produto_ativos;*/
/*	if cmiss(id_participante) then delete;*/
/*	drop _TYPE_ _FREQ_;*/
/*run;*/
