
%_eg_conditional_dropds(work.ativos_idades_cobertura);
PROC IML;
	use partic.ATIVOS;
		read all var {id_participante IddPartiCalc IddConjuCalc} into ativos;
	close partic.ATIVOS;

	qtdAtivos = nrow(ativos);

	if (qtdAtivos > 0) then do;
		qtd_evol = 0;
		b = 1;

		DO a = 1 TO qtdAtivos;
			IddPartiCalc = ativos[a, 2];
			qtd_evol = qtd_evol + ((&MaxAge - IddPartiCalc) + 1);
		END;

		cobertura = J(qtd_evol, 4, 0);

		DO a = 1 TO qtdAtivos;
			IdParticipante = ativos[a, 1];
			IddPartiCalc = ativos[a, 2];
			IddConjuCalc = ativos[a, 3];

			*------ Projeta os benefícios até a idade de aposentadoria do plano -1 ------*;
			DO t = 0 to (&MaxAge - IddPartiCalc);
				*------ Idade do participante na evolucao ------*;
				i = min(IddPartiCalc + t, &MaxAge);
				*------ Idade do conjuce na evolucao ------*;
				j = min(IddConjuCalc + t, &MaxAge);

				cobertura[b, 1] = IdParticipante;
				cobertura[b, 2] = t;
				cobertura[b, 3] = i;
				cobertura[b, 4] = j;
				b = b + 1;
			END;
		END;

		create work.ativos_idades_cobertura from cobertura[colname={'id_participante' 't' 'IddParticCobert' 'IddConjugCobert'}];
			append from cobertura;
		close work.ativos_idades_cobertura;

		free cobertura ativos;
	end;
QUIT;

%_eg_conditional_dropds(cobertur.ativos);
data cobertur.ativos;
	retain id_participante t;
	merge partic.ativos work.ativos_idades_cobertura;
	by id_participante;
	drop CdSitCadPart NoNomePartic CdEstCivPart EstCivPart CdExDirPatro DtAdmPatroci DtAssEntPrev CdElegApoEsp CdParEntPrev FL_DEFICIENTE NuMatrOrigem FlgPensionista FL_MIGRADO IDPLANOPREV VL_RESERVA_BPD CD_SITUACAO_FUNDACAO VlBenefiPrev CdTipoBenefi DtIniBenPrev DtNascConjug CdSexoFilJov DtNascFilJov CdSexoFilInv DtNascFilInv DtIniApoInss DtApoEntPrev IddIniciInss CD_SITUACAO_PATROC DT_OPCAO_BPD VL_SALDO_PORTADO;
run;

