
%_eg_conditional_dropds(cobertur.cobertura_ativos);
PROC IML;
	use partic.ATIVOS;
	read all var {id_participante IddPartiCalc IddConjuCalc id_bloco} into ativos;
	close;

	qtdAtivos = nrow(ativos);

	if (qtdAtivos > 0) then do;
		qtd_evol = 0;
		b = 1;

		DO a = 1 TO qtdAtivos;
			IddPartiCalc = ativos[a, 2];
			qtd_evol = qtd_evol + ((&MaxAgeCoberturaAtivos - IddPartiCalc) + 1);
		END;

		cobertura = J(qtd_evol, 4, 0);

		DO a = 1 TO qtdAtivos;
			IdParticipante = ativos[a, 1];
			IddPartiCalc = ativos[a, 2];
			IddConjuCalc = ativos[a, 3];

			*------ Projeta os benefícios até a idade de aposentadoria do plano -1 ------*;
			DO t = 0 to (&MaxAgeCoberturaAtivos - IddPartiCalc);
				*------ Idade do participante na evolucao ------*;
				i = min(IddPartiCalc + t, &MaxAgeCoberturaAtivos);
				*------ Idade do conjuce na evolucao ------*;
				j = min(IddConjuCalc + t, &MaxAgeCoberturaAtivos);

				cobertura[b, 1] = IdParticipante;
				cobertura[b, 2] = t;
				cobertura[b, 3] = i;
				cobertura[b, 4] = j;
				*cobertura[b, 5] = ativos[a, 4];
				b = b + 1;
			END;
		END;

		create cobertur.cobertura_ativos from cobertura[colname={'id_participante' 't' 'IddPartEvol' 'IddConjEvol'}];
			append from cobertura;
		close;
	end;
QUIT;