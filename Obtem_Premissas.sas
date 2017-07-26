
%macro loadPremissas;
	%if (%sysfunc(exist(work.avaliacao))) %then %do;
		DATA _NULL_;
			SET work.avaliacao;
			call symputx('ID_AVALIACAO', ID_AVALIACAO);
			call symputx('ID_CADASTRO', ID_CADASTRO);
			call symputx('isGravaMemoriaCalculo', FL_MEMORIA_CALCULO);
			call symputx('BenMinimo', VL_BENEFICIO_MINIMO);
			call symputx('CD_COMPOSICAO_FAMILIAR', CD_COMPOSICAO_FAMILIAR);
			call symputx('DtCalAval', DT_CALCULO);
			call symputx('DtReajBen', DT_REAJUSTE_BENEFICIO);
			call symputx('NR_DIFERENCIA_IDADE_CONJ_FEM', NR_DIFERENCIA_IDADE_CONJ_FEM);
			call symputx('NR_DIFERENCIA_IDADE_CONJ_MAS', NR_DIFERENCIA_IDADE_CONJ_MAS);
			call symputx('NR_IDADE_INI_CONT_INSS_MAS', NR_IDADE_INI_CONT_INSS_MAS);
			call symputx('NR_IDADE_INI_CONT_INSS_FEM', NR_IDADE_INI_CONT_INSS_FEM);
			call symputx('MaiorIdad', NR_MAIORIDADE_PLANO);
			call symputx('NR_TEMPO_CONT_INSS_MAS', NR_TEMPO_CONT_INSS_MAS);
			call symputx('NR_TEMPO_CONT_INSS_FEM', NR_TEMPO_CONT_INSS_FEM);
			call symputx('NR_IDADE_INI_APOS_MAS', NR_IDADE_INI_APOS_MAS);
			call symputx('NR_IDADE_INI_APOS_FEM', NR_IDADE_INI_APOS_FEM);
			call symputx('NroBenAno', NR_PAGTOS_BENEF_CONTRIB_ANO);
			call symputx('PC_DESPESA_ADM_PARTICIPANTE', PC_DESPESA_ADM_PARTICIPANTE);
			call symputx('PC_DESPESA_ADM_PATROCINADORA', PC_DESPESA_ADM_PATROCINADORA);
			call symputx('percentualSaidaBPD', PC_SAIDA_BPD);
			call symputx('percentualPortabilidade', PC_SAIDA_PORTABILIDADE);
			call symputx('percentualResgate', PC_SAIDA_RESGATE);
			call symputx('CtFamPens', PC_COTA_FAMILIAR_PENSAO);
			call symputx('Fxa01Cont', PC_FAIXA_01_CONTRIBUICAO);
			call symputx('Fxa02Cont', PC_FAIXA_02_CONTRIBUICAO);
			call symputx('Fxa03Cont', PC_FAIXA_03_CONTRIBUICAO);
			call symputx('FtBenLiquido', PC_FATOR_REAJ_BENEF_LIQUIDO);
			call symputx('FtBenEnti', PC_FATOR_VLR_REAL_BEN_FUNCEF);
			call symputx('FtBenInss', PC_FATOR_VLR_REAL_BEN_INSS);
			call symputx('FtSalPart', PC_FATOR_VLR_REAL_SALARIO);
			call symputx('PC_PROB_PARTIC_CAS_APOS_MAS', PC_PROB_PARTIC_CAS_APOS_MAS);
			call symputx('PC_PROB_PARTIC_CAS_APOS_FEM', PC_PROB_PARTIC_CAS_APOS_FEM);
			call symputx('TxaAdmBen', PC_TAXA_ADMIN_BENEFICIO);
			call symputx('PrTxBenef', PC_TAXA_REAL_CRESC_BENEFICIO);
			call symputx('PrSalPart', PC_TAXA_REAL_CRESC_SALARIAL);
