
%_eg_conditional_dropds(work.assistidos_idades_fluxo);
PROC IML;
	USE cobertur.assistidos;
		read all var {id_participante IddPartiCalc CdSexoPartic IddConjuCalc IddFilJovCalc IddFilInvCalc} into assistidos;
	CLOSE cobertur.assistidos;

	nObsAssistidos = nrow(assistidos);
	
	if (nObsAssistidos > 0) then do;
		nObsCobert = 0;
		b = 1;

		DO a = 1 TO nObsAssistidos;
			IddPartiCalc = assistidos[a, 2];
			IddConjuCalc = assistidos[a, 4];
			IddFilJovCalc = assistidos[a, 5];
			IddFilInvCalc = assistidos[a, 6];
			menorIdade = min(IddPartiCalc, min(IddConjuCalc, min(IddFilJovCalc, IddFilInvCalc)));
			nObsCobert = nObsCobert + ((&MaxAge - menorIdade) +1);
		END;

		idades_fluxo = J(nObsCobert, 6, 0);

		DO a = 1 TO nObsAssistidos;
			IdParticipante = assistidos[a, 1];
			IddPartiCalc = assistidos[a, 2];
			CdSexoPartic = assistidos[a, 3];
			IddConjuCalc = assistidos[a, 4];
			IddFilJovCalc = assistidos[a, 5];
			IddFilInvCalc = assistidos[a, 6];

			menorIdade = min(IddPartiCalc, min(IddConjuCalc, min(IddFilJovCalc, IddFilInvCalc)));

			*---- PROJEÇÃO DOS SALÁRIOS, AS CONTRIBUIÇÕES E OS BENEFÍCIOS DA IDADE ATUAL ATÉ A ÚLTIMA IDADE DA TÁBUA DE MORTILIDADE GERAL ---*;
			DO t = 0 TO (&MaxAge - menorIdade);
				*--- DIFERENÇA ENTRE IDADES ---*;
			    i = min(IddPartiCalc + t, &MaxAge);

				if (IddConjuCalc ^= .) then
			    	j = min(IddConjuCalc + t, &MaxAge);
				else
					j = .;

				if (IddFilJovCalc ^= .) then
					fv = min(IddFilJovCalc + t, &MaxAge);
				else
					fv = .;

				if (IddFilInvCalc ^= .) then
					fi = min(IddFilInvCalc + t, &MaxAge);
				else
					fi = .;

				idades_fluxo[b, 1] = IdParticipante;
				idades_fluxo[b, 2] = t;
				idades_fluxo[b, 3] = i;
				idades_fluxo[b, 4] = j;
				idades_fluxo[b, 5] = fv;
				idades_fluxo[b, 6] = fi;

				b = b + 1;
			END;
		END;

		create work.assistidos_idades_fluxo from idades_fluxo[colname={'id_participante' 't' 'IddPartiEvol' 'IddConjuEvol' 'IddFilJovEvol' 'IddFilInvEvol'}];
			append from idades_fluxo;
		close work.assistidos_idades_fluxo;
	end;
QUIT;

%_eg_conditional_dropds(fluxo.assistidos);
data fluxo.assistidos;
	retain id_participante t;
	merge cobertur.assistidos work.assistidos_idades_fluxo;
	by id_participante;
	drop PeFatReduPbe CdTipoFtAtuSal CdCopensao QtdGrupoCopensao;
run;


