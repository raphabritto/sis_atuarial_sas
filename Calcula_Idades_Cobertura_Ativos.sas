
%_eg_conditional_dropds(work.ativos_idades_cobertura);
PROC IML;
	use partic.ATIVOS;
		read all var {id_participante} into id_partic;
		read all var {idade_partic} into idade_partic;
		read all var {idade_conjug} into idade_conjug;
	close partic.ATIVOS;

	qtd_ativos = nrow(id_partic);

	if (qtd_ativos > 0) then do;
		qtd_evol = 0;
		b = 1;

		DO a = 1 TO qtd_ativos;
			qtd_evol = qtd_evol + ((&MaxAge - idade_partic[a]) + 1);
		END;

		id_participante		= J(qtd_evol, 1, 0);
		t1		 			= J(qtd_evol, 1, 0);
		idade_partic_cober 	= J(qtd_evol, 1, 0);
		idade_conjug_cober 	= J(qtd_evol, 1, 0);

		DO a = 1 TO qtd_ativos;
			*------ Projeta os benefícios até a idade de aposentadoria do plano -1 ------*;
			DO t = 0 to (&MaxAge - idade_partic[a]);
				id_participante[b] = id_partic[a];
				t1[b] = t;

				*------ Idade do participante na evolucao ------*;
				idade_partic_cober[b] = min(idade_partic[a] + t, &MaxAge);

				*------ Idade do conjuce na evolucao ------*;
				idade_conjug_cober[b] = min(idade_conjug[a] + t, &MaxAge);
				b = b + 1;
			END;
		END;

		create work.ativos_idades_cobertura var {id_participante t1 idade_partic_cober idade_conjug_cober};
			append;
		close work.ativos_idades_cobertura;
	end;
QUIT;

%_eg_conditional_dropds(cobertur.ativos);
data cobertur.ativos;
	retain id_participante t;
	merge partic.ativos work.ativos_idades_cobertura;
	by id_participante;
	drop CdSitCadPart NoNomePartic CdEstCivPart DtAdmPatroci DtAssEntPrev FL_DEFICIENTE NuMatrOrigem FL_MIGRADO IDPLANOPREV VL_RESERVA_BPD CD_SITUACAO_FUNDACAO VlBenefiPrev CdTipoBenefi DtIniBenPrev DtNascConjug DtIniApoInss DtApoEntPrev IddIniciInss CD_SITUACAO_PATROC VL_SALDO_PORTADO;
run;

