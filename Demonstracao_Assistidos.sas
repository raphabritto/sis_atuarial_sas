
%_eg_conditional_dropds(work.quant_assistidos_fluxo);
proc sql;
	create table work.quant_assistidos_fluxo as
	select a1.id_participante, 
		   a1.t,
		   (case
/*				when ((a1.CdTipoBenefi = 1 or a1.CdTipoBenefi = 2) or (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 0 and a1.IddPartiCalc >= &MaiorIdad))*/
		   		when (a1.TipoAssistido = 1 | a1.TipoAssistido = 3)
				then (nod.lx / no.lx)
				else 0
			end) as QtdAssistidosValidos,
		   (case
/*				   		when (a1.CdTipoBenefi = 3 or (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 1))*/
	   			when (a1.TipoAssistido = 2 | a1.TipoAssistido = 4)
				then (nod.lxii / no.lxii)
				else 0
			end) as QtdAssistidosInvalidos,
			(case
/*				when (a1.CdTipoBenefi = 4 and a1.FL_DEFICIENTE = 0 and i1.IddPartiEvol < &MaiorIdad)*/
				when (a1.TipoAssistido = 5 and a1.IddPartiEvol < &MaiorIdad)
				then 1
				else 0
			end) as QtdPensionistaTemporario
	from fluxo.assistidos a1
	inner join tabuas.tabuas_servico_normal no on (a1.CdSexoPartic = no.Sexo and a1.IddPartiCalc = no.Idade and no.t = 0)
	inner join tabuas.tabuas_servico_normal nod on (a1.CdSexoPartic = nod.Sexo and a1.IddPartiEvol = nod.Idade and nod.t = min(a1.t, &maxTaxaJuros))
	order by a1.id_participante, a1.t;
quit;

%_eg_conditional_dropds(work.quantidade_assistidos);
proc sql;
	create table work.quantidade_assistidos as
	select qtd.t,
		   sum(qtd.QtdAssistidosValidos) as QtdAssistidosValidos, 
		   sum(qtd.QtdAssistidosInvalidos) as QtdAssistidosInvalidos,
		   sum(qtd.QtdPensionistaTemporario) as QtdPensionistaTemporario
	from work.quant_assistidos_fluxo qtd
	group by qtd.t
	order by qtd.t;
quit;


%macro despesaAssistidos;
	%do s = 1 %to &numeroCalculos;
		%_eg_conditional_dropds(sisatu.assistidos_despesas_tp&tipoCalculo._s&s.);
		data sisatu.assistidos_despesas_tp&tipoCalculo._s&s.;
			merge fluxo.assistidos_despesa_tp&tipoCalculo._s&s. work.quantidade_assistidos;
		run;

		%_eg_conditional_dropds(sisatu.demonstracao_assistido_tp&tipoCalculo._s&s.);
		proc sql;
			create table sisatu.demonstracao_assistido_tp&tipoCalculo._s&s. as
			select (case
						when t1.CdTipoBenefi = 1 then 'Aposentadoria tempo de contribuição'
						when t1.CdTipoBenefi = 2 then 'Aposentadoria especial'
						when t1.CdTipoBenefi = 3 then 'Aposentadoria invalidez'
						else 'Pensão'
					end) as TipoBeneficio,
				   count(t1.id_participante) as QuantAssistidos,
				   sum(t1.VlBenefiPrev) format=commax18.2 as ValorMedioBeneficio,
				   mean(t1.IddPartiCalc) format=commax18.2 as IdadeMedia,
				   sum(t3.ResMatTotal) format=commax18.2 as ReservaMatematica
			from partic.assistidos t1
			inner join cobertur.assistidos t3 on (t1.id_participante = t3.id_participante)
			group by t1.CdTipoBenefi;
		quit;
	%end;
%mend;
%despesaAssistidos;
