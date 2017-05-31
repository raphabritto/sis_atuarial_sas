
%_eg_conditional_dropds(work.assistidos_fatores);
proc sql;
	create table work.assistidos_fatores as
	select t1.id_participante,
			age.t,
			t1.IddPartiCalc,
			t1.IddFilJovCalc,
			t1.CdEstCivPart,
			t1.CdTipoBenefi,
			t1.fl_deficiente,
			apo.BenLiqCobApo,
			apo.BenTotApo,
			fut.BenLiqCobFut,
			fut.BenTotFut,
			pms.BenTotPms,
			max(0, (t3.lx / t4.lx)) format=12.8 as lx,
			max(0, (t3.lxii / t4.lxii)) format=12.8 as lxii,
			(case 
				when t1.CdSexoConjug is not null and age.IddConjuEvol is not null
					then max(0, (t5.lx / t6.lx))
					else 0
			end) format=12.8 as ljx,
			(case
				when t1.IddFilInvCalc is not null and age.IddFilInvEvol is not null
					then max(0, (invD.lxii / invC.lxii))
					else 0
			end) format=12.8 as lixii,
			rst.ftFluxoCopen,
			max(0, (t3.dx / t4.lx)) format=12.8 as dxn_lx,
			max(0, (t3.dxii / t4.lxii)) format=12.8 as dxnii_lxii,
			max(0, (t3.dx / t3.lx)) format=12.8 as dxn_lxn,
			(case
				when age.t = 0
					then max(0, (t7.lx / t4.lx))
					else 0
			end) format=12.8 as lxn,
			(case
				when age.t = 0
					then max(0, (t7.lxii / t4.lxii))
					else 0
			end) format=12.8 as lxnii,
			txc.vl_taxa_juros as vl_taxa_juros_cal
/*			txd.vl_taxa_juros as vl_taxa_juros_det*/
	from partic.ASSISTIDOS t1
	inner join determin.deterministico_assistidos age on (t1.id_participante = age.id_participante)
	inner join cobertur.apo_assistidos apo on (t1.id_participante = apo.id_participante)
	inner join cobertur.fut_assistidos fut on (t1.id_participante = fut.id_participante)
	inner join cobertur.pms_assistidos pms on (t1.id_participante = pms.id_participante)
	inner join work.taxa_juros txc on (txc.t = 0)
/*	inner join work.taxa_juros txd on (txd.t = min(age.t, &maxTaxaJuros))*/
	inner join tabuas.tabuas_servico_normal t3 on (t1.CdSexoPartic = t3.Sexo and age.IddPartiEvol = t3.Idade and t3.t = 0)
	inner join tabuas.tabuas_servico_normal t4 on (t1.CdSexoPartic = t4.Sexo and t1.IddPartiCalc = t4.Idade and t4.t = 0)
	left join tabuas.tabuas_servico_normal t5 on (t1.CdSexoConjug = t5.Sexo and age.IddConjuEvol = t5.Idade and t5.t = 0)
	left join tabuas.tabuas_servico_normal t6 on (t1.CdSexoConjug = t6.Sexo and t1.IddConjuCalc = t6.Idade and t6.t = 0)
	left join tabuas.tabuas_servico_normal invD on (t1.CdSexoFilInv = invD.Sexo and age.IddFilInvEvol = invD.Idade and invD.t = 0)
	left join tabuas.tabuas_servico_normal invC on (t1.CdSexoFilInv = invC.Sexo and t1.IddFilInvCalc = invC.Idade and invC.t = 0)
	inner join cobertur.reserv_matem_assistidos rst on (t1.id_participante = rst.id_participante)
	left join tabuas.tabuas_servico_normal t7 on (t1.CdSexoPartic = t7.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t7.Idade and t7.t = 0)
	order by age.id_participante, age.t;
quit;

data determin.deterministico_assistidos;
	merge determin.deterministico_assistidos work.assistidos_fatores;
	by id_participante t;
run;

proc delete data = work.assistidos_fatores;

