

%macro calcCoberturaAxfa;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.);
		PROC IML;
			use cobertur.ativos_tp&tipoCalculo._s&s.;
				read all var {id_participante} into id_participante;
				read all var {t1} into t1;
				read all var {salario_contrib} into SalConPrj;
			close cobertur.ativos_tp&tipoCalculo._s&s.;

			use cobertur.ativos_fatores;
				read all var {qx} into qx;
				read all var {apxa} into apxa;
			close cobertur.ativos_fatores;

			qtd_ativos = nrow(id_participante);

			if (qtd_ativos > 0) then do;
				aux_funeral_ativo = J(qtd_ativos, 1, 0);

				DO a = 1 TO qtd_ativos;
					if (&CdPlanBen = 1) then do;
						*------ Auxílio funeral por morte de ativo/pecúlio por morte ------*;
						if (t1[a] = 0) then do;
							if (round(apxa[a], 0.00001) = 1) then
				        		aux_funeral_ativo[a] = max(0, round((SalConPrj[a] / &FtSalPart) * qx[a], 0.01));
							else
								aux_funeral_ativo[a] = max(0, round((SalConPrj[a] / &FtSalPart) * qx[a] * (1 - apxa[a]), 0.01));
						end;
					end;
				END;

				create work.ativos_cobertura_axfa_tp&tipoCalculo._s&s. var {id_participante t1 aux_funeral_ativo};
					append;
				close work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
			end;
		QUIT;

		%if (%sysfunc(exist(work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.))) %then %do;
			data cobertur.ativos_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
				by id_participante t1;
				format aux_funeral_ativo COMMAX14.2;
			run;

			%_eg_conditional_dropds(work.ativos_encargo_axfa_tp&tipoCalculo._s&s.);
			proc summary data = work.ativos_cobertura_axfa_tp&tipoCalculo._s&s.;
			 class id_participante;
			 var aux_funeral_ativo;
			 format aux_funeral_ativo commax18.2;
			 output out= work.ativos_encargo_axfa_tp&tipoCalculo._s&s. sum=;
			run;

			data cobertur.ativos_encargo_axfa_tp&tipoCalculo._s&s.;
				set work.ativos_encargo_axfa_tp&tipoCalculo._s&s.;
				if cmiss(id_participante) then delete;
				drop _TYPE_ _FREQ_;
			run;

			proc delete data = work.ativos_cobertura_axfa_tp&tipoCalculo._s&s. (gennum=all);
			run;
		%end;
	%end;
%mend;
%calcCoberturaAxfa;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
