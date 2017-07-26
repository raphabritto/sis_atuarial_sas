* --- Cálculo das reservas de APO assistidos --- *;

%_eg_conditional_dropds(work.apo_copensao);
proc sql;
	create table work.apo_copensao as
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
					then (max(0, ((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** (&MaiorIdad - atp.IddPartiCalc) - 1) / (((1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** ((&MaiorIdad - atp.IddPartiCalc) - 1)) * ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) - &Fb * (1 - (1 + ((1 + txc.vl_taxa_juros) / (1 + &PrTxBenef) - 1)) ** - (&MaiorIdad - atp.IddPartiCalc))))
					else 0
			end) format=.10 AS anpen,
			gp.VlBenefiInssGrupo,
			gp.VlBenefiPrevGrupo,
			avv.ftAtuSal as ftAtuSalVitVal,
			aiv.ftAtuSal as ftAtuSalVitInv,
			atp.ftAtuSal as ftAtuSalTemp
	from work.GRUPO_COPENSAO_ASSISTIDOS gp
	left join partic.assistidos avv on (gp.idParticipanteVitVal = avv.id_participante)
	left join partic.assistidos aiv on (gp.idParticipanteVitInval = aiv.id_participante)
	left join partic.assistidos atp on (gp.idParticipanteTemp = atp.id_participante)
	inner join work.taxa_juros txc on (txc.t = 0)
	left join tabuas.tabuas_servico_normal nvv on (avv.CdSexoPartic = nvv.Sexo and avv.IddPartiCalc = nvv.Idade and nvv.t = 0)
	left join tabuas.tabuas_servico_normal nvv1 on (avv.CdSexoPartic = nvv1.Sexo and (avv.IddPartiCalc + &MaiorIdad - atp.IddPartiCalc) = nvv1.Idade and nvv1.t = 0)
	left join tabuas.tabuas_servico_normal niv on (aiv.CdSexoPartic = niv.Sexo and aiv.IddPartiCalc = niv.Idade and niv.t = 0)
	left join tabuas.tabuas_servico_normal niv1 on (aiv.CdSexoPartic = niv1.Sexo and (aiv.IddPartiCalc + &MaiorIdad - atp.IddPartiCalc) = niv1.Idade and niv1.t = 0)
	order by gp.CdCopensao;
quit;

%_eg_conditional_dropds(work.apo_calculo_copensao);
PROC IML;
	load module= GetContribuicao;

	use work.apo_copensao;
		read all var {CdCopensao idParticipanteVitVal idParticipanteVitInval idParticipanteTemp VlBenefiInssGrupo VlBenefiPrevGrupo ftAtuSalVitVal ftAtuSalVitInv ftAtuSalTemp ajx djxn1_djx ajxn1 ajxii djxn1ii_djxii ajxn1ii anpen} into assistidos;
	close;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		coberturaApo = J(qtdObs, 5, 0);

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

				*ConPvdPen = round(BenTotPen * &TxaAdmBen, 0.01);
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

			coberturaApo[a, 1] = assistidos[a, 1];
			coberturaApo[a, 2] = BenTotPen;
			coberturaApo[a, 3] = ConPvdPen;
			coberturaApo[a, 4] = BenLiqCobPen;
			coberturaApo[a, 5] = ResMatPen;
		end;
	
		create work.apo_calculo_copensao from coberturaApo[colname={'CdCopensao' 'BenTotPen' 'ConPvdPen' 'BenLiqCobPen' 'ResMatPen'}];
			append from coberturaApo;
		close;
	end;
QUIT;

%_eg_conditional_dropds(work.pen_copensao);
proc sql;
	create table work.pen_copensao as
	select apo.id_participante,
		   apo.CdCopensao,
		   apo.ResMatPenTemp,
		   sum(apo.ResMatPenTemp) format=commax14.2 as ResMatPenGrupo,
		   max(0, (apo.ResMatPenTemp / sum(apo.ResMatPenTemp))) format=8.4 as PercResMatPen,
		   max(0, capo.ResMatPen * (apo.ResMatPenTemp / sum(apo.ResMatPenTemp))) format=commax14.2 as ResMatCoPen
	from cobertur.apo_assistidos apo
	inner join work.apo_calculo_copensao capo on (apo.CdCopensao = capo.CdCopensao)
	where apo.CdCopensao is not null
	group by apo.CdCopensao
	order by apo.CdCopensao, apo.id_participante;
quit;

proc sql;
	update cobertur.apo_assistidos a1
	set ResMatPen = (select p1.ResMatCoPen from work.pen_copensao p1 where a1.id_participante = p1.id_participante)
	where a1.CdCopensao is not null;
run;

proc delete data = work.apo_copensao work.apo_calculo_copensao work.pen_copensao;