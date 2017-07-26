
%macro calcCoberturaAxfi;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.);
		PROC IML;
			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t IddParticCobert IddIniApoInss VlBenefiInss SalBenefInssEvol BenTotCobAiv} into ativos;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {qxi ix apxa} into fatores;
			close cobertur.ativos_fatores;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				cobertura_axfi = J(qtdObs, 4, 0);

				DO a = 1 TO qtdObs;
					BenAuxFunInv = 0;
					CusNorAuxFunFutInv = 0;

					if (&CdPlanBen = 1) then do;
						t = ativos[a, 2];
						idade_partic_cober = ativos[a, 3];
						idade_aposen_inss = ativos[a, 4];
						VlBenefiInss = ativos[a, 5];
						SalBenefInss = ativos[a, 6];
						beneficio_total_aiv = ativos[a, 7];

						qxii = fatores[a, 1];
						ix = fatores[a, 2];
						apxa = fatores[a, 3];

						*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
						if (t = 0 & VlBenefiInss = 0 & idade_partic_cober < idade_aposen_inss) then do;
				        	BenAuxFunInv = max(0, round(beneficio_total_aiv + SalBenefInss, 0.01) * 2);
					        CusNorAuxFunFutInv = max(0, round(BenAuxFunInv * (qxii * ix) * (1 - apxa), 0.01));
						end;
					end;

					cobertura_axfi[a, 1] = ativos[a, 1];
					cobertura_axfi[a, 2] = ativos[a, 2];
					cobertura_axfi[a, 3] = BenAuxFunInv;
					cobertura_axfi[a, 4] = CusNorAuxFunFutInv;
				END;

				create work.ativos_cobertura_axfi_tp&tipoCalculo._s&s. from cobertura_axfi[colname={'id_participante' 't' 'BenefCobAxfi' 'CusNorCobAXFI'}];
					append from cobertura_axfi;
				close work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;

				free cobertura_axfi ativos fatores;
			end;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;
			by id_participante t;
			format BenefCobAXFI COMMAX14.2 CusNorCobAXFI COMMAX14.2;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_axfi_tp&tipoCalculo._s&s.);
		proc summary data = work.ativos_cobertura_axfi_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var CusNorCobAXFI;
		 format CusNorCobAXFI commax18.2;
		 output out= work.ativos_encargo_axfi_tp&tipoCalculo._s&s. sum=;
		run; 

		data cobertur.ativos_encargo_axfi_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_axfi_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calcCoberturaAxfi;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
