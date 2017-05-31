
%_eg_conditional_dropds(determin.deterministico_assistidos);
PROC IML;
	USE partic.assistidos;
		read all var {id_participante IddPartiCalc CdSexoPartic IddConjuCalc IddFilJovCalc IddFilInvCalc} into assistidos;
	CLOSE;

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
			nObsCobert = nObsCobert + ((&MaxAgeDeterministicoAssistidos - menorIdade) +1);
		END;

		fluxoDeterCob = J(nObsCobert, 6, 0);

		DO a = 1 TO nObsAssistidos;
			IdParticipante = assistidos[a, 1];
			IddPartiCalc = assistidos[a, 2];
			CdSexoPartic = assistidos[a, 3];
			IddConjuCalc = assistidos[a, 4];
			IddFilJovCalc = assistidos[a, 5];
			IddFilInvCalc = assistidos[a, 6];

			menorIdade = min(IddPartiCalc, min(IddConjuCalc, min(IddFilJovCalc, IddFilInvCalc)));

			*---- PROJEÇÃO DOS SALÁRIOS, AS CONTRIBUIÇÕES E OS BENEFÍCIOS DA IDADE ATUAL ATÉ A ÚLTIMA IDADE DA TÁBUA DE MORTILIDADE GERAL ---*;
			DO t = 0 TO (&MaxAgeDeterministicoAssistidos - menorIdade);
				*--- DIFERENÇA ENTRE IDADES ---*;
			    i = min(IddPartiCalc + t, &MaxAgeDeterministicoAssistidos);

				if (IddConjuCalc ^= .) then
			    	j = min(IddConjuCalc + t, &MaxAgeDeterministicoAssistidos);
				else
					j = .;

				if (IddFilJovCalc ^= .) then
					fv = min(IddFilJovCalc + t, &MaxAgeDeterministicoAssistidos);
				else
					fv = .;

				if (IddFilInvCalc ^= .) then
					fi = min(IddFilInvCalc + t, &MaxAgeDeterministicoAssistidos);
				else
					fi = .;

				fluxoDeterCob[b, 1] = IdParticipante;
				fluxoDeterCob[b, 2] = t;
				fluxoDeterCob[b, 3] = i;
				fluxoDeterCob[b, 4] = j;
				fluxoDeterCob[b, 5] = fv;
				fluxoDeterCob[b, 6] = fi;

				b = b + 1;
			END;
		END;

		create determin.deterministico_assistidos from fluxoDeterCob[colname={'id_participante' 't' 'IddPartiEvol' 'IddConjuEvol' 'IddFilJovEvol' 'IddFilInvEvol'}];
			append from fluxoDeterCob;
		close;
	end;
QUIT;