/*			call symputx('PrTxJrAno', PC_TAXA_REAL_JUROS_ANUAL); -- campo retirado pra aplicacao da taxa de juros decrescente */
			call symputx('peculioMorteAtivo', PC_PECULIO_MINIMO_MORTE);
			call symputx('peculioMorteAssistido', VL_PECULIO_MORTE_ASSISTIDO);
			call symputx('LimPecMin', VL_PECULIO_MINIMO_MORTE);
			call symputx('VL_MAX_SALARIO_CAIXA', VL_SALARIO_CAIXA);
			call symputx('VL_TETO_INSS_CONTRIBUICAO', VL_TETO_INSS_CONTRIBUICAO);
			call symputx('TtInssBen', VL_TETO_INSS_BENEFICIO);
			call symputx('SalMinimo', VL_SALARIO_MINIMO);
			call symputx('VlrLxInicial', VL_INICIAL_LX);
			call symputx('TxCarregamentoAdm', PC_META_CUSTEIO_ADMIN);
			call symputx('FlCalculaFluxo', FL_FLUXO_RECEITA_DESPESA_FOLHA);
			call symputx('CdPlanBen', ID_PLANO_BENEFICIO);
			call symputx('IDPLANOPREV', IDPLANOPREV);
			call symputx('percentualBUA', PC_OPCAO_BUA);
			call symputx('percentualSaqueBUA', PC_SAQUE_BUA);
			call symputx('percentualSRB', perc_srb);
		RUN;

		%if (&id_avaliacao > 0) %then %do;
			libname SISATU "&root_dir.\Avaliacoes\&id_avaliacao.\";
			libname TABUAS "&root_dir.\Avaliacoes\&id_avaliacao.\Tabua\";
			libname COBERTUR "&root_dir.\Avaliacoes\&id_avaliacao.\Cobertura\";
			libname FLUXO "&root_dir.\Avaliacoes\&id_avaliacao.\Fluxo\";
			libname PREMISSA "&root_dir.\Avaliacoes\&id_avaliacao.\Premissa\";
			*libname DETERMIN "&root_dir.\Avaliacoes\&id_avaliacao.\Deterministico\";
			*libname ESTOCAST "&root_dir.\Avaliacoes\&id_avaliacao.\Estocastico\";
			libname PARTIC "&root_dir.\Avaliacoes\&id_avaliacao.\Participante\";
			libname RISCO "&root_dir.\Avaliacoes\&id_avaliacao.\Risco\";
			libname TEMP "&root_dir.\Avaliacoes\&id_avaliacao.\Temp\";
			run;
		%end;

		%_eg_conditional_dropds(premissa.avaliacao);
		data premissa.avaliacao;
			set work.avaliacao;
		run;

		%_eg_conditional_dropds(premissa.GLOBAL);
		PROC SQL;
		   CREATE TABLE premissa.GLOBAL AS 
		   SELECT (DATEPART(t1.DT_ORIGEM_BNH)) FORMAT=DDMMYY10. AS DT_ORIGEM_BNH,
				  (DATEPART(t1.DT_INICIO_LEI_9876_1999)) FORMAT=DDMMYY10. AS DT_INICIO_LEI_9876_1999,
				  (DATEPART(t1.DT_INICIO_MEDIA_80PC_MAIORES_S)) FORMAT=DDMMYY10. AS DT_INICIO_MEDIA_80PC_MAIORES_S
		      FROM ORACLE.TB_ATU_PARAMETRIZACAO t1
		      WHERE t1.DT_VIGENCIA_FIM IS MISSING
		      ORDER BY t1.ID_PARAMETRIZACAO DESC;
		RUN; quit;

		DATA _NULL_;
			SET premissa.GLOBAL;
			call symput('DtOrigBnh', DT_ORIGEM_BNH);
			call symput('DtLei9876', DT_INICIO_LEI_9876_1999);
			call symput('DatMedSal', DT_INICIO_MEDIA_80PC_MAIORES_S);
		RUN;

		%_eg_conditional_dropds(premissa.reajuste_salarial);
		PROC SQL;
		   CREATE TABLE premissa.REAJUSTE_SALARIAL AS 
		   SELECT t1.CD_TIPO_REAJUSTE_SALARIAL, 
		          t1.ID_PATROCINADORA as CdPatrocPlan, 
		          ((t1.PC_REAJUSTE / 100) + 1) format=12.8 as reajuste_salario
		      FROM ORACLE.TB_ATU_AVAL_PLANO_REAJ_SAL t1
		      WHERE t1.ID_AVALIACAO = &id_avaliacao
			  ORDER BY t1.ID_AVAL_PLANO_REAJ_SAL;
		RUN; quit;

		%_eg_conditional_dropds(premissa.INDEXADOR_MONETARIO);
		PROC SQL;
		   CREATE TABLE premissa.INDEXADOR_MONETARIO AS 
		   SELECT t1.ID_REFERENCIA_IDX_MON, 
		          t1.PC_REAJUSTE format=12.8
		      FROM ORACLE.TB_ATU_AVAL_PLANO_IDX_MON t1
			  WHERE t1.ID_AVALIACAO = &id_avaliacao
		      ORDER BY t1.ID_AVAL_PLANO_IDX_MON;
		RUN; quit;

		%_eg_conditional_dropds(premissa.COTACAO);
		PROC SQL;
		   CREATE TABLE premissa.COTACAO AS 
		   SELECT (DATEPART(t1.COTDATA)) FORMAT=DDMMYY10. AS COTDATA,
		          ((t1.COTVALOR / 100) + 1) AS COTVALOR
		      FROM ORACLE.COTACAOMOEDA t1
		      WHERE t1.MOECODIGO = 7
		      ORDER BY t1.COTDATA;
		RUN; quit;

		%_eg_conditional_dropds(temp.taxa_juros);
		proc sql;
			create table temp.taxa_juros as
			select t1.nr_tempo_taxa_juros as t, 
				   (t1.vl_taxa_juros / 100) as taxa_juros
			from oracle.tb_atu_avaliacao_taxa_juros t1
			where t1.id_avaliacao = &id_avaliacao
			order by t1.nr_tempo_taxa_juros;
		run; quit;

		PROC SQL NOPRINT;
			SELECT COUNT (*) INTO: numberOfTaxaJuros
			FROM temp.taxa_juros;

			SELECT max(t) into: maxTaxaJuros
			FROM temp.taxa_juros;
		RUN; quit;

		data temp.taxa_juros(keep = t taxa_juros desvio);
			call streaminit(123);
			a = 0.0000000000001;
			b = 0.0000000000001;

			set temp.taxa_juros;

			u = rand("Uniform");            /* decimal values in (0,1)    */
			desvio = a + (b - a) * u;       /* decimal values (a,b)       */
			output;

			format desvio 18.14;
		run;

		proc iml;
			use temp.taxa_juros;
				read all var {t taxa_juros desvio} into taxas;
			close;

			taxa_juros = J(&MaxAge + 1, 3, 0);
			a = 1;
			max_taxa = taxas[<>, 1];

			do j = 0 to &MaxAge;
				taxa_juros[j+1, 1] = j;
				taxa_juros[j+1, 2] = taxas[a, 2];
				taxa_juros[j+1, 3] = taxas[a, 3];
				
				if (a <= max_taxa) then
					a = a + 1;
			end;

			create temp.taxa_juros from taxa_juros[colname={'t' 'taxa_juros' 'desvio'}];
				append from taxa_juros;
			close temp.taxa_juros;
		quit;

		%_eg_conditional_dropds(premissa.taxa_juros);
		data premissa.taxa_juros;
			set temp.taxa_juros;
			format taxa_juros 10.6 desvio 18.14;
		run;

		%if (&tipoCalculo = 2) %then %do;
			%do s = 1 %to &numeroCalculos;
				%_eg_conditional_dropds(premissa.taxa_juros_s&s.);
				data premissa.taxa_juros_s&s.(drop = desvio);
					*call streaminit(123);
					set premissa.taxa_juros;

					taxa_juros = RAND('NORMAL', taxa_juros, desvio);
					output;

					format taxa_juros 8.4;
				run;
			%end;

			%_eg_conditional_dropds(work.taxa_salario);
			data work.taxa_salario(keep = t PC_TAXA_REAL_CRESC_SALARIAL desvio);
				retain t PC_TAXA_REAL_CRESC_SALARIAL desvio;
				call streaminit(-1);
				a = 0.0000000000001;
				b = 0.0000000000001;
				u = rand("Uniform");
				desvio = a + (b - a) * u;

				set premissa.avaliacao;

				do t = 0 to &MaxAge;
					output;
				end;

				format desvio 18.14;
			run;

			%do s = 1 %to &numeroCalculos;
				%_eg_conditional_dropds(premissa.taxa_salario_s&s.);
				data premissa.taxa_salario_s&s.(drop= PC_TAXA_REAL_CRESC_SALARIAL desvio);
					retain t taxa_salarial;
					*call streaminit(123);
					set work.taxa_salario;

					taxa_salarial = max(0, RAND('NORMAL', PC_TAXA_REAL_CRESC_SALARIAL, desvio));
					output;

					format taxa_salarial 8.4;
				run;
			%end;

			%_eg_conditional_dropds(work.taxa_beneficio);
			data work.taxa_beneficio(keep = t PC_TAXA_REAL_CRESC_BENEFICIO desvio);
				retain t PC_TAXA_REAL_CRESC_BENEFICIO desvio;
				call streaminit(-1);
				a = 0.0000000000001;
				b = 0.0000000000001;
				u = rand("Uniform");
				desvio = a + (b - a) * u;

				set premissa.avaliacao;

				do t = 0 to &MaxAge;
					output;
				end;

				format desvio 18.14;
			run;

			%do s = 1 %to &numeroCalculos;
				%_eg_conditional_dropds(premissa.taxa_beneficio_s&s.);
				data premissa.taxa_beneficio_s&s.(drop= PC_TAXA_REAL_CRESC_BENEFICIO desvio);
					retain t taxa_beneficio;
					*call streaminit(123);
					set work.taxa_salario;

					taxa_beneficio = max(0, RAND('NORMAL', PC_TAXA_REAL_CRESC_BENEFICIO, desvio));
					output;

					format taxa_beneficio 8.4;
				run;
			%end;
		%end;

		%_eg_conditional_dropds(premissa.taxa_risco);
		proc sql;
			create table premissa.taxa_risco as
			select t1.nr_tempo_taxa_risco as t,
				   t1.id_responsabilidade,
				   (t1.vl_taxa_risco / 100) as taxa_risco
			from oracle.tb_atu_avaliacao_taxa_risco t1
			where t1.id_avaliacao = &id_avaliacao
			order by t1.id_responsabilidade, t1.nr_tempo_taxa_risco;
		run; quit;

		PROC SQL NOPRINT;
			SELECT max(t) INTO: maxTaxaRiscoPartic
			FROM premissa.taxa_risco t1
			WHERE t1.id_responsabilidade = 1;

			SELECT max(t) INTO: maxTaxaRiscoPatroc
			FROM premissa.taxa_risco t1
			WHERE t1.id_responsabilidade = 2;
		RUN; quit;
	%end;