%_eg_conditional_dropds(fluxo.assistidos_fatores);
proc sql;
	create table fluxo.assistidos_fatores as
	select t1.id_participante,
		   t1.t,
		   max(0, (t3.lx / t4.lx)) format=12.8 as px,
		   max(0, (t3.lxii / t4.lxii)) format=12.8 as pxii,
			(case 
				when t1.CdSexoConjug is not null and t1.IddConjuEvol is not null
					then max(0, (t5.lx / t6.lx))
					else 0
			end) format=12.8 as pjx,
			(case
				when t1.IddFilInvCalc is not null and t1.IddFilInvEvol is not null
					then max(0, (invD.lxii / invC.lxii))
					else 0
			end) format=12.8 as pxi,
			t1.ftFluxoCopen,
			max(0, (t3.dx / t4.lx)) format=12.8 as dxn_lx,
			max(0, (t3.dxii / t4.lxii)) format=12.8 as dxnii_lxii,
			max(0, (t3.dx / t3.lx)) format=12.8 as dxn_lxn,
			(case
				when t1.t = 0
					then max(0, (t7.lx / t4.lx))
					else 0
			end) format=12.8 as pxn,
			(case
				when t1.t = 0
					then max(0, (t7.lxii / t4.lxii))
					else 0
			end) format=12.8 as pxnii,
			txc.taxa_juros as taxa_juros_fluxo
	from fluxo.assistidos t1
	inner join premissa.taxa_juros txc on (txc.t = 0)
	inner join tabuas.tabuas_servico_normal t3 on (t1.CdSexoPartic = t3.Sexo and t1.IddPartiEvol = t3.Idade and t3.t = 0)
	inner join tabuas.tabuas_servico_normal t4 on (t1.CdSexoPartic = t4.Sexo and t1.IddPartiCalc = t4.Idade and t4.t = 0)
	left join tabuas.tabuas_servico_normal t5 on (t1.CdSexoConjug = t5.Sexo and t1.IddConjuEvol = t5.Idade and t5.t = 0)
	left join tabuas.tabuas_servico_normal t6 on (t1.CdSexoConjug = t6.Sexo and t1.IddConjuCalc = t6.Idade and t6.t = 0)
	left join tabuas.tabuas_servico_normal invD on (t1.CdSexoFilInv = invD.Sexo and t1.IddFilInvEvol = invD.Idade and invD.t = 0)
	left join tabuas.tabuas_servico_normal invC on (t1.CdSexoFilInv = invC.Sexo and t1.IddFilInvCalc = invC.Idade and invC.t = 0)
	left join tabuas.tabuas_servico_normal t7 on (t1.CdSexoPartic = t7.Sexo and (t1.IddPartiCalc + &MaiorIdad - t1.IddFilJovCalc) = t7.Idade and t7.t = 0)
	order by t1.id_participante, t1.t;
quit;

%macro sorteioAssistidos;
	%if (&tipoCalculo = 2) %then %do;
		%do s = 1 %to &numeroCalculos;
			%_eg_conditional_dropds(fluxo.assistidos_estoc_s&s.);
			proc iml;
				load module= drawSobrevivencia;

				use fluxo.assistidos;
					read all var {id_participante t CdSexoPartic IddPartiEvol TipoAssistido} into assistidos;
				close fluxo.assistidos;

				use tabuas.tabuas_servico_normal;
					read all var {qx qxi} into tabua_f where (t = 0 & sexo = 1);
					read all var {qx qxi} into tabua_m where (t = 0 & sexo = 2);
				close tabuas.tabuas_servico_normal;

				qtd_assistidos = nrow(assistidos);

				if (qtd_assistidos > 0) then do;
					assistidos_estoc = J(qtd_assistidos, 4, 0);

					do a = 1 to qtd_assistidos;
						t = assistidos[a, 2];
						sexo_partic = assistidos[a, 3];
						idade_partic_fluxo = assistidos[a, 4];
/*						tipo_beneficio = assistidos[a, 5];*/
/*						is_deficiente = assistidos[a, 6];*/
						tipo_assistido = assistidos[a, 5];

						if (sexo_partic = 1) then do;
							qx	= tabua_f[idade_partic_fluxo + 1, 1];
							qxi = tabua_f[idade_partic_fluxo + 1, 2];
						end;
						else do;
							qx	= tabua_m[idade_partic_fluxo + 1, 1];
							qxi = tabua_m[idade_partic_fluxo + 1, 2];
						end;

						if (tipo_assistido = 1 | tipo_assistido = 3) then do;
							probab_morte = qx;
						end;
						else if (tipo_assistido = 2 | tipo_assistido = 4) then
							probab_morte = qxi;
						else do;
							if (idade_partic_fluxo < &MaiorIdad) then
								probab_morte = 0;
							else
								probab_morte = 1;
						end;

						isVivo = drawSobrevivencia(t, idade_partic_fluxo, probab_morte, isVivo);

						isMorto = 0;

						if (t > 0) then do;
							if (isVivo ^= assistidos_estoc[a - 1, 3]) then
								isMorto = 1;
						end;

						assistidos_estoc[a, 1] = assistidos[a, 1];
						assistidos_estoc[a, 2] = assistidos[a, 2];
						assistidos_estoc[a, 3] = isVivo;
						assistidos_estoc[a, 4] = isMorto;
					end;

					create fluxo.assistidos_estoc_s&s. from assistidos_estoc[colname={'id_participante' 't' 'Vivo' 'Morto'}];
						append from assistidos_estoc;
					close fluxo.assistidos_estoc_s&s.;

					free assistidos_estoc assistidos tabua_f tabua_m;
				end;
			quit;
		%end;
	%end;
