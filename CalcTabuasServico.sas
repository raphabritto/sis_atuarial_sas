%LET vRoundProb = 0.0000000001;
%LET vRoundPensao = 0.0000000001;

%_eg_conditional_dropds(work.tabuas_temp);
PROC SQL;
	CREATE TABLE work.tabuas_temp AS 
		SELECT t1.ID_TIPO_TABUA, 
		(case
			when t1.ID_TIPO_TABUA = 1 then 'ix'
			when t1.ID_TIPO_TABUA = 2 then 'qxi'
			when t1.ID_TIPO_TABUA = 3 then 'qx'
			when t1.ID_TIPO_TABUA = 4 then 'wx'
			when t1.ID_TIPO_TABUA = 5 then 'ex'
			when t1.ID_TIPO_TABUA = 6 then 'apx'
		end) as tipo,
			(case 
				when t2.CD_SEXO = 'F' then 1 
				else 2 
			end)
		AS Sexo, 
			t2.NR_IDADE AS Idade, 
			t2.VL_PROBABILIDADE AS Probabilidade
		FROM ORACLE.TB_ATU_TABUA_BIOMETRICA t1, ORACLE.TB_ATU_TABUA_BIOMETRICA_VALOR t2, ORACLE.TB_ATU_AVAL_TABUA t3
			WHERE (t1.ID_TABUA_BIOMETRICA = t2.ID_TABUA_BIOMETRICA AND t1.ID_TABUA_BIOMETRICA = t3.ID_TABUA_BIOMETRICA AND 
				t3.CD_SEXO = t2.CD_SEXO) AND (t3.ID_AVALIACAO = &id_avaliacao)
			ORDER BY t1.ID_TIPO_TABUA,
				t2.CD_SEXO,
				t2.NR_IDADE;
QUIT;

%_eg_conditional_dropds(WORK.tabua_servico_normal_temp,
		WORK.Tabua_Sorted);

PROC SORT
	DATA=WORK.TABUAS_TEMP(KEEP=Probabilidade tipo Sexo Idade)
	OUT=WORK.Tabua_Sorted;
	BY Sexo Idade;
RUN;
PROC TRANSPOSE DATA=WORK.Tabua_Sorted
	OUT=WORK.tabua_servico_normal_temp(drop=Source Label)
	NAME=Source
	LABEL=Label;
	BY Sexo Idade;
	ID tipo;
	VAR Probabilidade;
	format Probabilidade 12.10;
RUN; QUIT;
%_eg_conditional_dropds(WORK.Tabua_Sorted);

proc delete data=work.tabuas_temp;

data work.tabua_servico_ajustada_temp;
	set work.tabua_servico_normal_temp;
	keep Sexo Idade ix qxi qx wx ex apx;
	*output ix qxi qx wx ex apx;
	ix = max(0, ix - (((ix * qx) / 2) - ((ix * wx) / 2) + ((ix * wx * qx) / 3)));
	qxi = max(0, qxi);
	qx = max(0, qx - (((ix * qx) / 2) - ((qx * wx) / 2) + ((ix * wx * qx) / 3)));
	wx = max(0, wx - (((qx * wx) / 2) - ((ix * wx) / 2) + ((ix * wx * qx) / 3)));
	ex = ex;
	apx = 0;
	format ix 12.10 qxi 12.10 qx 12.10 wx 12.10;
run;


