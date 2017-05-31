
%_eg_conditional_dropds(cobertur.axfi_ativos);
proc sql;
	create table cobertur.axfi_ativos as
	select t1.id_participante,
			t3.t,
			t3.IddPartEvol,
			t1.IddIniApoInss,
			t3.SalConPrjEvol,
			t1.VlBenefiInss,
			t3.SalBenefInssEvol,
			aiv.BenTotCobAIV,
			t11.qxi,
			t11.ix,
			t7.apxa format=12.8 AS apx,
			t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join cobertur.aiv_ativos aiv on (t1.id_participante = aiv.id_participante and t3.t = aiv.t)
	inner join TABUAS.TABUAS_SERVICO_NORMAL t7 on (t1.CdSexoPartic = t7.Sexo and t3.IddPartEvol = t7.Idade and t7.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t11 on (t1.CdSexoPartic = t11.Sexo AND t3.IddPartEvol = t11.Idade and t11.t = min(t3.t, &maxTaxaJuros))
	order by t1.id_participante, t3.t;
quit;

%_eg_conditional_dropds(work.axfi_cobertura_ativos);
PROC IML;
	load module= GetContribuicao;

	use cobertur.axfi_ativos;
		read all var {id_participante t IddPartEvol IddIniApoInss VlBenefiInss SalBenefInssEvol BenTotCobAiv qxi ix apx} into ativos;
	close;

	qtdObs = nrow(ativos);

	if (qtdObs > 0) then do;
		coberturaAxfi = J(qtdObs, 4, 0);

		DO a = 1 TO qtdObs;
			t = ativos[a, 2];
			IddPartEvol = ativos[a, 3];
			IddIniApoInss = ativos[a, 4];
			VlBenefiInss = ativos[a, 5];
			SalBenefInss = ativos[a, 6];
			BenTotAiv = ativos[a, 7];
			qxii = ativos[a, 8];
			ix = ativos[a, 9];
			apx = ativos[a, 10];

			BenAuxFunInv = 0;
			CusNorAuxFunFutInv = 0;

			if (&CdPlanBen = 1) then do;
				*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
				if (t = 0 & VlBenefiInss = 0 & IddPartEvol < IddIniApoInss) then do;
		        	BenAuxFunInv = max(0, round(BenTotAiv + SalBenefInss, 0.01) * 2);
			        CusNorAuxFunFutInv = max(0, round(BenAuxFunInv * (qxii * ix) * (1 - apx), 0.01));
				end;
			end;

			coberturaAxfi[a, 1] = ativos[a, 1];
			coberturaAxfi[a, 2] = ativos[a, 2];
			coberturaAxfi[a, 3] = BenAuxFunInv;
			coberturaAxfi[a, 4] = CusNorAuxFunFutInv;
		END;

		create work.axfi_cobertura_ativos from coberturaAxfi[colname={'id_participante' 't' 'BenefCobAxfi' 'CusNorCobAXFI'}];
			append from coberturaAxfi;
		close;
	end;
QUIT;

data cobertur.axfi_ativos;
	merge cobertur.axfi_ativos work.axfi_cobertura_ativos;
	by id_participante t;
	format BenefCobAXFI COMMAX14.2 CusNorCobAXFI COMMAX14.2;
run;

proc delete data = work.axfi_cobertura_ativos;

%_eg_conditional_dropds(cobertur.axfi_produto_ativos);
proc summary data = cobertur.axfi_ativos;
 class id_participante;
 var CusNorCobAXFI;
 output out=cobertur.axfi_produto_ativos sum=;
run; 

data cobertur.axfi_produto_ativos;
	set cobertur.axfi_produto_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;