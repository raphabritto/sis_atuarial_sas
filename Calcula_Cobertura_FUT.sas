
/*
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
*/

%_eg_conditional_dropds(work.assistidos_cobertura_fut);
PROC IML;
	load module= GetContribuicao;

	use cobertur.assistidos;
		read all var {id_participante VlBenefiInss VlBenefiPrev CdTipoBenefi IddConjuCalc IddFilJovCalc IddFilInvCalc} into assistidos;
	close cobertur.assistidos;

	use cobertur.assistidos_fatores;
		read all var {ax ajx ajxx ajxx_i ajxii ajxxi_ ajxxii dxn1_dx axn1 an1 axii dxn1ii_dxii axn1ii djxn1_djx ajxn1 lxn1_lx ljxn1_ljx descap ajxn1xn1 lxn1ii_lxii ajxn1xn1_i djxn1ii_djxii ajxn1ii ljxn1ii_ljxii ajxn1xn1i_ ajxn1xn1ii reajuste_salario} into fatores;
	close cobertur.assistidos_fatores;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0) then do;
		cobertura_fut = J(qtdObs, 5, 0);

		do a = 1 to qtdObs;
			beneficio_inss = assistidos[a, 2];
			beneficio_funcef = assistidos[a, 3];
			tipo_beneficio = assistidos[a, 4];
			idade_conjug = assistidos[a, 5];
			idade_filho_temporario = assistidos[a, 6];
			idade_filho_invalido = assistidos[a, 7];
			
			ax = fatores[a, 1];
			ajx = fatores[a, 2];
			ajxx = fatores[a, 3];
			ajxx_i = fatores[a, 4];
			ajxii = fatores[a, 5];
			ajxxi_ = fatores[a, 6];
			ajxxii = fatores[a, 7];
			dxn1_dx = fatores[a, 8];
			axn1 = fatores[a, 9];
			an1 = fatores[a, 10];
			axii = fatores[a, 11];
			dxn1ii_dxii = fatores[a, 12];
			axn1ii = fatores[a, 13];
			djxn1_djx = fatores[a, 14];
			ajxn1 = fatores[a, 15];
			lxn1_lx = fatores[a, 16];
			ljxn1_ljx = fatores[a, 17];
			descap = fatores[a, 18];
			ajxn1xn1 = fatores[a, 19];
			lxn1ii_lxii = fatores[a, 20];
			ajxn1xn1_i = fatores[a, 21];
			djxn1ii_djxii = fatores[a, 22];
			ajxn1ii = fatores[a, 23];
			ljxn1ii_ljxii = fatores[a, 24];
			ajxn1xn1i_ = fatores[a, 25];
			ajxn1xn1ii = fatores[a, 26];
			reajuste_salario = fatores[a, 27];

			beneficio_total_fut = 0;
			contribuicao_fut = 0;
			beneficio_liquido_fut = 0;
			reserva_matematica_fut = 0;
			ftFut = 0;

			IF (&CdPlanBen = 1) THEN DO;
				if (beneficio_funcef >= &BenMinimo) then
				    beneficio_total_fut = round((beneficio_funcef + beneficio_inss) * reajuste_salario * &CtFamPens, 0.0000000001);
				else if (beneficio_funcef < &BenMinimo) then
				    beneficio_total_fut = round(((&BenMinimo * &FtBenMin2) + beneficio_inss) * reajuste_salario * &CtFamPens, 0.0000000001);

				beneficio_total_fut = max(0, round(beneficio_total_fut - (beneficio_inss * &FtInssAss), 0.01));
				contribuicao_fut = GetContribuicao(beneficio_total_fut) * (1 - &TxaAdmBen);
			END;
			ELSE DO;
				if (beneficio_funcef >= &BenMinimo) then
				    beneficio_total_fut = max(0, round(beneficio_funcef * reajuste_salario * &CtFamPens, 0.01));
				else if (beneficio_funcef < &BenMinimo) then
				    beneficio_total_fut = max(0, round(&BenMinimo * &FtBenMin2, 0.01));
			END;

			beneficio_liquido_fut = round((beneficio_total_fut - contribuicao_fut) * &FtBenEnti, 0.01);

			if ((tipo_beneficio = 1) | (tipo_beneficio = 2)) then do;
				v1 = max(0, round(ajx - ajxx, 0.0000000001));
				v2 = max(0, round(ajxii - ajxxi_, 0.0000000001));
				v3 = max(0, round(an1 - (ax - (dxn1_dx * axn1)), 0.0000000001));
				v5 = max(0, round(djxn1_djx * ajxn1, 0.0000000001));
				v6 = max(0, round(lxn1_lx * ljxn1_ljx * descap * ajxn1xn1, 0.0000000001));
				v7 = max(0, round(djxn1ii_djxii * ajxn1ii, 0.0000000001));
				v8 = max(0, round(ljxn1ii_ljxii * lxn1_lx * descap * ajxn1xn1i_, 0.0000000001));
				v9 = round((v3 + (v5 - v6)), 0.0000000001);
				v10 = round(v3 + (v7 - v8), 0.0000000001);

		        if (idade_conjug ^= . & idade_filho_temporario = . & idade_filho_invalido = .) then
					ftFut = v1;
				else if (idade_conjug = . & idade_filho_temporario = . & idade_filho_invalido ^= .) then
					ftFut = v2;
				else if (idade_conjug ^= . & idade_filho_temporario = . & idade_filho_invalido ^= .) then
					ftFut = max(v1, v2);
				else if (idade_conjug = . & idade_filho_temporario ^= . & idade_filho_invalido = .) then
					ftFut = v3;
				else if (idade_conjug ^= . & idade_filho_temporario ^= . & idade_filho_invalido = .) then
					ftFut = max(v1, v9);
				else if (idade_conjug = . & idade_filho_temporario ^= . & idade_filho_invalido ^= .) then
					ftFut = max(v2, v10);
				else if (idade_conjug ^= . & idade_filho_temporario ^= . & idade_filho_invalido ^= .) then
					ftFut = max(0, max(max(v1, v9), max(v2, v10)));
			end;
			else if (tipo_beneficio = 3) then do;
				v1 = max(0, round(ajx - ajxx_i, 0.0000000001));
				v2 = max(0, round(ajxii - ajxxii, 0.0000000001));
				v3 = max(0, round(an1 - (axii - (dxn1ii_dxii * axn1ii)), 0.0000000001));
				v5 = max(0, round(djxn1_djx * ajxn1, 0.0000000001));
				v6 = max(0, round(lxn1ii_lxii * ljxn1_ljx * descap * ajxn1xn1_i, 0.0000000001));
				v7 = max(0, round(djxn1ii_djxii * ajxn1ii, 0.0000000001));
				v8 = max(0, round(lxn1ii_lxii * ljxn1ii_ljxii * descap * ajxn1xn1ii, 0.0000000001));
				v9 = round(v3 + (v5 - v6), 0.0000000001);
				v10 = round(v3 + (v7 - v8), 0.0000000001);
	
				if (idade_conjug ^= . & idade_filho_temporario = . & idade_filho_invalido = .) then
					ftFut = v1;
				else if (idade_conjug = . & idade_filho_temporario = . & idade_filho_invalido ^= .) then
					ftFut = v2;
				else if (idade_conjug ^= . & idade_filho_temporario = . & idade_filho_invalido ^= .) then
					ftFut = max(v1, v2);
				else if (idade_conjug = . & idade_filho_temporario ^= . & idade_filho_invalido = .) then
					ftFut = v3;
				else if (idade_conjug ^= . & idade_filho_temporario ^= . & idade_filho_invalido = .) then
					ftFut = max(v1, v9);
				else if (idade_conjug = . & idade_filho_temporario ^= . & idade_filho_invalido ^= .) then
					ftFut = max(v2, v10);
				else if (idade_conjug ^= . & idade_filho_temporario ^= . & idade_filho_invalido ^= .) then
					ftFut = max(0, max(max(v1, v9), max(v2, v10)));
			end;

			reserva_matematica_fut = max(0, round(beneficio_liquido_fut * &NroBenAno * ftFut, 0.01));

			cobertura_fut[a, 1] = assistidos[a, 1];
			cobertura_fut[a, 2] = beneficio_total_fut;
			cobertura_fut[a, 3] = contribuicao_fut;
			cobertura_fut[a, 4] = beneficio_liquido_fut;
			cobertura_fut[a, 5] = reserva_matematica_fut;
		end;

		create work.assistidos_cobertura_fut from cobertura_fut[colname={'id_participante' 'BenTotFut' 'ConPvdFut' 'BenLiqCobFut' 'ResMatFut'}];
			append from cobertura_fut;
		close work.assistidos_cobertura_fut;
	end;
QUIT;

DATA cobertur.assistidos;
	merge cobertur.assistidos work.assistidos_cobertura_fut;
	by id_participante;
	format BenTotFut commax14.2 ConPvdFut commax14.2 BenLiqCobFut commax14.2 ResMatFut commax14.2;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;