%mend;
%sorteioAssistidos;

/*
%macro sorteioAssistidos2;
	%if (&tipoCalculo = 2) %then %do;
		%do s = 1 %to 100;
			%_eg_conditional_dropds(work.assistidos_estoc_s&s.);
			proc iml;
				load module= drawSobrevivencia;

				use fluxo.assistidos;
					read all var {id_participante t CdSexoPartic IddPartiEvol TipoAssistido} into assistidos;
				close fluxo.assistidos;

				use tabuas.tabuas_servico_normal;
					read all var {qx qxi} into tabua_f where (t = 0 & sexo = 1);
					read all var {qx qxi} into tabua_m where (t = 0 & sexo = 2);
				close tabuas.tabuas_servico_normal;

				qtd_assistidos = nrow(assistidos);

				if (qtd_assistidos > 0) then do;
					assistidos_estoc = J(qtd_assistidos, 4, 0);

					do a = 1 to qtd_assistidos;
						t = assistidos[a, 2];
						sexo_partic = assistidos[a, 3];
						idade_partic_fluxo = assistidos[a, 4];
						tipo_assistido = assistidos[a, 5];

						if (sexo_partic = 1) then do;
							qx	= tabua_f[idade_partic_fluxo + 1, 1];
							qxi = tabua_f[idade_partic_fluxo + 1, 2];
						end;
						else do;
							qx	= tabua_m[idade_partic_fluxo + 1, 1];
							qxi = tabua_m[idade_partic_fluxo + 1, 2];
						end;

						if (tipo_assistido = 1 | tipo_assistido = 3) then do;
							probab_morte = qx;
						end;
						else if (tipo_assistido = 2 | tipo_assistido = 4) then
							probab_morte = qxi;
						else do;
							if (idade_partic_fluxo < &MaiorIdad) then
								probab_morte = 0;
							else
								probab_morte = 1;
						end;

						isVivo = drawSobrevivencia(t, idade_partic_fluxo, probab_morte, isVivo);

						isMorto = 0;

						if (t > 0) then do;
							if (isVivo ^= assistidos_estoc[a - 1, 3]) then
								isMorto = 1;
						end;

						assistidos_estoc[a, 1] = assistidos[a, 1];
						assistidos_estoc[a, 2] = assistidos[a, 2];
						assistidos_estoc[a, 3] = isVivo;
						assistidos_estoc[a, 4] = isMorto;
					end;

					create work.assistidos_estoc_s&s. from assistidos_estoc[colname={'id_participante' 't' 'Vivo' 'Morto'}];
						append from assistidos_estoc;
					close work.assistidos_estoc_s&s.;

					free assistidos_estoc assistidos tabua_f tabua_m;
				end;
			quit;
		%end;
	%end;
%mend;
%sorteioAssistidos2;

%macro teste;
	%do s = 1 %to 100;
		proc sql;
			create table work.assist_estoc_group_s&s. as
			select t1.t, sum(t1.vivo) as total&s.
			from work.assistidos_estoc_s&s. t1
			group by t1.t
			order by t1.t;
		run; quit;

		%if (&s. = 1) %then %do;
			data work.assist_sort;
				set work.assist_estoc_group_s&s.;
			run;
		%end;
		%else %do;
			data work.assist_sort;
				merge work.assist_sort work.assist_estoc_group_s&s.;
				by t;
			run;
		%end;
	%end;
%mend;
%teste;
*/

proc datasets library=work kill memtype=data nolist;
	run;
quit;
