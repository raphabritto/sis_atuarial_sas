
%_eg_conditional_dropds(cobertur.fut_assistidos);
proc sql;
	create table cobertur.fut_assistidos as
	select t1.Id_Participante,
			t1.VlBenefiInss,
			t1.VlBenefiPrev,
			t1.CdTipoBenefi,
			t1.IddConjuCalc,
			t1.IddFilJovCalc,
			t1.IddFilInvCalc,
			t1.ftAtuSal,
			t4.ax,
			t4.ajx,
			t4.ajxx,
			t4.ajxx_i,
			t4.ajxii,
			t4.ajxxi_,
			t4.ajxxii,
			t4.dxn1_dx,
			t4.axn1,
			t4.an1,
			t4.axii,
			t4.dxn1ii_dxii,
			t4.axn1ii,
			t4.djxn1_djx,
			t4.ajxn1,
			t4.lxn1_lx,
			t4.ljxn1_ljx,
			t4.descap,
			t4.ajxn1xn1,
			t4.lxn1ii_lxii,
			t4.ajxn1xn1_i,
			t4.djxn1ii_djxii,
			t4.ajxn1ii,
			t4.ljxn1ii_ljxii,
			t4.ajxn1xn1i_,
			t4.ajxn1xn1ii
	from partic.assistidos t1
		inner join work.assistidos_fatores t4 on (t1.id_participante = t4.id_participante)
	order by t1.id_participante;
quit;

