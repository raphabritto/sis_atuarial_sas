* --- Cálculo das reservas de APO assistidos --- *;

%_eg_conditional_dropds(cobertur.apo_assistidos);
proc sql;
	create table cobertur.apo_assistidos as
	select t1.id_participante,
		   t1.IddPartiCalc,
		   t1.VlBenefiInss,
		   t1.VlBenefiPrev,
		   t1.CdTipoBenefi,
		   t1.fl_deficiente,
		   t1.ftAtuSal,
		   t1.CdCopensao,
		   t4.ax,
		   t4.axii,
		   t4.anpen
	from partic.assistidos t1
	inner join work.assistidos_fatores t4 on (t1.id_participante = t4.id_participante)
	order by t1.id_participante;
quit;

%_eg_conditional_dropds(work.apo_cobertura_assistidos);
PROC IML;
	load module= GetContribuicao;

	use cobertur.apo_assistidos;
		read all var {id_participante IddPartiCalc VlBenefiInss VlBenefiPrev CdTipoBenefi ftAtuSal ax axii anpen fl_deficiente} into assistidos;
	close;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		coberturaApo = J(qtdObs, 6, 0);

		do a = 1 to qtdObs;
			*IdParticipante = assistido[a, 1];
			IddPartiCalc = assistidos[a, 2];
			VlBenefiInss = assistidos[a, 3];
			VlBenefiPrev = assistidos[a, 4];
			CdTipoBenefi = assistidos[a, 5];
			ftAtuSal = assistidos[a, 6];
			ax = assistidos[a, 7];
			axii = assistidos[a, 8];
			anpen = assistidos[a, 9];
			isDeficiente = assistidos[a, 10];

			BenTotApo = 0;
			ConPvdApo = 0;
			BenLiqCobApo = 0;
			ResMatApo = 0;
			ftApo = 0;
			ftPen = 0;
			ResMatPen = 0;

			IF (&CdPlanBen = 1) THEN DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotApo = round((VlBenefiPrev + VlBenefiInss) * ftAtuSal, 0.01);
				else 
				    BenTotApo = round(((&BenMinimo * &FtBenMin2) + VlBenefiInss) * ftAtuSal, 0.01);

				BenTotApo = max(0, round(BenTotApo - (VlBenefiInss * &FtInssAss), 0.01));
				ConPvdApo = GetContribuicao(BenTotApo);
				ConPvdApo = max(0, round(ConPvdApo * (1 - &TxaAdmBen), 0.01));
			END;
			ELSE DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotApo = max(0, round(VlBenefiPrev * ftAtuSal, 0.01));
				else
					BenTotApo = max(0, round(&BenMinimo * &FtBenMin2, 0.01));

				*ConPvdApo = round(BenTotApo * &TxaAdmBen, 0.01);
			END;

			BenLiqCobApo = round((BenTotApo - ConPvdApo) * &FtBenEnti, 0.01);

			if (CdTipoBenefi = 1 | CdTipoBenefi = 2) then
				ftApo = ax;
			else if (CdTipoBenefi = 3) then
				ftApo = axii;
			else if (CdTipoBenefi = 4 & IddPartiCalc < &MaiorIdad & isDeficiente = 0) then
				ftPen = anpen;
			else if (CdTipoBenefi = 4 & IddPartiCalc >= &MaiorIdad & isDeficiente = 0) then
				ftPen = ax;
			else if (CdTipoBenefi = 4 & isDeficiente = 1) then
				ftPen = axii;

			ResMatApo = max(0, round(BenLiqCobApo * &NroBenAno * ftApo, 0.01));
			ResMatPen = max(0, round(BenLiqCobApo * &NroBenAno * ftPen, 0.01));

			coberturaApo[a, 1] = assistidos[a, 1];
			coberturaApo[a, 2] = BenTotApo;
			coberturaApo[a, 3] = ConPvdApo;
			coberturaApo[a, 4] = BenLiqCobApo;
			coberturaApo[a, 5] = ResMatApo;
			coberturaApo[a, 6] = ResMatPen;
		end;
	
		create work.apo_cobertura_assistidos from coberturaApo[colname={'id_participante' 'BenTotApo' 'ConPvdApo' 'BenLiqCobApo' 'ResMatApo' 'ResMatPenTemp'}];
			append from coberturaApo;
		close;
	end;
QUIT;

data cobertur.apo_assistidos;
	merge cobertur.apo_assistidos work.apo_cobertura_assistidos;
	format BenTotApo commax14.2 ConPvdApo commax14.2 BenLiqCobApo commax14.2 ResMatApo commax14.2 ResMatPenTemp commax14.2 ResMatPen commax14.2;
	ResMatPen = ResMatPenTemp;
run;

%_eg_conditional_dropds(work.apo_cobertura_assistidos);
