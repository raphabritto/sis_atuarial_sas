
%macro calcCoberturaAxfi;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.);
		PROC IML;
			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {idade_partic_cober} into idade_partic_cober;
				read all var {IddIniApoInss} into idade_aposen_inss;
				read all var {VlBenefiInss} into beneficio_inss;
				read all var {SalBenefInss} into SalBenefInss;
				read all var {beneficio_total_aiv} into beneficio_total_aiv;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {qxi} into qxi;
				read all var {ix} into ix;
				read all var {apxa} into apxa;
			close cobertur.ativos_fatores;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				benef_aux_funeral_invalido = J(qtd_ativos, 1, 0);
				aux_funeral_invalido = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					if (&CdPlanBen = 1) then do;
						*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
						if (t1[a] = 0 & beneficio_inss[a] = 0 & idade_partic_cober[a] < idade_aposen_inss[a]) then do;
				        	benef_aux_funeral_invalido[a] = max(0, round(beneficio_total_aiv[a] + SalBenefInss[a], 0.01) * 2);
					        aux_funeral_invalido[a] = max(0, round(benef_aux_funeral_invalido[a] * (qxi[a] * ix[a]) * (1 - apxa[a]), 0.01));
						end;
					end;
				END;

				create work.ativos_cobertura_axfi_tp&tipoCalculo._s&s. var {id_participante t1 benef_aux_funeral_invalido aux_funeral_invalido};
					append;
				close work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format benef_aux_funeral_invalido COMMAX14.2 aux_funeral_invalido COMMAX14.2;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_axfi_tp&tipoCalculo._s&s.);
			proc summary data = work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var aux_funeral_invalido;
			 format aux_funeral_invalido commax18.2;
			 output out= work.ativos_encargo_axfi_tp&tipoCalculo._s&s. sum=;
			run; 

			data cobertur.ativos_encargo_axfi_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_axfi_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;

			proc delete data = work.ativos_cobertura_axfi_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaAxfi;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