%_eg_conditional_dropds(work.cal_deterministico_assistidos);
PROC IML;
		*--- CALCULA O FLUXO ATUARIAL DAS RECEITAS E DESPESAS DO PLANO DE BENEFÍCIOS DOS ASSISTIDOS ---*;
	USE determin.deterministico_assistidos;
		read all var {id_participante t IddPartiCalc IddPartiEvol IddConjuEvol CdEstCivPart CdTipoBenefi lx lxii ljx BenTotApo BenTotFut IddFilJovEvol IddFilInvEvol lixii IddFilJovCalc ftFluxoCopen BenTotPms dxn_lx dxnii_lxii dxn_lxn fl_deficiente lxn lxnii vl_taxa_juros_cal} into assistidos;
	CLOSE;

	load module= GetContribuicao;

	nObs = nrow(assistidos);

	if (nObs > 0) then do;

		fluxoDeterAssistido = J(nObs, 15, 0);

		DO a = 1 TO nObs;
			IdParticipante = assistidos[a, 1];
			t = assistidos[a, 2];
			IddPartiCalc = assistidos[a, 3];
			IddPartiEvol = assistidos[a, 4];
			IddConjuEvol = assistidos[a, 5];
			CdEstCivPart = assistidos[a, 6];
			CdTipoBenefi = assistidos[a, 7];
			lx =  assistidos[a, 8];
			lxii = assistidos[a, 9];
			ljx = assistidos[a, 10];
			IddFilJovEvol = assistidos[a, 13];
			IddFilInvEvol = assistidos[a, 14];
			lixii = assistidos[a, 15];
			IddFilJovCalc = assistidos[a, 16];
			ftFluxoCopen = assistidos[a, 17];
			BenTotPms = assistidos[a, 18];
			dxn_lx = assistidos[a, 19];
			dxnii_lxii = assistidos[a, 20];
			dxn_lxn = assistidos[a, 21];
			fl_deficiente = assistidos[a, 22];
			lxn = assistidos[a, 23];
			lxnii = assistidos[a, 24];
			taxa_juros_cal = assistidos[a, 25];
	
			BenTotApo = assistidos[a, 11];

			if (CdTipoBenefi = 4) then
				BenTotApo = BenTotApo * ftFluxoCopen;
			
			BenTotFut = assistidos[a, 12];
			
			*------ ZERA AS VARIÁVEIS DO CÁLCULO ------*;
			ContribApo = 0;
			BenLiqApo = 0;
			DespApoFxo = 0;
			DespApoVP = 0;
			ContribFut = 0;
			BenLiqFut = 0;
			DespFutFxo = 0;
			DespFutVP = 0;
			DespPmsFxo = 0;
			DespPmsVP = 0;

			ftApo = 0;
			ftFut = 0;
			ftPms = 0;
			tPfr_r = 0; * conjuge *;
			tPjr_r = 0; * filho jovem *;
			tPjri_r = 0; * filho invalido *;

			if (CdTipoBenefi = 1 | CdTipoBenefi = 2) then do;
				ftApo = lx;

				if (IddConjuEvol ^= .) then do;
					tPjr_r = max(0, ljx - (lx * ljx));
				end;

				if (IddFilJovEvol ^= .) then do;
					tPfr = 0;

					if (t < &MaiorIdad - IddFilJovCalc) then
						tPfr = 1;

					tPfr_r = max(0, tPfr - (lx * tPfr));
				end;

				if (IddFilInvEvol ^= .) then do;
					tPjri_r = max(0, lixii - (lx * lixii));
				end;
			end;
			else if (CdTipoBenefi = 3) then do;
				ftApo = lxii;

				if (IddConjuEvol ^= .) then do;
					tPjr_r = max(0, ljx - (lxii * ljx));
				end;

				if (IddFilJovEvol ^= .) then do;
					tPfr = 0;

					if (t < &MaiorIdad - IddFilJovCalc) then
						tPfr = 1;

					tPfr_r = max(0, tPfr - (lxii * tPfr));
				end;

				if (IddFilInvEvol ^= .) then do;
					tPjri_r = max(0, lixii - (lxii * lixii));
				end;
			end;
			else if (CdTipoBenefi = 4) then do;
				if (IddPartiCalc < &MaiorIdad & IddPartiEvol < &MaiorIdad) then
					ftApo = 1;
				else if (IddPartiCalc < &MaiorIdad & IddPartiEvol >= &MaiorIdad) then
					ftApo = 0;
				else
					ftApo = lx;
			end;

			if (IddConjuEvol ^= . & IddFilJovEvol = . & IddFilInvEvol = .) then do;
				ftFut = tPjr_r;
			end;
			else if (IddConjuEvol = . & IddFilJovEvol ^= . & IddFilInvEvol = .) then do;
				ftFut = tPfr_r;
			end;
			else if (IddConjuEvol ^= . & IddFilJovEvol ^= . & IddFilInvEvol = .) then do;
				ftFut = max(0, max(tPfr_r, tPjr_r));
			end;
			else if (IddConjuEvol = . & IddFilJovEvol ^= . & IddFilInvEvol ^= .) then do;
				ftFut = max(0, max(tPfr_r, tPjri_r));
			end;
			else if (IddConjuEvol ^= . & IddFilJovEvol = . & IddFilInvEvol ^= .) then do;
				ftFut = max(0, max(tPjr_r, tPjri_r));
			end;
			else if (IddConjuEvol ^= . & IddFilJovEvol ^= . & IddFilInvEvol ^= .) then do;
				ftFut = max(0, max(max(tPfr_r, tPjr_r), tPjri_r));
			end;

			vt = 1 / ((1 + taxa_juros_cal) ** t);
			v = 1/((1 + taxa_juros_cal)/(1 + &PrTxBenef));

			if (CdTipoBenefi = 1 | CdTipoBenefi = 2 | (CdTipoBenefi = 4 & IddPartiCalc >= &MaiorIdad & fl_deficiente = 0)) then do;
				ftPms = max(0, dxn_lx * vt);
			end;
			else if (CdTipoBenefi = 4 & IddPartiCalc < &MaiorIdad & fl_deficiente = 0 & IddPartiEvol < &MaiorIdad) then do;
				ftPms = max(0, dxn_lxn * lx * vt);
			end;
			else if (CdTipoBenefi = 3 | (CdTipoBenefi = 4 & fl_deficiente = 1)) then do;
				ftPms = max(0, dxnii_lxii * vt);
			end;

			BenTotApo = max(0, round(BenTotApo * ((1 + &PrTxBenef) ** t), 0.01));
			ContribApo = max(0, GetContribuicao(BenTotApo));
			ContribApo = max(0, round(ContribApo * (1 - &TxaAdmBen), 0.01));
			BenLiqApo = max(0, round(BenTotApo - ContribApo, 0.01));
			DespApoFxo = max(0, round(BenLiqApo * &NroBenAno * ftApo, 0.01));

			BenTotFut = max(0, round(BenTotFut * ((1 + &PrTxBenef) ** t), 0.01));
			ContribFut = max(0, GetContribuicao(BenTotFut));
			ContribFut = max(0, round(ContribFut * (1 - &TxaAdmBen), 0.01));
			BenLiqFut = max(0, round(BenTotFut - ContribFut, 0.01));
			DespFutFxo = max(0, round(BenLiqFut * &NroBenAno * ftFut, 0.01));

			DespPmsFxo = max(0, round(BenTotPms * ftPms, 0.01));
			
			if (t = 0) then do;
				if (CdTipoBenefi = 1 | CdTipoBenefi = 2 | CdTipoBenefi = 3 | (CdTipoBenefi = 4 & IddPartiCalc >= &MaiorIdad & fl_deficiente = 0)) then do;
					DespApoVP = max(0, round(((DespApoFxo * vt) - &NroBenAno * &Fb * BenLiqApo) * &FtBenEnti, 0.01));
				end;
				else do;
					DespApoVP = max(0, round(((DespApoFxo * vt) - &NroBenAno * &Fb * BenLiqApo * (1 - v ** (&MaiorIdad - IddPartiCalc))) * &FtBenEnti, 0.01));
				end;

				if ((CdTipoBenefi = 1 | CdTipoBenefi = 2) & IddConjuEvol = . & IddFilInvEvol = . & IddFilJovEvol ^= .) then do;
					DespFutVP = max(0, round(((DespFutFxo * vt) - (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol))) + (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol) * lxn))) * &FtBenEnti, 0.01));
				end;
				else if (CdTipoBenefi = 3 & IddConjuEvol = . & IddFilInvEvol = . & IddFilJovEvol ^= .) then do;
					DespFutVP = max(0, round(((DespFutFxo * vt) - (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol))) + (&NroBenAno * &Fb * BenLiqFut * (1 - v ** (&MaiorIdad - IddFilJovEvol) * lxnii))) * &FtBenEnti, 0.01));
				end;
				else do;
					DespFutVP = max(0, round((DespFutFxo * vt) * &FtBenEnti), 0.01);
				end;
			end;
			else do;
				DespApoVP = max(0, round(DespApoFxo * vt * &FtBenEnti, 0.01));
				DespFutVP = max(0, round(DespFutFxo * vt * &FtBenEnti, 0.01));
			end;

			DespPmsVP = max(0, round(DespPmsFxo * (1 / (1 + taxa_juros_cal)), 0.01));

			fluxoDeterAssistido[a, 1] = IdParticipante;
			fluxoDeterAssistido[a, 2] = t;
			fluxoDeterAssistido[a, 3] = vt;
			fluxoDeterAssistido[a, 4] = BenTotApo;
			fluxoDeterAssistido[a, 5] = ContribApo;
			fluxoDeterAssistido[a, 6] = BenLiqApo;
			fluxoDeterAssistido[a, 7] = DespApoFxo;
			fluxoDeterAssistido[a, 8] = DespApoVP;
			fluxoDeterAssistido[a, 9] = BenTotFut;
			fluxoDeterAssistido[a, 10] = ContribFut;
			fluxoDeterAssistido[a, 11] = BenLiqFut;
			fluxoDeterAssistido[a, 12] = DespFutFxo;
			fluxoDeterAssistido[a, 13] = DespFutVP;
			fluxoDeterAssistido[a, 14] = DespPmsFxo;
			fluxoDeterAssistido[a, 15] = DespPmsVP;
		END;

		create work.cal_deterministico_assistidos from fluxoDeterAssistido[colname={'id_participante' 't' 'vt' 'BenTotApoFxo' 'ContribApoFxo' 'BenLiqApoFxo' 'DespApoFxo' 'DespApoVP' 'BenTotFutFxo' 'ContribFutFxo' 'BenLiqFutFxo' 'DespFutFxo' 'DespFutVP' 'DespPmsFxo' 'DespPmsVP'}];
			append from fluxoDeterAssistido;
		close;
	end;
