
%macro calculaEncargoDespesaAtivos;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(sisatu.ativos_encargos_tp&tipoCalculo._s&s.);
		PROC SQL;
			CREATE TABLE sisatu.ativos_encargos_tp&tipoCalculo._s&s. AS 
			SELECT t2.id_participante,
			      t2.NuMatrPartic, 
			      atc.DespesaVpATC as EncargoATC, 
			      ptc.DespesaVpPTC as EncargoTotPtc, 
			      pmc.DespesaVpPMC as EncargoTotPmc, 
			      aiv.DespesaVpAIV as EncargoTotAiv, 
			      piv.DespesaVpPIV as EncargoTotPiv, 
			      pmi.DespesaVpPMI as EncargoTotPmi, 
			      ppa.DespesaVpPPA as EncargoTotPpa, 
			      pma.DespesaVpPMA as EncargoTotPma,
			        (atc.DespesaVpAtc + ptc.DespesaVpPtc + pmc.DespesaVpPmc + aiv.DespesaVpAiv + piv.DespesaVpPiv + 
			        pmi.DespesaVpPmi + ppa.DespesaVpPpa + pma.DespesaVpPma) FORMAT=COMMAX14.2 AS EncargoTotal,
			        axfa.CusNorCobAXFA,
			        axfi.CusNorCobAXFI,
			        vacf.VACFParticipanteProgramada,
			        vacf.VACFParticipanteRisco,
			        vacf.VACFPatrocinadoraProgramada,
			        vacf.VACFPatrocinadoraRisco,
					rot.DespesaResgateVP,
					rot.DespesaPortabilidadeVP
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
		            i1.t,
		            (case
		                   when (i1.t = 0 and no.apxa = 1) then 1
		                   else (max(0, (aje.lxs / aj.lxs) * (1 - no.apxa)))
		              end) format=.10 as QtdeParticipantes,
		              (case
		                   when (i1.t = 0 and no.apxa = 1) then 0
		                    else (max(0, (aje.lxs / aj.lxs) * no.apxa))
		              end) format=.10 as QtdeElegiveis
		    from cobertur.ativos i1
		    inner join tabuas.tabuas_servico_normal no on (i1.CdSexoPartic = no.Sexo and i1.IddParticCobert = no.Idade and no.t = min(i1.t, &maxTaxaJuros))
		    inner join tabuas.tabuas_servico_ajustada aj on (i1.CdSexoPartic = aj.Sexo and i1.IddPartiCalc = aj.Idade and aj.t = 0)
		    inner join tabuas.tabuas_servico_ajustada aje on (i1.CdSexoPartic = aje.Sexo and i1.IddParticCobert = aje.Idade and aje.t = min(i1.t, &maxTaxaJuros))
		    order by i1.id_participante, i1.t;
		quit;

		 %_eg_conditional_dropds(sisatu.ativos_quantidade_tp&tipoCalculo._s&s.);
		 proc sql;
		      create table sisatu.ativos_quantidade_tp&tipoCalculo._s&s. as
		      select qtd.t, sum(qtd.QtdeParticipantes) as QtdeParticipantes, sum(qtd.QtdeElegiveis) as QtdeElegiveis
		      from work.quant_parcial_ativos_tp&tipoCalculo._s&s. qtd
		      group by qtd.t
		      order by qtd.t;
		 quit;

		 %_eg_conditional_dropds(work.ativos_despesa_sld_conta_tp&tipoCalculo._s&s.);
		 proc sql;
		      create table work.ativos_despesa_sld_conta_tp&tipoCalculo._s&s. as
		      select t1.t, 
					 max(0, sum(t1.VlSdoConPartEvol)) format=commax18.2 as VlSdoConPart, 
					 max(0, sum(t1.VlSdoConPatrEvol)) format=commax18.2 as VlSdoConPatr
		      from cobertur.ativos_tp&tipoCalculo._s&s. t1
		      group by t1.t
		      order by t1.t;
		 quit;
		 
		%_eg_conditional_dropds(sisatu.ativos_despesas_tp&tipoCalculo._s&s.);
		proc sql;
		     create table sisatu.ativos_despesas_tp&tipoCalculo._s&s. as
		     select qtat.t, 
		            qtat.QtdeParticipantes,
		            qtat.QtdeElegiveis,
		            atc.DespesaATC,
		            ptc.DespesaPTC,
		            pmc.DespesaPMC,
		            aiv.DespesaAIV,
		            piv.DespesaPIV,
		            pmi.DespesaPMI,
		            ppa.DespesaPPA,
		            pma.DespesaPMA,
		            res.DespesaResgate,
		            res.DespesaPortabilidade,
		            vacf.ReceitaParticipanteProgramada,
					vacf.ReceitaParticipanteRisco,
					vacf.ReceitaPatrocinadoraProgramada,
					vacf.ReceitaPatrocinadoraRisco,
					sdc.VlSdoConPart,
					sdc.VlSdoConPatr,
		            atc.DespesaVpATC,
		            ptc.DespesaVpPTC,
		            pmc.DespesaVpPMC,
		            aiv.DespesaVpAIV,
		            piv.DespesaVpPIV,
		            pmi.DespesaVpPMI,
		            ppa.DespesaVpPPA,
		            pma.DespesaVpPMA,
					res.DespesaResgateVP,
					res.DespesaPortabilidadeVP,
		            vacf.VACFParticipanteProgramada,
		            vacf.VACFParticipanteRisco,
		            vacf.VACFPatrocinadoraProgramada,
		            vacf.VACFPatrocinadoraRisco
		     from sisatu.ativos_quantidade_tp&tipoCalculo._s&s. qtat
		     inner join fluxo.ativos_despesa_atc_tp&tipoCalculo._s&s. atc on (qtat.t = atc.tFluxo)
		     inner join fluxo.ativos_despesa_ptc_tp&tipoCalculo._s&s. ptc on (qtat.t = ptc.tFluxo)
		     inner join fluxo.ativos_despesa_pmc_tp&tipoCalculo._s&s. pmc on (qtat.t = pmc.tFluxo)
		     inner join fluxo.ativos_despesa_aiv_tp&tipoCalculo._s&s. aiv on (qtat.t = aiv.tFluxo)
		     inner join fluxo.ativos_despesa_piv_tp&tipoCalculo._s&s. piv on (qtat.t = piv.tFluxo)
		     inner join fluxo.ativos_despesa_pmi_tp&tipoCalculo._s&s. pmi on (qtat.t = pmi.tFluxo)
		     inner join fluxo.ativos_despesa_ppa_tp&tipoCalculo._s&s. ppa on (qtat.t = ppa.tFluxo)
		     inner join fluxo.ativos_despesa_pma_tp&tipoCalculo._s&s. pma on (qtat.t = pma.tCober)
		     inner join fluxo.ativos_despesa_portab_tp&tipoCalculo._s&s. res on (qtat.t = res.t)
		     inner join fluxo.ativos_receita_vacf_tp&tipoCalculo._s&s. vacf on (qtat.t = vacf.t)
			 inner join work.ativos_despesa_sld_conta_tp&tipoCalculo._s&s. sdc on (qtat.t = sdc.t)
		     order by qtat.t;
		quit;
	%end;
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


