
%_eg_conditional_dropds(work.ativos_idades_fluxo);
PROC IML;
	USE cobertur.ativos;
		read all var {id_participante} into id_partic;
		read all var {t1} into t;
		read all var {idade_partic_cober} into IddParticCobert;
		read all var {idade_conjug_cober} into IddConjugCobert;
	CLOSE cobertur.ativos;

	qtd_ativos = nrow(id_partic);

	if (qtd_ativos > 0) then do;
		qtd_ciclos = 0;
		b = 1;

		DO a = 1 TO qtd_ativos;
			qtd_ciclos = qtd_ciclos + ((&MaxAge - IddParticCobert[a]) + 1);
		END;

		id_participante = J(qtd_ciclos, 1, 0);
		t1 = J(qtd_ciclos, 1, 0);
		t2 = J(qtd_ciclos, 1, 0);
		idade_partic_fluxo = J(qtd_ciclos, 1, 0);
		idade_conjug_fluxo = J(qtd_ciclos, 1, 0);

		DO a = 1 TO qtd_ativos;
			tfluxo = t[a];

			DO i = IddParticCobert[a] to &MaxAge;
				id_participante[b] = id_partic[a];
				t1[b] = t[a];
				t2[b] = tfluxo;

				*------ Idade do participante na evolucao ------*;
				idade_partic_fluxo[b] = i;
				*------ Idade do conjuce na evolucao ------*;
				idade_conjug_fluxo[b] = min(IddConjugCobert[a] + (i - IddParticCobert[a]), &MaxAge);

				b = b + 1;
				tfluxo = tfluxo + 1;
			END;
		END;

		create work.ativos_idades_fluxo var {id_participante t1 t2 idade_partic_fluxo idade_conjug_fluxo};
			append;
		close work.ativos_idades_fluxo;
	end;
QUIT;

%_eg_conditional_dropds(work.ativos_fluxo);
data work.ativos_fluxo;
	retain id_participante t1 t2 ;
	merge cobertur.ativos work.ativos_idades_fluxo;
	by id_participante t1;
	keep id_participante t1 t2 sexo_partic idade_partic idade_partic_cober idade_partic_fluxo sexo_conjug idade_conjug_cober idade_conjug_fluxo;
run;