QUIT;

data determin.deterministico_assistidos;
	merge determin.deterministico_assistidos work.cal_deterministico_assistidos;
	by id_participante t;
	format BenTotApoFxo commax14.2 ContribApoFxo commax14.2 BenLiqApoFxo commax14.2 DespApoFxo commax14.2 DespApoVP commax14.2 BenTotFutFxo commax14.2 ContribFutFxo commax14.2 BenLiqFutFxo commax14.2 DespFutFxo commax14.2 DespFutVP commax14.2 DespPmsFxo commax14.2 DespPmsVP commax14.2;
run;

proc delete data = work.cal_deterministico_assistidos;

%_eg_conditional_dropds(work.quantidade_assistidos_temp);
proc sql;
	create table work.quantidade_assistidos_temp as
	select a1.id_participante, 
		   i1.t,
		   (case
		   		when ((a1.CdTipoBenefi = 1 or a1.CdTipoBenefi = 2) or (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 0 and a1.IddPartiCalc >= &MaiorIdad))
				then (nod.lx / no.lx)
				else 0
			end) as QtdAssistidosValidos,
		   (case
		   		when (a1.CdTipoBenefi = 3 or (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 1))
					then (nod.lxii / no.lxii)
					else 0
				end) as QtdAssistidosInvalidos,
			(case
		   		when (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 0 and i1.IddPartiEvol < &MaiorIdad)
				then 1
				else 0
			end) as QtdPensionistaTemporario
	from partic.assistidos a1
	inner join determin.deterministico_assistidos i1 on (a1.id_participante = i1.id_participante)
	inner join tabuas.tabuas_servico_normal no on (a1.CdSexoPartic = no.Sexo and a1.IddPartiCalc = no.Idade and no.t = 0)
	inner join tabuas.tabuas_servico_normal nod on (a1.CdSexoPartic = nod.Sexo and i1.IddPartiEvol = nod.Idade and nod.t = min(i1.t, &maxTaxaJuros))
	order by i1.id_participante, i1.t;
