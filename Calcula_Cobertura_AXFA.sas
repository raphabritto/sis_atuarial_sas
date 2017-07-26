

%macro calcCoberturaAxfa;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.);
		PROC IML;
			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante t SalConPrjEvol} into ativos;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {qx apxa} into fatores;
			close cobertur.ativos_fatores;

			qtdObs = nrow(ativos);

			if (qtdObs > 0) then do;
				cobertura_axfa = J(qtdObs, 3, 0);

				DO a = 1 TO qtdObs;
					CusNorAuxFunAt = 0;

					if (&CdPlanBen = 1) then do;
						t = ativos[a, 2];
						SalConPrj = ativos[a, 3];

						qx = fatores[a, 1];
						apxa = fatores[a, 2];

						*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
						if (t = 0) then do;
							if (round(apxa, 0.00001) = 1) then
				        		CusNorAuxFunAt = max(0, round((SalConPrj / &FtSalPart) * qx, 0.01));
							else
								CusNorAuxFunAt = max(0, round((SalConPrj / &FtSalPart) * qx * (1 - apxa), 0.01));
						end;
					end;

					cobertura_axfa[a, 1] = ativos[a, 1];
					cobertura_axfa[a, 2] = ativos[a, 2];
					cobertura_axfa[a, 3] = CusNorAuxFunAt;
				END;

				create work.ativos_cobertura_axfa_tp&tipoCalculo._s&s. from cobertura_axfa[colname={'id_participante' 't' 'CusNorCobAXFA'}];
					append from cobertura_axfa;
				close work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
			end;

			free ativos cobertura_axfa fatores;
		QUIT;

		data cobertur.ativos_tp&tipoCalculo._s&s.;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
			by id_participante t;
			format CusNorCobAXFA COMMAX14.2;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_axfa_tp&tipoCalculo._s&s.);
		proc summary data = work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
		 class id_participante;
		 var CusNorCobAXFA;
		 format CusNorCobAXFA commax18.2;
		 output out= work.ativos_encargo_axfa_tp&tipoCalculo._s&s. sum=;
		run;

		data cobertur.ativos_encargo_axfa_tp&tipoCalculo._s&s.;
			set work.ativos_encargo_axfa_tp&tipoCalculo._s&s.;
			if cmiss(id_participante) then delete;
			drop _TYPE_ _FREQ_;
		run;
	%end;
%mend;
%calcCoberturaAxfa;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