%_eg_conditional_dropds(work.fut_cobertura_assistidos);
PROC IML;
	load module= GetContribuicao;

	use cobertur.fut_assistidos;
		read all var {Id_Participante VlBenefiInss VlBenefiPrev CdTipoBenefi IddConjuCalc IddFilJovCalc IddFilInvCalc ftAtuSal ax ajx ajxx ajxx_i ajxii ajxxi_ ajxxii dxn1_dx axn1 an1 axii dxn1ii_dxii axn1ii djxn1_djx ajxn1 lxn1_lx ljxn1_ljx descap ajxn1xn1 lxn1ii_lxii ajxn1xn1_i djxn1ii_djxii ajxn1ii ljxn1ii_ljxii ajxn1xn1i_ ajxn1xn1ii} into assistidos;
	close;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0) then do;
		coberturaFut = J(qtdObs, 5, 0);

		do a = 1 to qtdObs;
			VlBenefiInss = assistidos[a, 2];
			VlBenefiPrev = assistidos[a, 3];
			CdTipoBenefi = assistidos[a, 4];
			IddConjuCalc = assistidos[a, 5];
			IddFilJovCalc = assistidos[a, 6];
			IddFilInvCalc = assistidos[a, 7];
			ftAtuSal = assistidos[a, 8];
			ax = assistidos[a, 9];
			ajx = assistidos[a, 10];
			ajxx = assistidos[a, 11];
			ajxx_i = assistidos[a, 12];
			ajxii = assistidos[a, 13];
			ajxxi_ = assistidos[a, 14];
			ajxxii = assistidos[a, 15];
			dxn1_dx = assistidos[a, 16];
			axn1 = assistidos[a, 17];
			an1 = assistidos[a, 18];
			axii = assistidos[a, 19];
			dxn1ii_dxii = assistidos[a, 20];
			axn1ii = assistidos[a, 21];
			djxn1_djx = assistidos[a, 22];
			ajxn1 = assistidos[a, 23];
			lxn1_lx = assistidos[a, 24];
			ljxn1_ljx = assistidos[a, 25];
			descap = assistidos[a, 26];
			ajxn1xn1 = assistidos[a, 27];
			lxn1ii_lxii = assistidos[a, 28];
			ajxn1xn1_i = assistidos[a, 29];
			djxn1ii_djxii = assistidos[a, 30];
			ajxn1ii = assistidos[a, 31];
			ljxn1ii_ljxii = assistidos[a, 32];
			ajxn1xn1i_ = assistidos[a, 33];
			ajxn1xn1ii = assistidos[a, 34];

			BenTotFut = 0;
			ConPvdFut = 0;
			BenLiqCobFut = 0;
			ResMatFut = 0;
			ftFut = 0;

			IF (&CdPlanBen = 1) THEN DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotFut = round((VlBenefiPrev + VlBenefiInss) * ftAtuSal * &CtFamPens, 0.0000000001);
				else if (VlBenefiPrev < &BenMinimo) then
				    BenTotFut = round(((&BenMinimo * &FtBenMin2) + VlBenefiInss) * ftAtuSal * &CtFamPens, 0.0000000001);

				BenTotFut = max(0, round(BenTotFut - (VlBenefiInss * &FtInssAss), 0.01));
				ConPvdFut = GetContribuicao(BenTotFut) * (1 - &TxaAdmBen);
			END;
			ELSE DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotFut = max(0, round(VlBenefiPrev * ftAtuSal * &CtFamPens, 0.01));
				else if (VlBenefiPrev < &BenMinimo) then
				    BenTotFut = max(0, round(&BenMinimo * &FtBenMin2, 0.01));
			END;

			BenLiqCobFut = round((BenTotFut - ConPvdFut) * &FtBenEnti, 0.01);

			if ((CdTipoBenefi = 1) | (CdTipoBenefi = 2)) then do;
				v1 = max(0, round(ajx - ajxx, 0.0000000001));
				v2 = max(0, round(ajxii - ajxxi_, 0.0000000001));
				v3 = max(0, round(an1 - (ax - (dxn1_dx * axn1)), 0.0000000001));
				v5 = max(0, round(djxn1_djx * ajxn1, 0.0000000001));
				v6 = max(0, round(lxn1_lx * ljxn1_ljx * descap * ajxn1xn1, 0.0000000001));
				v7 = max(0, round(djxn1ii_djxii * ajxn1ii, 0.0000000001));
				v8 = max(0, round(ljxn1ii_ljxii * lxn1_lx * descap * ajxn1xn1i_, 0.0000000001));
				v9 = round((v3 + (v5 - v6)), 0.0000000001);
				v10 = round(v3 + (v7 - v8), 0.0000000001);

		        if (IddConjuCalc ^= . & IddFilJovCalc = . & IddFilInvCalc = .) then
					ftFut = v1;
				else if (IddConjuCalc = . & IddFilJovCalc = . & IddFilInvCalc ^= .) then
					ftFut = v2;
				else if (IddConjuCalc ^= . & IddFilJovCalc = . & IddFilInvCalc ^= .) then
					ftFut = max(v1, v2);
				else if (IddConjuCalc = . & IddFilJovCalc ^= . & IddFilInvCalc = .) then
					ftFut = v3;
				else if (IddConjuCalc ^= . & IddFilJovCalc ^= . & IddFilInvCalc = .) then
					ftFut = max(v1, v9);
				else if (IddConjuCalc = . & IddFilJovCalc ^= . & IddFilInvCalc ^= .) then
					ftFut = max(v2, v10);
				else if (IddConjuCalc ^= . & IddFilJovCalc ^= . & IddFilInvCalc ^= .) then
					ftFut = max(0, max(max(v1, v9), max(v2, v10)));
			end;
			else if (CdTipoBenefi = 3) then do;
				v1 = max(0, round(ajx - ajxx_i, 0.0000000001));
				v2 = max(0, round(ajxii - ajxxii, 0.0000000001));
				v3 = max(0, round(an1 - (axii - (dxn1ii_dxii * axn1ii)), 0.0000000001));
				v5 = max(0, round(djxn1_djx * ajxn1, 0.0000000001));
				v6 = max(0, round(lxn1ii_lxii * ljxn1_ljx * descap * ajxn1xn1_i, 0.0000000001));
				v7 = max(0, round(djxn1ii_djxii * ajxn1ii, 0.0000000001));
				v8 = max(0, round(lxn1ii_lxii * ljxn1ii_ljxii * descap * ajxn1xn1ii, 0.0000000001));
				v9 = round(v3 + (v5 - v6), 0.0000000001);
				v10 = round(v3 + (v7 - v8), 0.0000000001);
	
				if (IddConjuCalc ^= . & IddFilJovCalc = . & IddFilInvCalc = .) then
					ftFut = v1;
				else if (IddConjuCalc = . & IddFilJovCalc = . & IddFilInvCalc ^= .) then
					ftFut = v2;
				else if (IddConjuCalc ^= . & IddFilJovCalc = . & IddFilInvCalc ^= .) then
					ftFut = max(v1, v2);
				else if (IddConjuCalc = . & IddFilJovCalc ^= . & IddFilInvCalc = .) then
					ftFut = v3;
				else if (IddConjuCalc ^= . & IddFilJovCalc ^= . & IddFilInvCalc = .) then
					ftFut = max(v1, v9);
				else if (IddConjuCalc = . & IddFilJovCalc ^= . & IddFilInvCalc ^= .) then
					ftFut = max(v2, v10);
				else if (IddConjuCalc ^= . & IddFilJovCalc ^= . & IddFilInvCalc ^= .) then
					ftFut = max(0, max(max(v1, v9), max(v2, v10)));
			end;

			ResMatFut = max(0, round(BenLiqCobFut * &NroBenAno * ftFut, 0.01));

			coberturaFut[a, 1] = assistidos[a, 1];
			coberturaFut[a, 2] = BenTotFut;
			coberturaFut[a, 3] = ConPvdFut;
			coberturaFut[a, 4] = BenLiqCobFut;
			coberturaFut[a, 5] = ResMatFut;
		end;

		create work.fut_cobertura_assistidos from coberturaFut[colname={'id_participante' 'BenTotFut' 'ConPvdFut' 'BenLiqCobFut' 'ResMatFut'}];
			append from coberturaFut;
		close;
	end;
QUIT;

DATA cobertur.fut_assistidos;
	merge cobertur.fut_assistidos work.fut_cobertura_assistidos;
	by id_participante;
	format BenTotFut commax14.2 ConPvdFut commax14.2 BenLiqCobFut commax14.2 ResMatFut commax14.2;
run;

%_eg_conditional_dropds(work.fut_cobertura_assistidos);