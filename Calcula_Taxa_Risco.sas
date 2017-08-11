

%macro calculaTaxaRisco;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(work.ativos_reservas_tp&tipoCalculo._s&s.);
		%_eg_conditional_dropds(work.ativos_folha_salarial_tp&tipoCalculo._s&s.);
		
		proc sql;
			create table work.ativos_reservas_tp&tipoCalculo._s&s. as
			select t1.id_participante,
				   t1.t1,
				   (case
						when t1.flg_manutencao_saldo = 1 and &CdPlanBen <> 2
							then 0
							else max(0, ((t1.salario_contrib / &FtSalPart) * f1.pxs * &NroBenAno * (1 - f1.apxa)))
					end) format=commax14.2 as FolhaSalarial,
					(case
						when &CdPlanBen = 2
							then max(0, t1.VlBenSaldado * &FtBenLiquido * f1.pxs * &NroBenAno * (1 - f1.apxa))
							else 0
					end) format=commax14.2 as FolhaBenSaldado,
					max(0, t1.saldo_conta_partic + t1.saldo_conta_patroc) format=commax14.2 as SaldoContaTotal,
					max(0, t1.beneficio_liquido_aiv * f1.axiicb * &NroBenAno) format=commax14.2 as EncargoAIV,
					max(0, t1.beneficio_liquido_piv * f1.amix * &NroBenAno) format=commax14.2 as EncargoPIV,
					max(0, p1.beneficio_pmi * f1.Axii) format=commax14.2 as EncargoPMI,
					max(0, t1.beneficio_liquido_ppa * f1.ajxcb * &NroBenAno * t1.probab_casado) format=commax14.2 as EncargoPPA,
					max(0, p2.beneficio_pma) format=commax14.2 as EncargoPMA
			from cobertur.ativos_tp&tipoCalculo._s&s. t1
			inner join cobertur.ativos_fatores f1 on (t1.id_participante = f1.id_participante and t1.t1 = f1.t1)
			inner join temp.ativos_fluxo_pmi_tp&tipoCalculo._s&s. p1 on (p1.id_participante = t1.id_participante and p1.t1 = t1.t1 and p1.t1 = p1.t2)
			inner join temp.ativos_fluxo_pma_tp&tipoCalculo._s&s. p2 on (p2.id_participante = t1.id_participante and p2.t1 = t1.t1)
			order by t1.id_participante, t1.t1;

			%if (&tipoCalculo = 1) %then %do;
				create table work.ativos_folha_salarial_tp&tipoCalculo._s&s. as
				select t1.id_participante,
					   t1.t1,
						max(0, ((t1.salario_contrib / &FtSalPart) * f1.pxs * &NroBenAno * (1 - f1.apxa) * 1 / ((1 + tx1.taxa_juros) ** t1.t1))) format=commax14.2 as FolhaSalarialVP
				from cobertur.ativos_tp&tipoCalculo._s&s. t1
				inner join cobertur.ativos_fatores f1 on (t1.id_participante = f1.id_participante and t1.t1 = f1.t1)
				left join premissa.taxa_juros tx1 on (t1.t1 = tx1.t)
				order by t1.id_participante, t1.t1;
			%end;
			%else %do;
				create table work.ativos_folha_salarial_tp&tipoCalculo._s&s. as
				select t1.id_participante,
					   t1.t1,
					   max(0, ((t1.salario_contrib / &FtSalPart) * f1.pxs * &NroBenAno * (1 - f1.apxa) * 1 / ((1 + tx2.taxa_juros) ** t1.t1))) format=commax14.2 as FolhaSalarialVP
				from cobertur.ativos_tp&tipoCalculo._s&s. t1
				inner join cobertur.ativos_fatores f1 on (t1.id_participante = f1.id_participante and t1.t1 = f1.t1)
				left join premissa.taxa_juros_s&s. tx2 on (t1.t1 = tx2.t)
				order by t1.id_participante, t1.t1;
			%end;
		quit;

		data work.ativos_reservas_tp&tipoCalculo._s&s.;
			merge work.ativos_reservas_tp&tipoCalculo._s&s. work.ativos_folha_salarial_tp&tipoCalculo._s&s.;
			by id_participante t1;
		run;

		%_eg_conditional_dropds(work.ativos_encargo_risco_tp&tipoCalculo._s&s.);
		proc sql;
			create table work.ativos_encargo_risco_tp&tipoCalculo._s&s. as
			select t1.id_participante,
					t1.t1,
					max(0, ((t1.EncargoAIV + t1.EncargoPIV + t1.EncargoPMI) - t1.SaldoContaTotal) * a1.ix * (1 - a1.apxa)) format=commax14.2 as CustoNormalInvalidez,
					max(0, (max(0, t1.EncargoPPA - t1.SaldoContaTotal) + t1.EncargoPMA) * a1.qx * (1 - a1.apxa)) format=commax14.2 as CustoNormalMorte
			from work.ativos_reservas_tp&tipoCalculo._s&s. t1
			inner join cobertur.ativos_fatores a1 on (a1.id_participante = t1.id_participante and a1.t1 = t1.t1)
			order by t1.id_participante, t1.t1;
		quit;

		%_eg_conditional_dropds(risco.ativos_folha_salarial_tp&tipoCalculo._s&s.);
		data risco.ativos_folha_salarial_tp&tipoCalculo._s&s.;
			merge work.ativos_reservas_tp&tipoCalculo._s&s. work.ativos_encargo_risco_tp&tipoCalculo._s&s.;
			by id_participante t1;
		run;

		%_eg_conditional_dropds(risco.ativos_taxa_risco_tp&tipoCalculo._s&s.);
		proc sql;
			create table risco.ativos_taxa_risco_tp&tipoCalculo._s&s. as
			select enc.t1,
					max(0, sum(enc.FolhaSalarial)) format=commax18.2 as FolhaSalarial,
					max(0, sum(enc.FolhaSalarialVP)) format=commax18.2 as FolhaSalarialVP,
					max(0, sum(enc.SaldoContaTotal)) format=commax18.2 as SaldoContaTotal,
					max(0, sum(enc.FolhaBenSaldado)) format=commax18.2 as FolhaBenSaldado,
					max(0, sum(enc.EncargoAIV)) format=commax18.2 as EncargoAIV,
					max(0, sum(enc.EncargoPIV)) format=commax18.2 as EncargoPIV,
					max(0, sum(enc.EncargoPMI)) format=commax18.2 as EncargoPMI,
					max(0, sum(enc.EncargoPPA)) format=commax18.2 as EncargoPPA,
					max(0, sum(enc.EncargoPMA)) format=commax18.2 as EncargoPMA,
					max(0, sum(enc.CustoNormalInvalidez)) format=commax18.2 as CustoNormalInvalidez,
					max(0, sum(enc.CustoNormalMorte)) format=commax18.2 as CustoNormalMorte,
				   max(0, (sum(enc.CustoNormalInvalidez + enc.CustoNormalMorte) / sum(enc.FolhaSalarial))) format=10.6 as TaxaRisco
			from risco.ativos_folha_salarial_tp&tipoCalculo._s&s. enc
			group by enc.t1
			order by enc.t1;
		quit;
	%end;
%mend;
%calculaTaxaRisco;

proc datasets library=work kill memtype=data nolist;
	run;
quit;