%_eg_conditional_dropds(cobertur.ativos_fatores);
proc sql;
	create table cobertur.ativos_fatores as
	select ta.id_participante,
		   ta.t1,
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
		   max(0, ((((tsnc.Nxcb / tsnc.Dxcb) - &Fb) - ((n2.njxx / d2.djxx) - &Fb)) * ta.probab_casado)) format=12.8 as amix,
		   txrp1.taxa_risco as taxa_risco_partic,
		   txrp2.taxa_risco as taxa_risco_patroc
	from cobertur.ativos ta
	inner join tabuas.tabuas_servico_normal tsn on (ta.sexo_partic = tsn.Sexo and ta.idade_partic_cober = tsn.Idade and tsn.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_normal tsnc on (ta.sexo_conjug = tsnc.Sexo and ta.idade_conjug_cober = tsnc.Idade and tsnc.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada tsa1 on (ta.sexo_partic = tsa1.Sexo and ta.idade_partic_cober = tsa1.Idade and tsa1.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_servico_ajustada tsa2 on (ta.sexo_partic = tsa2.Sexo and ta.idade_partic = tsa2.Idade and tsa2.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n1 on (ta.sexo_partic = n1.sexo and ta.idade_partic_cober = n1.idade_x and ta.idade_conjug_cober = n1.idade_j and n1.tipo = 1 and n1.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d1 on (ta.sexo_partic = d1.sexo and ta.idade_partic_cober = d1.idade_x and ta.idade_conjug_cober = d1.idade_j and d1.tipo = 1 and d1.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n2 on (ta.sexo_partic = n2.sexo and ta.idade_partic_cober = n2.idade_x and ta.idade_conjug_cober = n2.idade_j and n2.tipo = 2 and n2.t = min(ta.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d2 on (ta.sexo_partic = d2.sexo and ta.idade_partic_cober = d2.idade_x and ta.idade_conjug_cober = d2.idade_j and d2.tipo = 2 and d2.t = min(ta.t1, &maxTaxaJuros))
	inner join premissa.taxa_risco txrp1 on (txrp1.t = min(ta.t1, &maxTaxaRiscoPartic) and txrp1.id_responsabilidade = 1)
	inner join premissa.taxa_risco txrp2 on (txrp2.t = min(ta.t1, &maxTaxaRiscoPatroc) and txrp2.id_responsabilidade = 2)
	order by ta.id_participante, ta.t1;
run; quit;


%macro sorteioFatoresEstocastico;
	%do s = 1 %to &numeroCalculos;
		%if (&tipoCalculo = 2) %then %do;
			%_eg_conditional_dropds(cobertur.ativos_fatores_estoc_s&s.);
			PROC IML;
				load module = sorteioEstocastico;

				use cobertur.ativos;
					read all var {id_participante} into id_participante;
					read all var {t1} into t1;
					read all var {sexo_partic} into sexo;
					read all var {idade_partic_cober} into idade;
				close cobertur.ativos;

				use tabuas.tabuas_servico_normal;
					read all var {qx} into qx_f where (t = 0 & Sexo = 1);
					read all var {ix} into ix_f where (t = 0 & Sexo = 1);
					read all var {qxi} into qxi_f where (t = 0 & Sexo = 1);
					read all var {wx} into wx_f where (t = 0 & Sexo = 1);
					read all var {apxa} into apxa_f where (t = 0 & Sexo = 1);

					read all var {qx} into qx_m where (t = 0 & Sexo = 2);
					read all var {ix} into ix_m where (t = 0 & Sexo = 2);
					read all var {qxi} into qxi_m where (t = 0 & Sexo = 2);
					read all var {wx} into wx_m where (t = 0 & Sexo = 2);
					read all var {apxa} into apxa_m where (t = 0 & Sexo = 2);
				close tabuas.tabuas_servico_normal;

				qtd_partic = nrow(id_participante);

				if (qtd_partic > 0) then do;
					vivo = J(qtd_partic, 1, 0);
					ativo = J(qtd_partic, 1, 0);
					valido = J(qtd_partic, 1, 0);
					ligado = J(qtd_partic, 1, 0);

					morto = J(qtd_partic, 1, 0);
					aposentado = J(qtd_partic, 1, 0);
					invalido = J(qtd_partic, 1, 0);
					desligado = J(qtd_partic, 1, 0);

					DO a = 1 TO qtd_partic;
						if (sexo[a] = 1) then do;
							qx  = qx_f[idade[a] + 1];
							ix	= ix_f[idade[a] + 1];
							qxi = qxi_f[idade[a] + 1];
							wx 	= wx_f[idade[a] + 1];
							apx = apxa_f[idade[a] + 1];
						end;
						else do;
							qx  = qx_m[idade[a] + 1];
							ix	= ix_m[idade[a] + 1];
							qxi = qxi_m[idade[a] + 1];
							wx 	= wx_m[idade[a] + 1];
							apx = apxa_m[idade[a] + 1];
						end;

						*--- sorteio sobrevivencia ---*;
						if (t1[a] = 0) then 
							vivo[a] = sorteioEstocastico(qx, 1);
						else if (valido[a - 1] = 1) then
							vivo[a] = sorteioEstocastico(qx, vivo[a - 1]);
						else
							vivo[a] = sorteioEstocastico(qxi, vivo[a - 1]);

						*--- sorteio aposentadoria ---*;
						if (t1[a] = 0) then
							ativo[a] = sorteioEstocastico(apx, 1);
						else
							ativo[a] = sorteioEstocastico(apx, ativo[a - 1]);

							*--- sorteio invalidez ---*;
						if (t1[a] = 0) then
							valido[a] = sorteioEstocastico(ix, 1);
						else
							valido[a] = sorteioEstocastico(ix, valido[a - 1]);

						if(t1[a] = 0) then
							ligado[a] = sorteioEstocastico(wx, 1);
						else
							ligado[a] = sorteioEstocastico(wx, ligado[a - 1]);

						if (t1[a] = 0) then do;
							if (vivo[a] = 0) then do;
								ativo[a] = 1;
								valido[a] = 1;
								ligado[a] = 1;
							end;
							else if (ativo[a] = 0) then do;
								valido[a] = 1;
								ligado[a] = 1;
							end;
							else if (valido[a] = 0) then
								ligado[a] = 1;
						end;
						else do;
							if (vivo[a] = 0 & (vivo[a - 1] = 1 & ativo[a - 1] = 1 & valido[a - 1] = 1 & ligado[a - 1] = 1)) then do;
								ativo[a] = 1;
								valido[a] = 1;
								ligado[a] = 1;
							end;
							else if (ativo[a] = 0 & (vivo[a - 1] = 1 & ativo[a - 1] = 1 & valido[a - 1] = 1 & ligado[a - 1] = 1)) then do;
								valido[a] = 1;
								ligado[a] = 1;
							end;
							else if (valido[a] = 0 & (vivo[a - 1] = 1 & ativo[a - 1] = 1 & valido[a - 1] = 1 & ligado[a - 1] = 1)) then
								ligado[a] = 1;
						end;

						if (t1[a] = 0) then do;
							if (ativo[a] = 0) then
								aposentado[a] = 1;

							if (vivo[a] = 0) then
								morto[a] = 1;

							if (valido[a] = 0) then
								invalido[a] = 1;

							if (ligado[a] = 0) then
								desligado[a] = 1;
						end;
						else do;
							if (ativo[a] ^= ativo[a - 1]) then
								aposentado[a] = 1;

							if (vivo[a] ^= vivo[a - 1]) then
								morto[a] = 1;

							if (valido[a] ^= valido[a - 1]) then
								invalido[a] = 1;

							if (ligado[a] ^= ligado[a - 1]) then
								desligado[a] = 1;
						end;
					END;

					create cobertur.ativos_fatores_estoc_s&s. var {id_participante t1 vivo ativo valido ligado morto aposentado invalido desligado};
						append;
					close cobertur.ativos_fatores_estoc_s&s.;
				end;
			QUIT;
		%end;
	%end;
%mend;
%sorteioFatoresEstocastico;

proc datasets library=work kill memtype=data nolist;
	run;
quit;