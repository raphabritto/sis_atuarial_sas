* --- Cálculo das reservas de APO assistidos --- *;

%_eg_conditional_dropds(work.assistidos_copensao_fatores);
proc sql;
	create table work.assistidos_copensao_fatores as
	select gp.CdCopensao,
		   gp.idParticipanteVitVal,
		   (case
				when gp.idParticipanteVitVal is null
					then 0
					else max(0, ((nvv.Nxcb / nvv.Dxcb) - &Fb))
		    end) format=.10 as ajx,
		   (case
				when gp.idParticipanteVitVal is null and gp.idParticipanteTemp is not null
					then 0
					else max(0, (nvv1.Dxcb / nvv.Dxcb))
		   end) format=.10 as djxn1_djx,
		   (case
				when gp.idParticipanteVitVal is null and gp.idParticipanteTemp is not null
					then 0
					else max(0, ((nvv1.Nxcb / nvv1.Dxcb) - &Fb))
			end) format=.10 as ajxn1,
		   gp.idParticipanteVitInval,
		   (case
				when gp.idParticipanteVitInval is not null
					then max(0, ((niv.Nxiicb / niv.Dxiicb) - &Fb))
					else 0
			end) format=.10 as ajxii,
			(case
				when gp.idParticipanteVitInval is null and gp.idParticipanteTemp is null
					then 0
					else max(0, (niv1.Dxiicb / niv.Dxiicb))
			end) format=.10 as djxn1ii_djxii,
			(case
				when gp.idParticipanteVitInval is null and gp.idParticipanteTemp is null
					then 0
					else max(0, ((niv1.Nxiicb / niv1.Dxiicb) - &Fb))
			end) format=.10 as ajxn1ii,
		   gp.idParticipanteTemp,
		   (case
				when gp.idParticipanteTemp is not null
					then (max(0, ((1 + ((1 + txc.taxa_juros) / (1 + &PrTxBenef) - 1)) ** (&MaiorIdad - atp.IddPartiCalc) - 1) / (((1 + ((1 + txc.taxa_juros) / (1 + &PrTxBenef) - 1)) ** ((&MaiorIdad - atp.IddPartiCalc) - 1)) * ((1 + txc.taxa_juros) / (1 + &PrTxBenef) - 1)) - &Fb * (1 - (1 + ((1 + txc.taxa_juros) / (1 + &PrTxBenef) - 1)) ** - (&MaiorIdad - atp.IddPartiCalc))))
					else 0
			end) format=.10 AS anpen,
			gp.VlBenefiInssGrupo,
			gp.VlBenefiPrevGrupo,
			f1.reajuste_salario as reajuste_salario_vital,
			f2.reajuste_salario as reajuste_salario_inval,
			f3.reajuste_salario as reajuste_salario_tempor
	from work.ASSISTIDOS_GRUPO_COPENSAO gp
	left join cobertur.assistidos avv on (gp.idParticipanteVitVal = avv.id_participante)
	left join cobertur.assistidos aiv on (gp.idParticipanteVitInval = aiv.id_participante)
	left join cobertur.assistidos atp on (gp.idParticipanteTemp = atp.id_participante)
	left join cobertur.assistidos_fatores f1 on (gp.idParticipanteVitVal = f1.id_participante)
	left join cobertur.assistidos_fatores f2 on (gp.idParticipanteVitInval = f2.id_participante)
	left join cobertur.assistidos_fatores f3 on (gp.idParticipanteTemp = f3.id_participante)
	inner join premissa.taxa_juros txc on (txc.t = 0)
	left join tabuas.tabuas_servico_normal nvv on (avv.CdSexoPartic = nvv.Sexo and avv.IddPartiCalc = nvv.Idade and nvv.t = 0)
	left join tabuas.tabuas_servico_normal nvv1 on (avv.CdSexoPartic = nvv1.Sexo and (avv.IddPartiCalc + &MaiorIdad - atp.IddPartiCalc) = nvv1.Idade and nvv1.t = 0)
	left join tabuas.tabuas_servico_normal niv on (aiv.CdSexoPartic = niv.Sexo and aiv.IddPartiCalc = niv.Idade and niv.t = 0)
	left join tabuas.tabuas_servico_normal niv1 on (aiv.CdSexoPartic = niv1.Sexo and (aiv.IddPartiCalc + &MaiorIdad - atp.IddPartiCalc) = niv1.Idade and niv1.t = 0)
	order by gp.CdCopensao;
quit;

