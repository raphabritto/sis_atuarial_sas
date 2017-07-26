* --- Benefício total da reserva PMC --- *;


%_eg_conditional_dropds(work.assistidos_cobertura_pms);
PROC IML;
	use cobertur.assistidos;
		read all var {id_participante VlBenefiInss VlBenefiPrev CdTipoBenefi fl_deficiente IddPartiCalc fl_migrado} into assistidos;
	close cobertur.assistidos;

	use cobertur.assistidos_fatores;
		read all var {qxii_nr qx_aj mx_dx mxii_dxii mxn_dx reajuste_salario} into fatores;
	close cobertur.assistidos_fatores;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0 ) then do;
		cobertura_pms = J(qtdObs, 5, 0);

		do a = 1 to qtdObs;
			beneficio_inss = assistidos[a, 2];
			beneficio_funcef = assistidos[a, 3];
			tipo_beneficio = assistidos[a, 4];
			is_deficiente = assistidos[a, 5];
			idade_partic = assistidos[a, 6];
			is_migrado = assistidos[a, 7];
			
			qxii_nr = fatores[a, 1];
			qx_aj = fatores[a, 2];
			mx_dx = fatores[a, 3];
			mxii_dxii = fatores[a, 4];
			mxn_dx = fatores[a, 5];
			reajuste_salario = fatores[a, 6];

			beneficio_total_pms = 0;
			contribuicao_pms = 0;
			beneficio_liquido_pms = 0;
			reserva_matematica_pms = 0;
			ftAuxFun = 0;
			ftResPms = 0;

			IF (&CdPlanBen = 1) THEN DO;
				if (tipo_beneficio = 3) then 
					ftAuxFun = qxii_nr;
				else 
					ftAuxFun = qx_aj;

				contribuicao_pms = round((beneficio_funcef + beneficio_inss) * reajuste_salario, 0.0000000001);
				contribuicao_pms = round(contribuicao_pms * 2, 0.0000000001);
				contribuicao_pms = max(0, round(contribuicao_pms * ftAuxFun, 0.01));
			END;
			ELSE DO;
				if ((&CdPlanBen = 5 & is_migrado = 0) | &CdPlanBen ^= 5) then do;
					if (&IncBenMinBD = 0) then do;
						beneficio_total_pms = max(0, round(((beneficio_funcef * reajuste_salario)) * &peculioMorteAssistido, 0.01));
					end;
					else do;
						beneficio_total_pms = max(0, round(((&BenMinimo * &FtBenMin2)) * &peculioMorteAssistido, 0.01));
					end;

					beneficio_total_pms = round(max(beneficio_total_pms, &LimPecMin), 0.01);
				end;
				
			    beneficio_liquido_pms = beneficio_total_pms;

				if (tipo_beneficio = 3 | (tipo_beneficio = 4 & is_deficiente = 1)) then 
					ftResPms = mxii_dxii;
				else if (tipo_beneficio = 4 & idade_partic < &MaiorIdad) then
					ftResPms = mxn_dx;
				else
					ftResPms = mx_dx;

				reserva_matematica_pms = round(beneficio_liquido_pms * ftResPms, 0.01);
			END;

			cobertura_pms[a, 1] = assistidos[a, 1];
			cobertura_pms[a, 2] = contribuicao_pms;
			cobertura_pms[a, 3] = beneficio_total_pms;
			cobertura_pms[a, 4] = beneficio_liquido_pms;
			cobertura_pms[a, 5] = reserva_matematica_pms;
		end;

		create work.assistidos_cobertura_pms from cobertura_pms[colname={'id_participante' 'CnbAuxFun' 'BenTotPms' 'BenLiqPms' 'ResMatPms'}];
			append from cobertura_pms;
		close work.assistidos_cobertura_pms;
	end;
QUIT;

data cobertur.assistidos;
	merge cobertur.assistidos work.assistidos_cobertura_pms;
	by id_participante;
	format CnbAuxFun commax18.2 BenTotPms commax18.2 BenLiqPms commax18.2 ResMatPms commax18.2;
run;

proc datasets library=work kill memtype=data nolist;
	run;
quit;