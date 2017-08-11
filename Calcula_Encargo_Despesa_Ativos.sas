
%macro calculaEncargoDespesaAtivos;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(sisatu.ativos_encargos_tp&tipoCalculo._s&s.);
		PROC SQL;
			CREATE TABLE sisatu.ativos_encargos_tp&tipoCalculo._s&s. AS 
			SELECT t2.id_participante,
			      t2.NuMatrPartic, 
			      atc.despesa_vp_ATC as EncargoATC, 
			      ptc.despesa_vp_PTC as EncargoTotPtc, 
			      pmc.despesa_vp_PMC as EncargoTotPmc, 
			      aiv.despesa_vp_AIV as EncargoTotAiv, 
			      piv.despesa_vp_PIV as EncargoTotPiv, 
			      pmi.despesa_vp_PMI as EncargoTotPmi, 
			      ppa.despesa_vp_PPA as EncargoTotPpa, 
			      pma.despesa_vp_PMA as EncargoTotPma,
			        (atc.despesa_vp_Atc + ptc.despesa_vp_Ptc + pmc.despesa_vp_Pmc + aiv.despesa_vp_Aiv + piv.despesa_vp_Piv + 
			        pmi.despesa_vp_Pmi + ppa.despesa_vp_Ppa + pma.despesa_vp_Pma) FORMAT=COMMAX14.2 AS EncargoTotal,
			        axfa.AUX_FUNERAL_ATIVO,
			        axfi.AUX_FUNERAL_INVALIDO,
			        vacf.VACF_PROG_PARTIC,
			        vacf.VACF_RISCO_PARTIC,
			        vacf.VACF_PROG_PATROC,
			        vacf.VACF_RISCO_PATROC,
					rot.DESPESA_VP_RESGAT,
					rot.DESPESA_VP_PORTAB
			from partic.ATIVOS t2 
			INNER JOIN fluxo.ativos_encargo_atc_tp&tipoCalculo._s&s. atc ON (t2.ID_PARTICIPANTE = atc.id_participante)
			inner JOIN fluxo.ativos_encargo_ptc_tp&tipoCalculo._s&s. ptc ON (t2.ID_PARTICIPANTE = ptc.id_participante)
			INNER JOIN fluxo.ativos_encargo_pmc_tp&tipoCalculo._s&s. pmc ON (t2.ID_PARTICIPANTE = pmc.id_participante)
			inner JOIN fluxo.ativos_encargo_aiv_tp&tipoCalculo._s&s. aiv ON (t2.ID_PARTICIPANTE = aiv.id_participante)
			inner JOIN fluxo.ativos_encargo_piv_tp&tipoCalculo._s&s. piv ON (t2.ID_PARTICIPANTE = piv.id_participante)
			INNER JOIN fluxo.ativos_encargo_pma_tp&tipoCalculo._s&s. pma ON (t2.ID_PARTICIPANTE = pma.id_participante)
			inner JOIN fluxo.ativos_encargo_pmi_tp&tipoCalculo._s&s. pmi ON (t2.ID_PARTICIPANTE = pmi.id_participante)
			inner JOIN fluxo.ativos_encargo_ppa_tp&tipoCalculo._s&s. ppa ON (t2.ID_PARTICIPANTE = ppa.id_participante)
			INNER JOIN cobertur.ativos_encargo_axfa_tp&tipoCalculo._s&s. axfa ON (t2.id_participante = axfa.id_participante)
			inner JOIN cobertur.ativos_encargo_axfi_tp&tipoCalculo._s&s. axfi ON (t2.ID_PARTICIPANTE = axfi.id_participante)
			INNER JOIN fluxo.ativos_encargo_vacf_tp&tipoCalculo._s&s. vacf ON (t2.ID_PARTICIPANTE = vacf.id_participante) 
			inner join fluxo.ativos_encargo_portab_tp&tipoCalculo._s&s. rot on (t2.ID_PARTICIPANTE = rot.id_participante) 
			order by t2.id_participante;
		QUIT;

		%_eg_conditional_dropds(work.quant_parcial_ativos_tp&tipoCalculo._s&s.);
		proc sql;
		    create table work.quant_parcial_ativos_tp&tipoCalculo._s&s. as
		    select i1.id_participante, 
		            i1.t1,
		            (case
		                   when (i1.t1 = 0 and no.apxa = 1) then 1
		                   else (max(0, (aje.lxs / aj.lxs) * (1 - no.apxa)))
		              end) format=.10 as QtdeParticipantes,
		              (case
		                   when (i1.t1 = 0 and no.apxa = 1) then 0
		                    else (max(0, (aje.lxs / aj.lxs) * no.apxa))
		              end) format=.10 as QtdeElegiveis
		    from cobertur.ativos i1
		    inner join tabuas.tabuas_servico_normal no on (i1.sexo_partic = no.Sexo and i1.idade_partic_cober = no.Idade and no.t = min(i1.t1, &maxTaxaJuros))
		    inner join tabuas.tabuas_servico_ajustada aj on (i1.sexo_partic = aj.Sexo and i1.idade_partic = aj.Idade and aj.t = 0)
		    inner join tabuas.tabuas_servico_ajustada aje on (i1.sexo_partic = aje.Sexo and i1.idade_partic_cober = aje.Idade and aje.t = min(i1.t1, &maxTaxaJuros))
		    order by i1.id_participante, i1.t1;
		quit;

		 %_eg_conditional_dropds(work.ativos_quantidade_tp&tipoCalculo._s&s.);
		 proc sql;
		      create table work.ativos_quantidade_tp&tipoCalculo._s&s. as
		      select qtd.t1, sum(qtd.QtdeParticipantes) as QtdeParticipantes, sum(qtd.QtdeElegiveis) as QtdeElegiveis
		      from work.quant_parcial_ativos_tp&tipoCalculo._s&s. qtd
		      group by qtd.t1
		      order by qtd.t1;
		 quit;

		 %_eg_conditional_dropds(work.ativos_desp_sld_conta_tp&tipoCalculo._s&s.);
		 proc sql;
		      create table work.ativos_desp_sld_conta_tp&tipoCalculo._s&s. as
		      select t1.t1, 
					 max(0, sum(t1.saldo_conta_partic)) format=commax18.2 as VlSdoConPart, 
					 max(0, sum(t1.saldo_conta_patroc)) format=commax18.2 as VlSdoConPatr
		      from cobertur.ativos_tp&tipoCalculo._s&s. t1
		      group by t1.t1
		      order by t1.t1;
		 quit;
		 
		%_eg_conditional_dropds(sisatu.ativos_despesas_tp&tipoCalculo._s&s.);
		proc sql;
		     create table sisatu.ativos_despesas_tp&tipoCalculo._s&s. as
		     select &s. as simulacao,
					qtat.t1, 
		            qtat.QtdeParticipantes,
		            qtat.QtdeElegiveis,
		            atc.Despesa_ATC,
		            ptc.Despesa_PTC,
		            pmc.Despesa_PMC,
		            aiv.Despesa_AIV,
		            piv.Despesa_PIV,
		            pmi.Despesa_PMI,
		            ppa.Despesa_PPA,
		            pma.Despesa_PMA,
		            res.DESPESA_RESGAT,
		            res.DESPESA_PORTAB,
		            vacf.RECEITA_PROG_PARTIC,
					vacf.RECEITA_RISCO_PARTIC,
					vacf.RECEITA_PROG_PATROC,
					vacf.RECEITA_RISCO_PATROC,
					sdc.VlSdoConPart,
					sdc.VlSdoConPatr,
		            atc.despesa_vp_ATC,
		            ptc.despesa_vp_PTC,
		            pmc.despesa_vp_PMC,
		            aiv.despesa_vp_AIV,
		            piv.despesa_vp_PIV,
		            pmi.despesa_vp_PMI,
		            ppa.despesa_vp_PPA,
		            pma.despesa_vp_PMA,
					res.DESPESA_VP_RESGAT,
					res.DESPESA_VP_PORTAB,
		            vacf.VACF_PROG_PARTIC,
		            vacf.VACF_RISCO_PARTIC,
		            vacf.VACF_PROG_PATROC,
		            vacf.VACF_RISCO_PATROC,
					max(0, (atc.Despesa_ATC + ptc.Despesa_PTC + pmc.Despesa_PMC + aiv.Despesa_AIV + piv.Despesa_PIV + pmi.Despesa_PMI + ppa.Despesa_PPA +
		            pma.Despesa_PMA + res.DESPESA_RESGAT + res.DESPESA_PORTAB)) format=commax18.2 as DESPESA,
					max(0, (vacf.RECEITA_PROG_PARTIC + vacf.RECEITA_RISCO_PARTIC + vacf.RECEITA_PROG_PATROC + vacf.RECEITA_RISCO_PATROC)) format=commax18.2 as RECEITA,
					(calculated DESPESA - calculated RECEITA) format=commax18.2 as DESPESA_LIQUIDA
		     from work.ativos_quantidade_tp&tipoCalculo._s&s. qtat
		     inner join fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s. atc on (qtat.t1 = atc.t2)
		     inner join fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s. ptc on (qtat.t1 = ptc.t2)
		     inner join fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s. pmc on (qtat.t1 = pmc.t2)
		     inner join fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s. aiv on (qtat.t1 = aiv.t2)
		     inner join fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s. piv on (qtat.t1 = piv.t2)
		     inner join fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s. pmi on (qtat.t1 = pmi.t2)
		     inner join fluxo.ativos_despesa_ppa_tp&tipoCalculo._s&s. ppa on (qtat.t1 = ppa.t2)
		     inner join fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s. pma on (qtat.t1 = pma.t1)
		     inner join fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s. res on (qtat.t1 = res.t1)
		     inner join fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s. vacf on (qtat.t1 = vacf.t1)
			 inner join work.ativos_desp_sld_conta_tp&tipoCalculo._s&s. sdc on (qtat.t1 = sdc.t1)
		     order by qtat.t1;
		quit;
	%end;

	data sisatu.ativos_despesa_tp&tipoCalculo.;
		set sisatu.ativos_despesas_tp&tipoCalculo._s1 - sisatu.ativos_despesas_tp&tipoCalculo._s&numeroCalculos;
	run;
%mend;
%calculaEncargoDespesaAtivos;

%_eg_conditional_dropds(sisatu.ativo_demonstracao_atuarial);
proc sql;
     create table sisatu.ativo_demonstracao_atuarial as
     select count(t1.id_participante) as QuantParticipantes,
             round((sum(t1.TmpPlanoPrev) / count(t1.id_participante))) * 12 as TempoMedioContribuicao,
             round((sum(t1.TmpPlanoRest) / count(t1.id_participante)) * 12) as TempoMedioFaltanteAposent,
             sum(t1.VlSalEntPrev) format=commax14.2 as SalarioParticipacao
     from partic.ativos t1;
quit;

proc datasets library=work kill memtype=data nolist;
	run;
quit;