%_eg_conditional_dropds(work.assistidos_copensao_apo);
PROC IML;
	load module= GetContribuicao;

	use work.assistidos_copensao_fatores;
		read all var {CdCopensao idParticipanteVitVal idParticipanteVitInval idParticipanteTemp VlBenefiInssGrupo VlBenefiPrevGrupo reajuste_salario_vital reajuste_salario_inval reajuste_salario_tempor ajx djxn1_djx ajxn1 ajxii djxn1ii_djxii ajxn1ii anpen} into assistidos;
	close work.assistidos_copensao_fatores;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		cobertura_apo = J(qtdObs, 5, 0);

		do a = 1 to qtdObs;
			idParticipanteVitVal = assistidos[a, 2];
			idParticipanteVitInval = assistidos[a, 3];
			idParticipanteTemp = assistidos[a, 4];
			VlBenefiInss = assistidos[a, 5];
			VlBenefiPrev = assistidos[a, 6];
			ftAtuSalVitVal = assistidos[a, 7];
			ftAtuSalVitInv = assistidos[a, 8];
			ftAtuSalTemp = assistidos[a, 9];
			ajx = assistidos[a, 10];
			djxn1_djx = assistidos[a, 11];
			ajxn1 = assistidos[a, 12];
			ajxii = assistidos[a, 13];
			djxn1ii_djxii = assistidos[a, 14];
			ajxn1ii = assistidos[a, 15];
			anpen = assistidos[a, 16];

			BenTotPen = 0;
			ConPvdPen = 0;
			BenLiqCobPen = 0;
			ftPen = 0;
			ResMatPen = 0;
			ftAtuSal = 0;

			if (idParticipanteVitVal ^= .) then
				ftAtuSal = ftAtuSalVitVal;
			else if (idParticipanteVitInval ^= .) then
				ftAtuSal = ftAtuSalVitInv;
			else
				ftAtuSal = ftAtuSalTemp;

			IF (&CdPlanBen = 1) THEN DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotPen = round((VlBenefiPrev + VlBenefiInss) * ftAtuSal, 0.01);
				else 
				    BenTotPen = round(((&BenMinimo * &FtBenMin2) + VlBenefiInss) * ftAtuSal, 0.01);

				BenTotPen = max(0, round(BenTotPen - (VlBenefiInss * &FtInssAss), 0.01));
				ConPvdPen = GetContribuicao(BenTotPen);
				ConPvdPen = max(0, round(ConPvdPen * (1 - &TxaAdmBen), 0.01));
			END;
			ELSE DO;
				if (VlBenefiPrev >= &BenMinimo) then
				    BenTotPen = max(0, round(VlBenefiPrev * ftAtuSal, 0.01));
				else
					BenTotPen = max(0, round(&BenMinimo * &FtBenMin2, 0.01));
			END;

			BenLiqCobPen = round((BenTotPen - ConPvdPen) * &FtBenEnti, 0.01);

			if (idParticipanteVitVal ^= . & idParticipanteVitInval = . & idParticipanteTemp = .) then do;
				ftPen = ajx;
			end;
			else if (idParticipanteVitVal = . & idParticipanteVitInval = . & idParticipanteTemp ^= .) then do;
				ftPen = anpen;
			end;
			else if (idParticipanteVitVal ^= . & idParticipanteVitInval = . & idParticipanteTemp ^= .) then do;
				ftPen = max(0, max(anpen + ajxn1 * djxn1_djx, ajx));
			end;
			else if (idParticipanteVitVal = . & idParticipanteVitInval ^= . & idParticipanteTemp = .) then do;
				ftPen = ajxii;
			end;
			else if (idParticipanteVitVal = . & idParticipanteVitInval ^= . & idParticipanteTemp ^= .) then do;
				ftPen = max(0, max(anpen + ajxn1ii * djxn1ii_djxii, ajxii));
			end;
			else if (idParticipanteVitVal ^= . & idParticipanteVitInval ^= . & idParticipanteTemp ^= .) then do;
				aux1 = max(0, max(anpen + ajxn1 * djxn1_djx, ajx));
				aux2 = max(0, max(anpen + ajxn1ii * djxn1ii_djxii, ajxii));
				ftPen = max(aux1, aux2);
			end;

			ResMatPen = max(0, round(BenLiqCobPen * &NroBenAno * ftPen, 0.01));

			cobertura_apo[a, 1] = assistidos[a, 1];
			cobertura_apo[a, 2] = BenTotPen;
			cobertura_apo[a, 3] = ConPvdPen;
			cobertura_apo[a, 4] = BenLiqCobPen;
			cobertura_apo[a, 5] = ResMatPen;
		end;
	
		create work.assistidos_copensao_apo from cobertura_apo[colname={'CdCopensao' 'BenTotPen' 'ConPvdPen' 'BenLiqCobPen' 'ResMatPen'}];
			append from cobertura_apo;
		close work.assistidos_copensao_apo;

		free cobertura_apo assistidos;
	end;
QUIT;

%_eg_conditional_dropds(work.assistidos_copensao_pen);
proc sql;
	create table work.assistidos_copensao_pen as
	select apo.id_participante,
		   apo.CdCopensao,
		   apo.ResMatPenTemp,
		   sum(apo.ResMatPenTemp) format=commax14.2 as ResMatPenGrupo,
		   max(0, (apo.ResMatPenTemp / sum(apo.ResMatPenTemp))) format=8.4 as PercResMatPen,
		   max(0, capo.ResMatPen * (apo.ResMatPenTemp / sum(apo.ResMatPenTemp))) format=commax14.2 as ResMatCoPen
	from cobertur.assistidos apo
	inner join work.assistidos_copensao_apo capo on (apo.CdCopensao = capo.CdCopensao)
	where apo.CdCopensao is not null
	group by apo.CdCopensao
	order by apo.CdCopensao, apo.id_participante;
quit;

proc sql;
	update cobertur.assistidos a1
	set ResMatPen = (select p1.ResMatCoPen from work.assistidos_copensao_pen p1 where a1.id_participante = p1.id_participante)
	where a1.CdCopensao is not null;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