quit;

%_eg_conditional_dropds(work.quantidade_assistidos);
proc sql;
	create table work.quantidade_assistidos as
	select qtd.t,
		   sum(qtd.QtdAssistidosValidos) as QtdAssistidosValidos, 
		   sum(qtd.QtdAssistidosInvalidos) as QtdAssistidosInvalidos,
		   sum(qtd.QtdPensionistaTemporario) as QtdPensionistaTemporario
	from work.quantidade_assistidos_temp qtd
	group by qtd.t
	order by qtd.t;

	drop table work.quantidade_assistidos_temp;
quit;

%_eg_conditional_dropds(determin.DESPESA_ASSISTIDOS);
PROC SQL;
   CREATE TABLE determin.DESPESA_ASSISTIDOS AS 
   SELECT t1.t, 
		  sum(t1.DespApoFxo) format=commax14.2 as VlDespApoFxo,
		  sum(t1.DespFutFxo) format=commax14.2 as VlDespFutFxo,
		  sum(t1.DespPmsFxo) format=commax14.2 as VlDespPmsFxo,
		  sum(t1.DespApoVP) format=commax14.2 as VPDesApo,
		  sum(t1.DespFutVP) format=commax14.2 as VPDesFut,
		  sum(t1.DespPmsVP) format=commax14.2 as VPDesPms
      FROM determin.deterministico_assistidos t1
	  group by t1.t
	  ORDER BY t1.t;
