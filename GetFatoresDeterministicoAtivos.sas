
proc sql;
	create table work.idade_cobertura_bloco as
	select t2.id_participante,
		   t2.t,
		   t2.IddPartEvol,
		   t2.IddConjEvol,
		   t1.id_bloco
	from partic.ativos t1
	inner join cobertur.cobertura_ativos t2 on (t1.id_participante = t2.id_participante)
	order by t1.id_participante, t2.t;
quit;

%macro evolucaoDeterministicoAtivos;
	%do a = 1 %to &numberOfBlocksAtivos;
		%_eg_conditional_dropds(work.idade_deterministico_ativos);

		PROC IML; *SYMSIZE=10737418240 WORKSIZE=34359738368;
			USE work.idade_cobertura_bloco;
				read all var {id_participante t IddPartEvol IddConjEvol} into ativos where (id_bloco = &a.);
			CLOSE;

			qtsObs = nrow(ativos);

			if (qtsObs > 0) then do;
				qtdEvol = 0;
				b = 1;

				DO a = 1 TO qtsObs;
					IddPartEvol = ativos[a, 3];
					qtdEvol = qtdEvol + ((&MaxAgeDeterministicoAtivos - IddPartEvol) + 1);
				END;

				deterministico = J(qtdEvol, 5, 0);

				DO a = 1 TO qtsObs;
					IdParticipante = ativos[a, 1];
					tC = ativos[a, 2];
					IddPartEvol = ativos[a, 3];
					IddConjEvol = ativos[a, 4];
					c = 0;
					tD = tC;

					DO i = IddPartEvol to &MaxAgeDeterministicoAtivos;
						*------ Idade do participante na evolucao ------*;
						*i = min(IddPartEvol + c, &MaxAgeDeterministicoAtivos);
						*------ Idade do conjuce na evolucao ------*;
						j = min(IddConjEvol + (i - IddPartEvol), &MaxAgeDeterministicoAtivos);

						deterministico[b, 1] = IdParticipante;
						deterministico[b, 2] = tC;
						deterministico[b, 3] = tD;
						deterministico[b, 4] = i;
						deterministico[b, 5] = j;
						b = b + 1;
						tD = tD + 1;
					END;
				END;

				create work.idade_deterministico_ativos from deterministico[colname={'id_participante' 'tCobertura' 'tDeterministico' 'IddPartiDeter' 'IddConjuDeter'}];
					append from deterministico;
				close;
			end;
		QUIT;

		data determin.deterministico_ativos&a.;
			set work.idade_deterministico_ativos;
		run;
	%end;

	proc delete data = work.idade_deterministico_ativos;
%mend;
%evolucaoDeterministicoAtivos;