%mend;
%loadPremissas;


/*%macro calculaTaxaJurosEstocastico;*/
/*	%do s = 1 %to &numeroCalculos;*/
/*		%_eg_conditional_dropds(premissa.taxa_juros_s&s.);*/
/*		data premissa.taxa_juros_s&s.(drop = desvio);*/
/*			*call streaminit(123);*/
/*			set premissa.taxa_juros;*/

/*			taxa_juros = RAND('NORMAL', taxa_juros, desvio);*/
/*			output;*/

/*			format taxa_juros 8.4;*/
/*		run;*/
/*	%end;*/
/*%mend;*/
/*%calculaTaxaJurosEstocastico;*/

/*%macro calculaTaxaSalarioEstocastico;*/
/*	data work.taxa_salario(keep = t PC_TAXA_REAL_CRESC_SALARIAL desvio);*/
/*		retain t PC_TAXA_REAL_CRESC_SALARIAL desvio;*/
/*		call streaminit(-1);*/
/*		a = 0.0000000000001;*/
/*		b = 0.0000000000001;*/
/*		u = rand("Uniform");*/
/*		desvio = a + (b - a) * u;*/

/*		set premissa.avaliacao;*/

/*		do t = 0 to &MaxAge;*/
/*			output;*/
/*		end;*/