QUIT;

%_eg_conditional_dropds(sisatu.encargos_assistido);
proc sql;
	create table sisatu.encargos_assistido as
	select t1.id_participante,
		   sum(t1.DespApoVP) format=commax14.2 as EncargoApo,
		   sum(t1.DespFutVP) format=commax14.2 as EncargoFut,
		   sum(DespPmsVP) format=commax14.2 as EncargoPms
	from determin.deterministico_assistidos t1
	group by t1.id_participante
	order by t1.id_participante;
run;

data sisatu.DESPESAS_ASSISTIDOS;
	merge determin.DESPESA_ASSISTIDOS work.quantidade_assistidos;
run;

proc sql;
	create table sisatu.demonstracao_atuarial_assistido as
	select (case
				when t1.CdTipoBenefi = 1 then 'Aposentadoria tempo de contribuição'
				when t1.CdTipoBenefi = 2 then 'Aposentadoria especial'
				when t1.CdTipoBenefi = 3 then 'Aposentadoria invalidez'
				else 'Pensão'
			end) as CdTipoBenefi,
		   count(t1.id_participante) as QuantAssistidos,
		   sum(t1.VlBenefiPrev) format=commax14.2 as ValorMedioBenef,
		   mean(t1.IddPartiCalc) format=commax14.2 as IdadeMedia,
		   sum(t3.ResMatTotal) format=commax14.2 as ReservaMatematica
	from partic.assistidos t1
	inner join cobertur.reserv_matem_assistidos t3 on (t1.id_participante = t3.id_participante)
	group by t1.CdTipoBenefi;
quit;