%_eg_conditional_dropds(cobertur.ativos_fatores);
proc sql;
	create table cobertur.ativos_fatores as
	select t1.id_participante,
		   t1.t,
		   tsn.ex,
		   tsn.apxa,
		   max(0, (tsa1.lxs / tsa2.lxs)) format=12.8 as pxs,
		   max(0, ((tsn.Nxcb / tsn.Dxcb) - &Fb)) format=12.8 as axcb,
		   max(0, ((tsnc.Nxcb / tsnc.Dxcb) - &Fb)) format=12.8 as ajxcb,
		   max(0, (tsa1.Dxs / tsa2.Dxs)) format=12.8 as dy_dx,
		   max(0, ((n1.njxx / d1.djxx) - &Fb)) format=12.8 as ajxx,
		   max(0, (tsn.Mx / tsn.'Dx*'n)) format=12.8 as Ax,
		   max(0, ((tsn.Nxiicb / tsn.Dxiicb) - &Fb)) format=12.8 AS axiicb,
		   max(0, ((n2.njxx / d2.djxx) - &Fb)) format=12.8 AS ajxx_i,
		   tsa1.ix,
		   tsa1.qx,
		   tsa1.qxi,
		   tsa1.wx,
		   max(0, (tsn.Mxii / tsn.'Dxii*'n)) format=12.8 as Axii,
		   max(0, ((((tsnc.Nxcb / tsnc.Dxcb) - &Fb) - ((n2.njxx / d2.djxx) - &Fb)) * t1.PrbCasado)) format=12.8 as amix,
		   txrp1.taxa_risco as taxa_risco_partic,
		   txrp2.taxa_risco as taxa_risco_patroc
	from cobertur.ativos t1
	inner join tabuas.tabuas_servico_normal tsn on (t1.CdSexoPartic = tsn.Sexo and t1.IddParticCobert = tsn.Idade and tsn.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal tsnc on (t1.CdSexoConjug = tsnc.Sexo and t1.IddConjugCobert = tsnc.Idade and tsnc.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada tsa1 on (t1.CdSexoPartic = tsa1.Sexo and t1.IddParticCobert = tsa1.Idade and tsa1.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada tsa2 on (t1.CdSexoPartic = tsa2.Sexo and t1.IddPartiCalc = tsa2.Idade and tsa2.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n1 on (t1.CdSexoPartic = n1.sexo and t1.IddParticCobert = n1.idade_x and t1.IddConjugCobert = n1.idade_j and n1.tipo = 1 and n1.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d1 on (t1.CdSexoPartic = d1.sexo and t1.IddParticCobert = d1.idade_x and t1.IddConjugCobert = d1.idade_j and d1.tipo = 1 and d1.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n2 on (t1.CdSexoPartic = n2.sexo and t1.IddParticCobert = n2.idade_x and t1.IddConjugCobert = n2.idade_j and n2.tipo = 2 and n2.t = min(t1.t, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d2 on (t1.CdSexoPartic = d2.sexo and t1.IddParticCobert = d2.idade_x and t1.IddConjugCobert = d2.idade_j and d2.tipo = 2 and d2.t = min(t1.t, &maxTaxaJuros))
	inner join premissa.taxa_risco txrp1 on (txrp1.t = min(t1.t, &maxTaxaRiscoPartic) and txrp1.id_responsabilidade = 1)
	inner join premissa.taxa_risco txrp2 on (txrp2.t = min(t1.t, &maxTaxaRiscoPatroc) and txrp2.id_responsabilidade = 2)
	order by t1.id_participante, t1.t;
run; quit;

/*
%macro fatoresCobertura;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(cobertur.ativos_fatores_tp&tipoCalculo._s&s.);

		%if &tipoCalculo = 1 %then %do;
			proc sql;
				create table cobertur.ativos_fatores_tp&tipoCalculo._s&s. as
				select t1.*, 
					   t2.taxa_juros
				from work.ativos_fatores t1
				inner join premissa.taxa_juros t2 on (t2.t = t1.t)
				order by t1.id_participante, t1.t;
			run;
		%end;
		%else %if &tipoCalculo = 2 %then %do;
			proc sql;
				create table cobertur.ativos_fatores_tp&tipoCalculo._s&s. as
				select t1.*, 
					   t2.taxa_juros
				from work.ativos_fatores t1
				inner join premissa.taxa_juros_s&s. t2 on (t2.t = t1.t)
				order by t1.id_participante, t1.t;
			run;
		%end;
	%end;
%mend;
%fatoresCobertura;
*/

/*
%macro unionTaxas;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(cobertur.ativos_fatores_tp&tipoCalculo._s&s.);
		data cobertur.ativos_fatores_tp&tipoCalculo._s&s.;
			merge work.ativos_fatores temp.ativos_taxa_juros_tp&tipoCalculo._s&s.;
			by id_participante t;
		run;

		%if (&tipoCalculo = 2) %then %do;
			data cobertur.ativos_fatores_tp&tipoCalculo._s&s.;
				merge cobertur.ativos_fatores_tp&tipoCalculo._s&s. temp.ativos_fatores_estoc_tp&tipoCalculo._s&s.(keep= id_participante t vivo valido ligado ativo desligado);
				by id_participante t;
			run;
		%end;
	%end;
%mend;
%unionTaxas;
*/

%macro sorteioFatoresEstocastico;
	%do s = 1 %to &numeroCalculos;
		%if (&tipoCalculo = 2) %then %do;
			%_eg_conditional_dropds(cobertur.ativos_fatores_estoc_s&s.);
			PROC IML;
				load module = drawSobrevivencia;
				load module = drawValidezRotatividade;

				use cobertur.ativos;
					read all var {id_participante t CdSexoPartic IddParticCobert} into ativos;
				close cobertur.ativos;

				use tabuas.tabuas_servico_normal;
					read all var {qx ix qxi wx apxa} into tabua_f where (t = 0 & sexo = 1);
					read all var {qx ix qxi wx apxa} into tabua_m where (t = 0 & sexo = 2);
				close;

				qtdAtivos = nrow(ativos);

				if (qtdAtivos > 0) then do;
					estocastico = J(qtdAtivos, 10, 0);

					DO a = 1 TO qtdAtivos;
						id_participante = ativos[a, 1];
						t = ativos[a, 2];
						sexo = ativos[a, 3];
						idade = ativos[a, 4];

						if (sexo = 1) then do;
							qx	= tabua_f[idade + 1, 1];
							ix	= tabua_f[idade + 1, 2];
							qxi = tabua_f[idade + 1, 3];
							wx 	= tabua_f[idade + 1, 4];
							apx = tabua_f[idade + 1, 5];
						end;
						else do;
							qx	= tabua_m[idade + 1, 1];
							ix	= tabua_m[idade + 1, 2];
							qxi = tabua_m[idade + 1, 3];
							wx 	= tabua_m[idade + 1, 4];
							apx = tabua_m[idade + 1, 5];
						end;

						prob_sobrev = 0;

						if (t = 0) then do;
							tipoAposentadoria = 0;
						end;

						isValido = drawValidezRotatividade(t, ix, isValido);
						isAtivo = drawValidezRotatividade(t, apx, isAtivo);

						if (isValido = 1 & isAtivo = 0 & tipoAposentadoria = 0) then
							tipoAposentadoria = 1;
						else if (isValido = 0 & isAtivo = 0 & tipoAposentadoria = 0) then
							tipoAposentadoria = 2;

						if ((isValido = 1 & tipoAposentadoria = 0) | tipoAposentadoria = 1) then
							prob_sobrev = qx;
						else
							prob_sobrev = qxi;

						isVivo = drawSobrevivencia(t, idade, prob_sobrev, isVivo);
						
						isParticipante = drawValidezRotatividade(t, wx, isParticipante);

						isMorto = 0;
						isAposentadoria = 0;
						isInvalido = 0;
						isDesligado = 0;

						if (t > 0) then do;
							if (isAtivo ^= estocastico[a - 1, 6]) then
								isAposentadoria = 1;

							if (isVivo ^= estocastico[a - 1, 3]) then
								isMorto = 1;

							if (isValido ^= estocastico[a - 1, 4]) then
								isInvalido = 1;

							if (isParticipante ^= estocastico[a - 1, 5]) then
								isDesligado = 1;
						end;

						estocastico[a, 1] = id_participante;
						estocastico[a, 2] = t;
						estocastico[a, 3] = isVivo;
						estocastico[a, 4] = isValido;
						estocastico[a, 5] = isParticipante;
						estocastico[a, 6] = isAtivo;
						estocastico[a, 7] = isAposentadoria;
						estocastico[a, 8] = isMorto;
						estocastico[a, 9] = isInvalido;
						estocastico[a, 10] = isDesligado;
					END;

					create cobertur.ativos_fatores_estoc_s&s. from estocastico[colname={'id_participante' 't' 'Vivo' 'Valido' 'Ligado' 'Ativo' 'Aposentadoria' 'Morto' 'Invalido' 'Desligado'}];
						append from estocastico;
					close cobertur.ativos_fatores_estoc_s&s.;

					free estocastico ativos tabua_f tabua_m;
				end;
			QUIT;
		%end;
	%end;
%mend;
%sorteioFatoresEstocastico;


/*proc datasets library=temp kill memtype=data nolist;*/
proc datasets library=work kill memtype=data nolist;
	run;
quit;