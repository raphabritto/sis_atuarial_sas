
%_eg_conditional_dropds(work.assistidos_copensao);
proc sql;
	create table work.assistidos_copensao as
	select t1.id_participante,
			t1.CdSexoPartic,
			t1.IddPartiCalc,
			t1.FL_DEFICIENTE,
			t1.CdCopensao,
			t1.QtdGrupoCopensao,
			apo.ax,
			apo.axii,
			apo.anpen
	from partic.assistidos t1
	inner join cobertur.apo_assistidos apo on (t1.id_participante = apo.id_participante)
	where t1.CdCopensao is not null
	order by t1.CdCopensao, t1.id_participante;
quit;

%_eg_conditional_dropds(work.grupo_copensao_assistidos);
proc iml;
	use work.assistidos_copensao;
		read all var {id_participante CdSexoPartic IddPartiCalc CdCopensao ax axii anpen QtdGrupoCopensao} into assistidos;
	close;

	qtdObs = nrow(assistidos);

	if (qtdObs > 0) then do;
		numberRows = assistidos[<>, 4];
		output = J(numberRows, 4, .);
		b = 1;

		grupoCopensao = 0;
		count = 0;
		idParticipanteVitVal = .;
		axParticipanteVitVal = 0;
		idParticipanteVitInval = .;
		axiiParticipanteVitInval = 0;
		idParticipanteTemp = .;
		anpenParticipanteTemp = 0;

		do a = 1 to qtdObs;
			idParticipante = assistidos[a, 1];
			grupoCopensaoAssistido = assistidos[a, 4];
			ax = assistidos[a, 5];
			axii = assistidos[a, 6];
			anpen = assistidos[a, 7];
			qtdGrupoFamiliar = assistidos[a, 8];

			if (grupoCopensaoAssistido ^= grupoCopensao) then do;
				count = 0;
				idParticipanteVitVal = .;
				axParticipanteVitVal = 0;
				idParticipanteVitInval = .;
				axiiParticipanteVitInval = 0;
				idParticipanteTemp = .;
				anpenParticipanteTemp = 0;

				if (ax > 0) then do;
					idParticipanteVitVal = idParticipante;
					axParticipanteVitVal = ax;
				end;
				else if (axii > 0) then do;
					idParticipanteVitInval = idParticipante;
					axiiParticipanteVitInval = axii;
				end;
				else if (anpen > 0) then do;
					idParticipanteTemp = idParticipante;
					anpenParticipanteTemp = anpen;
				end;

				grupoCopensao = grupoCopensaoAssistido;
			end;
			else do;
				if (ax > axParticipanteVitVal) then do;
					idParticipanteVitVal = idParticipante;
					axParticipanteVitVal = ax;
				end;
				else if (axii > axiiParticipanteVitInval) then do;
					idParticipanteVitInval = idParticipante;
					axiiParticipanteVitInval = axii;
				end;
				else if (anpen > anpenParticipanteTemp) then do;
					idParticipanteTemp = idParticipante;
					anpenParticipanteTemp = anpen;
				end;
			end;

			count = count + 1;

			if (qtdGrupoFamiliar = count) then do;
				output[b, 1] = grupoCopensaoAssistido;
				output[b, 2] = idParticipanteVitVal;
				output[b, 3] = idParticipanteVitInval;
				output[b, 4] = idParticipanteTemp;
				b = b + 1;
			end;
		end;

		create work.grupo_copensao_assistidos from output[colname={'CdCopensao' 'idParticipanteVitVal' 'idParticipanteVitInval' 'idParticipanteTemp'}];
			append from output;
		close;

		free assistidos output;
	end;
quit;

%_eg_conditional_dropds(work.copensao_beneficios_grupo);
proc sql;
	create table work.copensao_beneficios_grupo as
	select 	t1.CdCopensao, 
			sum(t1.VlBenefiPrev) format=commax14.2 as VlBenefiPrevGrupo, 
			sum(t1.VlBenefiInss) format=commax14.2 as VlBenefiInssGrupo
	from partic.assistidos t1
	where t1.CdCopensao is not null
	group by t1.CdCopensao;
quit;

data work.grupo_copensao_assistidos;
	merge work.grupo_copensao_assistidos work.copensao_beneficios_grupo;
	by CdCopensao;
run;

/*data enquadra.MATRICULA_GRUPO_COPENSAO;*/
/*	merge enquadra.MATRICULA_GRUPO_COPENSAO work.assistidos_enquadra_copensao;*/
/*	merge enquadra.MATRICULA_GRUPO_COPENSAO work.assistidos_beneficios_copensao;*/
/*run;*/

proc delete data = work.copensao_beneficios_grupo work.assistidos_copensao;