%_eg_conditional_dropds(work.ativos_fatores_iml);
proc iml;
	use tabuas.tabuas_servico_normal;
		read all var {lx} into lx_f where (sexo = 1 & t = 0);
		read all var {lx} into lx_m where (sexo = 2 & t = 0);
		read all var {dx} into dx1_f where (sexo = 1 & t = 0);
		read all var {dx} into dx1_m where (sexo = 2 & t = 0);
		read all var {dxii} into dxii1_f where (sexo = 1 & t = 0);
		read all var {dxii} into dxii1_m where (sexo = 2 & t = 0);
		read all var {lxii} into lxii_f where (sexo = 1 & t = 0);
		read all var {lxii} into lxii_m where (sexo = 2 & t = 0);
		read all var {apx} into apx_f where (sexo = 1 & t = 0);
		read all var {apx} into apx_m where (sexo = 2 & t = 0);
		read all var {apxa} into apxa_f where (sexo = 1 & t = 0);
		read all var {apxa} into apxa_m where (sexo = 2 & t = 0);
	close tabuas.tabuas_servico_normal;

	use tabuas.tabuas_servico_ajustada;
		read all var {lxs} into lxs_f where (sexo = 1 & t = 0);
		read all var {lxs} into lxs_m where (sexo = 2 & t = 0);
		read all var {qx} into qx_f where (sexo = 1 & t = 0);
		read all var {qx} into qx_m where (sexo = 2 & t = 0);
		read all var {ix} into ix_f where (sexo = 1 & t = 0);
		read all var {ix} into ix_m where (sexo = 2 & t = 0);
	close tabuas.tabuas_servico_ajustada;

	nxcb_f = .;
	nxcb_m = .;
	dxcb_f = .;
	dxcb_m = .;
	mx_f = .;
	mx_m = .;
	dx2_f = .;
	dx2_m = .;
	nxiicb_f = .;
	nxiicb_m = .;
	dxiicb_f = .;
	dxiicb_m = .;
	mxii_f = .;
	mxii_m = .;
	dxii2_f = .;
	dxii2_m = .;

	do i = 0 to &numberOfTaxaJuros - 1;
		use tabuas.tabuas_servico_normal;
			read all var {Nxcb} into nxcb_fx where (sexo = 1 & t = i);
			read all var {Nxcb} into nxcb_mx where (sexo = 2 & t = i);
			read all var {Dxcb} into dxcb_fx where (sexo = 1 & t = i);
			read all var {Dxcb} into dxcb_mx where (sexo = 2 & t = i);
			read all var {Nxiicb} into nxiicb_fx where (sexo = 1 & t = i);
			read all var {Nxiicb} into nxiicb_mx where (sexo = 2 & t = i);
			read all var {Dxiicb} into dxiicb_fx where (sexo = 1 & t = i);
			read all var {Dxiicb} into dxiicb_mx where (sexo = 2 & t = i);
			read all var {Mx} into mx_fx where (sexo = 1 & t = i);
			read all var {Mx} into mx_mx where (sexo = 2 & t = i);
			read all var {'Dx*'} into dx3_f where (sexo = 1 & t = i);
			read all var {'Dx*'} into dx3_m where (sexo = 2 & t = i);
			read all var {Mxii} into mxii_fx where (sexo = 1 & t = i);
			read all var {Mxii} into mxii_mx where (sexo = 2 & t = i);
			read all var {'Dxii*'} into dxii3_f where (sexo = 1 & t = i);
			read all var {'Dxii*'} into dxii3_m where (sexo = 2 & t = i);
		close tabuas.tabuas_servico_normal;

		if (i = 0) then do;
			nxcb_f = nxcb_fx;
			nxcb_m = nxcb_mx;
			dxcb_f = dxcb_fx;
			dxcb_m = dxcb_mx;
			nxiicb_f = nxiicb_fx;
			nxiicb_m = nxiicb_mx;
			dxiicb_f = dxiicb_fx;
			dxiicb_m = dxiicb_mx;
			mx_f = mx_fx;
			mx_m = mx_mx;
			dx2_f = dx3_f;
			dx2_m = dx3_m;
			mxii_f = mxii_fx;
			mxii_m = mxii_mx;
			dxii2_f = dxii3_f;
			dxii2_m = dxii3_m;
		end;
		else do;
			nxcb_f = nxcb_f || nxcb_fx;
			nxcb_m = nxcb_m || nxcb_mx;
			dxcb_f = dxcb_f || dxcb_fx;
			dxcb_m = dxcb_m || dxcb_mx;
			nxiicb_f = nxiicb_f || nxiicb_fx;
			nxiicb_m = nxiicb_m || nxiicb_mx;
			dxiicb_f = dxiicb_f || dxiicb_fx;
			dxiicb_m = dxiicb_m || dxiicb_mx;
			mx_f = mx_f || mx_fx;
			mx_m = mx_m || mx_mx;
			dx2_f = dx2_f || dx3_f;
			dx2_m = dx2_m || dx3_m;
			mxii_f = mxii_f || mxii_fx;
			mxii_m = mxii_m || mxii_mx;
			dxii2_f = dxii2_f || dxii3_f;
			dxii2_m = dxii2_m || dxii3_m;
		end;
	end;

	use work.ativos_fluxo;
		read all var {id_participante} into id_participante;
		read all var {t1} into t1;
		read all var {t2} into t2;
		read all var {sexo_partic} into sexo_partic;
		read all var {idade_partic} into idade_partic;
		read all var {idade_partic_cober} into IddParticCobert;
		read all var {idade_partic_fluxo} into idade_partic_fluxo;
		read all var {sexo_conjug} into sexo_conjug;
		read all var {idade_conjug_cober} into IddConjugCobert;
		read all var {idade_conjug_fluxo} into idade_conjug_fluxo;
	close work.ativos_fluxo;

	qtd_ativos = nrow(id_participante);

	if (qtd_ativos > 0) then do;
		ax = J(qtd_ativos, 1, 0);
		dx = J(qtd_ativos, 1, 0);
		ix = J(qtd_ativos, 1, 0);
		lx = J(qtd_ativos, 1, 0);
		px = J(qtd_ativos, 1, 0);
		qx = J(qtd_ativos, 1, 0);
		apx = J(qtd_ativos, 1, 0);
		pjx = J(qtd_ativos, 1, 0);
		pxs = J(qtd_ativos, 1, 0);
		apxa = J(qtd_ativos, 1, 0);
		axcb = J(qtd_ativos, 1, 0);
		axii = J(qtd_ativos, 1, 0);
		dxii = J(qtd_ativos, 1, 0);
		lxii = J(qtd_ativos, 1, 0);
		pxii = J(qtd_ativos, 1, 0);
		ajxcb = J(qtd_ativos, 1, 0);
		axiicb = J(qtd_ativos, 1, 0);

		do a = 1 to qtd_ativos;
			if (sexo_partic[a] = 1) then do;
				if (lx_f[IddParticCobert[a] + 1] > 0) then
					px[a] = max(0, round(lx_f[idade_partic_fluxo[a] + 1] / lx_f[IddParticCobert[a] + 1], 0.00000001));

				if (lxii_f[IddParticCobert[a] + 1] > 0) then
					pxii[a] = max(0, lxii_f[idade_partic_fluxo[a] + 1] / lxii_f[IddParticCobert[a] + 1]);

				if (lxs_f[idade_partic[a] + 1] > 0) then
					pxs[a] = max(0, round(lxs_f[IddParticCobert[a] + 1] / lxs_f[idade_partic[a] + 1], 0.00000001));

				if (dxcb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
					nxcb = nxcb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					dxcb = dxcb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					axcb[a] = max(0, (nxcb / dxcb) - &Fb);
				end;

				if (t1[a] = t2[a]) then do;
					if(dx2_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1] > 0) then do;
						mx = mx_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						dx_ = dx2_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						ax[a] = max(0, mx / dx_);
					end;

					ix[a] = ix_f[IddParticCobert[a] + 1];

					if (dxii2_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1] > 0) then do;
						mxii = mxii_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						dxii_ = dxii2_f[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						axii[a] = max(0, mxii / dxii_);
					end;
				end;

				if (dxiicb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
					nxiicb = nxiicb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					dxiicb = dxiicb_f[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					axiicb[a] = max(0, (nxiicb / dxiicb) - &Fb);
				end;

				if (t2[a] = 0 | (&CdPlanBen = 4 | &CdPlanBen = 5)) then
					apx[a] = apxa_f[idade_partic_fluxo[a] + 1];
				else
					apx[a] = apx_f[idade_partic_fluxo[a] + 1];

				dx[a] = dx1_f[idade_partic_fluxo[a] + 1];
				lx[a] = lx_f[IddParticCobert[a] + 1];
				qx[a] = qx_f[idade_partic_fluxo[a] + 1];
				apxa[a] = apxa_f[idade_partic_fluxo[a] + 1];
				dxii[a] = dxii1_f[idade_partic_fluxo[a] + 1];
				lxii[a] = lxii_f[IddParticCobert[a] + 1];
			end;
			else do;
				if (lx_m[IddParticCobert[a] + 1] > 0) then
					px[a] = max(0, round(lx_m[idade_partic_fluxo[a] + 1] / lx_m[IddParticCobert[a] + 1], 0.00000001));

				if (lxii_m[IddParticCobert[a] + 1] > 0) then
					pxii[a] = max(0, lxii_m[idade_partic_fluxo[a] + 1] / lxii_m[IddParticCobert[a] + 1]);

				if (lxs_m[idade_partic[a] + 1] > 0) then
					pxs[a] = max(0, round(lxs_m[IddParticCobert[a] + 1] / lxs_m[idade_partic[a] + 1], 0.00000001));

				if (dxcb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
					nxcb = nxcb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					dxcb = dxcb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					axcb[a] = max(0, (nxcb / dxcb) - &Fb);
				end;

				if (t1[a] = t2[a]) then do;
					if(dx2_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1] > 0) then do;
						mx = mx_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						dx_ = dx2_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						ax[a] = max(0, mx / dx_);
					end;

					ix[a] = ix_m[IddParticCobert[a] + 1];

					if (dxii2_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1] > 0) then do;
						mxii = mxii_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						dxii_ = dxii2_m[IddParticCobert[a] + 1, min(t1[a], &maxTaxaJuros) + 1];
						axii[a] = max(0, mxii / dxii_);
					end;
				end;

				if (dxiicb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
					nxiicb = nxiicb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					dxiicb = dxiicb_m[idade_partic_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
					axiicb[a] = max(0, (nxiicb / dxiicb) - &Fb);
				end;

				if (t2[a] = 0 | (&CdPlanBen = 4 | &CdPlanBen = 5)) then
					apx[a] = apxa_m[idade_partic_fluxo[a] + 1];
				else
					apx[a] = apx_m[idade_partic_fluxo[a] + 1];

				dx[a] = dx1_m[idade_partic_fluxo[a] + 1];
				lx[a] = lx_m[IddParticCobert[a] + 1];
				qx[a] = qx_m[idade_partic_fluxo[a] + 1];
				apxa[a] = apxa_m[idade_partic_fluxo[a] + 1];
				dxii[a] = dxii1_m[idade_partic_fluxo[a] + 1];
				lxii[a] = lxii_m[IddParticCobert[a] + 1];
			end;

			if (sexo_conjug[a] = 1) then do;
				if (lx_f[IddConjugCobert[a] + 1] > 0) then
					pjx[a] = max(0, round(lx_f[idade_conjug_fluxo[a] + 1] / lx_f[IddConjugCobert[a] + 1], 0.00000001));

				if (t1[a] = t2[a]) then do;
					if (dxcb_f[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
						njxcb = nxcb_f[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
						djxcb = dxcb_f[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
						ajxcb[a] = max(0, (njxcb / djxcb) - &Fb);
					end;
				end;
			end;
			else do;
				if (lx_m[IddConjugCobert[a] + 1] > 0) then
					pjx[a] = max(0, round(lx_m[idade_conjug_fluxo[a] + 1] / lx_m[IddConjugCobert[a] + 1], 0.00000001));

				if (t1[a] = t2[a]) then do;
					if (dxcb_m[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1] > 0) then do;
						njxcb = nxcb_m[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
						djxcb = dxcb_m[idade_conjug_fluxo[a] + 1, min(t2[a], &maxTaxaJuros) + 1];
						ajxcb[a] = max(0, (njxcb / djxcb) - &Fb);
					end;
				end;
			end;
		end;

		create work.ativos_fatores_iml var {id_participante t1 t2 ax dx ix lx px qx apx pjx pxs apxa axcb axii dxii lxii pxii ajxcb axiicb};
			append;
		close work.ativos_fatores_iml;
	end;
quit;

%_eg_conditional_dropds(work.ativos_fatores_sql);
proc sql;
	create table work.ativos_fatores_sql as
	select t1.id_participante,
		   t1.t1,
		   t1.t2,
		   max(0, ((n1.njxx / d1.djxx) - &Fb)) format = 12.8 as ajxx,
		   max(0, ((n2.njxx / d2.djxx) - &Fb)) format= 12.8 as ajxx_i
	from work.ativos_fluxo t1
	inner join tabuas.tabuas_pensao_njxx n1 on (t1.sexo_partic = n1.sexo and t1.idade_partic_cober = n1.idade_x and t1.idade_conjug_cober = n1.idade_j and n1.tipo = 1 and n1.t = min(t1.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d1 on (t1.sexo_partic = d1.sexo and t1.idade_partic_cober = d1.idade_x and t1.idade_conjug_cober = d1.idade_j and d1.tipo = 1 and d1.t = min(t1.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_njxx n2 on (t1.sexo_partic = n2.sexo and t1.idade_partic_cober = n2.idade_x and t1.idade_conjug_cober = n2.idade_j and n2.tipo = 2 and n2.t = min(t1.t1, &maxTaxaJuros))
	inner join tabuas.tabuas_pensao_djxx d2 on (t1.sexo_partic = d2.sexo and t1.idade_partic_cober = d2.idade_x and t1.idade_conjug_cober = d2.idade_j and d2.tipo = 2 and d2.t = min(t1.t1, &maxTaxaJuros))
	where t1.t1 = t1.t2
	order by t1.id_participante, t1.t1, t1.t2;
run;

%_eg_conditional_dropds(fluxo.ativos_fatores);
data fluxo.ativos_fatores;
	merge work.ativos_fatores_iml work.ativos_fatores_sql;
	by id_participante t1 t2;
	if ajxx = . then ajxx = 0;
	if ajxx_i = . then ajxx_i = 0;
	format px 12.8 apx 12.8 apxa 12.8 dx commax16.3 lx commax16.3 dxii commax16.3 lxii commax16.3 pxii 12.8 pjx 12.8 qx 12.8 pxs 12.8 axcb 12.8 ajxcb 12.8 ax 12.8 axiicb 12.8 axii 12.8 ix 12.8;
run;

%macro calculaIdadeFluxo;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(fluxo.ativos_tp&tipoCalculo._s&s.);
		data fluxo.ativos_tp&tipoCalculo._s&s.;
			retain id_participante t1 t2;
			merge cobertur.ativos_tp&tipoCalculo._s&s. work.ativos_idades_fluxo;
			by id_participante t1;
			drop PeFatReduPbe DtAdesaoPlan VlBenSaldado DtIniBenInss VlBenefiInss IddIniApoInss idade_partic_cober salario_contrib contribuicao_partic contribuicao_patroc SalBenefInss beneficioInss contribuicao_atc beneficio_total_ptc contribuicao_ptc contribuicao_aiv beneficio_total_piv contribuicao_piv contribuicao_ppa aux_funeral_ativo BENEF_AUX_FUNERAL_INVALIDO AUX_FUNERAL_INVALIDO idade_partic_fluxo idade_conjug_fluxo;
		run;

		%if (&tipoCalculo = 2) %then %do;
			%_eg_conditional_dropds(fluxo.ativos_fatores_estoc_s&s.);
			proc sql;
				create table fluxo.ativos_fatores_estoc_s&s. as
				select t2.vivo, t2.Morto, t2.Invalido, t2.ativo, t2.ligado, t2.valido, t3.aposentado
				from work.ativos_fluxo t1
				inner join cobertur.ativos_fatores_estoc_s&s. t2 on (t1.id_participante = t2.id_participante and t1.t2 = t2.t1)
				inner join cobertur.ativos_fatores_estoc_s&s. t3 on (t1.id_participante = t3.id_participante and t1.t1 = t3.t1)
				order by t1.id_participante, t1.t1, t1.t2;
			run; quit;
		%end;
	%end;
%mend;
%calculaIdadeFluxo;

proc datasets library=work kill memtype=data nolist;
	run;
quit;