PROC IML;
	**** funcao recebe o tipo de tabua (1 - normal, 2 - ajustada), tempo e sexo ***;
	START CalcularTabuaServico(tabua_servico, tipo_tabua, tempo, sexo);
		***
			tipo_tabua = 
				1 - servico normal 
				2 - servico ajustada;
		***;

		use work.taxa_juros;
			read all var {VL_TAXA_JUROS} into taxa_juros where(t = tempo);
		close;

		numberRows = nrow(tabua_servico);

		tabua_calculada = J(numberRows, 28, 0);
		taxa_juros_cb = max(0, (( 1 + taxa_juros) / (1 + &PrTxBenef)) - 1);

		DO a = 1 to numberRows;
			*** adiciona o tempo e o sexo na tabua ***;
			tabua_calculada[a, 1] = tempo;
			tabua_calculada[a, 2] = sexo;
			tabua_calculada[a, 3] = a - 1;

			IF a = 1 THEN DO;
				*--- calculo lx ### tabua_temp[a, 7] ---*;
				tabua_calculada[a, 4] = round(&VlrLxInicial, &vRoundProb);

				*--- calculo lxii ### tabua_temp[a, 9] # NAO É USADO NOS CALCULOS ---*;
				tabua_calculada[a, 6] = 0; 

				*--- calculo lxaa ### tabua_temp[a, 10] # NAO É USADO NOS CALCULOS ---*;
				tabua_calculada[a, 7] = round(&VlrLxInicial, &vRoundProb);

				* calculo lxs *;
				tabua_calculada[a, 12] = round(&VlrLxInicial, &vRoundProb);

				* calculo lxii *;
				tabua_calculada[a, 14] = round(&VlrLxInicial, &vRoundProb);

				* entrada aposentadoria apx *;
				*if (tipo_tabua = 1) then tabua_calculada[a, 58] = round(tabua_servico[a, 8], &vRoundProb);
				if (tipo_tabua = 1) then tabua_calculada[a, 28] = round(tabua_servico[a, 8], &vRoundProb);
			END;
			ELSE DO;
				*--- calculo lx ### tabua_temp[a, 7] ### lx = qx-1 * lx-1 ---*;
				tabua_calculada[a, 4] = max(0, round((1 - tabua_servico[a - 1, 5]) * tabua_calculada[a - 1, 4], &vRoundProb));

				*--- calculo lxii ### tabua_temp[a, 9] ### lxii =  lxii-1 + lxai-1 - dxi-1 # NAO É USADO NOS CALCULOS ---*;
				tabua_calculada[a, 6] = max(0, round(tabua_calculada[a - 1, 6] + tabua_calculada[a - 1, 8] - tabua_calculada[a - 1, 11], &vRoundProb));

				*--- calculo lxaa ### tabua_temp[a, 10] ### lxaa = lxaa-1 - lxai-1 - dxaa-1 # NAO É USADO NOS CALCULOS ---*;
				tabua_calculada[a, 7] = max(0, round(tabua_calculada[a - 1, 7] - tabua_calculada[a - 1, 8] - tabua_calculada[a - 1, 9], &vRoundProb));

				*--- calculo lxs ### tabua_temp[a, 15] ### lxs = lxs-1 - pxs-1 ---*;
				tabua_calculada[a, 12] = max(0, round(tabua_calculada[a - 1, 12] * tabua_calculada[a - 1, 13], &vRoundProb));

				*--- calculo lxii ### tabua_temp[a, 17] ### lxii = lxii-1 - dxii-1 ---*;
				tabua_calculada[a, 14] = max(0, round(tabua_calculada[a - 1, 14] - tabua_calculada[a - 1, 15], &vRoundProb));

				* entrada aposentadoria apx *;
				*if (tipo_tabua = 1) then tabua_calculada[a, 58] = round(tabua_calculada[a - 1, 58] + tabua_servico[a, 8], &vRoundProb);
				if (tipo_tabua = 1) then tabua_calculada[a, 28] = round(tabua_calculada[a - 1, 28] + tabua_servico[a, 8], &vRoundProb);
			END;

			*--- calculo dx ### tabua_temp[a, 8] ### dx = lx * qx ---*;
			tabua_calculada[a, 5] = max(0, round(tabua_calculada[a, 4] * tabua_servico[a, 5], &vRoundProb));

			*--- calculo lxai ### tabua_temp[a, 11] ### lxai = ix * lx # NAO É USADO NOS CALCULOS ---*;
			tabua_calculada[a, 8] = max(0, round(tabua_servico[a, 3] * tabua_calculada[a, 4], &vRoundProb));

			*--- calculo dxi ### tabua_temp[a, 14] ### dxi = lxii + (lxai / 2) * qxi # NAO É USADO NOS CALCULOS ---*;
			tabua_calculada[a, 11] = max(0, round((tabua_calculada[a, 6] + (tabua_calculada[a, 8] / 2)) * tabua_servico[a, 4], &vRoundProb));

			*--- calculo dxaa ### tabua_temp[a, 12] ### dxaa = dx - dxi # NAO É USADO NOS CALCULOS ---*;
			tabua_calculada[a, 9] = max(0, round(tabua_calculada[a, 5] - tabua_calculada[a, 11], &vRoundProb));

			*--- calculo qxaa ### tabua_temp[a, 13] ### qxaa = dxaa / lxaa # NAO É USADO NOS CALCULOS ---*;
			IF (round(tabua_calculada[a, 7], 0.01) = 0) THEN
				tabua_calculada[a, 10] = 1;
			ELSE
				tabua_calculada[a, 10] = max(0, min(1, round(tabua_calculada[a, 9] / tabua_calculada[a, 7], &vRoundProb)));

			*--- calculo pxs ### tabua_temp[a, 16] ### IF tipo_tabua = 1 pxs = (1 - qxaa) - ix - wx ELSE pxs = (1 - qx) - ix - wx # NAO É USADO NOS CALCULOS ---*;
			IF tipo_tabua = 1 THEN
				tabua_calculada[a, 13] = max(0, round(1 - tabua_calculada[a, 10] - tabua_servico[a, 3] - tabua_servico[a, 6], &vRoundProb));
			ELSE
				tabua_calculada[a, 13] = max(0, round(1 - tabua_servico[a, 5] - tabua_servico[a, 3] - tabua_servico[a, 6], &vRoundProb));

			* calculo dxii ### tabua_temp[a, 18] ### dxii = lxii * qxi ---*;
			tabua_calculada[a, 15] = max(0, round(tabua_calculada[a, 14] * tabua_servico[a, 4], &vRoundProb));

			*--- Dx* # Dx = lx * (1 / (1 + taxa de juros anual)) ** idade ---*;
			tabua_calculada[a, 16] = max(0, round(tabua_calculada[a, 4] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxc # Dxc = lx * (1 / (1 + taxa salarial)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 18] = max(0, round(tabua_calculada[a, 4] * (1 / (1 + &PrSalario)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxcb # Dxcb = lx * (1 / (1 + taxa beneficio)) ** idade ---*;
			*tabua_calculada[a, 20] = max(0, round(tabua_calculada[a, 4] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));
			tabua_calculada[a, 17] = max(0, round(tabua_calculada[a, 4] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxii # Dxii = lxii** * (1 / (1 + taxa juros)) ** idade ---*;
			*tabua_calculada[a, 22] = max(0, round(tabua_calculada[a, 14] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));
			tabua_calculada[a, 19] = max(0, round(tabua_calculada[a, 14] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxiic # Dxiic = lxii** * (1 / (1 + taxa salarial)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 24] = max(0, round(tabua_calculada[a, 14] * (1 / (1 + &PrSalario)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxiicb # Dxiicb = lxii** * (1 / (1 + taxa beneficio)) ** idade ---*;
			*tabua_calculada[a, 26] = max(0, round(tabua_calculada[a, 14] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));
			tabua_calculada[a, 20] = max(0, round(tabua_calculada[a, 14] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxaa # Dxaa = lxaa * (1 / (1 + taxa juros)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 28] = max(0, round(tabua_calculada[a, 7] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxaac # Dxaac = lxaa * (1 / (1 + taxa salarial)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 30] = max(0, round(tabua_calculada[a, 7] * (1 / (1 + &PrSalario)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxaacb # Dxaacb = lxaa * (1 / (1 + taxa beneficio)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 32] = max(0, round(tabua_calculada[a, 7] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxs # Dxs = lxs * (1 / (1 + taxa juros)) ** idade ---*;
			*tabua_calculada[a, 40] = max(0, round(tabua_calculada[a, 12] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));
			tabua_calculada[a, 22] = max(0, round(tabua_calculada[a, 12] * (1 / (1 + taxa_juros)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxsc # Dxsc = lxs * (1 / (1 + taxa salarial)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 42] = max(0, round(tabua_calculada[a, 12] * (1 / (1 + &PrSalario)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Dxscb # Dxscb = lxs * (1 / (1 + taxa beneficio)) ** idade # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 44] = max(0, round(tabua_calculada[a, 12] * (1 / (1 + taxa_juros_cb)) ** tabua_calculada[a, 3], &vRoundProb));

			*--- Cx # Cx = dx * (1 / (1 + taxa juros)) ** (idade + 1) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 52] = max(0, round(tabua_calculada[a, 5] * (1 / (1 + taxa_juros)) ** (tabua_calculada[a, 3] + 1), &vRoundProb));
			tabua_calculada[a, 24] = max(0, round(tabua_calculada[a, 5] * (1 / (1 + taxa_juros)) ** (tabua_calculada[a, 3] + 1), &vRoundProb));

			*--- Cxaa # Cxaa = dxaa * (1 / (1 + taxa juros)) ** (idade + 1) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 54] = max(0, round(tabua_calculada[a, 9] * (1 / (1 + taxa_juros)) ** (tabua_calculada[a, 3] + 1), &vRoundProb));

			*--- Cxii # Cxii = dxii * (1 / (1 + taxa juros)) ** (idade + 1) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 56] = max(0, round(tabua_calculada[a, 15] * (1 / (1 + taxa_juros)) ** (tabua_calculada[a, 3] + 1), &vRoundProb));
			tabua_calculada[a, 26] = max(0, round(tabua_calculada[a, 15] * (1 / (1 + taxa_juros)) ** (tabua_calculada[a, 3] + 1), &vRoundProb));
		end;

		*DO a = 1 to numberRows - 1;
			*--- Dxai # Dxai = Dxaa * ix * (1 - (qxi / 2)) * (Nxii+1/Dxii+1) * (1 / (1 + taxa juros)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 34] = max(0, round(tabua_calculada[a, 28] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 23] / tabua_calculada[a + 1, 22]) * (1 / (1 + taxa_juros)), &vRoundProb));

			*--- Dxaic # Dxaic = Dxaa * ix * (1 - (qxi / 2)) * (Nxiic+1/Dxiic+1) * (1 / (1 + taxa salarial)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 36] = max(0, round(tabua_calculada[a, 30] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 25] / tabua_calculada[a + 1, 24]) * (1 / (1 + &PrSalario)), &vRoundProb));

			*--- Dxaicb # Dxaicb = Dxaacb * ix * (1 - (qxi / 2)) * (Nxiicb+1/Dxiicb+1) * (1 / (1 + taxa beneficio)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 38] = max(0, round(tabua_calculada[a, 32] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 27] / tabua_calculada[a + 1, 26]) * (1 / (1 + taxa_juros_cb)), &vRoundProb));

			*--- Dxsi # Dxsi = Dxs * ix * (1 - (qxi / 2)) * (Nxii+1 / Dxii+1) * (1 / (1 + taxa juros)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 46] = max(0, round(tabua_calculada[a, 40] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 23] / tabua_calculada[a + 1, 22]) * (1 / (1 + taxa_juros)), &vRoundProb));

			*--- Dxsic # Dxsic = Dxsc * ix * (1 - (qxi / 2)) * (Nxiic+1 / Dxiic+1) * (1 / (1 + taxa salarial)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 48] = max(0, round(tabua_calculada[a, 42] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 25] / tabua_calculada[a + 1, 24]) * (1 / (1 + &PrSalario)), &vRoundProb));

			*--- Dxsicb # Dxsicb = Dxscb * ix * (1 - (qxi / 2)) * (Nxiicb+1 / Dxiicb+1) * (1 / (1 + taxa beneficio)) # NAO É USADO NOS CALCULOS ---*;
			*tabua_calculada[a, 50] = max(0, round(tabua_calculada[a, 44] * tabua_servico[a, 3] * (1 - (tabua_servico[a, 4] / 2)) * (tabua_calculada[a + 1, 27] / tabua_calculada[a + 1, 26]) * (1 / (1 + taxa_juros_cb)), &vRoundProb));
		*END;

		DO a = 1 to numberRows;
			DO b = a to numberRows;
				*--- Nx # Nx = soma(Dx) # soma Dx da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 17] = tabua_calculada[b, 16] + tabua_calculada[a, 17];

				*--- Nxc # Nxc = soma(Dxc) # soma Dxc da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 19] = tabua_calculada[b, 18] + tabua_calculada[a, 19];

				*--- Nxcb # Nxcb = soma(Dxcb) # soma Dxcb da idade atual ate a idade maxima ---*;
				*tabua_calculada[a, 21] = tabua_calculada[b, 20] + tabua_calculada[a, 21];
				tabua_calculada[a, 18] = tabua_calculada[b, 17] + tabua_calculada[a, 18];

				*--- Nxii # Nxii = soma(Dxii) # soma Dxii da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 23] = tabua_calculada[b, 22] + tabua_calculada[a, 23];

				*--- Nxiic # Nxiic = soma(Dxiic) # soma Dxiic da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 25] = tabua_calculada[b, 24] + tabua_calculada[a, 25];

				*--- Nxiicb # Nxiicb = soma(Dxiicb) # soma Dxiicb da idade atual ate a idade maxima ---*;
				*tabua_calculada[a, 27] = tabua_calculada[b, 26] + tabua_calculada[a, 27];
				tabua_calculada[a, 21] = tabua_calculada[b, 20] + tabua_calculada[a, 21];

				*--- Nxaa # Nxaa = soma(Dxaa) # soma Dxaa da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 29] = tabua_calculada[b, 28] + tabua_calculada[a, 29];

				*--- Nxaac # Nxaac = soma(Dxaac) # soma Dxaac da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 31] = tabua_calculada[b, 30] + tabua_calculada[a, 31];

				*--- Nxaacb # Nxaacb = soma(Dxaacb) # soma Dxaacb da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 33] = tabua_calculada[b, 32] + tabua_calculada[a, 33];

				*--- Nxai # Nxai = soma(Dxai) # soma Dxai da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 35] = tabua_calculada[b, 34] + tabua_calculada[a, 35];

				*--- Nxaic # Nxaic = soma(Dxaic) # soma Dxaic da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 37] = tabua_calculada[b, 36] + tabua_calculada[a, 37];

				*--- Nxaicb # Nxaicb = soma(Dxaicb) # soma Dxaicb da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 39] = tabua_calculada[b, 38] + tabua_calculada[a, 39];

				*--- Nxs # Nxs = soma(Dxs) # soma Dxs da idade atual ate a idade maxima ---*;
				*tabua_calculada[a, 41] = tabua_calculada[b, 40] + tabua_calculada[a, 41];
				tabua_calculada[a, 23] = tabua_calculada[b, 22] + tabua_calculada[a, 23];

				*--- Nxsc # Nxsc = soma(Dxsc) # soma Dxsc da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 43] = tabua_calculada[b, 42] + tabua_calculada[a, 43];

				*--- Nxscb # Nxscb = soma(Dxscb) # soma Dxscb da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 45] = tabua_calculada[b, 44] + tabua_calculada[a, 45];

				*--- Nxsi # Nxsi = soma(Dxsi) # soma Dxsi da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 47] = tabua_calculada[b, 46] + tabua_calculada[a, 47];

				*--- Nxsic # Nxsic = soma(Dxsic) # soma Dxsic da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 49] = tabua_calculada[b, 48] + tabua_calculada[a, 49];

				*--- Nxsicb # Nxsicb = soma(Dxsicb) # soma Dxsicb da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 51] = tabua_calculada[b, 50] + tabua_calculada[a, 51];

				*--- Mx # Mx = soma(Cx) # soma Cx da idade atual ate a idade maxima ---*;
				*tabua_calculada[a, 53] = tabua_calculada[b, 52] + tabua_calculada[a, 53];
				tabua_calculada[a, 25] = tabua_calculada[b, 24] + tabua_calculada[a, 25];

				*--- Mxaa # Mxaa = soma(Cxaa) # soma Cxaa da idade atual ate a idade maxima # NAO É USADO NOS CALCULOS ---*;
				*tabua_calculada[a, 55] = tabua_calculada[b, 54] + tabua_calculada[a, 55];

				*--- Mxii # Mxii = soma(Cxii) # soma Cxii da idade atual ate a idade maxima ---*;
				*tabua_calculada[a, 57] = tabua_calculada[b, 56] + tabua_calculada[a, 57];
				tabua_calculada[a, 27] = tabua_calculada[b, 26] + tabua_calculada[a, 27];
			END;
		END;

		*create work.tabua_servico_temp from tabua_calculada[colname={'t' 'Sexo' 'Idade' 'lx' 'dx' 'lxii_' 'lxaa_' 'lxai_' 'dxaa_' 'qxaa_' 'dxi_' 'lxs' 'pxs_' 'lxii' 'dxii' 'Dx*' 'Nx' 'Dxc' 'Nxc' 'Dxcb' 'Nxcb' 'Dxii*' 'Nxii' 'Dxiic' 'Nxiic' 'Dxiicb' 'Nxiicb' 'Dxaa*' 'Nxaa' 'Dxaac' 'Nxaac' 'Dxaacb' 'Nxaacb' 'Dxai' 'Nxai' 'Dxaic' 'Nxaic' 'Dxaicb' 'Nxaicb' 'Dxs' 'Nxs' 'Dxsc' 'Nxsc' 'Dxscb' 'Nxscb' 'Dxsi' 'Nxsi' 'Dxsic' 'Nxsic' 'Dxsicb' 'Nxsicb' 'Cx' 'Mx' 'Cxaa' 'Mxaa' 'Cxii' 'Mxii' 'apxa'}];
		create work.tabua_servico_temp from tabua_calculada[colname={'t' 'Sexo' 'Idade' 'lx' 'dx' 'lxii_' 'lxaa_' 'lxai_' 'dxaa_' 'qxaa_' 'dxi_' 'lxs' 'pxs_' 'lxii' 'dxii' 'Dx*' 'Dxcb' 'Nxcb' 'Dxii*' 'Dxiicb' 'Nxiicb' 'Dxs' 'Nxs' 'Cx_' 'Mx' 'Cxii_' 'Mxii' 'apxa'}];
			append from tabua_calculada;
		close;
	FINISH;
	store module = CalcularTabuaServico;
QUIT;

%macro calcularTabuaServicoNormal;
	%_eg_conditional_dropds(work.tabua_servico_normal);

	%do a = 0 %to &numberOfTaxaJuros - 1;
		%do b = 1 %to 2;
			
			%_eg_conditional_dropds(work.tabua_servico_temp);
			PROC IML;
				load module=CalcularTabuaServico;

				use work.tabua_servico_normal_temp;
					read all var _all_ into tabua_servico where(sexo = &b);
				close;

				run CalcularTabuaServico(tabua_servico, 1, &a, &b);
			QUIT;

			%_eg_conditional_dropds(work.tabua_servico_normal_t&a.s&b.);
			data work.tabua_servico_normal_t&a.s&b.;
				retain t;
				merge work.tabua_servico_normal_temp(where=(Sexo = &b.)) work.tabua_servico_temp;
				by sexo idade;
				drop lxii_ lxaa_ lxai_ dxaa_ qxaa_ dxi_ pxs_ Cx_ Cxii_;
				format lx COMMAX14.3		dx COMMAX14.3		lxs COMMAX14.3		lxii COMMAX14.3			dxii COMMAX14.3			Dx COMMAX14.3
					   Dxcb COMMAX14.3		Nxcb COMMAX14.3		Dxii COMMAX14.3 	Dxiicb COMMAX14.3 		Nxiicb COMMAX14.3		Dxs COMMAX14.3
					   Nxs COMMAX14.3 		Mx COMMAX14.3 		Mxii COMMAX14.3 	apxa 10.6;
			run;

			%_eg_conditional_dropds(work.tabua_servico_temp);

			%if (&a = 0 & &b = 1) %then %do;
				%_eg_conditional_dropds(tabuas.tabuas_servico_normal);
				data tabuas.tabuas_servico_normal;
					set work.tabua_servico_normal_t&a.s&b.;
				run;
			%end;
			%else %do;
				data tabuas.tabuas_servico_normal;
					set tabuas.tabuas_servico_normal work.tabua_servico_normal_t&a.s&b.;
				run;
			%end;

			%_eg_conditional_dropds(work.tabua_servico_normal_t&a.s&b.);
		%end;
	%end;

	%_eg_conditional_dropds(work.tabua_servico_normal_temp);
%mend;
%calcularTabuaServicoNormal;


%macro calcularTabuaServicoAjustada;
	%_eg_conditional_dropds(work.tabua_servico_ajustada);

	%do a = 0 %to &numberOfTaxaJuros - 1;
		%do b = 1 %to 2;
			
			%_eg_conditional_dropds(work.tabua_servico_temp);
			PROC IML;
				load module=CalcularTabuaServico;

				use work.tabua_servico_ajustada_temp;
					read all var _all_ into tabua_servico where(sexo = &b);
				close;

				run CalcularTabuaServico(tabua_servico, 2, &a, &b);
			QUIT;

			%_eg_conditional_dropds(work.tabua_servico_ajustada_t&a.s&b.);
			data work.tabua_servico_ajustada_t&a.s&b.;
				retain t;
				merge work.tabua_servico_ajustada_temp(where=(Sexo = &b.)) work.tabua_servico_temp;
				by sexo idade;
				drop lxii_ lxaa_ lxai_ dxaa_ qxaa_ dxi_ pxs_ Cx_ Cxii_ apx apxa;
				format lx COMMAX14.3		dx COMMAX14.3		lxs COMMAX14.3		lxii COMMAX14.3			dxii COMMAX14.3			Dx COMMAX14.3
					   Dxcb COMMAX14.3		Nxcb COMMAX14.3		Dxii COMMAX14.3 	Dxiicb COMMAX14.3 		Nxiicb COMMAX14.3		Dxs COMMAX14.3
					   Nxs COMMAX14.3 		Mx COMMAX14.3 		Mxii COMMAX14.3 	apxa 10.6;
			run;

			%_eg_conditional_dropds(work.tabua_servico_temp);

			%if (&a = 0 & &b = 1) %then %do;
				%_eg_conditional_dropds(tabuas.tabuas_servico_ajustada);
				data tabuas.tabuas_servico_ajustada;
					set work.tabua_servico_ajustada_t&a.s&b.;
				run;
			%end;
			%else %do;
				data tabuas.tabuas_servico_ajustada;
					set tabuas.tabuas_servico_ajustada work.tabua_servico_ajustada_t&a.s&b.;
				run;
			%end;

			%_eg_conditional_dropds(work.tabua_servico_ajustada_t&a.s&b.);
		%end;
	%end;

	%_eg_conditional_dropds(work.tabua_servico_ajustada_temp);
%mend;
%calcularTabuaServicoAjustada;

%let idade_apx_fem = 0;
%let idade_apx_mas = 0;

proc sql outobs=1 noprint;
	select (Idade - 1) as idade into: idade_apx_fem
	from tabuas.tabuas_servico_normal t1
	where t1.apxa = 1
	and sexo = 1
	order by idade;

	select (Idade - 1) as idade into: idade_apx_mas
	from tabuas.tabuas_servico_normal t1
	where t1.apxa = 1
	and sexo = 2
	order by idade;
run;