/*		format desvio 18.14;*/
/*	run;*/

/*	%do s = 1 %to &numeroCalculos;*/
/*		data premissa.taxa_salario_tp&tipoCalculo._s&s.(drop= PC_TAXA_REAL_CRESC_SALARIAL desvio);*/
/*			retain t taxa_salarial;*/
/*			*call streaminit(123);*/
/*			set work.taxa_salario;*/

/*			taxa_salarial = max(0, RAND('NORMAL', PC_TAXA_REAL_CRESC_SALARIAL, desvio));*/
/*			output;*/

/*			format taxa_salarial 8.4;*/
/*		run;*/
/*	%end;*/
/*%mend;*/
/*%calculaTaxaSalarioEstocastico;*/

/*%macro calculaTaxaBeneficioEstocastico;*/
/*	data work.taxa_beneficio(keep = t PC_TAXA_REAL_CRESC_BENEFICIO desvio);*/
/*		retain t PC_TAXA_REAL_CRESC_BENEFICIO desvio;*/
/*		call streaminit(-1);*/
/*		a = 0.0000000000001;*/
/*		b = 0.0000000000001;*/
/*		u = rand("Uniform");*/
/*		desvio = a + (b - a) * u;*/

/*		set premissa.avaliacao;*/

/*		do t = 0 to &MaxAge;*/
/*			output;*/
/*		end;*/

/*		format desvio 18.14;*/
/*	run;*/

/*	%do s = 1 %to &numeroCalculos;*/
/*		data premissa.taxa_beneficio_tp&tipoCalculo._s&s.(drop= PC_TAXA_REAL_CRESC_BENEFICIO desvio);*/
/*			retain t taxa_beneficio;*/
/*			*call streaminit(123);*/
/*			set work.taxa_salario;*/

/*			taxa_beneficio = max(0, RAND('NORMAL', PC_TAXA_REAL_CRESC_BENEFICIO, desvio));*/
/*			output;*/

/*			format taxa_beneficio 8.4;*/
/*		run;*/
/*	%end;*/
/*%mend;*/
/*%calculaTaxaBeneficioEstocastico;*/

proc datasets library=temp kill memtype=data nolist;
proc datasets library=work kill memtype=data nolist;
	run;
quit;
