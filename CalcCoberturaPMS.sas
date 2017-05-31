* --- Benefício total da reserva PMC --- *;

%_eg_conditional_dropds(cobertur.pms_assistidos);
proc sql;
	create table cobertur.pms_assistidos as
	select t1.id_participante,
			t1.VlBenefiInss,
			t1.VlBenefiPrev,
			t1.CdTipoBenefi,
			t1.fl_deficiente,
			t1.IddPartiCalc,
			t1.ftAtuSal,
			t1.fl_migrado,
			t4.qxii_nr,
			t4.qx_aj,
			t4.mx_dx,
			t4.mxii_dxii,
			t4.mxn_dx
	from partic.assistidos t1
	inner join work.assistidos_fatores t4 on (t1.id_participante = t4.id_participante)
	order by t1.id_participante;
quit;

%_eg_conditional_dropds(work.pms_cobertura_assistidos);
PROC IML;
	use cobertur.pms_assistidos;
		read all var {id_participante VlBenefiInss VlBenefiPrev CdTipoBenefi ftAtuSal qxii_nr qx_aj mx_dx mxii_dxii fl_deficiente mxn_dx IddPartiCalc fl_migrado} into assistidos;
	close;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		coberturaPms = J(qtdObs, 5, 0);

		do a = 1 to qtdObs;
			VlBenefiInss = assistidos[a, 2];
			VlBenefiPrev = assistidos[a, 3];
			CdTipoBenefi = assistidos[a, 4];
			ftAtuSal = assistidos[a, 5];
			qxii_nr = assistidos[a, 6];
			qx_aj = assistidos[a, 7];
			mx_dx = assistidos[a, 8];
			mxii_dxii = assistidos[a, 9];
			fl_deficiente = assistidos[a, 10];
			mxn_dx = assistidos[a, 11];
			IddPartiCalc = assistidos[a, 12];
			migrado = assistidos[a, 13];

			CnbAuxFun = 0;
			BenTotPms = 0;
			BenLiqPms = 0;
			ResMatPms = 0;
			ftAuxFun = 0;
			ftResPms = 0;

			IF (&CdPlanBen = 1) THEN 
				DO;
					if (CdTipoBenefi = 3) then 
						ftAuxFun = qxii_nr;
					else 
						ftAuxFun = qx_aj;

					CnbAuxFun = round((VlBenefiPrev + VlBenefiInss) * ftAtuSal, 0.0000000001);
					CnbAuxFun = round(CnbAuxFun * &peculioMorteAssistido * 2, 0.0000000001);
					CnbAuxFun = max(0, round(CnbAuxFun * ftAuxFun, 0.01));
				END;
			ELSE 
				DO;
					if ((&CdPlanBen = 5 & migrado = 0) | &CdPlanBen ^= 5) then do;
						if (&IncBenMinBD = 0) then do;
							BenTotPms = max(0, round(((VlBenefiPrev * ftAtuSal)) * &peculioMorteAssistido, 0.01));
						end;
						else do;
							BenTotPms = max(0, round(((&BenMinimo * &FtBenMin2)) * &peculioMorteAssistido, 0.01));
						end;

						BenTotPms = round(max(BenTotPms, &LimPecMin), 0.01);
					end;
					
				    BenLiqPms = BenTotPms;

					if (CdTipoBenefi = 3 | (CdTipoBenefi = 4 & fl_deficiente = 1)) then 
						ftResPms = mxii_dxii;
					else if (CdTipoBenefi = 4 & IddPartiCalc < &MaiorIdad) then
						ftResPms = mxn_dx;
					else
						ftResPms = mx_dx;

					ResMatPms = round(BenLiqPms * ftResPms, 0.01);
				END;

			coberturaPms[a, 1] = assistidos[a, 1];
			coberturaPms[a, 2] = CnbAuxFun;
			coberturaPms[a, 3] = BenTotPms;
			coberturaPms[a, 4] = BenLiqPms;
			coberturaPms[a, 5] = ResMatPms;
		end;

		create work.pms_cobertura_assistidos from coberturaPms[colname={'id_participante' 'CnbAuxFun' 'BenTotPms' 'BenLiqPms' 'ResMatPms'}];
			append from coberturaPms;
		close;
	end;
QUIT;

data cobertur.pms_assistidos;
	merge cobertur.pms_assistidos work.pms_cobertura_assistidos;
	by id_participante;
	format CnbAuxFun commax18.2 BenTotPms commax18.2 BenLiqPms commax18.2 ResMatPms commax18.2;
run;

%_eg_conditional_dropds(work.pms_cobertura_assistidos);