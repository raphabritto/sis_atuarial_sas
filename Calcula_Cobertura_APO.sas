* --- Cálculo das reservas de APO assistidos --- *;

%_eg_conditional_dropds(work.assistidos_cobertura_apo);
PROC IML;
	load module= GetContribuicao;

	use cobertur.assistidos;
		read all var {id_participante IddPartiCalc VlBenefiInss VlBenefiPrev CdTipoBenefi fl_deficiente} into assistidos;
	close cobertur.assistidos;

	use cobertur.assistidos_fatores;
		read all var {ax axii anpen reajuste_salario} into fatores;
	close cobertur.assistidos_fatores;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		cobertura_apo = J(qtdObs, 6, 0);

		do a = 1 to qtdObs;
			idade_partic = assistidos[a, 2];
			beneficio_inss = assistidos[a, 3];
			beneficio_funcef = assistidos[a, 4];
			tipo_beneficio = assistidos[a, 5];
			isDeficiente = assistidos[a, 6];

			ax = fatores[a, 1];
			axii = fatores[a, 2];
			anpen = fatores[a, 3];
			reajuste_salario = fatores[a, 4];

			beneficio_total_apo = 0;
			contribuicao_apo = 0;
			beneficio_liquido_apo = 0;
			reserva_matematica_apo = 0;
			reserva_matematica_pen = 0;
			ftApo = 0;
			ftPen = 0;

			IF (&CdPlanBen = 1) THEN DO;
				if (beneficio_funcef >= &BenMinimo) then
				    beneficio_total_apo = round((beneficio_funcef + beneficio_inss) * reajuste_salario, 0.01);
				else 
				    beneficio_total_apo = round(((&BenMinimo * &FtBenMin2) + beneficio_inss) * reajuste_salario, 0.01);

				beneficio_total_apo = max(0, round(beneficio_total_apo - (beneficio_inss * &FtInssAss), 0.01));
				contribuicao_apo = GetContribuicao(beneficio_total_apo);
				contribuicao_apo = max(0, round(contribuicao_apo * (1 - &TxaAdmBen), 0.01));
			END;
			ELSE DO;
				if (beneficio_funcef >= &BenMinimo) then
				    beneficio_total_apo = max(0, round(beneficio_funcef * reajuste_salario, 0.01));
				else
					beneficio_total_apo = max(0, round(&BenMinimo * &FtBenMin2, 0.01));
			END;

			beneficio_liquido_apo = round((beneficio_total_apo - contribuicao_apo) * &FtBenEnti, 0.01);

			if (tipo_beneficio = 1 | tipo_beneficio = 2) then
				ftApo = ax;
			else if (tipo_beneficio = 3) then
				ftApo = axii;
			else if (tipo_beneficio = 4 & idade_partic < &MaiorIdad & isDeficiente = 0) then
				ftPen = anpen;
			else if (tipo_beneficio = 4 & idade_partic >= &MaiorIdad & isDeficiente = 0) then
				ftPen = ax;
			else if (tipo_beneficio = 4 & isDeficiente = 1) then
				ftPen = axii;

			reserva_matematica_apo = max(0, round(beneficio_liquido_apo * &NroBenAno * ftApo, 0.01));
			reserva_matematica_pen = max(0, round(beneficio_liquido_apo * &NroBenAno * ftPen, 0.01));

			cobertura_apo[a, 1] = assistidos[a, 1];
			cobertura_apo[a, 2] = beneficio_total_apo;
			cobertura_apo[a, 3] = contribuicao_apo;
			cobertura_apo[a, 4] = beneficio_liquido_apo;
			cobertura_apo[a, 5] = reserva_matematica_apo;
			cobertura_apo[a, 6] = reserva_matematica_pen;
		end;
	
		create work.assistidos_cobertura_apo from cobertura_apo[colname={'id_participante' 'BenTotApo' 'ConPvdApo' 'BenLiqCobApo' 'ResMatApo' 'ResMatPenTemp'}];
			append from cobertura_apo;
		close work.assistidos_cobertura_apo;

		free assistidos cobertura_apo fatores;
	end;
QUIT;

data cobertur.assistidos;
	merge cobertur.assistidos work.assistidos_cobertura_apo;
	by id_participante;
	format BenTotApo commax14.2 ConPvdApo commax14.2 BenLiqCobApo commax14.2 ResMatApo commax14.2 ResMatPenTemp commax14.2 ResMatPen commax14.2;
	ResMatPen = ResMatPenTemp;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
