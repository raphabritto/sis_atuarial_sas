
%_eg_conditional_dropds(cobertur.axfa_ativos);
proc sql;
	create table cobertur.axfa_ativos as
	select t1.id_participante,
			t3.t,
			t3.SalConPrjEvol,
			t11.qx,
			t7.apxa format=12.8 AS apx,
			t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t3 on (t1.id_participante = t3.id_participante)
	inner join TABUAS.TABUAS_SERVICO_NORMAL t7 on (t1.CdSexoPartic = t7.Sexo and t3.IddPartEvol = t7.Idade and t7.t = min(t3.t, &maxTaxaJuros))
	inner join TABUAS.TABUAS_SERVICO_AJUSTADA t11 on (t1.CdSexoPartic = t11.Sexo AND t3.IddPartEvol = t11.Idade and t11.t = min(t3.t, &maxTaxaJuros))
	order by t1.id_participante, t3.t;
quit;

%_eg_conditional_dropds(work.axfa_cobertura_ativos);
PROC IML;
	load module= GetContribuicao;

	use cobertur.axfa_ativos;
		read all var {id_participante t SalConPrjEvol qx apx} into ativos;
	close;

	qtdObs = nrow(ativos);

	if (qtdObs > 0) then do;
		coberturaAuxFunAt = J(qtdObs, 3, 0);

		DO a = 1 TO qtdObs;
			t = ativos[a, 2];
			SalConPrj = ativos[a, 3];
			qx = ativos[a, 4];
			apx = ativos[a, 5];

			CusNorAuxFunAt = 0;

			if (&CdPlanBen = 1) then do;
				*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
				if (t = 0) then do;
					if (round(apx, 0.00001) = 1) then
		        		CusNorAuxFunAt = max(0, round((SalConPrj/&FtSalPart) * qx, 0.01));
					else
						CusNorAuxFunAt = max(0, round((SalConPrj/&FtSalPart) * qx * (1 - apx), 0.01));
				end;
			end;

			coberturaAuxFunAt[a, 1] = ativos[a, 1];
			coberturaAuxFunAt[a, 2] = ativos[a, 2];
			coberturaAuxFunAt[a, 3] = CusNorAuxFunAt;
		END;

		create work.axfa_cobertura_ativos from coberturaAuxFunAt[colname={'id_participante' 't' 'CusNorCobAXFA'}];
			append from coberturaAuxFunAt;
		close;
	end;
QUIT;

data cobertur.axfa_ativos;
	merge cobertur.axfa_ativos work.axfa_cobertura_ativos;
	by id_participante t;
	format CusNorCobAXFA COMMAX14.2;
run;

proc delete data = work.axfa_cobertura_ativos;

%_eg_conditional_dropds(cobertur.axfa_produto_ativos);
proc summary data = cobertur.axfa_ativos;
 class id_participante;
 var CusNorCobAXFA;
 output out=cobertur.axfa_produto_ativos sum=;
run;

data cobertur.axfa_produto_ativos;
	set cobertur.axfa_produto_ativos;
	if cmiss(id_participante) then delete;
	drop _TYPE_ _FREQ_;
run;